BeforeAll {
    $script:repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
    $script:installerPath = Join-Path $script:repositoryRoot '.github\cli\Install-CiTestDependencies.ps1'
    $script:runnerPath = Join-Path $script:repositoryRoot '.github\cli\Invoke-MaintainedTestGroup.ps1'
    $script:testLeaf = '.github/cli/tests/CiTestExecution.Tests.ps1'
    $script:resultRoot = Join-Path $script:repositoryRoot 'test-results\unit-ci-test-execution'

    function script:Assert-InstallerExists {
        (Test-Path -LiteralPath $script:installerPath -PathType Leaf) |
            Should -BeTrue -Because 'the CI dependency installer must exist'
    }

    function script:Assert-RunnerExists {
        (Test-Path -LiteralPath $script:runnerPath -PathType Leaf) |
            Should -BeTrue -Because 'the maintained Pester runner must exist'
    }

    function script:New-Clock {
        $clock = {
            param()

            [datetime]::SpecifyKind(
                [datetime]'2026-10-22T10:00:00',
                [DateTimeKind]::Utc
            )
        }.GetNewClosure()

        $clock
    }

    function script:New-SuccessfulModuleInstaller {
        param(
            [Parameter(Mandatory)]
            [AllowEmptyCollection()]
            [Collections.Generic.List[object]]$Calls
        )

        $moduleInstaller = {
            param([string]$Name, [string]$RequiredVersion, [int]$Attempt)

            $Calls.Add([pscustomobject]@{
                Name = $Name
                RequiredVersion = $RequiredVersion
                Attempt = $Attempt
            })
        }.GetNewClosure()

        $moduleInstaller
    }

    function script:New-SuccessfulModuleVerifier {
        param(
            [Parameter(Mandatory)]
            [AllowEmptyCollection()]
            [Collections.Generic.List[object]]$Calls
        )

        $moduleVerifier = {
            param([string]$Name, [string]$RequiredVersion)

            $Calls.Add([pscustomobject]@{
                Name = $Name
                RequiredVersion = $RequiredVersion
            })
            [version]'5.7.1'
        }.GetNewClosure()

        $moduleVerifier
    }

    function script:New-SuccessfulPythonRunner {
        param(
            [Parameter(Mandatory)]
            [AllowEmptyCollection()]
            [Collections.Generic.List[object]]$Calls
        )

        $pythonRunner = {
            param(
                [string[]]$Arguments,
                [ValidateSet('Acquire', 'Verify')][string]$Phase,
                [int]$Attempt
            )

            $Calls.Add([pscustomobject]@{
                Arguments = [string[]]@($Arguments)
                Phase = $Phase
                Attempt = $Attempt
            })
            [pscustomobject]@{
                ExitCode = [int]0
                Detail = [string]'success'
            }
        }.GetNewClosure()

        $pythonRunner
    }

    function script:New-Sleeper {
        param(
            [Parameter(Mandatory)]
            [AllowEmptyCollection()]
            [Collections.Generic.List[double]]$Delays
        )

        $sleeper = {
            param([timespan]$Delay)

            $Delays.Add($Delay.TotalSeconds)
        }.GetNewClosure()

        $sleeper
    }

    function script:New-PesterResult {
        param(
            [int]$TotalCount = 1,
            [int]$FailedCount = 0,
            [int]$FailedContainersCount = 0,
            [string]$Result = 'Passed'
        )

        [pscustomobject]@{
            TotalCount = $TotalCount
            FailedCount = $FailedCount
            FailedContainersCount = $FailedContainersCount
            Result = $Result
        }
    }

    function script:New-RunnerProbe {
        param(
            [Parameter(Mandatory)]
            [psobject]$Result,

            [switch]$SkipResultFile
        )

        $state = [ordered]@{
            Configurations = [Collections.Generic.List[object]]::new()
            ApplicationNames = [Collections.Generic.List[string]]::new()
            InvokeCount = 0
            ParentExisted = $false
        }

        $pesterInvoker = {
            param([PesterConfiguration]$Configuration)

            $state.InvokeCount++
            $state.Configurations.Add($Configuration)
            $resultPath = [string]$Configuration.TestResult.OutputPath.Value
            $state.ParentExisted = Test-Path -LiteralPath (
                Split-Path -Parent $resultPath
            ) -PathType Container
            if (-not $SkipResultFile) {
                [IO.File]::WriteAllText(
                    $resultPath,
                    '<test-results />',
                    [Text.UTF8Encoding]::new($false)
                )
            }
            $Result
        }.GetNewClosure()

        $applicationResolver = {
            param(
                [ValidateSet('git.exe', 'pwsh.exe')]
                [string]$Name
            )

            $state.ApplicationNames.Add($Name)
            if ($Name -ceq 'git.exe') {
                [string[]]@(
                    'C:\tools\git-first.exe'
                    'C:\tools\git-second.exe'
                )
            }
            else {
                [string[]]@(
                    'C:\tools\pwsh-first.exe'
                    'C:\tools\pwsh-second.exe'
                )
            }
        }.GetNewClosure()

        [pscustomobject]@{
            State = $state
            PesterInvoker = $pesterInvoker
            ApplicationResolver = $applicationResolver
            Clock = New-Clock
        }
    }

    function script:New-RunnerParameters {
        param(
            [Parameter(Mandatory)]
            [psobject]$Probe,

            [Parameter(Mandatory)]
            [string]$OutputPath
        )

        @{
            Path = [string[]]@($script:testLeaf)
            OutputPath = $OutputPath
            PesterInvoker = $Probe.PesterInvoker
            ApplicationResolver = $Probe.ApplicationResolver
            Clock = $Probe.Clock
        }
    }

    function script:New-InjectedFileSystemProbe {
        param(
            [Parameter(Mandatory)]
            [string[]]$ReparsePaths
        )

        [string[]]$markedPaths = @(
            $ReparsePaths |
                ForEach-Object { [IO.Path]::GetFullPath($_) }
        )
        $fileSystemProbe = {
            param([string]$LiteralPath)

            $item = Get-Item `
                -LiteralPath $LiteralPath `
                -Force `
                -ErrorAction SilentlyContinue
            if ($null -eq $item) {
                return [pscustomobject]@{
                    Exists = [bool]$false
                    IsContainer = [bool]$false
                    IsLeaf = [bool]$false
                    Attributes = [IO.FileAttributes]::Normal
                }
            }

            $attributes = [IO.FileAttributes]$item.Attributes
            if (
                @(
                    $markedPaths |
                        Where-Object {
                            [string]::Equals(
                                $_,
                                [IO.Path]::GetFullPath($LiteralPath),
                                [StringComparison]::OrdinalIgnoreCase
                            )
                        }
                ).Count -ne 0
            ) {
                $attributes = $attributes -bor [IO.FileAttributes]::ReparsePoint
            }
            [pscustomobject]@{
                Exists = [bool]$true
                IsContainer = [bool]$item.PSIsContainer
                IsLeaf = [bool](-not $item.PSIsContainer)
                Attributes = [IO.FileAttributes]$attributes
            }
        }.GetNewClosure()

        $fileSystemProbe
    }

    function script:New-PostRemovalReparseProbe {
        param(
            [Parameter(Mandatory)]
            [string]$OutputPath,

            [Parameter(Mandatory)]
            [string]$ReparsePath
        )

        $resolvedOutputPath = [IO.Path]::GetFullPath($OutputPath)
        $resolvedReparsePath = [IO.Path]::GetFullPath($ReparsePath)
        $state = [pscustomobject]@{
            SawExistingOutput = [bool]$false
        }
        $fileSystemProbe = {
            param([string]$LiteralPath)

            $resolvedLiteralPath = [IO.Path]::GetFullPath($LiteralPath)
            $item = Get-Item `
                -LiteralPath $resolvedLiteralPath `
                -Force `
                -ErrorAction SilentlyContinue
            if (
                [string]::Equals(
                    $resolvedLiteralPath,
                    $resolvedOutputPath,
                    [StringComparison]::OrdinalIgnoreCase
                ) -and
                $null -ne $item
            ) {
                $state.SawExistingOutput = $true
            }

            $currentOutput = Get-Item `
                -LiteralPath $resolvedOutputPath `
                -Force `
                -ErrorAction SilentlyContinue
            $afterRemoval = $state.SawExistingOutput -and $null -eq $currentOutput
            $markAsReparse = $afterRemoval -and [string]::Equals(
                $resolvedLiteralPath,
                $resolvedReparsePath,
                [StringComparison]::OrdinalIgnoreCase
            )
            if ($null -eq $item -and -not $markAsReparse) {
                return [pscustomobject]@{
                    Exists = [bool]$false
                    IsContainer = [bool]$false
                    IsLeaf = [bool]$false
                    Attributes = [IO.FileAttributes]::Normal
                }
            }

            $isContainer = $null -ne $item -and [bool]$item.PSIsContainer
            $attributes = if ($null -eq $item) {
                [IO.FileAttributes]::Normal
            }
            else {
                [IO.FileAttributes]$item.Attributes
            }
            if ($markAsReparse) {
                $attributes = $attributes -bor [IO.FileAttributes]::ReparsePoint
            }
            [pscustomobject]@{
                Exists = [bool]$true
                IsContainer = [bool]$isContainer
                IsLeaf = [bool](-not $isContainer)
                Attributes = [IO.FileAttributes]$attributes
            }
        }.GetNewClosure()

        $fileSystemProbe
    }
}

AfterAll {
    if (Test-Path -LiteralPath $script:resultRoot) {
        Remove-Item -LiteralPath $script:resultRoot -Recurse -Force
    }
}

Describe 'CI dependency installation' {
    It 'acquires and verifies exact Pester 5.7.1 for every group' {
        Assert-InstallerExists
        (Get-Command -Name $script:installerPath).Parameters.Keys |
            Should -Not -Contain 'PesterInvoker'
        (Get-Command -Name $script:installerPath).Parameters.Keys |
            Should -Not -Contain 'TestRunner'

        foreach ($group in @('Repository', 'Infrastructure', 'Hr', 'Lifecycle')) {
            $moduleCalls = [Collections.Generic.List[object]]::new()
            $verifyCalls = [Collections.Generic.List[object]]::new()
            $pythonCalls = [Collections.Generic.List[object]]::new()
            $delays = [Collections.Generic.List[double]]::new()

            & $script:installerPath `
                -Group $group `
                -ModuleInstaller (New-SuccessfulModuleInstaller -Calls $moduleCalls) `
                -ModuleVerifier (New-SuccessfulModuleVerifier -Calls $verifyCalls) `
                -PythonRunner (New-SuccessfulPythonRunner -Calls $pythonCalls) `
                -Sleeper (New-Sleeper -Delays $delays) `
                -Clock (New-Clock) |
                Out-Null

            $moduleCalls.Count | Should -Be 1
            $moduleCalls[0].Name | Should -BeExactly 'Pester'
            $moduleCalls[0].RequiredVersion | Should -BeExactly '5.7.1'
            $moduleCalls[0].Attempt | Should -Be 1
            $verifyCalls.Count | Should -Be 1
            $verifyCalls[0].Name | Should -BeExactly 'Pester'
            $verifyCalls[0].RequiredVersion | Should -BeExactly '5.7.1'
            $delays.Count | Should -Be 0
        }
    }

    It 'installs only hr/tests/requirements.txt and verifies jsonschema for Hr' {
        Assert-InstallerExists
        $moduleCalls = [Collections.Generic.List[object]]::new()
        $verifyCalls = [Collections.Generic.List[object]]::new()
        $pythonCalls = [Collections.Generic.List[object]]::new()
        $delays = [Collections.Generic.List[double]]::new()

        & $script:installerPath `
            -Group Hr `
            -ModuleInstaller (New-SuccessfulModuleInstaller -Calls $moduleCalls) `
            -ModuleVerifier (New-SuccessfulModuleVerifier -Calls $verifyCalls) `
            -PythonRunner (New-SuccessfulPythonRunner -Calls $pythonCalls) `
            -Sleeper (New-Sleeper -Delays $delays) `
            -Clock (New-Clock) |
            Out-Null

        $pythonCalls.Count | Should -Be 2
        ($pythonCalls[0].Arguments -join '|') |
            Should -BeExactly (
                '-m|pip|install|--disable-pip-version-check|--requirement|' +
                'hr/tests/requirements.txt'
            )
        $pythonCalls[0].Phase | Should -BeExactly 'Acquire'
        $pythonCalls[0].Attempt | Should -Be 1
        ($pythonCalls[1].Arguments -join '|') |
            Should -BeExactly '-c|import jsonschema'
        $pythonCalls[1].Phase | Should -BeExactly 'Verify'
        $pythonCalls[1].Attempt | Should -Be 1
    }

    It 'installs only infra/tests/requirements.txt and verifies jsonschema for Lifecycle' {
        Assert-InstallerExists
        $moduleCalls = [Collections.Generic.List[object]]::new()
        $verifyCalls = [Collections.Generic.List[object]]::new()
        $pythonCalls = [Collections.Generic.List[object]]::new()
        $delays = [Collections.Generic.List[double]]::new()

        & $script:installerPath `
            -Group Lifecycle `
            -ModuleInstaller (New-SuccessfulModuleInstaller -Calls $moduleCalls) `
            -ModuleVerifier (New-SuccessfulModuleVerifier -Calls $verifyCalls) `
            -PythonRunner (New-SuccessfulPythonRunner -Calls $pythonCalls) `
            -Sleeper (New-Sleeper -Delays $delays) `
            -Clock (New-Clock) |
            Out-Null

        $pythonCalls.Count | Should -Be 2
        ($pythonCalls[0].Arguments -join '|') |
            Should -BeExactly (
                '-m|pip|install|--disable-pip-version-check|--requirement|' +
                'infra/tests/requirements.txt'
            )
        $pythonCalls[0].Phase | Should -BeExactly 'Acquire'
        $pythonCalls[0].Attempt | Should -Be 1
        ($pythonCalls[1].Arguments -join '|') |
            Should -BeExactly '-c|import jsonschema'
        $pythonCalls[1].Phase | Should -BeExactly 'Verify'
        $pythonCalls[1].Attempt | Should -Be 1
    }

    It 'invokes no Python operation for Repository or Infrastructure' {
        Assert-InstallerExists
        foreach ($group in @('Repository', 'Infrastructure')) {
            $moduleCalls = [Collections.Generic.List[object]]::new()
            $verifyCalls = [Collections.Generic.List[object]]::new()
            $pythonCalls = [Collections.Generic.List[object]]::new()
            $delays = [Collections.Generic.List[double]]::new()

            & $script:installerPath `
                -Group $group `
                -ModuleInstaller (New-SuccessfulModuleInstaller -Calls $moduleCalls) `
                -ModuleVerifier (New-SuccessfulModuleVerifier -Calls $verifyCalls) `
                -PythonRunner (New-SuccessfulPythonRunner -Calls $pythonCalls) `
                -Sleeper (New-Sleeper -Delays $delays) `
                -Clock (New-Clock) |
                Out-Null

            $pythonCalls.Count | Should -Be 0
        }
    }

    It 'retries module acquisition twice and succeeds on attempt three' {
        Assert-InstallerExists
        $attempts = [Collections.Generic.List[int]]::new()
        $verifyCalls = [Collections.Generic.List[object]]::new()
        $pythonCalls = [Collections.Generic.List[object]]::new()
        $delays = [Collections.Generic.List[double]]::new()
        $moduleInstaller = {
            param([string]$Name, [string]$RequiredVersion, [int]$Attempt)

            $attempts.Add($Attempt)
            if ($Attempt -lt 3) {
                throw "module acquisition $Attempt"
            }
        }.GetNewClosure()

        & $script:installerPath `
            -Group Repository `
            -ModuleInstaller $moduleInstaller `
            -ModuleVerifier (New-SuccessfulModuleVerifier -Calls $verifyCalls) `
            -PythonRunner (New-SuccessfulPythonRunner -Calls $pythonCalls) `
            -Sleeper (New-Sleeper -Delays $delays) `
            -Clock (New-Clock) |
            Out-Null

        ($attempts -join ',') | Should -BeExactly '1,2,3'
        ($delays -join ',') | Should -BeExactly '2,4'
        $verifyCalls.Count | Should -Be 1
    }

    It 'fails after the third module acquisition failure' {
        Assert-InstallerExists
        $attempts = [Collections.Generic.List[int]]::new()
        $verifyCalls = [Collections.Generic.List[object]]::new()
        $pythonCalls = [Collections.Generic.List[object]]::new()
        $delays = [Collections.Generic.List[double]]::new()
        $moduleInstaller = {
            param([string]$Name, [string]$RequiredVersion, [int]$Attempt)

            $attempts.Add($Attempt)
            throw "terminal module failure $Attempt"
        }.GetNewClosure()

        {
            & $script:installerPath `
                -Group Repository `
                -ModuleInstaller $moduleInstaller `
                -ModuleVerifier (New-SuccessfulModuleVerifier -Calls $verifyCalls) `
                -PythonRunner (New-SuccessfulPythonRunner -Calls $pythonCalls) `
                -Sleeper (New-Sleeper -Delays $delays) `
                -Clock (New-Clock)
        } | Should -Throw -ExpectedMessage '*terminal module failure 3*'

        ($attempts -join ',') | Should -BeExactly '1,2,3'
        ($delays -join ',') | Should -BeExactly '2,4'
        $verifyCalls.Count | Should -Be 0
    }

    It 'retries pip acquisition twice and succeeds on attempt three' {
        Assert-InstallerExists
        $moduleCalls = [Collections.Generic.List[object]]::new()
        $verifyCalls = [Collections.Generic.List[object]]::new()
        $pythonCalls = [Collections.Generic.List[object]]::new()
        $delays = [Collections.Generic.List[double]]::new()
        $pythonRunner = {
            param(
                [string[]]$Arguments,
                [ValidateSet('Acquire', 'Verify')][string]$Phase,
                [int]$Attempt
            )

            $pythonCalls.Add([pscustomobject]@{
                Arguments = [string[]]@($Arguments)
                Phase = $Phase
                Attempt = $Attempt
            })
            if ($Phase -ceq 'Acquire' -and $Attempt -lt 3) {
                [pscustomobject]@{ ExitCode = 1; Detail = "pip failure $Attempt" }
            }
            else {
                [pscustomobject]@{ ExitCode = 0; Detail = 'success' }
            }
        }.GetNewClosure()

        & $script:installerPath `
            -Group Hr `
            -ModuleInstaller (New-SuccessfulModuleInstaller -Calls $moduleCalls) `
            -ModuleVerifier (New-SuccessfulModuleVerifier -Calls $verifyCalls) `
            -PythonRunner $pythonRunner `
            -Sleeper (New-Sleeper -Delays $delays) `
            -Clock (New-Clock) |
            Out-Null

        (@($pythonCalls | Where-Object Phase -CEQ 'Acquire').Attempt -join ',') |
            Should -BeExactly '1,2,3'
        @($pythonCalls | Where-Object Phase -CEQ 'Verify').Count | Should -Be 1
        ($delays -join ',') | Should -BeExactly '2,4'
    }

    It 'fails after the third pip acquisition failure' {
        Assert-InstallerExists
        $moduleCalls = [Collections.Generic.List[object]]::new()
        $verifyCalls = [Collections.Generic.List[object]]::new()
        $pythonCalls = [Collections.Generic.List[object]]::new()
        $delays = [Collections.Generic.List[double]]::new()
        $pythonRunner = {
            param(
                [string[]]$Arguments,
                [ValidateSet('Acquire', 'Verify')][string]$Phase,
                [int]$Attempt
            )

            $pythonCalls.Add([pscustomobject]@{
                Arguments = [string[]]@($Arguments)
                Phase = $Phase
                Attempt = $Attempt
            })
            [pscustomobject]@{
                ExitCode = 1
                Detail = "terminal pip failure $Attempt"
            }
        }.GetNewClosure()

        {
            & $script:installerPath `
                -Group Lifecycle `
                -ModuleInstaller (New-SuccessfulModuleInstaller -Calls $moduleCalls) `
                -ModuleVerifier (New-SuccessfulModuleVerifier -Calls $verifyCalls) `
                -PythonRunner $pythonRunner `
                -Sleeper (New-Sleeper -Delays $delays) `
                -Clock (New-Clock)
        } | Should -Throw -ExpectedMessage '*terminal pip failure 3*'

        (@($pythonCalls | Where-Object Phase -CEQ 'Acquire').Attempt -join ',') |
            Should -BeExactly '1,2,3'
        @($pythonCalls | Where-Object Phase -CEQ 'Verify').Count | Should -Be 0
        ($delays -join ',') | Should -BeExactly '2,4'
    }

    It 'never retries a wrong loaded Pester version' {
        Assert-InstallerExists
        $moduleCalls = [Collections.Generic.List[object]]::new()
        $verifyCalls = [Collections.Generic.List[object]]::new()
        $pythonCalls = [Collections.Generic.List[object]]::new()
        $delays = [Collections.Generic.List[double]]::new()
        $moduleVerifier = {
            param([string]$Name, [string]$RequiredVersion)

            $verifyCalls.Add([pscustomobject]@{
                Name = $Name
                RequiredVersion = $RequiredVersion
            })
            [version]'5.7.0'
        }.GetNewClosure()

        {
            & $script:installerPath `
                -Group Repository `
                -ModuleInstaller (New-SuccessfulModuleInstaller -Calls $moduleCalls) `
                -ModuleVerifier $moduleVerifier `
                -PythonRunner (New-SuccessfulPythonRunner -Calls $pythonCalls) `
                -Sleeper (New-Sleeper -Delays $delays) `
                -Clock (New-Clock)
        } | Should -Throw -ExpectedMessage '*CiDependencies.PesterVersion*'

        $moduleCalls.Count | Should -Be 1
        $verifyCalls.Count | Should -Be 1
        $delays.Count | Should -Be 0
    }

    It 'never retries a failed required Python import' {
        Assert-InstallerExists
        $moduleCalls = [Collections.Generic.List[object]]::new()
        $verifyCalls = [Collections.Generic.List[object]]::new()
        $pythonCalls = [Collections.Generic.List[object]]::new()
        $delays = [Collections.Generic.List[double]]::new()
        $pythonRunner = {
            param(
                [string[]]$Arguments,
                [ValidateSet('Acquire', 'Verify')][string]$Phase,
                [int]$Attempt
            )

            $pythonCalls.Add([pscustomobject]@{
                Arguments = [string[]]@($Arguments)
                Phase = $Phase
                Attempt = $Attempt
            })
            if ($Phase -ceq 'Verify') {
                [pscustomobject]@{
                    ExitCode = 1
                    Detail = 'jsonschema import failed'
                }
            }
            else {
                [pscustomobject]@{ ExitCode = 0; Detail = 'success' }
            }
        }.GetNewClosure()

        {
            & $script:installerPath `
                -Group Hr `
                -ModuleInstaller (New-SuccessfulModuleInstaller -Calls $moduleCalls) `
                -ModuleVerifier (New-SuccessfulModuleVerifier -Calls $verifyCalls) `
                -PythonRunner $pythonRunner `
                -Sleeper (New-Sleeper -Delays $delays) `
                -Clock (New-Clock)
        } | Should -Throw -ExpectedMessage '*jsonschema import failed*'

        @($pythonCalls | Where-Object Phase -CEQ 'Acquire').Count | Should -Be 1
        @($pythonCalls | Where-Object Phase -CEQ 'Verify').Count | Should -Be 1
        $delays.Count | Should -Be 0
    }

    It 'verifies Pester once and Python imports once' {
        Assert-InstallerExists
        $moduleCalls = [Collections.Generic.List[object]]::new()
        $verifyCalls = [Collections.Generic.List[object]]::new()
        $pythonCalls = [Collections.Generic.List[object]]::new()
        $delays = [Collections.Generic.List[double]]::new()

        $successOutput = @(
            & $script:installerPath `
                -Group Hr `
                -ModuleInstaller (New-SuccessfulModuleInstaller -Calls $moduleCalls) `
                -ModuleVerifier (New-SuccessfulModuleVerifier -Calls $verifyCalls) `
                -PythonRunner (New-SuccessfulPythonRunner -Calls $pythonCalls) `
                -Sleeper (New-Sleeper -Delays $delays) `
                -Clock (New-Clock)
        )

        $successOutput.Count | Should -Be 0
        $verifyCalls.Count | Should -Be 1
        @($pythonCalls | Where-Object Phase -CEQ 'Verify').Count | Should -Be 1
        $moduleCalls.Count | Should -Be 1
        @($pythonCalls | Where-Object Phase -CEQ 'Acquire').Count | Should -Be 1
    }

    It 'uses retry delays of two and four seconds only' {
        Assert-InstallerExists
        $moduleAttempts = [Collections.Generic.List[int]]::new()
        $verifyCalls = [Collections.Generic.List[object]]::new()
        $pythonCalls = [Collections.Generic.List[object]]::new()
        $delays = [Collections.Generic.List[double]]::new()
        $moduleInstaller = {
            param([string]$Name, [string]$RequiredVersion, [int]$Attempt)

            $moduleAttempts.Add($Attempt)
            if ($Attempt -lt 3) {
                throw "module retry $Attempt"
            }
        }.GetNewClosure()
        $pythonRunner = {
            param(
                [string[]]$Arguments,
                [ValidateSet('Acquire', 'Verify')][string]$Phase,
                [int]$Attempt
            )

            $pythonCalls.Add([pscustomobject]@{
                Arguments = [string[]]@($Arguments)
                Phase = $Phase
                Attempt = $Attempt
            })
            if ($Phase -ceq 'Acquire' -and $Attempt -lt 3) {
                [pscustomobject]@{ ExitCode = 1; Detail = "pip retry $Attempt" }
            }
            else {
                [pscustomobject]@{ ExitCode = 0; Detail = 'success' }
            }
        }.GetNewClosure()

        & $script:installerPath `
            -Group Lifecycle `
            -ModuleInstaller $moduleInstaller `
            -ModuleVerifier (New-SuccessfulModuleVerifier -Calls $verifyCalls) `
            -PythonRunner $pythonRunner `
            -Sleeper (New-Sleeper -Delays $delays) `
            -Clock (New-Clock) |
            Out-Null

        ($delays -join ',') | Should -BeExactly '2,4,2,4'
        @($delays | Where-Object { $_ -notin @(2, 4) }).Count | Should -Be 0
    }
}

Describe 'Fail-closed maintained Pester execution' {
    BeforeEach {
        if (Test-Path -LiteralPath $script:resultRoot) {
            Remove-Item -LiteralPath $script:resultRoot -Recurse -Force
        }
        $script:outputPath = Join-Path $script:resultRoot 'case\pester.xml'
    }

    It 'builds exact Throw non-exiting PassThru Detailed NUnit configuration' {
        Assert-RunnerExists
        $probe = New-RunnerProbe -Result (New-PesterResult)
        $parameters = New-RunnerParameters -Probe $probe -OutputPath $script:outputPath

        & $script:runnerPath @parameters | Out-Null

        $probe.State.Configurations.Count | Should -Be 1
        $configuration = $probe.State.Configurations[0]
        $configuration.Run.Path.Value.Count | Should -Be 1
        $configuration.Run.Path.Value[0] |
            Should -BeExactly (
                [IO.Path]::GetFullPath((Join-Path $script:repositoryRoot $script:testLeaf))
            )
        [bool]$configuration.Run.Throw.Value | Should -BeTrue
        [bool]$configuration.Run.Exit.Value | Should -BeFalse
        [bool]$configuration.Run.PassThru.Value | Should -BeTrue
        [string]$configuration.Output.Verbosity.Value | Should -BeExactly 'Detailed'
        [bool]$configuration.TestResult.Enabled.Value | Should -BeTrue
        [string]$configuration.TestResult.OutputFormat.Value |
            Should -BeExactly 'NUnitXml'
        [string]$configuration.TestResult.OutputPath.Value |
            Should -BeExactly ([IO.Path]::GetFullPath($script:outputPath))
    }

    It 'applies only the CICompatibilitySmoke include tag' {
        Assert-RunnerExists
        $probe = New-RunnerProbe -Result (New-PesterResult)
        $parameters = New-RunnerParameters -Probe $probe -OutputPath $script:outputPath
        $parameters.Tag = 'CICompatibilitySmoke'

        & $script:runnerPath @parameters | Out-Null

        $configuration = $probe.State.Configurations[0]
        ($configuration.Filter.Tag.Value -join ',') |
            Should -BeExactly 'CICompatibilitySmoke'
        $configuration.Filter.ExcludeTag.Value.Count | Should -Be 0
    }

    It 'applies only the CICompatibilitySmoke exclude tag' {
        Assert-RunnerExists
        $probe = New-RunnerProbe -Result (New-PesterResult)
        $parameters = New-RunnerParameters -Probe $probe -OutputPath $script:outputPath
        $parameters.ExcludeTag = 'CICompatibilitySmoke'

        & $script:runnerPath @parameters | Out-Null

        $configuration = $probe.State.Configurations[0]
        ($configuration.Filter.ExcludeTag.Value -join ',') |
            Should -BeExactly 'CICompatibilitySmoke'
        $configuration.Filter.Tag.Value.Count | Should -Be 0
    }

    It 'rejects simultaneous include and exclude tags' {
        Assert-RunnerExists
        $probe = New-RunnerProbe -Result (New-PesterResult)
        $parameters = New-RunnerParameters -Probe $probe -OutputPath $script:outputPath
        $parameters.Tag = 'CICompatibilitySmoke'
        $parameters.ExcludeTag = 'CICompatibilitySmoke'

        {
            & $script:runnerPath @parameters
        } | Should -Throw
        $probe.State.InvokeCount | Should -Be 0
    }

    It 'creates the repository-contained NUnit parent directory' {
        Assert-RunnerExists
        $probe = New-RunnerProbe -Result (New-PesterResult)
        $parameters = New-RunnerParameters -Probe $probe -OutputPath $script:outputPath

        Test-Path -LiteralPath (Split-Path -Parent $script:outputPath) |
            Should -BeFalse
        & $script:runnerPath @parameters | Out-Null

        $probe.State.ParentExisted | Should -BeTrue
        Test-Path -LiteralPath $script:outputPath -PathType Leaf |
            Should -BeTrue
    }

    It 'allows an output file directly under the repository root' {
        Assert-RunnerExists
        $outputPath = Join-Path $script:repositoryRoot (
            'task2-root-output-{0}.xml' -f [guid]::NewGuid().ToString('N')
        )
        $probe = New-RunnerProbe -Result (New-PesterResult)
        $parameters = New-RunnerParameters -Probe $probe -OutputPath $outputPath

        try {
            $summary = & $script:runnerPath @parameters

            $summary.Result | Should -BeExactly 'Passed'
            $summary.OutputPath |
                Should -BeExactly ([IO.Path]::GetFullPath($outputPath))
            $probe.State.InvokeCount | Should -Be 1
        }
        finally {
            if (Test-Path -LiteralPath $outputPath) {
                Remove-Item -LiteralPath $outputPath -Force
            }
        }
    }

    It 'rejects an injected reparse selected test file' {
        Assert-RunnerExists
        $probe = New-RunnerProbe -Result (New-PesterResult)
        $parameters = New-RunnerParameters -Probe $probe -OutputPath $script:outputPath
        $selectedTest = [IO.Path]::GetFullPath((
            Join-Path $script:repositoryRoot $script:testLeaf
        ))
        $parameters.FileSystemProbe = New-InjectedFileSystemProbe `
            -ReparsePaths @($selectedTest)

        {
            & $script:runnerPath @parameters
        } | Should -Throw -ExpectedMessage '*CiPester.ReparsePoint*'
        $probe.State.InvokeCount | Should -Be 0
    }

    It 'rejects an injected reparse selected test ancestor' {
        Assert-RunnerExists
        $probe = New-RunnerProbe -Result (New-PesterResult)
        $parameters = New-RunnerParameters -Probe $probe -OutputPath $script:outputPath
        $selectedAncestor = Join-Path $script:repositoryRoot '.github\cli\tests'
        $parameters.FileSystemProbe = New-InjectedFileSystemProbe `
            -ReparsePaths @($selectedAncestor)

        {
            & $script:runnerPath @parameters
        } | Should -Throw -ExpectedMessage '*CiPester.ReparsePoint*'
        $probe.State.InvokeCount | Should -Be 0
    }

    It 'rejects an injected reparse output ancestor after creating result directories' {
        Assert-RunnerExists
        $outputAncestor = Join-Path $script:resultRoot 'reparse-parent'
        $outputPath = Join-Path $outputAncestor 'case\pester.xml'
        $probe = New-RunnerProbe -Result (New-PesterResult)
        $parameters = New-RunnerParameters -Probe $probe -OutputPath $outputPath
        $parameters.FileSystemProbe = New-InjectedFileSystemProbe `
            -ReparsePaths @($outputAncestor)

        {
            & $script:runnerPath @parameters
        } | Should -Throw -ExpectedMessage '*CiPester.ReparsePoint*'
        $probe.State.InvokeCount | Should -Be 0
        Test-Path -LiteralPath (Split-Path -Parent $outputPath) |
            Should -BeTrue
    }

    It 'rejects an injected reparse existing output target' {
        Assert-RunnerExists
        [void](New-Item `
            -ItemType Directory `
            -Path (Split-Path -Parent $script:outputPath) `
            -Force)
        [IO.File]::WriteAllText(
            $script:outputPath,
            '<existing />',
            [Text.UTF8Encoding]::new($false)
        )
        $probe = New-RunnerProbe -Result (New-PesterResult)
        $parameters = New-RunnerParameters -Probe $probe -OutputPath $script:outputPath
        $parameters.FileSystemProbe = New-InjectedFileSystemProbe `
            -ReparsePaths @($script:outputPath)

        {
            & $script:runnerPath @parameters
        } | Should -Throw -ExpectedMessage '*CiPester.ReparsePoint*'
        $probe.State.InvokeCount | Should -Be 0
        Test-Path -LiteralPath $script:outputPath -PathType Leaf |
            Should -BeTrue
    }

    It 'rejects an output ancestor changed to reparse after target removal' {
        Assert-RunnerExists
        $outputAncestor = Join-Path $script:resultRoot 'post-removal-ancestor'
        [void](New-Item -ItemType Directory -Path $outputAncestor -Force)
        $outputPath = Join-Path $outputAncestor 'pester.xml'
        [IO.File]::WriteAllText(
            $outputPath,
            '<existing />',
            [Text.UTF8Encoding]::new($false)
        )
        $probe = New-RunnerProbe -Result (New-PesterResult)
        $parameters = New-RunnerParameters -Probe $probe -OutputPath $outputPath
        $parameters.FileSystemProbe = New-PostRemovalReparseProbe `
            -OutputPath $outputPath `
            -ReparsePath $outputAncestor

        {
            & $script:runnerPath @parameters
        } | Should -Throw -ExpectedMessage '*CiPester.ReparsePoint*'
        $probe.State.InvokeCount | Should -Be 0
    }

    It 'rejects an output target boundary changed to reparse after removal' {
        Assert-RunnerExists
        [void](New-Item `
            -ItemType Directory `
            -Path (Split-Path -Parent $script:outputPath) `
            -Force)
        [IO.File]::WriteAllText(
            $script:outputPath,
            '<existing />',
            [Text.UTF8Encoding]::new($false)
        )
        $probe = New-RunnerProbe -Result (New-PesterResult)
        $parameters = New-RunnerParameters -Probe $probe -OutputPath $script:outputPath
        $parameters.FileSystemProbe = New-PostRemovalReparseProbe `
            -OutputPath $script:outputPath `
            -ReparsePath $script:outputPath

        {
            & $script:runnerPath @parameters
        } | Should -Throw -ExpectedMessage '*CiPester.ReparsePoint*'
        $probe.State.InvokeCount | Should -Be 0
    }

    It 'rejects a relative output path and a path outside the repository' {
        Assert-RunnerExists
        $outsidePath = Join-Path (
            Split-Path -Parent $script:repositoryRoot
        ) ('outside-{0}.xml' -f [guid]::NewGuid().ToString('N'))

        foreach ($invalidPath in @('test-results\relative.xml', $outsidePath)) {
            $probe = New-RunnerProbe -Result (New-PesterResult)
            $parameters = New-RunnerParameters -Probe $probe -OutputPath $invalidPath
            {
                & $script:runnerPath @parameters
            } | Should -Throw -ExpectedMessage '*CiPester.OutputPath*'
            $probe.State.InvokeCount | Should -Be 0
        }
    }

    It 'fails when TotalCount is zero' {
        Assert-RunnerExists
        $probe = New-RunnerProbe -Result (New-PesterResult -TotalCount 0)
        $parameters = New-RunnerParameters -Probe $probe -OutputPath $script:outputPath

        {
            & $script:runnerPath @parameters
        } | Should -Throw -ExpectedMessage '*CiPester.ZeroTests*'
    }

    It 'fails when FailedCount is positive' {
        Assert-RunnerExists
        $probe = New-RunnerProbe -Result (New-PesterResult -FailedCount 1)
        $parameters = New-RunnerParameters -Probe $probe -OutputPath $script:outputPath

        {
            & $script:runnerPath @parameters
        } | Should -Throw -ExpectedMessage '*CiPester.FailedTests*'
    }

    It 'fails when FailedContainersCount is positive' {
        Assert-RunnerExists
        $probe = New-RunnerProbe -Result (
            New-PesterResult -FailedContainersCount 1
        )
        $parameters = New-RunnerParameters -Probe $probe -OutputPath $script:outputPath

        {
            & $script:runnerPath @parameters
        } | Should -Throw -ExpectedMessage '*CiPester.FailedContainers*'
    }

    It 'fails when final Result is not Passed' {
        Assert-RunnerExists
        $probe = New-RunnerProbe -Result (New-PesterResult -Result 'Failed')
        $parameters = New-RunnerParameters -Probe $probe -OutputPath $script:outputPath

        {
            & $script:runnerPath @parameters
        } | Should -Throw -ExpectedMessage '*CiPester.ResultNotPassed*'
    }

    It 'fails when a successful invocation does not create the requested NUnit file' {
        Assert-RunnerExists
        $probe = New-RunnerProbe -Result (New-PesterResult) -SkipResultFile
        $parameters = New-RunnerParameters -Probe $probe -OutputPath $script:outputPath

        {
            & $script:runnerPath @parameters
        } | Should -Throw -ExpectedMessage '*CiPester.ResultFileMissing*'
        $probe.State.InvokeCount | Should -Be 1
    }

    It 'invokes Pester exactly once for a test failure' {
        Assert-RunnerExists
        $probe = New-RunnerProbe -Result (New-PesterResult -FailedCount 1)
        $parameters = New-RunnerParameters -Probe $probe -OutputPath $script:outputPath

        {
            & $script:runnerPath @parameters
        } | Should -Throw -ExpectedMessage '*CiPester.FailedTests*'
        $probe.State.InvokeCount | Should -Be 1
    }

    It 'logs selected paths host Pester applications start and finish' {
        Assert-RunnerExists
        $probe = New-RunnerProbe -Result (New-PesterResult)
        $parameters = New-RunnerParameters -Probe $probe -OutputPath $script:outputPath
        $information = @()

        $summary = & $script:runnerPath @parameters -InformationVariable information

        @($summary).Count | Should -Be 1
        $messages = @(
            $information |
                ForEach-Object {
                    if ($_ -is [Management.Automation.InformationRecord]) {
                        [string]$_.MessageData
                    }
                    else {
                        [string]$_
                    }
                }
        ) -join "`n"
        $messages | Should -Match 'CiTestExecution[.]Tests[.]ps1'
        $messages | Should -Match 'CI Pester host='
        $messages | Should -Match 'CI Pester version=5[.]7[.]1'
        $messages | Should -Match 'CI Pester git applications='
        $messages | Should -Match 'CI Pester pwsh applications='
        $messages | Should -Match 'CI Pester start='
        $messages | Should -Match 'CI Pester finish='
    }

    It 'chooses one deterministic native application scalar' {
        Assert-RunnerExists
        $probe = New-RunnerProbe -Result (New-PesterResult)
        $parameters = New-RunnerParameters -Probe $probe -OutputPath $script:outputPath
        $information = @()

        & $script:runnerPath @parameters -InformationVariable information |
            Out-Null

        ($probe.State.ApplicationNames -join ',') |
            Should -BeExactly 'git.exe,pwsh.exe'
        $messages = @(
            $information |
                ForEach-Object {
                    if ($_ -is [Management.Automation.InformationRecord]) {
                        [string]$_.MessageData
                    }
                    else {
                        [string]$_
                    }
                }
        ) -join "`n"
        $messages |
            Should -Match (
                'CI Pester selected git application=' +
                [regex]::Escape('C:\tools\git-first.exe')
            )
        $messages |
            Should -Match (
                'CI Pester selected pwsh application=' +
                [regex]::Escape('C:\tools\pwsh-first.exe')
            )
    }

    It 'returns only the seven closed summary fields' {
        Assert-RunnerExists
        $probe = New-RunnerProbe -Result (New-PesterResult)
        $parameters = New-RunnerParameters -Probe $probe -OutputPath $script:outputPath

        $summary = @(& $script:runnerPath @parameters)

        $summary.Count | Should -Be 1
        ($summary[0].PSObject.Properties.Name -join ',') |
            Should -BeExactly (
                'TotalCount,FailedCount,FailedContainersCount,Result,' +
                'OutputPath,StartedAtUtc,FinishedAtUtc'
            )
        $summary[0].TotalCount | Should -Be 1
        $summary[0].FailedCount | Should -Be 0
        $summary[0].FailedContainersCount | Should -Be 0
        $summary[0].Result | Should -BeExactly 'Passed'
        $summary[0].OutputPath |
            Should -BeExactly ([IO.Path]::GetFullPath($script:outputPath))
        $summary[0].StartedAtUtc | Should -BeExactly '2026-10-22T10:00:00.0000000Z'
        $summary[0].FinishedAtUtc | Should -BeExactly '2026-10-22T10:00:00.0000000Z'
    }

    It 'runs under Windows PowerShell 5.1 and installed PowerShell 7' {
        Assert-InstallerExists
        Assert-RunnerExists
        foreach ($hostName in @('powershell.exe', 'pwsh.exe')) {
            $hostApplication = Get-Command `
                -Name $hostName `
                -CommandType Application `
                -ErrorAction Stop |
                Select-Object -First 1
            $compatibilityRoot = Join-Path $script:resultRoot (
                'compatibility-{0}' -f $hostName.Replace('.', '-')
            )
            $compatibilityOutput = Join-Path $compatibilityRoot 'pester.xml'
            $installerLiteral = "'$($script:installerPath.Replace("'", "''"))'"
            $runnerLiteral = "'$($script:runnerPath.Replace("'", "''"))'"
            $testLeafLiteral = "'$(([IO.Path]::GetFullPath(
                (Join-Path $script:repositoryRoot $script:testLeaf)
            )).Replace("'", "''"))'"
            $outputLiteral = "'$($compatibilityOutput.Replace("'", "''"))'"
            $compatibilityRootLiteral = "'$($compatibilityRoot.Replace("'", "''"))'"
            $command = @"
`$ErrorActionPreference = 'Stop'
try {
    Import-Module Pester -RequiredVersion 5.7.1 -Force
    foreach (`$scriptPath in @($installerLiteral, $runnerLiteral)) {
        `$tokens = `$null
        `$errors = `$null
        [void][Management.Automation.Language.Parser]::ParseFile(
            `$scriptPath,
            [ref]`$tokens,
            [ref]`$errors
        )
        if (`$errors.Count -ne 0) {
            throw "Parser errors in `${scriptPath}: `$(`$errors.Message -join '; ')"
        }
    }

    `$moduleInstaller = {
        param([string]`$Name, [string]`$RequiredVersion, [int]`$Attempt)
    }
    `$moduleVerifier = {
        param([string]`$Name, [string]`$RequiredVersion)
        [version]'5.7.1'
    }
    `$pythonRunner = {
        param(
            [string[]]`$Arguments,
            [ValidateSet('Acquire', 'Verify')][string]`$Phase,
            [int]`$Attempt
        )
        [pscustomobject]@{ ExitCode = [int]0; Detail = [string]'success' }
    }
    `$sleeper = { param([timespan]`$Delay) }
    `$clock = {
        param()

        [datetime]::SpecifyKind(
            [datetime]'2026-10-22T10:00:00',
            [DateTimeKind]::Utc
        )
    }
    `$installerParameters = @{
        Group = 'Repository'
        ModuleInstaller = `$moduleInstaller
        ModuleVerifier = `$moduleVerifier
        PythonRunner = `$pythonRunner
        Sleeper = `$sleeper
        Clock = `$clock
    }
    & $installerLiteral @installerParameters | Out-Null

    `$pesterInvoker = {
        param([PesterConfiguration]`$Configuration)
        `$resultPath = [string]`$Configuration.TestResult.OutputPath.Value
        [IO.File]::WriteAllText(
            `$resultPath,
            '<test-results />',
            [Text.UTF8Encoding]::new(`$false)
        )
        [pscustomobject]@{
            TotalCount = 1
            FailedCount = 0
            FailedContainersCount = 0
            Result = 'Passed'
        }
    }
    `$applicationResolver = {
        param(
            [ValidateSet('git.exe', 'pwsh.exe')]
            [string]`$Name
        )
        [string[]]@("C:\tools\`$Name")
    }
    `$runnerParameters = @{
        Path = $testLeafLiteral
        OutputPath = $outputLiteral
        PesterInvoker = `$pesterInvoker
        ApplicationResolver = `$applicationResolver
        Clock = `$clock
    }
    `$summary = & $runnerLiteral @runnerParameters
    if (
        `$summary.TotalCount -ne 1 -or
        `$summary.FailedCount -ne 0 -or
        `$summary.FailedContainersCount -ne 0 -or
        [string]`$summary.Result -cne 'Passed' -or
        -not (Test-Path -LiteralPath $outputLiteral -PathType Leaf)
    ) {
        throw 'Injected compatibility probe did not return a closed success.'
    }
    Remove-Item -LiteralPath $compatibilityRootLiteral -Recurse -Force
    exit 0
}
catch {
    Write-Error `$_.Exception.Message
    exit 1
}
"@
            $encoded = [Convert]::ToBase64String(
                [Text.Encoding]::Unicode.GetBytes($command)
            )
            $childOutput = @(
                & $hostApplication.Source -NoProfile -EncodedCommand $encoded 2>&1
            )
            $childExitCode = $LASTEXITCODE

            $childExitCode |
                Should -Be 0 -Because (($childOutput | Out-String).Trim())
        }
    }
}
