Param(
    [Parameter(Mandatory=$true)]
    [String]$ScriptFullPath,

    [Parameter(Mandatory=$false)]
    [hashtable]$ScriptArguments
)

$ErrorActionPreference = "Stop";

Function Reset-StopwatchCollection {
    Remove-Variable -Scope Global -Name StopwatchCollection -ErrorAction Ignore;
    Remove-Variable -Scope Global -Name StopwatchLapTimes   -ErrorAction Ignore;

    $Global:StopwatchCollection = @{};
    $Global:StopwatchLapTimes = @{};
    $Global:InvalidRegionsAndFunctions = @();
}
Function Start-Stopwatch {
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Label
    )
    
    $MyFunctionName = $MyInvocation.MyCommand;
    $LineNumber = (Get-PSCallStack `
                        | WHERE { `
                                 ($_.InvocationInfo.MyCommand.Name        -ine  $MyFunctionName) `
                            -and ($_.Position.Text                        -like "$MyFunctionName *") `
                                } `
                            | SELECT -ExpandProperty ScriptLineNumber);
    
    # Instantiate new stopwatch collection or check for key collision
    If ($Global:StopwatchCollection -isnot [hashtable]) {
       Write-Error "You must call 'Reset-StopwatchCollection' first.";
    }

    # If stopwatch does not exist, create it
    If (-not $Global:StopwatchCollection.ContainsKey($Label)) {
        $Stopwatch = [system.diagnostics.stopwatch]::New();
        $Stopwatch | Add-Member -MemberType NoteProperty `
                             -Name       Label `
                             -Value      $Label;
        $Stopwatch | Add-Member -MemberType NoteProperty `
                             -Name       LineNumberStart `
                             -Value      $LineNumber;
        $Stopwatch | Add-Member -MemberType NoteProperty `
                             -Name       LineNumberFinish `
                             -Value      -1;
        $Global:StopwatchCollection.Add($Label,$Stopwatch);
    }
    Else {
        # A stopwatch by this label already exists.
        # Verify the LineNumberStart is the same.

        If ($Global:StopwatchCollection[$Label].LineNumberStart -ne $LineNumber) {
            Write-Error "The stopwatch '$Label' has been started with a new line number.  Choose a new label, instead.";
        }
    }
    
    $Global:StopwatchCollection[$Label].Restart();
}
Function Add-StopwatchLap {
    Param(
        [Parameter(Mandatory=$true)]
        [String]$Label

        #[Parameter(Mandatory=$true)]
        #[ValidateSet("ContinueToRun", "ResetToZeroAndRun", "Stop")]
        #[String]$Action
    )

    $MyFunctionName = $MyInvocation.MyCommand;
    $LineNumber = (Get-PSCallStack `
                        | WHERE { `
                                 ($_.InvocationInfo.MyCommand.Name        -ine  $MyFunctionName) `
                            -and ($_.Position.Text                        -like "$MyFunctionName *") `
                                } `
                        | SELECT -ExpandProperty ScriptLineNumber);
                        
    # Test if stopwatch exists
    If (-not $Global:StopwatchCollection.ContainsKey($Label)) {
        Write-Error "There is no stopwatch in `$Global:StopwatchCollection called '$Label'.";
    }

    # Extract this single stopwatch
    $Stopwatch = $Global:StopwatchCollection[$Label];
    
    # Test if stopwatch is not running
    If ($Stopwatch.IsRunning -eq $false) {
        Write-Error "Cannot add lap from stopwatch '$Label' because it is not running";
    }

    $Stopwatch.stop();

    If ($Stopwatch.LineNumberFinish -eq -1) {
        # This is the first time this stopwatch has been used.
        # It is safe to apply the finishing line number.

        $Stopwatch.LineNumberFinish = $LineNumber;
    }
    ElseIf ($Stopwatch.LineNumberFinish -ne $LineNumber) {
            Write-Error "The stopwatch '$Label' has been lapped with a new line number.  Set up a different stopwatch, instead.";
    }

    # Create a new ArrayList for stopwatch $Label if one does not already exist
    If (-not $Global:StopwatchLapTimes.ContainsKey($Label)) {
        $Global:StopwatchLapTimes.Add($Label,([System.Collections.ArrayList]::new()));
    }

    $Global:StopwatchLapTimes[$Label].add($Stopwatch.Elapsed.TotalMilliseconds) | Out-Null;

}
Function Get-StopwatchReport {
    Param(
        [String]$Label = "*"
    )

    If ($Label -ne "*") {
        # A specific stopwatch has been chosen

        If (-not $Global:StopwatchCollection.ContainsKey($Label)) {
            Write-Error "There is no stopwatch in `$Global:StopwatchCollection called '$Label'.";
        }

        [Array]$Labels = $Label;
    }
    Else {
        # All stopwatches have been chosen

        [Array]$Labels = $Global:StopwatchLapTimes.Keys;
    }

    $ReportCollection = New-Object System.Collections.ArrayList;

    ForEach ($Label in $Labels) {
        [Array]$LapTimes = $Global:StopwatchLapTimes[$Label];

        $Report = [PSCustomObject][Ordered]@{
                    Stopwatch      = $Label
                    Max_MS         = [Int](($LapTimes | Measure -Maximum).Maximum)
                    Avg_MS         = [Int](($LapTimes | Measure -Average).Average)
                    Min_MS         = [Int](($LapTimes | Measure -Minimum).Minimum)
                    Total_MS       = [Int](($LapTimes | Measure -Sum    ).sum)
                    Total_Sec      = [Int](($LapTimes | Measure -Sum   ).sum/1000)
                    Total_Min      = [Int](($LapTimes | Measure -Sum   ).sum/1000/60)
                    ExecutionCount = $LapTimes.Count
                    Line_Start     = $Global:StopwatchCollection[$Label].LineNumberStart  - 44444444
                    Line_Finish    = $Global:StopwatchCollection[$Label].LineNumberFinish - 44444444
                }

        $ReportCollection.Add($Report) | Out-Null;
    }
    If ($ReportCollection.Count -gt 0) {
        Write-Output ($ReportCollection | SORT Total_Sec -Descending);
    }
    Else {
        Write-Output "Cannot generate report; no lap times were recorded.";
    }
}

Function Get-ScriptAsOneLine {
    Param(
        [Parameter(Mandatory=$true)]
        [String]$FileName
    )

    $ScriptAsOneLine    = Get-Content -LiteralPath $FileName -Raw;
    
    Write-Output $ScriptAsOneLine -NoEnumerate;
}
Function Get-Functions {
    Param(
        [Parameter(Mandatory=$true)]
        [String]$ScriptAsOneLine
    )
    
    <#
    $FunctionList = $ScriptAsOneLine | Select-String -Pattern '[ \t]*Function[\s]+(?<FunctionName>\S+)[\n\s]*{' -AllMatches;
    
    
    $FunctionList = $FunctionList.Matches | SELECT -Property `
                                            @{Name="Type";           Expression={"Function"}}, `
                                            @{Name="Name";           Expression={$_.Groups[1].Value}}, `
                                            @{Name="OpeningBracket"; Expression={$_.Index + $_.Length -1}}, `
                                            @{Name="ClosingBracket"; Expression={0}};
    #>
    $FunctionList = $ScriptAsOneLine | Select-String -Pattern '[ \t]*Function[\s\t]+(?<FunctionName>\S+)[\n\s]*(?<OpeningBracket>{)[\n\s\t]*(Param[\n\s\t]*(?<OpeningParameters>\()){0,1}' -AllMatches;
    
    $FunctionList = $FunctionList.Matches | SELECT -Property `
                                            @{Name="Type";              Expression={"Function"}}, `
                                            @{Name="Name";              Expression={$_.Groups['FunctionName'].Value}}, `
                                            @{Name="OpeningBracket";    Expression={$_.Groups['OpeningBracket'].Index}}, `
                                            @{Name="ClosingBracket";    Expression={0}}, `
                                            @{Name="OpeningParameters"; Expression={$_.Groups['OpeningParameters'].Index}}, `
                                            @{Name="ClosingParameters"; Expression={0}};

    <# $FunctionList looks like:

        $FunctionList | FT -AutoSize | Out-String | Write-Host;

        Type     Name               OpeningBracket ClosingBracket OpeningParameters ClosingParameters
        ----     ----               -------------- -------------- ----------------- -----------------
        Function Get-SYZ                       996              0              1009                 0
        Function Validate-ResultSet           1122              0              1135                 0

    #>

    # Convert $ScriptAsOneLine to a character array so it can be inspected character by character
    $CharArray = $ScriptAsOneLine.ToCharArray();

    ForEach ($Function in $FunctionList) {

        # $Index points to the Function's opening bracket "{"
        $Index = $Function.OpeningBracket;
        
        # Search for the Function's closing bracket "}"
        $BracketCount = 1;
        While ($BracketCount -gt 0) {
            $Index++;
            If ($CharArray[$Index] -eq '{') { $BracketCount++ }
            If ($CharArray[$Index] -eq '}') { $BracketCount-- }
        }
        $Function.ClosingBracket = $Index;

        # Debugging: Uncomment this line to see each function
        #$ScriptAsOneLine.Substring($Function.Index,(1+$Function.ClosingBracket - $Function.Index)) | Write-Host;
    }

    ForEach ($Function in $FunctionList) {

        # $Index points to the Function's Parameter's opening paren "("
        $Index = $Function.OpeningParameters;

        If ($Index -eq 0) {
            # Skip this function.  It doesn't define parameters.
            Continue;
        }
        
        # Search for the Function's closing paren ")"
        $ParenCount = 1;
        While ($ParenCount -gt 0) {
            $Index++;
            If ($CharArray[$Index] -eq '(') { $ParenCount++ }
            If ($CharArray[$Index] -eq ')') { $ParenCount-- }
        }
        $Function.ClosingParameters = $Index;
    }

    <# $FunctionList looks like:

        $FunctionList | FT -AutoSize | Out-String | Write-Host;

        Type     Name               OpeningBracket ClosingBracket OpeningParameters ClosingParameters
        ----     ----               -------------- -------------- ----------------- -----------------
        Function Get-SYZ                       996           1089              1009              1039
        Function Validate-ResultSet           1122           3611              1135              1243

    #>
    
    #$FunctionList | FT -AutoSize | Out-String | Write-Host;

    Remove-Variable CharArray;
    Write-Output $FunctionList -NoEnumerate;
}
Function Get-ScriptRegions {
    Param(
        [Parameter(Mandatory=$true)]
        [String]$ScriptAsOneLine
    )

    $Regions          = New-Object System.Collections.ArrayList;
    $ScriptLines      = $ScriptAsOneLine.Split("`n");
    $StartRegionLines = $ScriptLines | WHERE {$_ -imatch '\s*#region\s\S+'};
    <# Regex Key:
        \s = Any single whitespace character
        \S = Any single non-whitespace character
        *  = Zero or more instances of something
        +  = One or more instances of something
    #>

    ForEach ($StartRegionLine in $StartRegionLines) {

        # Build Region Object
        $Region = [PSCustomObject]@{
                        Type       = 'Region'
                        Name       = ''
                        StartLine  = -1
                        FinishLine = -1
                    }
    
        # Extract Region Name
        $StartRegionLine -imatch "\s*#region\s(?<Name>.*)" | Out-Null;
        $Region.Name = $Matches['Name']

        #Generate Matching End Line
        $FinishRegionLine = $StartRegionLine.Replace('#region ','#endregion ');

        # How many regions like this exist?
        $StartRegionCount = ($ScriptLines -imatch "\s*#region\s$($Region.Name)").count;
        If ($StartRegionCount -gt 1) {
            $Global:InvalidRegionsAndFunctions += "The region titled '$($Region.Name.Trim())' cannot be used because there are $StartRegionCount regions with this name.";
            # Go to next region definition
            Continue;
        }

        # Get the Region's Boundaries
        $Region.StartLine  = $ScriptLines.IndexOf($StartRegionLine);
        $Region.FinishLine = $ScriptLines.IndexOf($FinishRegionLine);

        If ($Region.FinishLine -eq -1) {
            # No matching #endregion tag was found
            $Global:InvalidRegionsAndFunctions += "The region titled '$($Region.Name.Trim())' cannot be used because a matching '#endregion' was not found.";

            # Go to next region definition
            Continue;
        }

        If ($Region.FinishLine -le $Region.StartLine) {
            # The #endregion tag was listed before the #region tag
            $Global:InvalidRegionsAndFunctions += "The region titled '$($Region.Name.Trim())' cannot be used because the matching '#endregion' came before the '#region' tag.";

            # Go to next region definition
            Continue;
        }
        $Regions.Add($Region) | Out-Null;
    }

    # NoEnumerate: Do not change the output object
    Write-Output -InputObject $Regions -NoEnumerate;
}
Function Insert-StopwatchInFunctions {
    Param(
        [Parameter(Mandatory=$true)]
        [String]$ScriptAsOneLine
    )

    $Functions = Get-Functions -ScriptAsOneLine $ScriptAsOneLine;

    <# $Functions looks like this:
            Type     Name                   OpeningBracket ClosingBracket
            ----     ----                   -------------- --------------
            Function Get-SYZ                           996           1089
            Function Validate-ResultSet               1122           3611
            Function global:Write-Host()              4744           4745
            Function global:Write-Warning()           4789           4790
    #>

    <# $Temp looks like this:

            $Temp = $Functions | ForEach {
                            $_ | SELECT -Property Name, `
                                            @{Name="Action";          Expression={'Open'} }, `
                                            @{Name="CharacterNumber"; Expression={$_.OpeningBracket}};
                            $_ | SELECT -Property Name, `
                                            @{Name="Action";          Expression={'Close'}}, `
                                            @{Name="CharacterNumber"; Expression={$_.ClosingBracket}};
                         } `
                       | Sort -Property CharacterNumber -Descending;

            Name                   Action CharacterNumber
            ----                   ------ ---------------
            global:Write-Warning() Close             4790
            global:Write-Warning() Open              4789
            global:Write-Host()    Close             4745
            global:Write-Host()    Open              4744
            Validate-ResultSet     Close             3611
            Validate-ResultSet     Open              1122
            Get-SYZ                Close             1089
            Get-SYZ                Open               996
    #>
    

    $Functions | ForEach {
                    $_ | SELECT -Property Name, `
                                    @{Name="Action";          Expression={'Open'} }, `
                                    @{Name="CharacterNumber"; Expression={[Math]::Max($_.OpeningBracket,$_.ClosingParameters)}};
                    $_ | SELECT -Property Name, `
                                    @{Name="Action";          Expression={'Close'}}, `
                                    @{Name="CharacterNumber"; Expression={$_.ClosingBracket}};
                 } `
               | Sort -Property CharacterNumber -Descending `
               | ForEach {
                    If ($_.Action -ieq 'Open')  { $ScriptAsOneLine = $ScriptAsOneLine.Insert($_.CharacterNumber+1,"; Start-Stopwatch 'Function $($_.Name)'; ") }
                    If ($_.Action -ieq 'Close') { $ScriptAsOneLine = $ScriptAsOneLine.Insert($_.CharacterNumber,  "; Add-StopwatchLap 'Function $($_.Name)'; ") }
                 }

    Write-Output -InputObject $ScriptAsOneLine -NoEnumerate;
}
Function Insert-StopwatchInRegions {
    Param(
        [Parameter(Mandatory=$true)]
        [String]$ScriptAsOneLine
    )

    $ScriptAsManyLines = $ScriptAsOneLine.Split("`n");

    $RegionList = Get-ScriptRegions -ScriptAsOneLine $ScriptAsOneLine;
    $RegionList | ForEach {
                    $ScriptAsManyLines[$_.StartLine]  = ";Start-Stopwatch -Label 'Region $($_.Name.Trim())';" + $ScriptAsManyLines[$_.StartLine];
                    $ScriptAsManyLines[$_.FinishLine] = ";Add-StopwatchLap -Label 'Region $($_.Name.Trim())';" + $ScriptAsManyLines[$_.FinishLine];
                }
    
    $ScriptAsOneLine = $ScriptAsManyLines -join "`n";

    Write-Output -InputObject $ScriptAsOneLine -NoEnumerate;
}
Function Get-StopwatchFunctions {
    $SwFunctions = @( `
        'Reset-StopwatchCollection', `
        'Start-Stopwatch', `
        'Add-StopwatchLap', `
        'Get-StopwatchReport');

    $FunctionString = ""
    ForEach ($SwFunction in $SwFunctions) {
        $FunctionString += "Function $SwFunction {" + (Get-ChildItem function:$SwFunction).Definition + "Out-Null;`n};`n";
    }

    Write-Output $FunctionString;
}

Reset-StopwatchCollection;
$ScriptAsOneLine = Get-ScriptAsOneLine         -FileName        $ScriptFullPath;
$ScriptAsOneLine = Insert-StopwatchInFunctions -ScriptAsOneLine $ScriptAsOneLine;
$ScriptAsOneLine = Insert-StopwatchInRegions   -ScriptAsOneLine $ScriptAsOneLine;

$Global:InvalidRegionsAndFunctions | SELECT -Unique | Write-Host;

$Code = @"
Param(`$ScriptArguments2)
&{

    $(Get-StopwatchFunctions)

    Function Run-Me {
        $($ScriptAsOneLine)
    }

    Reset-StopwatchCollection;
    
    Write-Verbose "Begin Executing ScriptBlock";
    Write-Verbose "===========================";
    Run-Me @ScriptArguments;
    Write-Verbose "===========================";
    Write-Verbose "Finishing ScriptBlock";
    
    Get-StopwatchReport | Format-Table -AutoSize | Out-String | Write-Host;
}
`$ScriptArguments2 = `$args[0];
"@;

# Calculate the Line Offset for the Stopwatch Report
$LineOffset = (($Code -split "Function Run-Me {")[0] | Measure-Object -Line).Lines;
$Code       = $Code.Replace('44444444',$LineOffset);

$ScriptBlock     = [ScriptBlock]::Create($Code);

$OriginalPath = (Get-Location).Path;
Set-Location (Split-Path $ScriptFullPath -Parent)
Invoke-Command -NoNewScope -ScriptBlock $ScriptBlock -ArgumentList $ScriptArguments -Verbose | Write-Output;
Set-Location $OriginalPath;
