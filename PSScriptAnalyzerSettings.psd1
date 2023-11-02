@{
    Severity     = @('Error', 'Warning')
    CustomRulePath = "buildfunctions\PsScriptAnalyserRules\BoltRules.psm1"
    
    IncludeRules = @(
        # "Measure-Ternary"
        # "Measure-Backtick"
        # "UseCorrectCasing"
        # "UseSingularNouns"
    )
    ExcludeRules = @(
        "PSUseBOMForUnicodeEncodedFile"
        'PSAvoidUsingWriteHost'
        "PSAvoidGlobalVars"
        "PSUseShouldProcessForStateChangingFunctions"
    )
}