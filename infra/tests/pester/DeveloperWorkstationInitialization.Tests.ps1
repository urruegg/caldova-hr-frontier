Set-StrictMode -Version Latest

function Get-NonWingetActionCase {
    @(
        @{
            name = 'Pester'
            actionManifest = [pscustomobject][ordered]@{
                action = 'InstallPesterExact'
                targetId = 'Pester'
                packageSource = 'PSGallery'
                scope = 'CurrentUser'
                requiredVersion = '5.7.1'
                expectedPostcondition = 'Pester 5.7.1 resolves in CurrentUser scope'
            }
            assessment = { New-SyntheticAssessment -ToolOverrides @{ Pester = @{ status = 'Missing'; version = $null; executablePath = $null; executableSha256 = $null } } -VsCodeExtensionOverrides @{ status = 'Ready'; diagnostic = $null } }
            hostCommand = 'C:\Approved\powershell.exe'
            versionArguments = '-NoLogo -NoProfile -Command $PSVersionTable.PSVersion.ToString()'
            mismatchedVersionOutput = @('5.1.0')
            expectedInstall = 'Install-Module ''Pester'' -RequiredVersion ''5.7.1'' -Repository ''PSGallery'' -Scope ''CurrentUser'''
            readBackArguments = '-NoProfile -Command (Get-Module -ListAvailable Pester | Where-Object Version -eq ([version]''5.7.1'') | Select-Object -First 1).Version.ToString()'
            failedReadBackOutput = @('')
            passingReadBackOutput = @('5.7.1')
        }
        @{
            name = 'Bicep'
            actionManifest = [pscustomobject][ordered]@{
                action = 'InstallBicepComponent'
                targetId = 'Bicep'
                expectedPostcondition = 'az bicep version exits 0'
            }
            assessment = { New-SyntheticAssessment -ToolOverrides @{ Bicep = @{ status = 'Missing'; version = $null; executablePath = $null; executableSha256 = $null } } -VsCodeExtensionOverrides @{ status = 'Ready'; diagnostic = $null } }
            hostCommand = 'C:\Approved\az.cmd'
            versionArguments = 'version --output json'
            mismatchedVersionOutput = @('{"azure-cli":"9.9.9"}')
            expectedInstall = 'bicep install'
            readBackArguments = 'bicep version'
            failedReadBackOutput = @('')
            passingReadBackOutput = @('Bicep CLI version 0.38.33')
        }
        @{
            name = 'AzureDevOpsExtension'
            actionManifest = [pscustomobject][ordered]@{
                action = 'InstallAzureCliExtensionExact'
                targetId = 'azure-devops'
                requiredVersion = $null
                expectedPostcondition = 'Azure CLI extension azure-devops resolves at the reviewed version'
            }
            assessment = { New-SyntheticAssessment -AzureCliExtensionOverrides @{ status = 'Missing'; version = $null; diagnostic = 'Reviewed Azure CLI extension is not installed.' } -VsCodeExtensionOverrides @{ status = 'Ready'; diagnostic = $null } }
            hostCommand = 'C:\Approved\az.cmd'
            versionArguments = 'version --output json'
            mismatchedVersionOutput = @('{"azure-cli":"9.9.9"}')
            expectedInstall = 'extension add --name azure-devops'
            readBackArguments = 'extension list --output json'
            failedReadBackOutput = @('[]')
            passingReadBackOutput = @('[{"name":"azure-devops","version":"1.0.8"}]')
        }
        @{
            name = 'VsCodeExtension'
            actionManifest = [pscustomobject][ordered]@{
                action = 'InstallVsCodeExtensionExact'
                targetId = 'GitHub.copilot'
                expectedPostcondition = 'VS Code reports extension GitHub.copilot'
            }
            assessment = { New-SyntheticAssessment -VsCodeExtensionOverrides @{ status = 'Missing'; diagnostic = 'Reviewed VS Code extension is not installed.' } }
            hostCommand = 'C:\Approved\code.cmd'
            versionArguments = '--version'
            mismatchedVersionOutput = @('0.0.0')
            expectedInstall = '--install-extension GitHub.copilot'
            readBackArguments = '--list-extensions'
            failedReadBackOutput = @('ms-vscode.powershell')
            passingReadBackOutput = @('GitHub.copilot')
        }
    )
}

Describe 'Developer workstation initialization gates' {
    BeforeAll {
        $script:ScriptPath = Join-Path $PSScriptRoot '..\..\src\scripts\runbooks\Initialize-DeveloperWorkstation.ps1'
        $script:ModulePath = Join-Path $PSScriptRoot '..\..\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'
        Import-Module $script:ModulePath -Force

        function script:New-SyntheticAssessment {
            param(
                [ValidateSet('', 'Git')][string]$MissingTool = '',
                [hashtable]$ToolOverrides = @{},
                [hashtable]$AzureCliExtensionOverrides = @{},
                [hashtable]$VsCodeExtensionOverrides = @{}
            )

            $toolDefinitions = [ordered]@{
                Git = [ordered]@{
                    id = 'Git'; status = 'Ready'; version = '2.51.0.windows.1'
                    executablePath = 'C:\Approved\git.exe'; executableSha256 = ('2' * 64); diagnostic = $null
                }
                WindowsPowerShell = [ordered]@{
                    id = 'WindowsPowerShell'; status = 'Ready'; version = '5.1.26100.6584'
                    executablePath = 'C:\Approved\powershell.exe'; executableSha256 = ('3' * 64); diagnostic = $null
                }
                AzureCli = [ordered]@{
                    id = 'AzureCli'; status = 'Ready'; version = '2.78.0'
                    executablePath = 'C:\Approved\az.cmd'; executableSha256 = ('4' * 64); diagnostic = $null
                }
                VisualStudioCode = [ordered]@{
                    id = 'VisualStudioCode'; status = 'Ready'; version = '1.95.0'
                    executablePath = 'C:\Approved\code.cmd'; executableSha256 = ('5' * 64); diagnostic = $null
                }
                Pester = [ordered]@{
                    id = 'Pester'; status = 'Ready'; version = '5.7.1'
                    executablePath = 'C:\Approved\powershell.exe'; executableSha256 = ('3' * 64); diagnostic = $null
                }
                Bicep = [ordered]@{
                    id = 'Bicep'; status = 'Ready'; version = '0.38.33'
                    executablePath = 'C:\Approved\az.cmd'; executableSha256 = ('4' * 64); diagnostic = $null
                }
            }

            if ($MissingTool -eq 'Git') {
                $toolDefinitions.Git.status = 'Missing'
                $toolDefinitions.Git.version = $null
                $toolDefinitions.Git.executablePath = $null
                $toolDefinitions.Git.executableSha256 = $null
            }

            foreach ($toolId in @($ToolOverrides.Keys)) {
                foreach ($property in @($ToolOverrides[$toolId].Keys)) {
                    $toolDefinitions[$toolId][$property] = $ToolOverrides[$toolId][$property]
                }
            }

            $azureCliExtension = [ordered]@{
                name = 'azure-devops'
                status = 'Ready'
                version = '1.0.8'
                diagnostic = $null
            }
            foreach ($property in @($AzureCliExtensionOverrides.Keys)) {
                $azureCliExtension[$property] = $AzureCliExtensionOverrides[$property]
            }

            $vsCodeExtension = [ordered]@{
                id = 'GitHub.copilot'
                status = 'Missing'
                diagnostic = 'Reviewed VS Code extension is not installed.'
            }
            foreach ($property in @($VsCodeExtensionOverrides.Keys)) {
                $vsCodeExtension[$property] = $VsCodeExtensionOverrides[$property]
            }

            [pscustomobject]@{
                schemaVersion = '1.0'
                platform = [pscustomobject]@{
                    productName = 'Windows 11'
                    build = 26100
                    stableId = 'SYNTHETIC-WORKSTATION\operator'
                    packageManager = [pscustomobject]@{
                        executablePath = 'C:\Approved\winget.exe'
                        executableSha256 = ('1' * 64)
                        version = '1.9.25200'
                    }
                }
                repository = [pscustomobject]@{
                    sourceCommit = ('a' * 40)
                    clean = $true
                }
                tools = @(
                    foreach ($toolId in @($toolDefinitions.Keys)) {
                        [pscustomobject]$toolDefinitions[$toolId]
                    }
                )
                azureCliExtensions = @([pscustomobject]$azureCliExtension)
                vsCodeExtensions = @([pscustomobject]$vsCodeExtension)
                assessmentDigest = ('b' * 64)
                overallStatus = $(if ($MissingTool) { 'Blocked' } else { 'Ready' })
            }
        }

        function script:New-ManifestFile {
            param([Parameter(Mandatory)][object]$AllowedAction)

            $path = Join-Path $TestDrive ([guid]::NewGuid().ToString() + '.json')
            $manifest = New-RunbookExecutionManifest -RunId ([guid]'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee') `
                -Kind Workstation -SourceCommit ('a' * 40) -AssessmentDigest ('b' * 64) `
                -TargetStableId 'SYNTHETIC-WORKSTATION\operator' `
                -AuthenticationContext ([pscustomobject]@{
                    executionHost = 'InteractiveWindows11PowerShell'
                    mode = 'NotRequired'
                }) `
                -AllowedActions (, $AllowedAction) -ToolVersions @{} -GeneratedAtUtc ([datetime]'2026-09-26T05:00:00Z')
            Write-CanonicalJson -InputObject $manifest -Path $path | Out-Null
            [pscustomobject]@{
                path = $path
                digest = $manifest.digest
            }
        }

        $script:ValidManifest = Join-Path $TestDrive 'workstation-execution-manifest.json'
        $manifest = New-RunbookExecutionManifest -RunId ([guid]'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee') `
            -Kind Workstation -SourceCommit ('a' * 40) -AssessmentDigest ('b' * 64) `
            -TargetStableId 'SYNTHETIC-WORKSTATION\operator' `
            -AuthenticationContext ([pscustomobject]@{
                executionHost = 'InteractiveWindows11PowerShell'
                mode = 'NotRequired'
            }) `
            -AllowedActions @([pscustomobject]@{
                action = 'WinGetInstallExact'
                targetId = 'Git.Git'
                packageSource = 'winget'
                packageId = 'Git.Git'
                scope = 'machine'
                expectedPostcondition = 'git.exe resolves and git --version exits 0'
            }) `
            -ToolVersions @{} -GeneratedAtUtc ([datetime]'2026-09-26T05:00:00Z')
        $script:ApprovedDigest = $manifest.digest
        Write-CanonicalJson -InputObject $manifest -Path $script:ValidManifest | Out-Null
    }

    It 'does not call a mutator by default and writes plan artifacts' {
        $mutations = [Collections.Generic.List[string]]::new()
        $repositoryRoot = Join-Path $TestDrive 'repo'
        $reportPath = Join-Path $TestDrive 'external\preview'
        [void](New-Item -ItemType Directory -Path $repositoryRoot -Force)

        $result = & $script:ScriptPath -RepositoryRoot $repositoryRoot -ReportPath $reportPath `
            -AssessmentProvider { New-SyntheticAssessment } `
            -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $true; reason = 'TestHost' } } `
            -NativeCommandRunner {
                param($f, $a)
                if (($a -join ' ') -match 'install|add') { [void]$mutations.Add("$f $a") }
            }

        $mutations.Count | Should -Be 0
        $result.mode | Should -Be 'Preview'
        (Join-Path $reportPath 'workstation-plan.json') | Should -Exist
        (Join-Path $reportPath 'workstation-execution-manifest.json') | Should -Exist
    }

    It 'does not call a mutator under WhatIf even when Apply is present' {
        $mutations = [Collections.Generic.List[string]]::new()

        & $script:ScriptPath -Apply -ExecutionManifestPath $script:ValidManifest `
            -ApprovedDigest $script:ApprovedDigest -WhatIf -Confirm:$false `
            -AssessmentProvider { New-SyntheticAssessment } `
            -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $true; reason = 'TestHost' } } `
            -NowUtc ([datetime]'2026-09-26T05:10:00Z') `
            -NativeCommandRunner {
                param($f, $a)
                if (($a -join ' ') -match 'install|add') { [void]$mutations.Add("$f $a") }
            } | Out-Null

        $mutations.Count | Should -Be 0
    }

    It 'refuses a digest mismatch before calling a mutator' {
        $mutations = [Collections.Generic.List[string]]::new()

        {
            & $script:ScriptPath -Apply -ExecutionManifestPath $script:ValidManifest `
                -ApprovedDigest ('f' * 64) -Confirm:$false `
                -AssessmentProvider { New-SyntheticAssessment } `
                -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $true; reason = 'TestHost' } } `
                -NowUtc ([datetime]'2026-09-26T05:10:00Z') `
                -NativeCommandRunner { param($f, $a) [void]$mutations.Add("$f $a") }
        } | Should -Throw '*Approved digest*'

        $mutations.Count | Should -Be 0
    }

    It 'refuses non-interactive and GitHub Actions execution before calling a mutator' {
        $mutations = [Collections.Generic.List[string]]::new()

        {
            & $script:ScriptPath -Apply -ExecutionManifestPath $script:ValidManifest `
                -ApprovedDigest $script:ApprovedDigest -Confirm:$false `
                -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $false; reason = 'GitHub Actions' } } `
                -AssessmentProvider { New-SyntheticAssessment } `
                -NowUtc ([datetime]'2026-09-26T05:10:00Z') `
                -NativeCommandRunner { param($f, $a) [void]$mutations.Add("$f $a") }
        } | Should -Throw '*interactive Windows 11 PowerShell session*'

        $mutations.Count | Should -Be 0
    }

    It 'uses exact allowlisted arguments and reads back after an approved action' {
        $manifestFile = New-ManifestFile -AllowedAction ([pscustomobject][ordered]@{
            action = 'InstallPesterExact'
            targetId = 'Pester'
            packageSource = 'PSGallery'
            scope = 'CurrentUser'
            requiredVersion = '5.7.1'
            expectedPostcondition = 'Pester 5.7.1 resolves in CurrentUser scope'
        })
        $calls = [Collections.Generic.List[string]]::new()
        $summaries = [Collections.Generic.List[object]]::new()

        $result = & $script:ScriptPath -Apply -ExecutionManifestPath $manifestFile.path `
            -ApprovedDigest $manifestFile.digest -Confirm:$false `
            -AssessmentProvider { New-SyntheticAssessment -ToolOverrides @{ Pester = @{ status = 'Missing'; version = $null; executablePath = $null; executableSha256 = $null } } -VsCodeExtensionOverrides @{ status = 'Ready'; diagnostic = $null } } `
            -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $true; reason = 'TestHost' } } `
            -NowUtc ([datetime]'2026-09-26T05:10:00Z') `
            -NativeCommandRunner {
                param($f, $a)
                [void]$calls.Add(('{0}|{1}' -f $f, ($a -join ' ')))
                if ($f -eq 'C:\Approved\powershell.exe' -and ($a -join ' ') -match 'PSVersionTable\.PSVersion') {
                    return [pscustomobject]@{ exitCode = 0; stdout = @('5.1.26100.6584'); stderr = @() }
                }
                if ($f -eq 'C:\Approved\powershell.exe' -and ($a -join ' ') -match "Get-Module -ListAvailable Pester") {
                    return [pscustomobject]@{ exitCode = 0; stdout = @('5.7.1'); stderr = @() }
                }
                [pscustomobject]@{ exitCode = 0; stdout = @('synthetic'); stderr = @() }
            } `
            -CommandResolver { param($name) if ($name -eq 'powershell.exe') { @('C:\Approved\powershell.exe') } else { @("C:\Approved\$name") } } `
            -FileIdentityProvider {
                param($path)
                [pscustomobject]@{
                    path = $path
                    sha256 = $(if ($path -like '*powershell.exe') { '3' * 64 } else { '2' * 64 })
                }
            } `
            -SummaryWriter { param($operations) foreach ($operation in $operations) { $summaries.Add($operation) } }

        $calls | Should -Contain "C:\Approved\powershell.exe|-NoProfile -Command Install-Module 'Pester' -RequiredVersion '5.7.1' -Repository 'PSGallery' -Scope 'CurrentUser'"
        $calls[-1] | Should -Match 'Get-Module -ListAvailable Pester'
        $summaries.Count | Should -Be 1
        $summaries[0].targetId | Should -BeExactly 'Pester'
        $result.operations[0].readBack.status | Should -Be 'Verified'
    }

    It 'refuses stale assessed command state before mutating <name>' -ForEach (Get-NonWingetActionCase) {
        param($name, $actionManifest, $assessment, $hostCommand, $versionArguments, $mismatchedVersionOutput, $expectedInstall)

        $manifestFile = New-ManifestFile -AllowedAction $actionManifest
        $calls = [Collections.Generic.List[string]]::new()

        {
            & $script:ScriptPath -Apply -ExecutionManifestPath $manifestFile.path `
                -ApprovedDigest $manifestFile.digest -Confirm:$false `
                -AssessmentProvider $assessment `
                -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $true; reason = 'TestHost' } } `
                -NowUtc ([datetime]'2026-09-26T05:10:00Z') `
                -NativeCommandRunner {
                    param($f, $a)
                    $call = '{0}|{1}' -f $f, ($a -join ' ')
                    [void]$calls.Add($call)
                    if ($f -ceq $hostCommand -and (($a -join ' ') -match 'PSVersionTable\.PSVersion|version --output json|^--version$')) {
                        return [pscustomobject]@{ exitCode = 0; stdout = $mismatchedVersionOutput; stderr = @() }
                    }
                    if ($call -match [regex]::Escape($expectedInstall)) {
                        return [pscustomobject]@{ exitCode = 0; stdout = @('mutated'); stderr = @() }
                    }
                    return [pscustomobject]@{ exitCode = 0; stdout = @('ok'); stderr = @() }
                } `
                -CommandResolver { param($commandName) @("C:\Approved\$commandName") } `
                -FileIdentityProvider {
                    param($path)
                    $sha = switch -Wildcard ($path) {
                        '*powershell.exe' { '3' * 64; break }
                        '*az.cmd' { '4' * 64; break }
                        '*code.cmd' { '5' * 64; break }
                        default { '1' * 64 }
                    }
                    [pscustomobject]@{ path = $path; sha256 = $sha }
                }
        } | Should -Throw '*reviewed executable state changed*'

        ($calls -join "`n") | Should -Not -Match ([regex]::Escape($expectedInstall))
    }

    It 'fails read-back verification when <name> does not prove its reviewed postcondition' -ForEach (Get-NonWingetActionCase) {
        param($name, $actionManifest, $assessment, $hostCommand, $versionArguments, $passingReadBackOutput, $readBackArguments, $expectedInstall, $failedReadBackOutput)

        $manifestFile = New-ManifestFile -AllowedAction $actionManifest

        $result = & $script:ScriptPath -Apply -ExecutionManifestPath $manifestFile.path `
            -ApprovedDigest $manifestFile.digest -Confirm:$false `
            -AssessmentProvider $assessment `
            -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $true; reason = 'TestHost' } } `
            -NowUtc ([datetime]'2026-09-26T05:10:00Z') `
            -NativeCommandRunner {
                param($f, $a)
                $call = '{0}|{1}' -f $f, ($a -join ' ')
                if ($f -ceq $hostCommand -and (($a -join ' ') -match 'PSVersionTable\.PSVersion|version --output json|^--version$')) {
                    switch -Wildcard ($hostCommand) {
                        '*powershell.exe' { return [pscustomobject]@{ exitCode = 0; stdout = @('5.1.26100.6584'); stderr = @() } }
                        '*az.cmd' { return [pscustomobject]@{ exitCode = 0; stdout = @('{"azure-cli":"2.78.0"}'); stderr = @() } }
                        '*code.cmd' { return [pscustomobject]@{ exitCode = 0; stdout = @('1.95.0'); stderr = @() } }
                    }
                }
                if ($call -match [regex]::Escape($expectedInstall)) {
                    return [pscustomobject]@{ exitCode = 0; stdout = @('mutated'); stderr = @() }
                }
                if ($call -ceq ('{0}|{1}' -f $hostCommand, $readBackArguments)) {
                    return [pscustomobject]@{ exitCode = 0; stdout = $failedReadBackOutput; stderr = @() }
                }
                return [pscustomobject]@{ exitCode = 0; stdout = @('ok'); stderr = @() }
            } `
            -CommandResolver { param($commandName) @("C:\Approved\$commandName") } `
            -FileIdentityProvider {
                param($path)
                $sha = switch -Wildcard ($path) {
                    '*powershell.exe' { '3' * 64; break }
                    '*az.cmd' { '4' * 64; break }
                    '*code.cmd' { '5' * 64; break }
                    default { '1' * 64 }
                }
                [pscustomobject]@{ path = $path; sha256 = $sha }
            }

        $result.operations[0].status | Should -Be 'Failed'
        $result.operations[0].readBack.status | Should -Be 'Failed'
        @($result.operations[0].recovery).Count | Should -BeGreaterThan 0
    }

    It 'refuses a changed executable identity before mutation' {
        $manifestFile = New-ManifestFile -AllowedAction ([pscustomobject][ordered]@{
            action = 'InstallPesterExact'
            targetId = 'Pester'
            packageSource = 'PSGallery'
            scope = 'CurrentUser'
            requiredVersion = '5.7.1'
            expectedPostcondition = 'Pester 5.7.1 resolves in CurrentUser scope'
        })
        $calls = [Collections.Generic.List[string]]::new()

        {
            & $script:ScriptPath -Apply -ExecutionManifestPath $manifestFile.path `
                -ApprovedDigest $manifestFile.digest -Confirm:$false `
                -AssessmentProvider { New-SyntheticAssessment -ToolOverrides @{ Pester = @{ status = 'Missing'; version = $null; executablePath = $null; executableSha256 = $null } } -VsCodeExtensionOverrides @{ status = 'Ready'; diagnostic = $null } } `
                -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $true; reason = 'TestHost' } } `
                -NowUtc ([datetime]'2026-09-26T05:10:00Z') `
                -CommandResolver { param($name) if ($name -eq 'powershell.exe') { @('C:\Approved\powershell.exe') } else { @("C:\Approved\$name") } } `
                -FileIdentityProvider { param($path) [pscustomobject]@{ path = $path; sha256 = ('f' * 64) } } `
                -NativeCommandRunner { param($f, $a) [void]$calls.Add($f) }
        } | Should -Throw '*executable identity changed*'

        $calls.Count | Should -Be 0
    }

    It 'marks machine-scope reviewed installs as requiring elevation in preview' {
        $result = & $script:ScriptPath -RepositoryRoot (Join-Path $TestDrive 'repo-elevation') `
            -ReportPath (Join-Path $TestDrive 'preview-elevation') `
            -AssessmentProvider { New-SyntheticAssessment -MissingTool Git } `
            -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $true; reason = 'TestHost' } }

        $planResult = @($result)[-1]
        $plan = Get-Content -Raw -LiteralPath (Join-Path $planResult.reportDirectory 'workstation-plan.json') | ConvertFrom-Json
        ($plan.operations | Where-Object targetId -eq 'Git.Git' | Select-Object -First 1).requiresElevation | Should -BeTrue
    }

    It 'refuses machine-scope apply when the current token is not elevated' {
        $isElevated = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).
            IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        if ($isElevated) {
            Set-ItResult -Skipped -Because 'This coverage requires a non-elevated token.'
            return
        }

        $calls = [Collections.Generic.List[string]]::new()
        $result = & $script:ScriptPath -Apply -ExecutionManifestPath $script:ValidManifest `
            -ApprovedDigest $script:ApprovedDigest -Confirm:$false `
            -AssessmentProvider { New-SyntheticAssessment -MissingTool Git -VsCodeExtensionOverrides @{ status = 'Ready'; diagnostic = $null } } `
            -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $true; reason = 'TestHost' } } `
            -NowUtc ([datetime]'2026-09-26T05:10:00Z') `
            -CommandResolver { param($commandName) @("C:\Approved\$commandName") } `
            -FileIdentityProvider {
                param($path)
                $sha = switch -Wildcard ($path) {
                    '*winget.exe' { '1' * 64; break }
                    default { '2' * 64 }
                }
                [pscustomobject]@{ path = $path; sha256 = $sha }
            } `
            -NativeCommandRunner {
                param($f, $a)
                [void]$calls.Add(('{0}|{1}' -f $f, ($a -join ' ')))
                if ($f -eq 'C:\Approved\winget.exe' -and ($a -join ' ') -eq '--version') {
                    return [pscustomobject]@{ exitCode = 0; stdout = @('1.9.25200'); stderr = @() }
                }
                [pscustomobject]@{ exitCode = 0; stdout = @('synthetic'); stderr = @() }
            }

        $calls.Count | Should -Be 0
        $result.operations[0].status | Should -Be 'Manual'
    }

    It 'preserves blocked and manual planning states and emits only executable actions into the manifest' {
        $reportPath = Join-Path $TestDrive 'blocked-preview'
        $result = & $script:ScriptPath -RepositoryRoot (Join-Path $TestDrive 'repo-blocked') `
            -ReportPath $reportPath `
            -AssessmentProvider {
                New-SyntheticAssessment `
                    -ToolOverrides @{
                        Git = @{
                            status = 'Blocked'; version = $null; executablePath = $null; executableSha256 = $null
                            diagnostic = 'Executable resolution for git.exe is ambiguous.'
                        }
                        WindowsPowerShell = @{
                            status = 'Blocked'; version = '5.0.0'; executablePath = 'C:\Approved\powershell.exe'; executableSha256 = ('3' * 64)
                            diagnostic = 'Reviewed version policy failed for WindowsPowerShell.'
                        }
                        Pester = @{
                            status = 'Blocked'; version = '5.6.0'; executablePath = 'C:\Approved\powershell.exe'; executableSha256 = ('3' * 64)
                            diagnostic = 'Reviewed version policy failed for Pester.'
                        }
                    } `
                    -VsCodeExtensionOverrides @{ status = 'Ready'; diagnostic = $null }
            } `
            -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $true; reason = 'TestHost' } }

        $manifest = Get-Content -Raw -LiteralPath (Join-Path $reportPath 'workstation-execution-manifest.json') | ConvertFrom-Json
        $planResult = @($result)[-1]
        $plan = Get-Content -Raw -LiteralPath (Join-Path $planResult.reportDirectory 'workstation-plan.json') | ConvertFrom-Json
        ($plan.operations | Where-Object targetId -eq 'Git.Git' | Select-Object -First 1).classification | Should -Be 'Blocked'
        ($plan.operations | Where-Object targetId -eq 'WindowsPowerShell' | Select-Object -First 1).classification | Should -Be 'Manual'
        ($plan.operations | Where-Object targetId -eq 'Pester' | Select-Object -First 1).classification | Should -Be 'Update'
        @($manifest.allowedActions).Count | Should -Be 1
        $manifest.allowedActions[0].targetId | Should -Be 'Pester'
    }

    It 'keeps executable policy actions isolated from summary-writer mutation' {
        $manifestFile = New-ManifestFile -AllowedAction ([pscustomobject][ordered]@{
            action = 'InstallPesterExact'
            targetId = 'Pester'
            packageSource = 'PSGallery'
            scope = 'CurrentUser'
            requiredVersion = '5.7.1'
            expectedPostcondition = 'Pester 5.7.1 resolves in CurrentUser scope'
        })
        $calls = [Collections.Generic.List[string]]::new()

        & $script:ScriptPath -Apply -ExecutionManifestPath $manifestFile.path `
            -ApprovedDigest $manifestFile.digest -Confirm:$false `
            -AssessmentProvider { New-SyntheticAssessment -ToolOverrides @{ Pester = @{ status = 'Missing'; version = $null; executablePath = $null; executableSha256 = $null } } -VsCodeExtensionOverrides @{ status = 'Ready'; diagnostic = $null } } `
            -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $true; reason = 'TestHost' } } `
            -NowUtc ([datetime]'2026-09-26T05:10:00Z') `
            -CommandResolver { param($name) if ($name -eq 'powershell.exe') { @('C:\Approved\powershell.exe') } else { @("C:\Approved\$name") } } `
            -FileIdentityProvider {
                param($path)
                [pscustomobject]@{
                    path = $path
                    sha256 = $(if ($path -like '*powershell.exe') { '3' * 64 } else { '2' * 64 })
                }
            } `
            -SummaryWriter { param($rows) $rows[0].packageId = 'Synthetic.Mutated' } `
            -NativeCommandRunner {
                param($f, $a)
                [void]$calls.Add(('{0}|{1}' -f $f, ($a -join ' ')))
                if ($f -eq 'C:\Approved\powershell.exe' -and ($a -join ' ') -match 'PSVersionTable\.PSVersion') {
                    return [pscustomobject]@{ exitCode = 0; stdout = @('5.1.26100.6584'); stderr = @() }
                }
                if ($f -eq 'C:\Approved\powershell.exe' -and ($a -join ' ') -match "Get-Module -ListAvailable Pester") {
                    return [pscustomobject]@{ exitCode = 0; stdout = @('5.7.1'); stderr = @() }
                }
                [pscustomobject]@{ exitCode = 0; stdout = @('synthetic'); stderr = @() }
            } | Out-Null

        ($calls -join "`n") | Should -Match "Install-Module 'Pester'"
        ($calls -join "`n") | Should -Not -Match 'Synthetic\.Mutated'
    }

    It 'refuses every manifest argument that differs from reviewed policy' -ForEach @(
        @{ field = 'packageId'; value = 'Synthetic.Other' }
        @{ field = 'packageSource'; value = 'unreviewed' }
        @{ field = 'scope'; value = 'user' }
        @{ field = 'requiredVersion'; value = '99.0.0' }
        @{ field = 'expectedPostcondition'; value = 'skip verification' }
    ) {
        param([string]$field, [string]$value)

        $manifest = Get-Content -Raw -LiteralPath $script:ValidManifest | ConvertFrom-Json
        $allowedAction = [ordered]@{
            action = [string]$manifest.allowedActions[0].action
            targetId = [string]$manifest.allowedActions[0].targetId
            packageSource = [string]$manifest.allowedActions[0].packageSource
            packageId = [string]$manifest.allowedActions[0].packageId
            scope = [string]$manifest.allowedActions[0].scope
            expectedPostcondition = [string]$manifest.allowedActions[0].expectedPostcondition
        }
        $allowedAction[$field] = $value
        $copy = New-RunbookExecutionManifest -RunId ([guid]$manifest.runId) -Kind $manifest.kind `
            -SourceCommit $manifest.sourceCommit -AssessmentDigest $manifest.assessmentDigest `
            -TargetStableId $manifest.target.stableId -AuthenticationContext $manifest.authentication `
            -AllowedActions @([pscustomobject]$allowedAction) -ToolVersions @{} `
            -GeneratedAtUtc ([datetime]$manifest.generatedAtUtc)
        $path = Join-Path $TestDrive "tampered-$field.json"
        Write-CanonicalJson -InputObject $copy -Path $path | Out-Null
        $calls = [Collections.Generic.List[string]]::new()

        {
            & $script:ScriptPath -Apply -ExecutionManifestPath $path -ApprovedDigest $copy.digest `
                -Confirm:$false -AssessmentProvider { New-SyntheticAssessment -MissingTool Git } `
                -InteractiveHostProbe { [pscustomobject]@{ isInteractive = $true; reason = 'TestHost' } } `
                -NowUtc ([datetime]'2026-09-26T05:10:00Z') `
                -NativeCommandRunner { param($f, $a) [void]$calls.Add($f) }
        } | Should -Throw '*arguments differ from reviewed policy*'

        $calls.Count | Should -Be 0
    }
}
