function Write-Badu {
    [CmdletBinding()]
    param (
        [ValidateSet(
            'Info',
            'Warning',
            'Error',
            'Verbose',
            'Debug',
            "System"
        )]
        $Level = 'Info',

        [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments)]
        $Message,

        [System.Management.Automation.CallStackFrame[]]$Callstack
    )
    begin {
        #get log context. send in callstack with itself removed
        $ctx = @{
            Tag           = 'TEMP'
            IsSubFunction = $false
            Tab           = 0
        }

        if (!$Callstack) {
            $Callstack = (Get-PSCallStack | Select-Object -Skip 1)
        }
        $Ctx = Get-BaduLogContext -CallStack $Callstack
    }
    process {
        $msg = $Message -join " "
        $tag = $ctx.Tag
        $levelMap = @{
            'Info'    = 'Inf'
            'Warning' = 'Wrn'
            'Error'   = 'Err'
            'Verbose' = 'Vrb'
            'Debug'   = 'Dbg'
        }
        $out = "<$($levelMap[$Level])>$("    " * $ctx.tab)<$tag> $msg"

        switch ($Level) {
            'Info' {
                Write-Host $out -ForegroundColor Gray
            }
            'Warning' {
                if ($WarningPreference -eq 'SilentlyContinue') { return }
                Write-Host $out -ForegroundColor DarkYellow
            }
            'Error' {
                Write-Host $out -ForegroundColor Red
            }
            'Verbose' {
                if ($VerbosePreference -eq 'SilentlyContinue') { return }
                Write-Host $out -ForegroundColor Cyan
            }
            'Debug' {
                if($DebugPreference -eq 'SilentlyContinue') { return }
                Write-Host $out -ForegroundColor Magenta
            }
        }
    }
    end {}
}

function Write-BaduVerb {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments)]
        $Message
    )
    Write-Badu -Level Verbose -Message $Message -Callstack (Get-PSCallStack | Select-Object -Skip 1)
}

function Write-BaduDebug {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments)]
        $Message
    )
    Write-Badu -Level Debug -Message $Message -Callstack (Get-PSCallStack | Select-Object -Skip 1)
}

function Write-BaduInfo {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments)]
        $Message
    )
    Write-Badu -Level Info -Message $Message -Callstack (Get-PSCallStack | Select-Object -Skip 1)
}

function Write-BaduWarning {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments)]
        $Message
    )
    Write-Badu -Level Warning -Message $Message -Callstack (Get-PSCallStack | Select-Object -Skip 1)
}

function Write-BaduError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments)]
        $Message
    )
    Write-Badu -Level Error -Message $Message -Callstack (Get-PSCallStack | Select-Object -Skip 1)
}