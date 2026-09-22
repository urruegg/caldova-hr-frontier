[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [string]$Repository,

    [Parameter(Mandatory)]
    [long]$ValidatorRunId,

    [Parameter(Mandatory)]
    [long]$BootstrapRunId,

    [Parameter(Mandatory)]
    [string]$BootstrapEvidencePath,

    [Parameter(Mandatory)]
    [string]$DesiredStatePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$expectedRepository = 'urruegg/caldova-hr-frontier'
$expectedTenantAlias = 'caldova25156897'
$expectedTenantId = 'e2312862-df63-440c-8bcf-007a2c52859d'
$expectedSubscriptionId = 'edb45a24-408d-47c4-bbc7-685b9b3fc017'
$expectedScope = "/subscriptions/$expectedSubscriptionId"
$expectedEnvironmentName = 'bootstrap-caldova25156897'
$expectedVariableNames = @('AZURE_CLIENT_ID', 'AZURE_TENANT_ID', 'AZURE_SUBSCRIPTION_ID')
$evidenceMaximumAge = [timespan]::FromHours(24)

function New-DefaultNativeCommandRunner {
    {
        param(
            [Parameter(Mandatory)]
            [string]$FilePath,

            [Parameter(Mandatory)]
            [string[]]$ArgumentList
        )

        $command = Get-Command -Name $FilePath -ErrorAction Stop
        if ($command.CommandType -in @('Function', 'Filter')) {
            $output = & $FilePath @ArgumentList
            return [pscustomobject]@{
                ExitCode = $LASTEXITCODE
                StdOut = ($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
                StdErr = ''
            }
        }

        $stderrPath = [System.IO.Path]::GetTempFileName()
        $originalErrorActionPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $output = & $command.Source @ArgumentList 2> $stderrPath
            $exitCode = $LASTEXITCODE
            [pscustomobject]@{
                ExitCode = $exitCode
                StdOut = ($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
                StdErr = [System.IO.File]::ReadAllText($stderrPath)
            }
        }
        finally {
            $ErrorActionPreference = $originalErrorActionPreference
            [System.IO.File]::Delete($stderrPath)
        }
    }
}

function ConvertTo-PropertyTable {
    param(
        [AllowNull()]
        [object]$InputObject
    )

    $table = @{}
    if ($null -eq $InputObject) {
        return $table
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        foreach ($key in $InputObject.Keys) {
            $table[[string]$key] = $InputObject[$key]
        }
        return $table
    }

    foreach ($property in @($InputObject.PSObject.Properties)) {
        if ($property.MemberType -in @('NoteProperty', 'Property', 'ScriptProperty')) {
            $table[$property.Name] = $property.Value
        }
    }

    $table
}

function Assert-ClosedObject {
    param(
        [Parameter(Mandatory)]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string[]]$AllowedProperties,

        [Parameter(Mandatory)]
        [string[]]$RequiredProperties,

        [Parameter(Mandatory)]
        [string]$Context
    )

    if ($null -eq $InputObject -or $InputObject -is [string] -or $InputObject -is [ValueType] -or $InputObject -is [System.Array]) {
        throw "$Context must be an object."
    }

    $properties = @(
        $InputObject.PSObject.Properties |
            Where-Object { $_.MemberType -in @('NoteProperty', 'Property', 'ScriptProperty') } |
            ForEach-Object { $_.Name }
    )

    foreach ($property in $properties) {
        if (-not ($AllowedProperties -ccontains $property)) {
            throw "$Context contains unknown property '$property'."
        }
    }

    foreach ($requiredProperty in $RequiredProperties) {
        if (-not ($properties -ccontains $requiredProperty)) {
            throw "$Context is missing required property '$requiredProperty'."
        }
    }
}

function Assert-StringValue {
    param(
        [AllowNull()][object]$Value,
        [Parameter(Mandatory)][string]$Context,
        [string]$Expected
    )

    if ($Value -isnot [string]) {
        throw "$Context must be a string."
    }

    if ($PSBoundParameters.ContainsKey('Expected') -and [string]$Value -cne $Expected) {
        throw "$Context does not match the reviewed value."
    }
}

function Assert-BooleanValue {
    param(
        [AllowNull()][object]$Value,
        [Parameter(Mandatory)][string]$Context,
        [Parameter(Mandatory)][bool]$Expected
    )

    if ($Value -isnot [bool] -or [bool]$Value -ne $Expected) {
        throw "$Context does not match the reviewed boolean value."
    }
}

function Test-IntegerValue {
    param([AllowNull()][object]$Value)

    $Value -is [byte] -or
        $Value -is [sbyte] -or
        $Value -is [int16] -or
        $Value -is [uint16] -or
        $Value -is [int32] -or
        $Value -is [uint32] -or
        $Value -is [int64] -or
        $Value -is [uint64]
}

function Assert-ArrayValue {
    param(
        [AllowNull()][object]$Value,
        [Parameter(Mandatory)][string]$Context
    )

    if ($Value -isnot [System.Array]) {
        throw "$Context must be an array."
    }
}

function Read-JsonFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Context
    )

    $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    if (-not (Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
        throw "$Context was not found: $resolvedPath"
    }

    try {
        $value = Get-Content -Raw -LiteralPath $resolvedPath | ConvertFrom-Json
    }
    catch {
        throw "$Context must contain valid JSON."
    }

    if ($null -eq $value) {
        throw "$Context must contain one JSON object."
    }

    [pscustomobject]@{
        Path = $resolvedPath
        Value = $value
    }
}

function Assert-ExactStringArray {
    param(
        [AllowNull()][object]$Value,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Expected,
        [Parameter(Mandatory)][string]$Context
    )

    Assert-ArrayValue -Value $Value -Context $Context
    $actual = @($Value)
    if ($actual.Count -ne $Expected.Count) {
        throw "$Context does not match the reviewed values."
    }

    for ($index = 0; $index -lt $Expected.Count; $index++) {
        if ($actual[$index] -isnot [string] -or [string]$actual[$index] -cne $Expected[$index]) {
            throw "$Context does not match the reviewed values."
        }
    }
}

function Assert-DesiredState {
    param(
        [Parameter(Mandatory)][object]$DesiredState
    )

    Assert-ClosedObject -InputObject $DesiredState -AllowedProperties @('$schema', 'schemaVersion', 'repository', 'rulesets') -RequiredProperties @('$schema', 'schemaVersion', 'repository', 'rulesets') -Context 'Desired state'
    Assert-StringValue -Value $DesiredState.'$schema' -Expected '../schemas/github-ruleset.schema.json' -Context 'Desired state $schema'
    Assert-StringValue -Value $DesiredState.schemaVersion -Expected '1.0' -Context 'Desired state schemaVersion'
    Assert-StringValue -Value $DesiredState.repository -Expected $expectedRepository -Context 'Desired state repository'
    Assert-ArrayValue -Value $DesiredState.rulesets -Context 'Desired state rulesets'

    $rulesets = @($DesiredState.rulesets)
    $names = @()
    foreach ($candidate in $rulesets) {
        Assert-ClosedObject -InputObject $candidate -AllowedProperties @('name', 'target', 'enforcement', 'bypassActors', 'conditions', 'rules') -RequiredProperties @('name', 'target', 'enforcement', 'bypassActors', 'conditions', 'rules') -Context 'Desired ruleset'
        Assert-StringValue -Value $candidate.name -Context 'Desired ruleset name'
        $names += [string]$candidate.name
    }

    if (@($names | Select-Object -Unique).Count -ne $names.Count) {
        throw 'Desired state contains a duplicate ruleset name.'
    }

    if ($rulesets.Count -ne 1) {
        throw 'Desired state must contain exactly one ruleset.'
    }

    $ruleset = $rulesets[0]
    Assert-StringValue -Value $ruleset.name -Expected 'main' -Context 'Desired ruleset name'
    Assert-StringValue -Value $ruleset.target -Expected 'branch' -Context 'Desired ruleset target'
    Assert-StringValue -Value $ruleset.enforcement -Expected 'active' -Context 'Desired ruleset enforcement'

    Assert-ArrayValue -Value $ruleset.bypassActors -Context 'Desired ruleset bypassActors'
    $bypassActors = @($ruleset.bypassActors)
    if ($bypassActors.Count -ne 1) {
        throw 'Desired ruleset must contain exactly one bypass actor.'
    }

    $bypassActor = $bypassActors[0]
    Assert-ClosedObject -InputObject $bypassActor -AllowedProperties @('actorType', 'login', 'bypassMode') -RequiredProperties @('actorType', 'login', 'bypassMode') -Context 'Desired bypass actor'
    Assert-StringValue -Value $bypassActor.actorType -Expected 'User' -Context 'Desired bypass actor type'
    Assert-StringValue -Value $bypassActor.login -Expected 'urruegg' -Context 'Desired bypass actor login'
    Assert-StringValue -Value $bypassActor.bypassMode -Expected 'pull_request' -Context 'Desired bypass mode'

    Assert-ClosedObject -InputObject $ruleset.conditions -AllowedProperties @('refName') -RequiredProperties @('refName') -Context 'Desired ruleset conditions'
    Assert-ClosedObject -InputObject $ruleset.conditions.refName -AllowedProperties @('include', 'exclude') -RequiredProperties @('include', 'exclude') -Context 'Desired ruleset refName condition'
    Assert-ExactStringArray -Value $ruleset.conditions.refName.include -Expected @('refs/heads/main') -Context 'Desired included refs'
    Assert-ExactStringArray -Value $ruleset.conditions.refName.exclude -Expected @() -Context 'Desired excluded refs'

    Assert-ArrayValue -Value $ruleset.rules -Context 'Desired ruleset rules'
    $rules = @($ruleset.rules)
    if ($rules.Count -ne 4) {
        throw 'Desired ruleset must contain exactly four rules.'
    }

    Assert-ClosedObject -InputObject $rules[0] -AllowedProperties @('type') -RequiredProperties @('type') -Context 'Deletion rule'
    Assert-StringValue -Value $rules[0].type -Expected 'deletion' -Context 'Deletion rule type'
    Assert-ClosedObject -InputObject $rules[1] -AllowedProperties @('type') -RequiredProperties @('type') -Context 'Non-fast-forward rule'
    Assert-StringValue -Value $rules[1].type -Expected 'non_fast_forward' -Context 'Non-fast-forward rule type'

    Assert-ClosedObject -InputObject $rules[2] -AllowedProperties @('type', 'parameters') -RequiredProperties @('type', 'parameters') -Context 'Pull request rule'
    Assert-StringValue -Value $rules[2].type -Expected 'pull_request' -Context 'Pull request rule type'
    $pullRequestParameters = $rules[2].parameters
    Assert-ClosedObject -InputObject $pullRequestParameters -AllowedProperties @('dismissStaleReviewsOnPush', 'requireCodeOwnerReview', 'requireLastPushApproval', 'requiredApprovingReviewCount', 'requiredReviewThreadResolution', 'allowedMergeMethods') -RequiredProperties @('dismissStaleReviewsOnPush', 'requireCodeOwnerReview', 'requireLastPushApproval', 'requiredApprovingReviewCount', 'requiredReviewThreadResolution', 'allowedMergeMethods') -Context 'Pull request rule parameters'
    Assert-BooleanValue -Value $pullRequestParameters.dismissStaleReviewsOnPush -Expected $true -Context 'Dismiss stale reviews'
    Assert-BooleanValue -Value $pullRequestParameters.requireCodeOwnerReview -Expected $true -Context 'CODEOWNERS review'
    Assert-BooleanValue -Value $pullRequestParameters.requireLastPushApproval -Expected $false -Context 'Last-push approval'
    if (-not (Test-IntegerValue -Value $pullRequestParameters.requiredApprovingReviewCount) -or [long]$pullRequestParameters.requiredApprovingReviewCount -ne 1) {
        throw 'Pull request approval count must be the integer 1.'
    }
    Assert-BooleanValue -Value $pullRequestParameters.requiredReviewThreadResolution -Expected $true -Context 'Resolved review conversations'
    Assert-ExactStringArray -Value $pullRequestParameters.allowedMergeMethods -Expected @('merge', 'squash', 'rebase') -Context 'Allowed merge methods'

    Assert-ClosedObject -InputObject $rules[3] -AllowedProperties @('type', 'parameters') -RequiredProperties @('type', 'parameters') -Context 'Required status checks rule'
    Assert-StringValue -Value $rules[3].type -Expected 'required_status_checks' -Context 'Required status checks rule type'
    $statusParameters = $rules[3].parameters
    Assert-ClosedObject -InputObject $statusParameters -AllowedProperties @('doNotEnforceOnCreate', 'requiredStatusChecks', 'strictRequiredStatusChecksPolicy') -RequiredProperties @('doNotEnforceOnCreate', 'requiredStatusChecks', 'strictRequiredStatusChecksPolicy') -Context 'Required status checks parameters'
    Assert-BooleanValue -Value $statusParameters.doNotEnforceOnCreate -Expected $false -Context 'Status checks create enforcement'
    Assert-BooleanValue -Value $statusParameters.strictRequiredStatusChecksPolicy -Expected $true -Context 'Strict required status checks policy'
    Assert-ArrayValue -Value $statusParameters.requiredStatusChecks -Context 'Required status checks'
    $statusChecks = @($statusParameters.requiredStatusChecks)
    if ($statusChecks.Count -ne 1) {
        throw 'Desired ruleset must contain exactly one required status context.'
    }
    Assert-ClosedObject -InputObject $statusChecks[0] -AllowedProperties @('context', 'integrationId') -RequiredProperties @('context', 'integrationId') -Context 'Required status check'
    Assert-StringValue -Value $statusChecks[0].context -Expected 'Repository setup validation' -Context 'Required status context'
    if (-not (Test-IntegerValue -Value $statusChecks[0].integrationId) -or [long]$statusChecks[0].integrationId -ne 15368) {
        throw 'Required status integration must be the GitHub Actions application id 15368.'
    }

    $ruleset
}

function Test-CurrentTimestamp {
    param(
        [AllowNull()][object]$Value,
        [Parameter(Mandatory)][string]$Context
    )

    if ($Value -isnot [string]) {
        throw "$Context must be a timestamp string."
    }
    if ([string]$Value -cnotmatch '(?:Z|\+00:00)$') {
        throw "$Context must include an explicit UTC designator."
    }

    $parsed = [datetimeoffset]::MinValue
    if (-not [datetimeoffset]::TryParse(
            [string]$Value,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal,
            [ref]$parsed)) {
        throw "$Context must be a parseable timestamp."
    }

    $now = [datetimeoffset]::UtcNow
    if ($parsed -lt $now.Subtract($evidenceMaximumAge) -or $parsed -gt $now) {
        throw "$Context must be current within the reviewed 24-hour evidence window."
    }
}

function Assert-GuidString {
    param(
        [AllowNull()][object]$Value,
        [Parameter(Mandatory)][string]$Context
    )

    if ($Value -isnot [string]) {
        throw "$Context must be a GUID string."
    }

    $parsed = [guid]::Empty
    if (-not [guid]::TryParse([string]$Value, [ref]$parsed) -or $parsed -eq [guid]::Empty) {
        throw "$Context must be a non-empty GUID."
    }
}

function Assert-BootstrapEvidence {
    param(
        [Parameter(Mandatory)][object]$Evidence,
        [Parameter(Mandatory)][long]$ExpectedBootstrapRunId
    )

    Assert-ClosedObject -InputObject $Evidence -AllowedProperties @('SchemaVersion', 'BootstrapRunId', 'HeadSha', 'TenantAlias', 'SubscriptionId', 'PrincipalObjectId', 'Scope', 'VerifiedUtc', 'Assignments') -RequiredProperties @('SchemaVersion', 'BootstrapRunId', 'HeadSha', 'TenantAlias', 'SubscriptionId', 'PrincipalObjectId', 'Scope', 'VerifiedUtc', 'Assignments') -Context 'Bootstrap evidence'
    Assert-StringValue -Value $Evidence.SchemaVersion -Expected '1.0' -Context 'Bootstrap evidence SchemaVersion'
    if (-not (Test-IntegerValue -Value $Evidence.BootstrapRunId) -or [long]$Evidence.BootstrapRunId -ne $ExpectedBootstrapRunId) {
        throw 'Bootstrap evidence BootstrapRunId must be an integer equal to the supplied BootstrapRunId.'
    }
    if ($Evidence.HeadSha -isnot [string] -or [string]$Evidence.HeadSha -cnotmatch '^[0-9a-fA-F]{40}$') {
        throw 'Bootstrap evidence HeadSha must be a commit SHA.'
    }
    Assert-StringValue -Value $Evidence.TenantAlias -Expected $expectedTenantAlias -Context 'Bootstrap evidence TenantAlias'
    Assert-StringValue -Value $Evidence.SubscriptionId -Expected $expectedSubscriptionId -Context 'Bootstrap evidence SubscriptionId'
    Assert-GuidString -Value $Evidence.PrincipalObjectId -Context 'Bootstrap evidence PrincipalObjectId'
    Assert-StringValue -Value $Evidence.Scope -Expected $expectedScope -Context 'Bootstrap evidence Scope'
    Test-CurrentTimestamp -Value $Evidence.VerifiedUtc -Context 'Bootstrap evidence VerifiedUtc'
    Assert-ArrayValue -Value $Evidence.Assignments -Context 'Bootstrap evidence Assignments'

    $assignments = @($Evidence.Assignments)
    if ($assignments.Count -ne 2) {
        throw 'Bootstrap evidence must contain exactly two assignments.'
    }

    $ids = @()
    $roles = @()
    $expectedRoleDefinitionIds = @{
        Contributor = "$expectedScope/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c"
        'Role Based Access Control Administrator' = "$expectedScope/providers/Microsoft.Authorization/roleDefinitions/f58310d9-a9f6-439a-9e8d-f62e7b41a168"
    }

    foreach ($assignment in $assignments) {
        Assert-ClosedObject -InputObject $assignment -AllowedProperties @('Id', 'RoleName', 'RoleDefinitionId', 'PrincipalObjectId', 'Scope', 'ReadBackStatus', 'VerifiedUtc') -RequiredProperties @('Id', 'RoleName', 'RoleDefinitionId', 'PrincipalObjectId', 'Scope', 'ReadBackStatus', 'VerifiedUtc') -Context 'Bootstrap evidence assignment'
        Assert-StringValue -Value $assignment.Id -Context 'Bootstrap evidence assignment Id'
        if ([string]$assignment.Id -cnotmatch "^/subscriptions/$expectedSubscriptionId/providers/Microsoft\.Authorization/roleAssignments/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$") {
            throw 'Bootstrap evidence assignment Id must be an exact subscription role-assignment resource ID.'
        }

        Assert-StringValue -Value $assignment.RoleName -Context 'Bootstrap evidence assignment RoleName'
        $roleName = [string]$assignment.RoleName
        if (-not $expectedRoleDefinitionIds.ContainsKey($roleName)) {
            throw 'Bootstrap evidence assignment RoleName is not allowlisted.'
        }

        Assert-StringValue -Value $assignment.RoleDefinitionId -Expected $expectedRoleDefinitionIds[$roleName] -Context 'Bootstrap evidence assignment RoleDefinitionId'
        Assert-StringValue -Value $assignment.PrincipalObjectId -Expected ([string]$Evidence.PrincipalObjectId) -Context 'Bootstrap evidence assignment principal'
        Assert-StringValue -Value $assignment.Scope -Expected $expectedScope -Context 'Bootstrap evidence assignment scope'
        Assert-StringValue -Value $assignment.ReadBackStatus -Expected 'Absent' -Context 'Bootstrap evidence assignment ReadBackStatus Absent'
        Test-CurrentTimestamp -Value $assignment.VerifiedUtc -Context 'Bootstrap evidence assignment VerifiedUtc'
        $ids += [string]$assignment.Id
        $roles += $roleName
    }

    if (@($ids | Select-Object -Unique).Count -ne 2) {
        throw 'Bootstrap evidence assignment IDs must be unique.'
    }

    foreach ($requiredRole in @('Contributor', 'Role Based Access Control Administrator')) {
        if (@($roles | Where-Object { $_ -ceq $requiredRole }).Count -ne 1) {
            throw "Bootstrap evidence must contain $requiredRole exactly once."
        }
    }
}

function Get-ReviewedPrincipalObjectId {
    param(
        [Parameter(Mandatory)][object]$Configuration
    )

    $configurationTable = ConvertTo-PropertyTable -InputObject $Configuration
    foreach ($propertyName in @('TenantAlias', 'TenantId', 'SubscriptionId', 'GitHub', 'Components')) {
        if (-not $configurationTable.ContainsKey($propertyName)) {
            throw "Tenant configuration is missing required property '$propertyName'."
        }
    }

    Assert-StringValue -Value $configurationTable.TenantAlias -Expected $expectedTenantAlias -Context 'Tenant configuration TenantAlias'
    Assert-StringValue -Value $configurationTable.TenantId -Expected $expectedTenantId -Context 'Tenant configuration TenantId'
    Assert-StringValue -Value $configurationTable.SubscriptionId -Expected $expectedSubscriptionId -Context 'Tenant configuration SubscriptionId'

    $githubTable = ConvertTo-PropertyTable -InputObject $configurationTable.GitHub
    if (-not $githubTable.ContainsKey('EnvironmentName')) {
        throw 'Tenant configuration GitHub EnvironmentName is required.'
    }
    Assert-StringValue -Value $githubTable.EnvironmentName -Expected $expectedEnvironmentName -Context 'Tenant configuration GitHub EnvironmentName'

    $componentsTable = ConvertTo-PropertyTable -InputObject $configurationTable.Components
    if (-not $componentsTable.ContainsKey('EntraServicePrincipal')) {
        throw 'Tenant configuration EntraServicePrincipal is required.'
    }
    $servicePrincipalTable = ConvertTo-PropertyTable -InputObject $componentsTable.EntraServicePrincipal
    if (-not $servicePrincipalTable.ContainsKey('Id')) {
        throw 'Tenant configuration EntraServicePrincipal Id is required.'
    }
    Assert-GuidString -Value $servicePrincipalTable.Id -Context 'Tenant configuration EntraServicePrincipal Id'

    [string]$servicePrincipalTable.Id
}

function Import-CurrentMainTenantConfiguration {
    param(
        [Parameter(Mandatory)][scriptblock]$Runner,
        [Parameter(Mandatory)][string]$MainSha
    )

    $manifestPath = 'infra/src/config/tenants/caldova25156897.psd1'
    $manifestResponse = Invoke-GhJson -Runner $Runner -ArgumentList @('api', "repos/$expectedRepository/contents/$($manifestPath)?ref=$MainSha") -Context 'Current-main Tenant 1 manifest'
    if ([string]$manifestResponse.type -cne 'file' -or
        [string]$manifestResponse.path -cne $manifestPath -or
        [string]$manifestResponse.encoding -cne 'base64' -or
        [string]::IsNullOrWhiteSpace([string]$manifestResponse.content)) {
        throw 'Current-main Tenant 1 manifest response does not identify the exact reviewed file.'
    }

    try {
        $manifestBytes = [Convert]::FromBase64String(([string]$manifestResponse.content -replace '\s', ''))
    }
    catch {
        throw 'Current-main Tenant 1 manifest content is not valid base64.'
    }
    if ($manifestBytes.Length -eq 0 -or
        -not (Test-IntegerValue -Value $manifestResponse.size) -or
        [long]$manifestResponse.size -ne $manifestBytes.Length) {
        throw 'Current-main Tenant 1 manifest size does not match the reviewed file response.'
    }

    $temporaryPath = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString() + '.psd1')
    try {
        [System.IO.File]::WriteAllBytes($temporaryPath, $manifestBytes)
        Import-PowerShellDataFile -LiteralPath $temporaryPath
    }
    catch {
        throw 'Current-main Tenant 1 manifest is not a valid PowerShell data file.'
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath) {
            [System.IO.File]::Delete($temporaryPath)
        }
    }
}

function Invoke-NativeCommandResult {
    param(
        [Parameter(Mandatory)][scriptblock]$Runner,
        [string]$FilePath = 'gh',
        [Parameter(Mandatory)][string[]]$ArgumentList
    )

    $result = & $Runner -FilePath $FilePath -ArgumentList $ArgumentList
    $resultTable = ConvertTo-PropertyTable -InputObject $result
    if (-not $resultTable.ContainsKey('ExitCode')) {
        throw 'NativeCommandRunner must return ExitCode.'
    }

    [pscustomobject]@{
        ExitCode = [int]$resultTable.ExitCode
        StdOut = if ($resultTable.ContainsKey('StdOut')) { [string]$resultTable.StdOut } else { '' }
        StdErr = if ($resultTable.ContainsKey('StdErr')) { [string]$resultTable.StdErr } else { '' }
        StatusCode = if ($resultTable.ContainsKey('StatusCode')) { $resultTable.StatusCode } else { $null }
        ErrorCode = if ($resultTable.ContainsKey('ErrorCode')) { [string]$resultTable.ErrorCode } else { '' }
    }
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory)][scriptblock]$Runner,
        [string]$FilePath = 'gh',
        [Parameter(Mandatory)][string[]]$ArgumentList
    )

    $result = Invoke-NativeCommandResult -Runner $Runner -FilePath $FilePath -ArgumentList $ArgumentList
    if ($result.ExitCode -ne 0) {
        throw "$FilePath command failed with exit code $($result.ExitCode). $($result.StdErr) $($result.StdOut)"
    }

    $result.StdOut
}

function Get-ArmResourceStatusCode {
    param(
        [Parameter(Mandatory)][string]$ResourceId,
        [Parameter(Mandatory)][string]$AccessToken
    )

    $uri = [uri]("https://management.azure.com{0}?api-version=2022-04-01" -f $ResourceId)
    $statusCode = 0
    try {
        $response = Invoke-WebRequest `
            -Uri $uri `
            -Method Get `
            -Headers @{ Authorization = "Bearer $AccessToken" } `
            -UseBasicParsing `
            -ErrorAction Stop
        $statusCode = [int]$response.StatusCode
    }
    catch {
        $errorResponse = $_.Exception.Response
        if ($null -eq $errorResponse) {
            throw "ARM resource read failed without an HTTP response for $ResourceId."
        }

        try {
            $statusCode = [int]$errorResponse.StatusCode
        }
        finally {
            if ($errorResponse -is [System.IDisposable]) {
                $errorResponse.Dispose()
            }
            elseif ($errorResponse.PSObject.Methods.Name -contains 'Close') {
                $errorResponse.Close()
            }
        }
    }

    $statusCode
}

function Invoke-GhJson {
    param(
        [Parameter(Mandatory)][scriptblock]$Runner,
        [Parameter(Mandatory)][string[]]$ArgumentList,
        [Parameter(Mandatory)][string]$Context
    )

    $text = Invoke-NativeCommand -Runner $Runner -FilePath 'gh' -ArgumentList $ArgumentList
    if ([string]::IsNullOrWhiteSpace($text)) {
        throw "$Context returned no JSON."
    }

    try {
        $text | ConvertFrom-Json
    }
    catch {
        throw "$Context returned malformed JSON."
    }
}

function Invoke-GhPagedJson {
    param(
        [Parameter(Mandatory)][scriptblock]$Runner,
        [Parameter(Mandatory)][string]$Endpoint,
        [Parameter(Mandatory)][string]$Context
    )

    $text = Invoke-NativeCommand -Runner $Runner -FilePath 'gh' -ArgumentList @('api', '--paginate', '--slurp', $Endpoint)
    if ([string]::IsNullOrWhiteSpace($text)) {
        throw "$Context returned no JSON."
    }

    try {
        $pages = $text | ConvertFrom-Json
    }
    catch {
        throw "$Context returned malformed paginated JSON."
    }
    if ($pages -isnot [System.Array]) {
        throw "$Context must return an array of pages."
    }

    $items = [System.Collections.Generic.List[object]]::new()
    foreach ($page in @($pages)) {
        if ($page -isnot [System.Array]) {
            throw "$Context must return each page as an array."
        }
        foreach ($item in @($page)) {
            $items.Add($item) | Out-Null
        }
    }

    $items.ToArray()
}

function Invoke-AzJson {
    param(
        [Parameter(Mandatory)][scriptblock]$Runner,
        [Parameter(Mandatory)][string[]]$ArgumentList,
        [Parameter(Mandatory)][string]$Context
    )

    $text = Invoke-NativeCommand -Runner $Runner -FilePath 'az' -ArgumentList $ArgumentList
    if ([string]::IsNullOrWhiteSpace($text)) {
        throw "$Context returned no JSON."
    }

    try {
        $text | ConvertFrom-Json
    }
    catch {
        throw "$Context returned malformed JSON."
    }
}

function Assert-WorkflowRun {
    param(
        [Parameter(Mandatory)][object]$Run,
        [Parameter(Mandatory)][long]$ExpectedRunId,
        [Parameter(Mandatory)][string]$ExpectedPath,
        [Parameter(Mandatory)][string]$ExpectedName,
        [Parameter(Mandatory)][string[]]$ExpectedEvents,
        [Parameter(Mandatory)][string]$ExpectedHeadSha,
        [Parameter(Mandatory)][string]$Context
    )

    if (-not (Test-IntegerValue -Value $Run.id) -or [long]$Run.id -ne $ExpectedRunId) {
        throw "$Context run id does not match the supplied run id."
    }
    if ([string]$Run.repository.full_name -cne $expectedRepository) {
        throw "$Context repository does not match the reviewed repository."
    }
    if ([string]$Run.head_repository.full_name -cne $expectedRepository) {
        throw "$Context head repository does not match the reviewed repository."
    }
    if ([string]$Run.event -cnotin $ExpectedEvents) {
        throw "$Context event is not approved for governance activation."
    }
    if ([string]$Run.head_branch -cne 'main') {
        throw "$Context must belong to main and not a pull-request ref."
    }
    if ([string]$Run.head_sha -cne $ExpectedHeadSha) {
        throw "$Context must belong to the current main commit."
    }
    if ([string]$Run.status -cne 'completed') {
        throw "$Context status must be completed."
    }
    if ([string]$Run.conclusion -cne 'success') {
        throw "$Context conclusion must be success."
    }
    if ([string]$Run.path -cne $ExpectedPath) {
        throw "$Context workflow path does not match the reviewed workflow."
    }
    if ([string]$Run.name -cne $ExpectedName) {
        throw "$Context workflow name does not match the reviewed workflow."
    }
}

function New-RulesetPayload {
    param(
        [Parameter(Mandatory)][object]$DesiredRuleset,
        [Parameter(Mandatory)][long]$ResolvedUserId
    )

    [pscustomobject]([ordered]@{
        name = [string]$DesiredRuleset.name
        target = [string]$DesiredRuleset.target
        enforcement = [string]$DesiredRuleset.enforcement
        bypass_actors = @(
            [pscustomobject]([ordered]@{
                actor_id = $ResolvedUserId
                actor_type = [string]$DesiredRuleset.bypassActors[0].actorType
                bypass_mode = [string]$DesiredRuleset.bypassActors[0].bypassMode
            })
        )
        conditions = [pscustomobject]([ordered]@{
            ref_name = [pscustomobject]([ordered]@{
                include = @($DesiredRuleset.conditions.refName.include)
                exclude = @($DesiredRuleset.conditions.refName.exclude)
            })
        })
        rules = @(
            [pscustomobject]([ordered]@{ type = 'deletion' }),
            [pscustomobject]([ordered]@{ type = 'non_fast_forward' }),
            [pscustomobject]([ordered]@{
                type = 'pull_request'
                parameters = [pscustomobject]([ordered]@{
                    dismiss_stale_reviews_on_push = [bool]$DesiredRuleset.rules[2].parameters.dismissStaleReviewsOnPush
                    require_code_owner_review = [bool]$DesiredRuleset.rules[2].parameters.requireCodeOwnerReview
                    require_last_push_approval = [bool]$DesiredRuleset.rules[2].parameters.requireLastPushApproval
                    required_approving_review_count = [long]$DesiredRuleset.rules[2].parameters.requiredApprovingReviewCount
                    required_review_thread_resolution = [bool]$DesiredRuleset.rules[2].parameters.requiredReviewThreadResolution
                    allowed_merge_methods = @($DesiredRuleset.rules[2].parameters.allowedMergeMethods)
                })
            }),
            [pscustomobject]([ordered]@{
                type = 'required_status_checks'
                parameters = [pscustomobject]([ordered]@{
                    do_not_enforce_on_create = [bool]$DesiredRuleset.rules[3].parameters.doNotEnforceOnCreate
                    required_status_checks = @(
                        [pscustomobject]([ordered]@{
                            context = [string]$DesiredRuleset.rules[3].parameters.requiredStatusChecks[0].context
                            integration_id = [long]$DesiredRuleset.rules[3].parameters.requiredStatusChecks[0].integrationId
                        })
                    )
                    strict_required_status_checks_policy = [bool]$DesiredRuleset.rules[3].parameters.strictRequiredStatusChecksPolicy
                })
            })
        )
    })
}

function ConvertTo-ReviewedRulesetPayload {
    param(
        [Parameter(Mandatory)][object]$Ruleset
    )

    $bypassActors = @($Ruleset.bypass_actors)
    $rules = @($Ruleset.rules)
    if ($bypassActors.Count -ne 1 -or $rules.Count -ne 4) {
        return $null
    }

    if ([string]$rules[0].type -cne 'deletion' -or
        [string]$rules[1].type -cne 'non_fast_forward' -or
        [string]$rules[2].type -cne 'pull_request' -or
        [string]$rules[3].type -cne 'required_status_checks') {
        return $null
    }

    $statusChecks = @($rules[3].parameters.required_status_checks)
    if ($statusChecks.Count -ne 1) {
        return $null
    }

    [pscustomobject]([ordered]@{
        name = $Ruleset.name
        target = $Ruleset.target
        enforcement = $Ruleset.enforcement
        bypass_actors = @(
            [pscustomobject]([ordered]@{
                actor_id = $bypassActors[0].actor_id
                actor_type = $bypassActors[0].actor_type
                bypass_mode = $bypassActors[0].bypass_mode
            })
        )
        conditions = [pscustomobject]([ordered]@{
            ref_name = [pscustomobject]([ordered]@{
                include = @($Ruleset.conditions.ref_name.include)
                exclude = @($Ruleset.conditions.ref_name.exclude)
            })
        })
        rules = @(
            [pscustomobject]([ordered]@{ type = $rules[0].type }),
            [pscustomobject]([ordered]@{ type = $rules[1].type }),
            [pscustomobject]([ordered]@{
                type = $rules[2].type
                parameters = [pscustomobject]([ordered]@{
                    dismiss_stale_reviews_on_push = $rules[2].parameters.dismiss_stale_reviews_on_push
                    require_code_owner_review = $rules[2].parameters.require_code_owner_review
                    require_last_push_approval = $rules[2].parameters.require_last_push_approval
                    required_approving_review_count = $rules[2].parameters.required_approving_review_count
                    required_review_thread_resolution = $rules[2].parameters.required_review_thread_resolution
                    allowed_merge_methods = @($rules[2].parameters.allowed_merge_methods)
                })
            }),
            [pscustomobject]([ordered]@{
                type = $rules[3].type
                parameters = [pscustomobject]([ordered]@{
                    do_not_enforce_on_create = $rules[3].parameters.do_not_enforce_on_create
                    required_status_checks = @(
                        [pscustomobject]([ordered]@{
                            context = $statusChecks[0].context
                            integration_id = $statusChecks[0].integration_id
                        })
                    )
                    strict_required_status_checks_policy = $rules[3].parameters.strict_required_status_checks_policy
                })
            })
        )
    })
}

function Test-RulesetReadBack {
    param(
        [Parameter(Mandatory)][object]$Ruleset,
        [Parameter(Mandatory)][object]$ExpectedPayload
    )

    if ([string]$Ruleset.source_type -cne 'Repository' -or [string]$Ruleset.source -cne $expectedRepository) {
        return $false
    }

    try {
        $reviewedPayload = ConvertTo-ReviewedRulesetPayload -Ruleset $Ruleset
    }
    catch {
        return $false
    }

    if ($null -eq $reviewedPayload) {
        return $false
    }

    ($reviewedPayload | ConvertTo-Json -Depth 30 -Compress) -ceq ($ExpectedPayload | ConvertTo-Json -Depth 30 -Compress)
}

function Test-RefPatternMatchesMain {
    param(
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][string]$DefaultBranch
    )

    if ($Pattern -ceq '~ALL') {
        return $true
    }
    if ($Pattern -ceq '~DEFAULT_BRANCH') {
        return $DefaultBranch -ceq 'main'
    }
    if ($Pattern.StartsWith('~', [System.StringComparison]::Ordinal)) {
        throw "Unsupported repository ruleset ref pattern '$Pattern'."
    }
    if ($Pattern.IndexOfAny([char[]]'{}') -ge 0) {
        throw "Unsupported repository ruleset ref pattern '$Pattern'."
    }

    $regex = [System.Text.StringBuilder]::new('^')
    for ($index = 0; $index -lt $Pattern.Length; $index++) {
        $character = $Pattern[$index]
        switch ($character) {
            '\' {
                if ($index + 1 -ge $Pattern.Length) {
                    throw "Unsupported repository ruleset ref pattern '$Pattern'."
                }
                $index++
                [void]$regex.Append([regex]::Escape([string]$Pattern[$index]))
            }
            '*' {
                $runEnd = $index
                while ($runEnd + 1 -lt $Pattern.Length -and $Pattern[$runEnd + 1] -eq '*') {
                    $runEnd++
                }
                $isGlobstar = $runEnd -gt $index -and
                    ($index -eq 0 -or $Pattern[$index - 1] -eq '/') -and
                    ($runEnd + 1 -eq $Pattern.Length -or $Pattern[$runEnd + 1] -eq '/')
                $index = $runEnd
                if ($isGlobstar) {
                    if ($index + 1 -lt $Pattern.Length -and $Pattern[$index + 1] -eq '/') {
                        $index++
                        [void]$regex.Append('(?:.*/)?')
                    }
                    else {
                        [void]$regex.Append('.*')
                    }
                }
                else {
                    [void]$regex.Append('[^/]*')
                }
            }
            '?' {
                [void]$regex.Append('[^/]')
            }
            '[' {
                $closingIndex = -1
                $escaped = $false
                for ($candidateIndex = $index + 1; $candidateIndex -lt $Pattern.Length; $candidateIndex++) {
                    if ($escaped) {
                        $escaped = $false
                        continue
                    }
                    if ($Pattern[$candidateIndex] -eq '\') {
                        $escaped = $true
                        continue
                    }
                    if ($Pattern[$candidateIndex] -eq ']') {
                        $closingIndex = $candidateIndex
                        break
                    }
                }
                if ($closingIndex -lt 0 -or $closingIndex -eq $index + 1) {
                    throw "Unsupported repository ruleset ref pattern '$Pattern'."
                }

                $classText = $Pattern.Substring($index + 1, $closingIndex - $index - 1)
                $negated = $classText.StartsWith('!', [System.StringComparison]::Ordinal) -or $classText.StartsWith('^', [System.StringComparison]::Ordinal)
                if ($negated) {
                    $classText = $classText.Substring(1)
                }
                if ([string]::IsNullOrEmpty($classText) -or $classText.Contains('/')) {
                    throw "Unsupported repository ruleset ref pattern '$Pattern'."
                }

                $classRegex = [System.Text.StringBuilder]::new()
                for ($classIndex = 0; $classIndex -lt $classText.Length; $classIndex++) {
                    $classCharacter = $classText[$classIndex]
                    if ($classCharacter -eq '\') {
                        if ($classIndex + 1 -ge $classText.Length) {
                            throw "Unsupported repository ruleset ref pattern '$Pattern'."
                        }
                        $classIndex++
                        $escapedClassCharacter = $classText[$classIndex]
                        switch ($escapedClassCharacter) {
                            ']' { [void]$classRegex.Append('\]') }
                            '[' { [void]$classRegex.Append('\[') }
                            '\' { [void]$classRegex.Append('\\') }
                            '-' { [void]$classRegex.Append('\-') }
                            '^' { [void]$classRegex.Append('\^') }
                            default { [void]$classRegex.Append([regex]::Escape([string]$escapedClassCharacter)) }
                        }
                    }
                    elseif ($classCharacter -eq '[') {
                        throw "Unsupported repository ruleset ref pattern '$Pattern'."
                    }
                    elseif ($classCharacter -eq '^') {
                        [void]$classRegex.Append('\^')
                    }
                    elseif ($classCharacter -eq '-' -and ($classIndex -eq 0 -or $classIndex -eq $classText.Length - 1)) {
                        [void]$classRegex.Append('\-')
                    }
                    else {
                        [void]$classRegex.Append($classCharacter)
                    }
                }

                if ($negated) {
                    [void]$regex.Append("[^/$classRegex]")
                }
                else {
                    [void]$regex.Append("[$classRegex]")
                }
                $index = $closingIndex
            }
            ']' {
                throw "Unsupported repository ruleset ref pattern '$Pattern'."
            }
            default {
                [void]$regex.Append([regex]::Escape([string]$character))
            }
        }
    }
    [void]$regex.Append('$')

    [regex]::IsMatch('refs/heads/main', $regex.ToString(), [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)
}

function Test-RulesetAppliesToMain {
    param(
        [Parameter(Mandatory)][object]$Ruleset,
        [Parameter(Mandatory)][string]$DefaultBranch
    )

    if ([string]$Ruleset.target -cne 'branch') {
        return $false
    }

    $include = @($Ruleset.conditions.ref_name.include)
    $exclude = @($Ruleset.conditions.ref_name.exclude)
    if ($include.Count -eq 0) {
        throw 'Active repository branch ruleset has no included ref patterns.'
    }

    $included = @($include | Where-Object { Test-RefPatternMatchesMain -Pattern ([string]$_) -DefaultBranch $DefaultBranch }).Count -gt 0
    $excluded = @($exclude | Where-Object { Test-RefPatternMatchesMain -Pattern ([string]$_) -DefaultBranch $DefaultBranch }).Count -gt 0
    $included -and -not $excluded
}

function ConvertTo-CanonicalJson {
    param(
        [AllowNull()][object]$Value
    )

    if ($null -eq $Value) {
        return 'null'
    }
    if ($Value -is [string] -or $Value -is [ValueType]) {
        return ConvertTo-Json -InputObject $Value -Compress
    }
    if ($Value -is [System.Array] -or $Value -is [System.Collections.IList]) {
        $elements = @($Value | ForEach-Object { ConvertTo-CanonicalJson -Value $_ })
        return '[' + ($elements -join ',') + ']'
    }

    $table = ConvertTo-PropertyTable -InputObject $Value
    $names = [string[]]@($table.Keys | ForEach-Object { [string]$_ })
    [array]::Sort($names, [System.StringComparer]::Ordinal)
    $properties = foreach ($name in $names) {
        (ConvertTo-Json -InputObject $name -Compress) + ':' + (ConvertTo-CanonicalJson -Value $table[$name])
    }
    '{' + ($properties -join ',') + '}'
}

function Get-RepositoryDefaultBranch {
    param(
        [Parameter(Mandatory)][scriptblock]$Runner
    )

    $repository = Invoke-GhJson -Runner $Runner -ArgumentList @('api', "repos/$expectedRepository") -Context 'Repository metadata'
    if ($repository.default_branch -isnot [string] -or [string]$repository.default_branch -cnotmatch '^[A-Za-z0-9._/-]+$') {
        throw 'Repository default branch is missing or malformed.'
    }

    [string]$repository.default_branch
}

function Get-RepositoryRulesetState {
    param(
        [Parameter(Mandatory)][scriptblock]$Runner,
        [Parameter(Mandatory)][object]$DesiredRuleset,
        [Parameter(Mandatory)][object]$ExpectedPayload,
        [Parameter(Mandatory)][string]$DefaultBranch
    )

    $rulesets = @(Invoke-GhPagedJson -Runner $Runner -Endpoint "repos/$expectedRepository/rulesets?includes_parents=false&per_page=100" -Context 'Repository ruleset list')
    $sortedRulesets = @($rulesets | Sort-Object { [long]$_.id })
    $nameMatches = @($rulesets | Where-Object { [string]$_.name -ceq [string]$DesiredRuleset.name })
    foreach ($nameMatch in $nameMatches) {
        if ([string]$nameMatch.source_type -cne 'Repository' -or [string]$nameMatch.source -cne $expectedRepository) {
            throw 'Desired ruleset name matched an unexpected non-repository source.'
        }
    }
    if ($nameMatches.Count -gt 1) {
        throw 'Repository ruleset lookup is ambiguous for the desired ruleset name and repository source.'
    }

    $existingRulesetId = $null
    $existingRulesetExact = $false
    $detailSnapshots = [System.Collections.Generic.List[object]]::new()
    foreach ($rulesetSummary in $sortedRulesets) {
        if ([string]$rulesetSummary.source_type -cne 'Repository' -or [string]$rulesetSummary.source -cne $expectedRepository) {
            throw 'Repository ruleset list returned an unexpected non-repository source.'
        }
        if (-not (Test-IntegerValue -Value $rulesetSummary.id) -or [long]$rulesetSummary.id -le 0) {
            throw 'Repository ruleset list returned an invalid id.'
        }

        $isDesiredName = [string]$rulesetSummary.name -ceq [string]$DesiredRuleset.name
        $isActiveBranchRuleset = [string]$rulesetSummary.target -ceq 'branch' -and [string]$rulesetSummary.enforcement -ceq 'active'
        if (-not $isDesiredName -and -not $isActiveBranchRuleset) {
            continue
        }

        $rulesetId = [long]$rulesetSummary.id
        $rulesetDetail = Invoke-GhJson -Runner $Runner -ArgumentList @('api', "repos/$expectedRepository/rulesets/$rulesetId") -Context "Repository ruleset detail $rulesetId"
        $detailSnapshots.Add([pscustomobject]([ordered]@{
            id = $rulesetId
            name = [string]$rulesetDetail.name
            target = [string]$rulesetDetail.target
            source_type = [string]$rulesetDetail.source_type
            source = [string]$rulesetDetail.source
            enforcement = [string]$rulesetDetail.enforcement
            bypass_actors = @($rulesetDetail.bypass_actors)
            conditions = $rulesetDetail.conditions
            rules = @($rulesetDetail.rules)
        })) | Out-Null
        if ($isDesiredName) {
            $existingRulesetId = $rulesetId
            $existingRulesetExact = Test-RulesetReadBack -Ruleset $rulesetDetail -ExpectedPayload $ExpectedPayload
            continue
        }

        if (Test-RulesetAppliesToMain -Ruleset $rulesetDetail -DefaultBranch $DefaultBranch) {
            throw "An additional active repository ruleset applies to main: $([string]$rulesetDetail.name)."
        }
    }

    $summarySnapshots = @(
        $sortedRulesets | ForEach-Object {
            [pscustomobject]([ordered]@{
                id = [long]$_.id
                name = [string]$_.name
                target = [string]$_.target
                source_type = [string]$_.source_type
                source = [string]$_.source
                enforcement = [string]$_.enforcement
            })
        }
    )
    $snapshot = [pscustomobject]([ordered]@{
        summaries = $summarySnapshots
        inspected_details = @($detailSnapshots.ToArray() | Sort-Object id)
    })

    [pscustomobject]@{
        ExistingRulesetId = $existingRulesetId
        ExistingRulesetExact = $existingRulesetExact
        SnapshotJson = ConvertTo-CanonicalJson -Value $snapshot
    }
}

function Assert-EnvironmentReadBack {
    param(
        [Parameter(Mandatory)][scriptblock]$Runner,
        [Parameter(Mandatory)][long]$ResolvedUserId
    )

    $environment = Invoke-GhJson -Runner $Runner -ArgumentList @('api', "repos/$expectedRepository/environments/$expectedEnvironmentName") -Context 'GitHub Environment read-back'
    if ([string]$environment.name -cne $expectedEnvironmentName) {
        throw 'GitHub Environment name does not match the reviewed state.'
    }

    $deploymentBranchPolicy = $environment.deployment_branch_policy
    if ($deploymentBranchPolicy.protected_branches -isnot [bool] -or [bool]$deploymentBranchPolicy.protected_branches -or
        $deploymentBranchPolicy.custom_branch_policies -isnot [bool] -or -not [bool]$deploymentBranchPolicy.custom_branch_policies) {
        throw 'GitHub Environment branch policy does not match the reviewed state.'
    }

    $protectionRules = @($environment.protection_rules)
    $reviewerRules = @($protectionRules | Where-Object { [string]$_.type -ceq 'required_reviewers' })
    if ($protectionRules.Count -ne 1 -or $reviewerRules.Count -ne 1) {
        throw 'GitHub Environment protection rules do not match the exact reviewed state.'
    }

    if ($reviewerRules[0].prevent_self_review -isnot [bool] -or [bool]$reviewerRules[0].prevent_self_review) {
        throw 'GitHub Environment self-review protection does not match the reviewed state.'
    }

    $reviewers = @($reviewerRules[0].reviewers)
    if ($reviewers.Count -ne 1 -or
        [string]$reviewers[0].type -cne 'User' -or
        -not (Test-IntegerValue -Value $reviewers[0].reviewer.id) -or
        [long]$reviewers[0].reviewer.id -ne $ResolvedUserId -or
        [string]$reviewers[0].reviewer.login -cne 'urruegg') {
        throw 'GitHub Environment reviewer does not match the reviewed user.'
    }

    $branchPolicies = Invoke-GhJson -Runner $Runner -ArgumentList @('api', "repos/$expectedRepository/environments/$expectedEnvironmentName/deployment-branch-policies") -Context 'GitHub Environment deployment branch policy read-back'
    $policies = @($branchPolicies.branch_policies)
    if (-not (Test-IntegerValue -Value $branchPolicies.total_count) -or [long]$branchPolicies.total_count -ne 1 -or
        $policies.Count -ne 1 -or [string]$policies[0].type -cne 'branch' -or [string]$policies[0].name -cne 'main') {
        throw 'GitHub Environment deployment branch policies do not match the exact main-only state.'
    }

    $variables = Invoke-GhJson -Runner $Runner -ArgumentList @('api', "repos/$expectedRepository/environments/$expectedEnvironmentName/variables") -Context 'GitHub Environment variable read-back'
    $environmentVariables = @($variables.variables)
    $variableNames = @($environmentVariables | ForEach-Object { [string]$_.name })
    if (-not (Test-IntegerValue -Value $variables.total_count) -or [long]$variables.total_count -ne 3 -or
        $variableNames.Count -ne 3 -or @($variableNames | Select-Object -Unique).Count -ne 3) {
        throw 'GitHub Environment variable names do not match the reviewed state.'
    }

    $variablesByName = @{}
    foreach ($variable in $environmentVariables) {
        if ([string]$variable.name -cnotin $expectedVariableNames -or $variable.value -isnot [string]) {
            throw 'GitHub Environment variable names do not match the reviewed state.'
        }
        $variablesByName[[string]$variable.name] = [string]$variable.value
    }
    foreach ($expectedVariableName in $expectedVariableNames) {
        if (-not $variablesByName.ContainsKey($expectedVariableName)) {
            throw 'GitHub Environment variable names do not match the reviewed state.'
        }
    }

    if ([string]$variablesByName.AZURE_TENANT_ID -cne $expectedTenantId) {
        throw 'GitHub Environment variable AZURE_TENANT_ID does not match the reviewed Tenant 1 tenant id.'
    }
    if ([string]$variablesByName.AZURE_SUBSCRIPTION_ID -cne $expectedSubscriptionId) {
        throw 'GitHub Environment variable AZURE_SUBSCRIPTION_ID does not match the reviewed Tenant 1 subscription id.'
    }
    Assert-GuidString -Value $variablesByName.AZURE_CLIENT_ID -Context 'GitHub Environment variable AZURE_CLIENT_ID'

    [string]$variablesByName.AZURE_CLIENT_ID
}

function Assert-LiveAzureRoleAbsence {
    param(
        [Parameter(Mandatory)][scriptblock]$Runner,
        [Parameter(Mandatory)][string]$ClientId,
        [Parameter(Mandatory)][string]$ExpectedPrincipalObjectId,
        [Parameter(Mandatory)][object]$Evidence
    )

    $account = Invoke-AzJson -Runner $Runner -ArgumentList @('account', 'show', '--output', 'json', '--only-show-errors') -Context 'Azure account read-back'
    if ([string]$account.tenantId -cne $expectedTenantId) {
        throw 'Azure account tenant does not match the reviewed Tenant 1 tenant.'
    }
    if ([string]$account.id -cne $expectedSubscriptionId) {
        throw 'Azure account subscription does not match the reviewed Tenant 1 subscription.'
    }

    $servicePrincipal = Invoke-AzJson -Runner $Runner -ArgumentList @('ad', 'sp', 'show', '--id', $ClientId, '--output', 'json', '--only-show-errors') -Context 'Azure service principal read-back'
    if ([string]$servicePrincipal.id -cne $ExpectedPrincipalObjectId) {
        throw 'Azure service principal object does not match the reviewed Tenant 1 principal.'
    }
    if ([string]$servicePrincipal.appId -cne $ClientId) {
        throw 'GitHub Environment variable AZURE_CLIENT_ID does not match the reviewed Azure service principal client id.'
    }
    if ([string]$servicePrincipal.servicePrincipalType -cne 'Application') {
        throw 'Azure service principal type must be Application.'
    }

    $accessTokenResult = Invoke-NativeCommandResult -Runner $Runner -FilePath 'az' -ArgumentList @('account', 'get-access-token', '--resource', 'https://management.azure.com/', '--query', 'accessToken', '--output', 'tsv', '--only-show-errors')
    if ($accessTokenResult.ExitCode -ne 0) {
        throw "Azure Resource Manager access token command failed with exit code $($accessTokenResult.ExitCode)."
    }
    $accessToken = ([string]$accessTokenResult.StdOut).Trim()
    if ([string]::IsNullOrWhiteSpace($accessToken)) {
        throw 'Azure Resource Manager access token resolution returned an empty value.'
    }

    $evidenceAssignmentIds = @($Evidence.Assignments | ForEach-Object { [string]$_.Id })
    foreach ($assignmentId in $evidenceAssignmentIds) {
        $statusCode = Get-ArmResourceStatusCode -ResourceId $assignmentId -AccessToken $accessToken
        if ($statusCode -ge 200 -and $statusCode -lt 300) {
            throw "The exact bootstrap evidence assignment remains present in Azure: $assignmentId"
        }
        if ($statusCode -ne 404) {
            throw "Exact bootstrap evidence assignment read returned HTTP status $statusCode for $assignmentId."
        }
    }

    $roleAssignmentResponse = Invoke-AzJson -Runner $Runner -ArgumentList @('role', 'assignment', 'list', '--assignee-object-id', $ExpectedPrincipalObjectId, '--scope', $expectedScope, '--all', '--output', 'json', '--only-show-errors') -Context 'Azure role assignment read-back'
    $roleAssignments = if ($roleAssignmentResponse -is [System.Array]) {
        @($roleAssignmentResponse | ForEach-Object { $_ })
    }
    elseif ($null -eq $roleAssignmentResponse) {
        @()
    }
    else {
        @($roleAssignmentResponse)
    }
    $temporaryRoleDefinitionIds = @(
        "$expectedScope/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c",
        "$expectedScope/providers/Microsoft.Authorization/roleDefinitions/f58310d9-a9f6-439a-9e8d-f62e7b41a168"
    )
    foreach ($roleAssignment in $roleAssignments) {
        if ($null -eq $roleAssignment -or ($roleAssignment -is [System.Array] -and $roleAssignment.Count -eq 0)) {
            continue
        }

        $roleAssignmentTable = ConvertTo-PropertyTable -InputObject $roleAssignment
        foreach ($propertyName in @('id', 'principalId', 'roleDefinitionId', 'scope')) {
            if (-not $roleAssignmentTable.ContainsKey($propertyName)) {
                throw "Azure role assignment read-back is missing required property '$propertyName'."
            }
        }
        if ([string]$roleAssignmentTable.principalId -cne $ExpectedPrincipalObjectId) {
            throw 'Azure role assignment read-back returned an unexpected principal.'
        }
        if ([string]$roleAssignmentTable.id -cin $evidenceAssignmentIds) {
            throw 'A bootstrap evidence assignment remains present in Azure.'
        }
        if ([string]$roleAssignmentTable.scope -ceq $expectedScope -and [string]$roleAssignmentTable.roleDefinitionId -cin $temporaryRoleDefinitionIds) {
            throw 'A temporary Azure role remains present at the reviewed subscription scope.'
        }
    }
}

if ($Repository -cne $expectedRepository) {
    throw "Repository must be exactly '$expectedRepository'."
}
if ($ValidatorRunId -le 0 -or $BootstrapRunId -le 0) {
    throw 'ValidatorRunId and BootstrapRunId must be positive integers.'
}
if ($ValidatorRunId -eq $BootstrapRunId) {
    throw 'ValidatorRunId and BootstrapRunId must be different workflow runs.'
}

$desiredStateDocument = Read-JsonFile -Path $DesiredStatePath -Context 'GitHub governance desired state'
$desiredRuleset = Assert-DesiredState -DesiredState $desiredStateDocument.Value
$bootstrapEvidenceDocument = Read-JsonFile -Path $BootstrapEvidencePath -Context 'Bootstrap cleanup evidence'
Assert-BootstrapEvidence -Evidence $bootstrapEvidenceDocument.Value -ExpectedBootstrapRunId $BootstrapRunId

$nativeCommandRunner = New-DefaultNativeCommandRunner

$userIdText = (Invoke-NativeCommand -Runner $nativeCommandRunner -ArgumentList @('api', 'users/urruegg', '--jq', '.id')).Trim()
$resolvedUserId = [long]0
if (-not [long]::TryParse($userIdText, [ref]$resolvedUserId) -or $resolvedUserId -le 0) {
    throw 'GitHub user id resolution failed for urruegg.'
}

$adminText = (Invoke-NativeCommand -Runner $nativeCommandRunner -ArgumentList @('api', "repos/$expectedRepository/collaborators/urruegg/permission", '--jq', '.user.permissions.admin')).Trim()
if ($adminText -cne 'true') {
    throw 'GitHub collaborator urruegg must have repository administrator permission.'
}
$defaultBranch = Get-RepositoryDefaultBranch -Runner $nativeCommandRunner

$mainRef = Invoke-GhJson -Runner $nativeCommandRunner -ArgumentList @('api', "repos/$expectedRepository/git/ref/heads/main") -Context 'Current main ref'
$currentMainSha = [string]$mainRef.object.sha
if ($currentMainSha -cnotmatch '^[0-9a-fA-F]{40}$') {
    throw 'Current main ref did not return a valid commit SHA.'
}

$tenantConfiguration = Import-CurrentMainTenantConfiguration -Runner $nativeCommandRunner -MainSha $currentMainSha
$reviewedPrincipalObjectId = Get-ReviewedPrincipalObjectId -Configuration $tenantConfiguration
if ([string]$bootstrapEvidenceDocument.Value.PrincipalObjectId -cne $reviewedPrincipalObjectId) {
    throw 'Bootstrap evidence PrincipalObjectId does not match the reviewed service principal object.'
}

$validatorRun = Invoke-GhJson -Runner $nativeCommandRunner -ArgumentList @('api', "repos/$expectedRepository/actions/runs/$ValidatorRunId") -Context 'Validator workflow run'
Assert-WorkflowRun -Run $validatorRun -ExpectedRunId $ValidatorRunId -ExpectedPath '.github/workflows/validate-repository.yml' -ExpectedName 'Validate repository' -ExpectedEvents @('push', 'workflow_dispatch') -ExpectedHeadSha $currentMainSha -Context 'Validator workflow run'

$bootstrapRun = Invoke-GhJson -Runner $nativeCommandRunner -ArgumentList @('api', "repos/$expectedRepository/actions/runs/$BootstrapRunId") -Context 'Bootstrap workflow run'
Assert-WorkflowRun -Run $bootstrapRun -ExpectedRunId $BootstrapRunId -ExpectedPath '.github/workflows/bootstrap-tenant.yml' -ExpectedName 'Validate tenant bootstrap' -ExpectedEvents @('workflow_dispatch') -ExpectedHeadSha $currentMainSha -Context 'Bootstrap workflow run'
if ([string]$bootstrapEvidenceDocument.Value.HeadSha -cne $currentMainSha) {
    throw 'Bootstrap evidence HeadSha must match the current main commit.'
}

$payload = New-RulesetPayload -DesiredRuleset $desiredRuleset -ResolvedUserId $resolvedUserId
$rulesetState = Get-RepositoryRulesetState -Runner $nativeCommandRunner -DesiredRuleset $desiredRuleset -ExpectedPayload $payload -DefaultBranch $defaultBranch
$existingRulesetId = $rulesetState.ExistingRulesetId
$existingRulesetExact = [bool]$rulesetState.ExistingRulesetExact

$environmentClientId = Assert-EnvironmentReadBack -Runner $nativeCommandRunner -ResolvedUserId $resolvedUserId
Assert-LiveAzureRoleAbsence -Runner $nativeCommandRunner -ClientId $environmentClientId -ExpectedPrincipalObjectId $reviewedPrincipalObjectId -Evidence $bootstrapEvidenceDocument.Value

$action = if ($null -eq $existingRulesetId) { 'Create' } elseif (-not $existingRulesetExact) { 'Update' } else { 'None' }
$method = if ($action -ceq 'Create') { 'POST' } elseif ($action -ceq 'Update') { 'PUT' } else { $null }
$endpoint = if ($action -ceq 'Update') { "repos/$expectedRepository/rulesets/$existingRulesetId" } else { "repos/$expectedRepository/rulesets" }
$proposal = [pscustomobject]([ordered]@{
    Repository = $expectedRepository
    ValidatorRunId = $ValidatorRunId
    BootstrapRunId = $BootstrapRunId
    BootstrapEvidencePath = $bootstrapEvidenceDocument.Path
    RulesetName = [string]$desiredRuleset.name
    ExistingRulesetId = $existingRulesetId
    Action = $action
    Method = $method
    Endpoint = $endpoint
    Payload = $payload
    EnvironmentName = $expectedEnvironmentName
    Status = if ($action -ceq 'None') { 'Verified' } else { 'Proposed' }
})

if ($action -ceq 'None' -or $WhatIfPreference) {
    return $proposal
}

$target = "$expectedRepository ruleset '$($desiredRuleset.name)'"
if (-not $PSCmdlet.ShouldProcess($target, "$method $endpoint")) {
    throw 'GitHub ruleset mutation was declined; governance was not activated.'
}

$approvalUserIdText = (Invoke-NativeCommand -Runner $nativeCommandRunner -ArgumentList @('api', 'users/urruegg', '--jq', '.id')).Trim()
$approvalUserId = [long]0
if (-not [long]::TryParse($approvalUserIdText, [ref]$approvalUserId) -or $approvalUserId -ne $resolvedUserId) {
    throw 'GitHub owner identity changed during the approval window.'
}
$approvalAdminText = (Invoke-NativeCommand -Runner $nativeCommandRunner -ArgumentList @('api', "repos/$expectedRepository/collaborators/urruegg/permission", '--jq', '.user.permissions.admin')).Trim()
if ($approvalAdminText -cne 'true') {
    throw 'GitHub administrator permission changed during the approval window.'
}
$approvalDefaultBranch = Get-RepositoryDefaultBranch -Runner $nativeCommandRunner
if ($approvalDefaultBranch -cne $defaultBranch) {
    throw 'Repository default branch changed during the approval window.'
}

$approvalMainRef = Invoke-GhJson -Runner $nativeCommandRunner -ArgumentList @('api', "repos/$expectedRepository/git/ref/heads/main") -Context 'Post-approval current main ref'
$approvalMainSha = [string]$approvalMainRef.object.sha
if ($approvalMainSha -cne $currentMainSha) {
    throw 'The current main commit changed during the approval window.'
}

$approvalTenantConfiguration = Import-CurrentMainTenantConfiguration -Runner $nativeCommandRunner -MainSha $approvalMainSha
$approvalPrincipalObjectId = Get-ReviewedPrincipalObjectId -Configuration $approvalTenantConfiguration
if ($approvalPrincipalObjectId -cne $reviewedPrincipalObjectId) {
    throw 'The reviewed service principal changed during the approval window.'
}

$approvalEvidenceDocument = Read-JsonFile -Path $BootstrapEvidencePath -Context 'Post-approval bootstrap cleanup evidence'
Assert-BootstrapEvidence -Evidence $approvalEvidenceDocument.Value -ExpectedBootstrapRunId $BootstrapRunId
if (($approvalEvidenceDocument.Value | ConvertTo-Json -Depth 30 -Compress) -cne ($bootstrapEvidenceDocument.Value | ConvertTo-Json -Depth 30 -Compress)) {
    throw 'Bootstrap cleanup evidence changed during the approval window.'
}
if ([string]$approvalEvidenceDocument.Value.HeadSha -cne $approvalMainSha -or
    [string]$approvalEvidenceDocument.Value.PrincipalObjectId -cne $approvalPrincipalObjectId) {
    throw 'Post-approval bootstrap cleanup evidence does not match current main and the reviewed service principal.'
}

$approvalValidatorRun = Invoke-GhJson -Runner $nativeCommandRunner -ArgumentList @('api', "repos/$expectedRepository/actions/runs/$ValidatorRunId") -Context 'Post-approval validator workflow run'
Assert-WorkflowRun -Run $approvalValidatorRun -ExpectedRunId $ValidatorRunId -ExpectedPath '.github/workflows/validate-repository.yml' -ExpectedName 'Validate repository' -ExpectedEvents @('push', 'workflow_dispatch') -ExpectedHeadSha $approvalMainSha -Context 'Post-approval validator workflow run'
$approvalBootstrapRun = Invoke-GhJson -Runner $nativeCommandRunner -ArgumentList @('api', "repos/$expectedRepository/actions/runs/$BootstrapRunId") -Context 'Post-approval bootstrap workflow run'
Assert-WorkflowRun -Run $approvalBootstrapRun -ExpectedRunId $BootstrapRunId -ExpectedPath '.github/workflows/bootstrap-tenant.yml' -ExpectedName 'Validate tenant bootstrap' -ExpectedEvents @('workflow_dispatch') -ExpectedHeadSha $approvalMainSha -Context 'Post-approval bootstrap workflow run'

$approvalRulesetState = Get-RepositoryRulesetState -Runner $nativeCommandRunner -DesiredRuleset $desiredRuleset -ExpectedPayload $payload -DefaultBranch $approvalDefaultBranch
$approvalAction = if ($null -eq $approvalRulesetState.ExistingRulesetId) { 'Create' } elseif (-not [bool]$approvalRulesetState.ExistingRulesetExact) { 'Update' } else { 'None' }
if ($approvalAction -cne $action -or
    $approvalRulesetState.ExistingRulesetId -ne $existingRulesetId -or
    [string]$approvalRulesetState.SnapshotJson -cne [string]$rulesetState.SnapshotJson) {
    throw 'Repository ruleset target state changed during the approval window.'
}

$approvalEnvironmentClientId = Assert-EnvironmentReadBack -Runner $nativeCommandRunner -ResolvedUserId $approvalUserId
if ($approvalEnvironmentClientId -cne $environmentClientId) {
    throw 'GitHub Environment client id changed during the approval window.'
}
Assert-LiveAzureRoleAbsence -Runner $nativeCommandRunner -ClientId $approvalEnvironmentClientId -ExpectedPrincipalObjectId $approvalPrincipalObjectId -Evidence $approvalEvidenceDocument.Value

$tempPath = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString() + '.json')
try {
    $payloadJson = $payload | ConvertTo-Json -Depth 30 -Compress
    [System.IO.File]::WriteAllText($tempPath, $payloadJson, [System.Text.UTF8Encoding]::new($false))
    $mutationResult = Invoke-GhJson -Runner $nativeCommandRunner -ArgumentList @('api', '--method', $method, $endpoint, '--input', $tempPath) -Context 'GitHub ruleset mutation'
}
finally {
    if (Test-Path -LiteralPath $tempPath) {
        Remove-Item -LiteralPath $tempPath -Force
    }
}

if (-not (Test-IntegerValue -Value $mutationResult.id) -or [long]$mutationResult.id -le 0) {
    throw 'GitHub ruleset mutation did not return a valid ruleset id.'
}
$mutatedRulesetId = [long]$mutationResult.id
if ($action -ceq 'Update' -and $mutatedRulesetId -ne $existingRulesetId) {
    throw 'GitHub ruleset update returned an unexpected ruleset id.'
}

$rulesetReadBack = Invoke-GhJson -Runner $nativeCommandRunner -ArgumentList @('api', "repos/$expectedRepository/rulesets/$mutatedRulesetId") -Context 'GitHub ruleset read-back'
if (-not (Test-RulesetReadBack -Ruleset $rulesetReadBack -ExpectedPayload $payload)) {
    $observedPayload = ConvertTo-ReviewedRulesetPayload -Ruleset $rulesetReadBack
    $observedJson = if ($null -eq $observedPayload) { 'null' } else { $observedPayload | ConvertTo-Json -Depth 30 -Compress }
    $expectedJson = $payload | ConvertTo-Json -Depth 30 -Compress
    throw "GitHub ruleset read-back does not match every reviewed field. Expected: $expectedJson Observed: $observedJson"
}

$postMutationDefaultBranch = Get-RepositoryDefaultBranch -Runner $nativeCommandRunner
if ($postMutationDefaultBranch -cne $approvalDefaultBranch) {
    throw 'Repository default branch changed during ruleset mutation.'
}
$postMutationRulesetState = Get-RepositoryRulesetState -Runner $nativeCommandRunner -DesiredRuleset $desiredRuleset -ExpectedPayload $payload -DefaultBranch $postMutationDefaultBranch
if ($postMutationRulesetState.ExistingRulesetId -ne $mutatedRulesetId -or -not [bool]$postMutationRulesetState.ExistingRulesetExact) {
    throw 'Post-mutation repository ruleset inventory does not contain exactly the reviewed main ruleset.'
}

$proposal.Status = 'Verified'
$proposal