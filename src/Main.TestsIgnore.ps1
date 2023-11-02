describe "General Tests" -Tag "General" {
    BeforeDiscovery {
        $AllCommands = (Get-command)
        #get all functions in directory
        $Command = $AllCommands | 
        Where-Object { $_.CommandType -eq 'function' } | 
        Where-Object { $_.ScriptBlock.File -like "$PSScriptRoot*.ps1" } |
        Where-Object { $_.ScriptBlock.File -notlike "$PSScriptRoot*.tests.ps1" }

        #Add main.ps1 to commands
        $command += Get-Command (get-item "$PSScriptRoot/main.ps1").FullName

        #get all files
        $Tests = @()
        $Command | ForEach-Object {
            $Tests += @{
                Command     = $_
                Name        = $_.Name
                Scriptblock = $_.ScriptBlock
                SolutionCommands = $Command
            }
        }
    }

    it "there should be atleast 1 command loaded from current folder"{
        $AllCommands = (Get-command)
        #get all functions in directory
        $TheseCommands = $AllCommands | Where-Object { $_.CommandType -eq 'function' -and $_.ScriptBlock.File -like "$PSScriptRoot*.ps1" }| Where-Object { $_.ScriptBlock.File -notlike "$PSScriptRoot*.tests.ps1" }
        $TheseCommands.count | should -BeGreaterThan 1
    }

    context "command"{
        it "used commands in function '<Name>' should exist" -tag 'script' -TestCases $Tests {
            param(
                [string]$Name,
                [scriptblock]$ScriptBlock,
                $Command
            )
            #Find all ast tokens in script that are commands
            $CommandsInScript = $ScriptBlock.Ast.FindAll(
                {
                    param($ast)
                    $ast -is [System.Management.Automation.Language.CommandAst]
                }, $true
            )
    
            #filter away commands that are already defined
            $CommandsInScript = $CommandsInScript | Where-Object { $_.GetCommandName() -notin $AllCommands.Name } 
    
            #filter away commands that are needed for posh to work
            $CommandsInScript = $CommandsInScript | Where-Object {
                $_.InvocationOperator -notin @('dot', 'ampersand', 'pipe') -and 
                $_.GetCommandName() -notlike ":*"
            } 
    
            #filter away commands that exists
            $CommandsInScript = $CommandsInScript | Where-Object{!(get-command $_.GetCommandName() -ErrorAction silentlycontinue)}
            
            #report commands that are not found
            $CommandsInScript| ForEach-Object {
                $Location = @($($_.Extent.StartLineNumber), $($_.Extent.StartColumnNumber))
                Write-Verbose "Command $($_.GetCommandName())($($Location[0]),$($Location[1])) not found"
            }

            #add commands that are defined inside script
    
            #this should be empty
            $CommandsInScript|ForEach-Object{$_.GetCommandName()}| Select-Object -Unique | should -BeNullOrEmpty
        }
    
        it "command '<Name>' should have a test in same folder as script" -tag 'script' -TestCases $Tests {
            param(
                [string]$Name,
                [scriptblock]$ScriptBlock,
                $Command
            )
    
            $item = get-item $ScriptBlock.file
            join-path $item.Directory.FullName "$($item.BaseName).tests.ps1" | Should -Exist -Because "Test for $($item.BaseName) should exist"
        }

        it "command '<name>' should be used somewhere" -TestCases ($tests|?{$_.name -ne "main.ps1"}) {
            param(
                [string]$Name,
                [scriptblock]$ScriptBlock,
                $Command,
                [array]$SolutionCommands
            )
    
            #get all commands inside a folder
            $CommandList = $SolutionCommands|%{
                $_.ScriptBlock.Ast.FindAll(
                    {
                        param($ast)
                        $ast -is [System.Management.Automation.Language.CommandAst]
                    }, $true
                )|%{$_.GetCommandName()}|Select-Object -Unique
            }
            
            if($null -eq $CommandList|?{$_ -eq $Name})
            {
                Write-warning "UNUSED COMMAND: Command $Name should be used somewhere"
            }
            # $CommandList|?{$_ -eq $Name}|should -Not -BeNullOrEmpty -Because "Command $Name should be used somewhere"
        }
    }

    context "File"{
        it "file hosting <Name> should max host one function" -tag 'script' -TestCases $Tests{
            param(
                [string]$Name,
                [scriptblock]$ScriptBlock,
                $Command
            )
    
            $item = get-item $ScriptBlock.file
            $Functions = (get-command $item.FullName).ScriptBlock.Ast.FindAll(
                {
                    param($ast)
                    $ast -is [System.Management.Automation.Language.FunctionDefinitionAst]
                }, $true
            )
            if($Functions)
            {
                $Functions | should -HaveCount 1 -Because "File $($item.BaseName) should only host one function"
            }
        }
    }

    context "Just good practice"{

        #its a very heavy workaround.. ast cant normally read comments, so i have to parse the file myself
        it "Regions in <Name> should be defined on its own line" -TestCases $Tests{
            param(
                [string]$Name,
                [scriptblock]$ScriptBlock,
                $Command
            )

            get-content $command.ScriptBlock.file|?{$_ -like "*#region*"}|%{
                $_ | should -match "^\s*#region.*" -Because "Region should be defined on its own line"
            }
        }
    }


}
