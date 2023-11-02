function Set-BaduLogContext {
    [CmdletBinding()]
    param (
        [parameter(Mandatory = $true)]
        [string]$Tag,
        [switch]$IsSubFunction,
        [switch]$Clear
    )
    
    begin {
        if ($tag -eq '_') {
            throw "Tag '_' is reserved for internal use"
        }

        $Caller = (Get-PSCallStack)[1]

        #(Get-PSCallStack)[1].InvocationInfo.MyCommand.Path
        <#
            caller:{
                tag: some easy to unserstand tag
                isSubFunction: true/false -> if true, it will tab one out
                isClass: true/false -> if true, it will use the function name instead of the command name
            }
        #>
        if (!$Global:BaduLogContext -or $Clear) {
            Write-Badu -Level Debug -Message "Clearing context $($Caller.ScriptName):$($caller.ScriptLineNumber)"

            $Global:BaduLogContext = @{
                _ = @{
                    class = @{
                        # 'C:\thing\class.ps1' = @{
                        #     'class:name' = @(start, end)
                        # }
                    }
                }
            }

            #Classes in powershell classes suck when discovered through callstack, so i have to figure out the context of each method beforehand
            #Get allscriopt files.
            #If DEV, It means that the script files are all over the place, so i have to search.
            #If not DEV, it means that the scripts files are in the same file
            $sources = @($PSCmdlet.MyInvocation.ScriptName)
            if ($Global:BuildId -eq 'DEV') {
                # Write-Host ($Caller.InvocationInfo.MyCommand|ConvertTo-Json -depth 1)
                $sources = gci (split-path $Caller.InvocationInfo.MyCommand.ScriptBlock.file -Parent) -Recurse -File -Filter "*.ps1"
            }

            :classSearch foreach ($Script in $sources) {

                #Get all tokens that are of type class in script
                $Classes = (get-command $Script).ScriptBlock.Ast.FindAll(
                    {
                        param($ast)
                        $ast -is [System.Management.Automation.Language.TypeDefinitionAst]
                    }, $true
                )

                #If no classes, skip to next
                if ($Classes.count -eq 0) {
                    continue :classSearch
                }

                #Hashtables are static, so i have to initate once and i can write to whatever object holds the reference, and it will update all other references
                $ScriptMap = [ordered]@{}
                $Global:BaduLogContext._.class[$Script.FullName] = $ScriptMap

                $Classes | % {
                    $ClassName = $_.name
                    $_.members | ? { $_ -is [System.Management.Automation.Language.FunctionMemberAst] } |%{
                        $MethodName = $_.name
                        $RefName = "$ClassName`:$MethodName"
                        $ScriptMap[$RefName] =  @($_.extent.StartLineNumber,$_.extent.EndLineNumber)
                    }
                }
            }
        }
    }
    process {
        #Get Caller (0 is itself)
        $CallerName = $Caller.Command

        #If it is a class, a command wont be found. searching though the class map
        if (!$CallerName) {
            $CallerName = Get-BaduClassContext -ScriptPath $caller.ScriptName -LineNumber $Caller.ScriptLineNumber
        }

        # Write-warning "$tag - $CallerName"

        #return if already set
        if ($Global:BaduLogContext -and $Global:BaduLogContext.ContainsKey($CallerName)) {
            if (
                $Global:BaduLogContext[$CallerName].Tag -eq $Tag -and
                $Global:BaduLogContext[$CallerName].IsSubFunction -eq $IsSubFunction.IsPresent
            ) {
                return
            }
        }

        $Global:BaduLogContext[$CallerName] = @{
            Tag           = $Tag
            IsSubFunction = [bool]$IsSubFunction
        }
    }
    end {}
}
