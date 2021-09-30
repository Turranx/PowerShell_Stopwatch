# PowerShell_Stopwatch
This script will discover which blocks of your PowerShell code are consuming a lot of time.  Stopwatch.ps1 will detect all of your functions and regions and keep track of how many times each function and region was executed.  It will also track the execution time of each function and region.

To get started, call Stopwatch.ps1 using two arguments: "-ScriptFullPath" and "-NamedParameters":

    PS> $NamedParameters = @{DoRegions = $true; DoFunctions = $true};
    PS> Stopwatch.ps1 `
        -ScriptFullPath "C:\Git_Repository\Stopwatch\ExampleScript.ps1" `
        -ScriptArguments $NamedParameters;

"DoRegions" and "DoFunctions" are parameters used by ExampleScript.ps1.  ExampleScript uses them to determine if it should execute the Regions or not, and if it should execute the Functions or not.  By using $true/$false for these two parameters, you will change how ExampleScript.ps1 runs, which will change the output of Stopwatch.ps1


The Results:

![PowerShell_Stopwatch_Example_Run](https://user-images.githubusercontent.com/37883093/135522557-42f51232-a5ac-4714-a4b0-e22cf816b65f.PNG)


NOTE:  The two messages at the top of the output are supposed to be there when running against ExampleScript.ps1.  I cooked in a few mistakes on purpose.  Humans to make mistakes, after all.
