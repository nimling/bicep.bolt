@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        "PSUseBOMForUnicodeEncodedFile"
        'PSAvoidUsingWriteHost'
        "PSAvoidGlobalVars"
        "PSUseShouldProcessForStateChangingFunctions"
        # "PSUseDeclaredVarsMoreThanAssignments"
    )
}