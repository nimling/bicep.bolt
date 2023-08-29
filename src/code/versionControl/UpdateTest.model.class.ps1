using namespace System.Collections.Generic
enum ModuleUpdateType {
    added
    removed
    modified
    other
}
class ModuleUpdateReason {
    [string]$key
    [string]$detail = $null

    [ModuleUpdateType]$type
    [string]$oldValue
    [string]$newValue
    [string]$message
    ModuleUpdateReason() {}
    ModuleUpdateReason([string]$key) {
        $this.key = $key
    }

    static [ModuleUpdateReason] Added([string]$key, $newValue) {
        $reason = [ModuleUpdateReason]::new($key)
        $reason.type = [ModuleUpdateType]::added
        $reason.newValue = $NewValue|ConvertTo-Json -Compress
        return $reason
    }

    static [ModuleUpdateReason] Removed([string]$key, $oldValue) {
        $reason = [ModuleUpdateReason]::new($key)
        $reason.type = [ModuleUpdateType]::removed
        $reason.oldValue = $oldValue|ConvertTo-Json -Compress
        return $reason
    }

    static [ModuleUpdateReason] Modified([string]$key, $oldValue, $newValue) {
        $reason = [ModuleUpdateReason]::new($key)
        $reason.type = [ModuleUpdateType]::modified
        $reason.oldValue = $oldValue|ConvertTo-Json -Compress
        $reason.newValue = $newValue|ConvertTo-Json -Compress
        return $reason
    }

    static [ModuleUpdateReason] Other([string]$key, [string]$message) {
        $reason = [ModuleUpdateReason]::new($key)
        $reason.type = [ModuleUpdateType]::other
        $reason.message = $message
        return $reason
    }
}


<#
- Reasons:
    parameter:
        - 'key' -> 'ModuleupdateType' from 'OldValue' to 'NewValue'
        - 'someparam' -> 'added' from '' to 'somevalue'
        - 'otherparm/allowedvalues' -> 'removed' from

#>


class ModuleUpdateTest {
    [string] $type
    [Dictionary[string, [List[ModuleUpdateReason]]]] $reasons
    [bool] $result = $true
    ModuleUpdateTest([string]$type) {
        $this.type = $type
        $this.reasons = [Dictionary[string, [List[ModuleUpdateReason]]]]::new()
    }

    #returns as reference, not as value
    [List[ModuleUpdateReason]] NewReasonList([string]$key) {
        $this.Reasons.Add($key, [List[ModuleUpdateReason]]::new())
        return $this.reasons[$key]
    }

    [bool]ShouldUpdate() {
        $return = $false
        $this.reasons.GetEnumerator() | ForEach-Object {
            if ($_.value.Count -gt 0) {
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'is is a return key')]
                $return = $true
            }
        }
        return $return
    }
}