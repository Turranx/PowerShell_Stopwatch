Param (
    [Switch]$DoRegions,
    [Switch]$DoFunctions
)

$ErrorActionPreference = "Stop";

# This is a script that is used to demonstrate the functionality of Stopwatch.ps1.
# This script contains function calls, nested function calls, loops, regions,
#  and regions inside functions.


Function F1{
    #F1
    For ($i = 0; $i -lt 10; $i++) {
        #Sleep -milliseconds (Get-Random -Minimum 0 -Maximum 500);
        Set-F3
    }
    
}

Function F2 {
    #F2
    For ($i = 0; $i -lt 30; $i++) {
        Sleep -milliseconds (Get-Random -Minimum 0 -Maximum 50);
    }
    Set-F3;
    Get-F4;
}

Function Set-F3 
{   #F3
    For ($i = 0; $i -lt 2; $i++) {
        Sleep -milliseconds (Get-Random -Minimum 0 -Maximum 10);
    }
}

Function Get-F4 
{   #F4
    For ($i = 0; $i -lt 2; $i++) {
        Sleep -milliseconds (Get-Random -Minimum 200 -Maximum 500);
        Get-F5;
    }}

Function Get-F5 {
    Param($Object)

    For ($i = 0; $i -lt (Get-Random -Minimum 0 -Maximum 1000); $i++) {
        #region Region In A Function
        Sleep -milliseconds (Get-Random -Minimum 0 -Maximum 5);
        #endregion Region In A Function
        
        Get-F6;
    }
}

Function Get-F6 {Param($Object)
    For ($i = 0; $i -lt (Get-Random -Minimum 0 -Maximum 30); $i++) {
        Sleep -milliseconds (Get-Random -Minimum 0 -Maximum 5);
        Get-F7;
    }
}

Function Get-F7 {
    Param (
        [String]$Object
    )

    For ($i = 0; $i -lt (Get-Random -Minimum 0 -Maximum 10); $i++) {
        Sleep -milliseconds (Get-Random -Minimum 0 -Maximum 20);
    }
}


If ($DoRegions.IsPresent) {
#region One
    
    For ($i = 0; $i -lt 10; $i++) {
        Sleep -Seconds ($i/3);
    }

#endregion One

#region One
    
    For ($i = 0; $i -lt 10; $i++) {
        Sleep -Seconds ($i/3);
    }

#endregion One

#region Two
    
    For ($i = 0; $i -lt 3; $i++) {
        Sleep -milliseconds (Get-Random -Minimum 0 -Maximum 500);
    }

#endregion Two

#region 
    
    For ($i = 0; $i -lt 5; $i++) {
        Sleep -milliseconds (Get-Random -Minimum 0 -Maximum 500);
    }

#endregion 

#region Three
    
    For ($i = 0; $i -lt 30; $i++) {
        Sleep -milliseconds (Get-Random -Minimum 0 -Maximum 20);
    }

#endregion Three

<#endregion No Ending#>
#region No Ending

#region Long With Spaces
    
    For ($i = 0; $i -lt 10; $i++) {
        Sleep -milliseconds (Get-Random -Minimum 0 -Maximum 500);
    }

#endregion Long With Spaces

#region Long With Special Characters !@#$%^&*()
    
    For ($i = 0; $i -lt 10; $i++) {
        Sleep -milliseconds (Get-Random -Minimum 0 -Maximum 500);
    }

#endregion Long With Special Characters !@#$%^&*()
}

If ($DoFunctions.IsPresent) {
F1;
F2;
Get-F5;
Get-F6;
Get-F7;
}

Get-F4;