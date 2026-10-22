[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('Repository', 'Infrastructure', 'Hr', 'Lifecycle')]
    [string]$Group,

    [ValidateRange(1, 3)]
    [int]$MaxAttempts = 3,

    [Parameter(DontShow)]
    [scriptblock]$ModuleInstaller,

    [Parameter(DontShow)]
    [scriptblock]$ModuleVerifier,

    [Parameter(DontShow)]
    [scriptblock]$PythonRunner,

    [Parameter(DontShow)]
    [scriptblock]$Sleeper,

    [Parameter(DontShow)]
    [scriptblock]$Clock
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-BoundedDetail {
    param(
        [AllowEmptyString()]
        [string]$Detail
    )

    $bounded = $Detail -replace '[\r\n]+', ' '
    if ($bounded.Length -gt 512) {
        $bounded = $bounded.Substring(0, 512)
    }
    $bounded
}

function Invoke-BoundedAcquisition {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Acquire
    )

    $acquired = $false
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $attemptStarted = & $Clock
        $attemptDetail = 'success'
        try {
            & $Acquire $attempt
            $acquired = $true
            break
        }
        catch {
            $detail = Get-BoundedDetail -Detail $_.Exception.Message
            $attemptDetail = $detail
            if ($attempt -eq $MaxAttempts) {
                throw
            }
            & $Sleeper ([timespan]::FromSeconds([math]::Pow(2, $attempt)))
        }
        finally {
            $attemptFinished = & $Clock
            Write-Host (
                (
                    'CI dependency acquisition attempt {0}/{1}; start={2:o}; ' +
                    'finish={3:o}; elapsedMs={4}; detail={5}'
                ) -f
                $attempt,
                $MaxAttempts,
                $attemptStarted,
                $attemptFinished,
                [math]::Max(
                    0,
                    ($attemptFinished - $attemptStarted).TotalMilliseconds
                ),
                $attemptDetail
            )
        }
    }

    if (-not $acquired) {
        throw 'CiDependencies.AcquisitionIncomplete'
    }
}

if ($null -eq $ModuleInstaller) {
    $ModuleInstaller = {
        param([string]$Name, [string]$RequiredVersion, [int]$Attempt)

        Install-Module `
            -Name $Name `
            -RequiredVersion $RequiredVersion `
            -Scope CurrentUser `
            -Force `
            -AllowClobber `
            -ErrorAction Stop |
            Out-Null
    }
}

if ($null -eq $ModuleVerifier) {
    $ModuleVerifier = {
        param([string]$Name, [string]$RequiredVersion)

        Import-Module `
            -Name $Name `
            -RequiredVersion $RequiredVersion `
            -Force `
            -ErrorAction Stop
        $loadedModule = @(
            Get-Module -Name $Name |
                Where-Object Version -EQ ([version]$RequiredVersion)
        ) | Select-Object -First 1
        if ($null -eq $loadedModule) {
            throw "CiDependencies.PesterVersion: '$RequiredVersion' was not loaded."
        }
        [version]$loadedModule.Version
    }
}

if ($null -eq $PythonRunner) {
    $PythonRunner = {
        param(
            [string[]]$Arguments,
            [ValidateSet('Acquire', 'Verify')][string]$Phase,
            [int]$Attempt
        )

        $pythonApplication = Get-Command `
            -Name python.exe `
            -CommandType Application `
            -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($null -eq $pythonApplication) {
            return [pscustomobject]@{
                ExitCode = [int]127
                Detail = [string]'python.exe is unavailable'
            }
        }

        $pythonPath = [string]$pythonApplication.Source
        $nativeOutput = @(& $pythonPath @Arguments 2>&1)
        $exitCode = [int]$LASTEXITCODE
        $nativeOutput = $null
        [pscustomobject]@{
            ExitCode = $exitCode
            Detail = if ($exitCode -eq 0) {
                [string]'success'
            }
            else {
                [string]"python.exe exited with code $exitCode"
            }
        }
    }
}

if ($null -eq $Sleeper) {
    $Sleeper = {
        param([timespan]$Delay)

        Start-Sleep -Milliseconds ([int][math]::Ceiling($Delay.TotalMilliseconds))
    }
}

if ($null -eq $Clock) {
    $Clock = {
        param()

        [datetime]::UtcNow
    }
}

$moduleAcquire = {
    param([int]$Attempt)

    & $ModuleInstaller 'Pester' '5.7.1' $Attempt
}
Invoke-BoundedAcquisition -Acquire $moduleAcquire

$verifiedVersions = @(& $ModuleVerifier 'Pester' '5.7.1')
if (
    $verifiedVersions.Count -ne 1 -or
    -not ($verifiedVersions[0] -is [version]) -or
    $verifiedVersions[0] -ne [version]'5.7.1'
) {
    throw 'CiDependencies.PesterVersion: exact loaded version 5.7.1 is required.'
}

$requirementsPath = switch ($Group) {
    'Hr' { 'hr/tests/requirements.txt' }
    'Lifecycle' { 'infra/tests/requirements.txt' }
    default { $null }
}

if ($null -ne $requirementsPath) {
    $acquisitionArguments = [string[]]@(
        '-m'
        'pip'
        'install'
        '--disable-pip-version-check'
        '--requirement'
        $requirementsPath
    )
    $pythonAcquire = {
        param([int]$Attempt)

        $responses = @(
            & $PythonRunner $acquisitionArguments 'Acquire' $Attempt
        )
        if (
            $responses.Count -ne 1 -or
            $null -eq $responses[0].PSObject.Properties['ExitCode'] -or
            $null -eq $responses[0].PSObject.Properties['Detail']
        ) {
            throw 'CiDependencies.PythonResult: acquisition returned an invalid result.'
        }
        if ([int]$responses[0].ExitCode -ne 0) {
            throw (Get-BoundedDetail -Detail ([string]$responses[0].Detail))
        }
    }
    Invoke-BoundedAcquisition -Acquire $pythonAcquire

    $verificationResponses = @(
        & $PythonRunner ([string[]]@('-c', 'import jsonschema')) 'Verify' 1
    )
    if (
        $verificationResponses.Count -ne 1 -or
        $null -eq $verificationResponses[0].PSObject.Properties['ExitCode'] -or
        $null -eq $verificationResponses[0].PSObject.Properties['Detail']
    ) {
        throw 'CiDependencies.PythonResult: verification returned an invalid result.'
    }
    if ([int]$verificationResponses[0].ExitCode -ne 0) {
        $verificationDetail = Get-BoundedDetail `
            -Detail ([string]$verificationResponses[0].Detail)
        throw "CiDependencies.PythonVerification: $verificationDetail"
    }
}
