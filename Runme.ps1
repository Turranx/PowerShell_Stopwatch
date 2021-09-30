CLS;

# In this file, you will see how to use Stopwatch.ps1 to study your script ExampleScript.ps1.


# These parameters get passed to 'ExampleScript.ps1'
$NamedParameters = @{DoRegions = $true; DoFunctions = $true};

C:\Git_Repository\Stopwatch\Stopwatch.ps1 `
        -ScriptFullPath "C:\Git_Repository\Stopwatch\ExampleScript.ps1" `
        -ScriptArguments $NamedParameters;