@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        'PSAvoidUsingWriteHost'
        "PSAvoidGlobalVars"
        "PSUseShouldProcessForStateChangingFunctions"
        # "PSUseDeclaredVarsMoreThanAssignments"
    )
}