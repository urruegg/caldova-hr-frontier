[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[^/]+/[^/]+$')]
    [string]$Repository,

    [Parameter(Mandatory)]
    [ValidateScript({ $_ -gt 0 })]
    [long]$ValidatorRunId,

    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$DesiredStatePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-DefaultNativeCommandRunner {
    {
        param(
            [Parameter(Mandatory)]
            [string]$FilePath,

            [Parameter(Mandatory)]
            [string[]]$ArgumentList
        )

        $commands = @(Microsoft.PowerShell.Core\Get-Command -Name $FilePath -CommandType Application -All -ErrorAction Stop)
        if ($commands.Count -eq 0) {
            throw "Required application command was not found: $FilePath"
        }

        $stderrPath = Join-Path (Get-Location) ".github-governance-$([guid]::NewGuid()).stderr"
        $originalErrorActionPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $output = & $commands[0].Source @ArgumentList 2> $stderrPath
            [pscustomobject]@{
                ExitCode = $LASTEXITCODE
                StdOut = ($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
                StdErr = if (Test-Path -LiteralPath $stderrPath) {
                    [System.IO.File]::ReadAllText($stderrPath)
                }
                else {
                    ''
                }
            }
        }
        finally {
            $ErrorActionPreference = $originalErrorActionPreference
            Remove-Item -LiteralPath $stderrPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function ConvertTo-PropertyTable {
    param([AllowNull()][object]$InputObject)

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
        [Parameter(Mandatory)][object]$InputObject,
        [Parameter(Mandatory)][string[]]$AllowedProperties,
        [Parameter(Mandatory)][string[]]$RequiredProperties,
        [Parameter(Mandatory)][string]$Context
    )

    if ($null -eq $InputObject -or
        $InputObject -is [string] -or
        $InputObject -is [ValueType] -or
        $InputObject -is [System.Array]) {
        throw "$Context must be an object."
    }

    $properties = @(
        $InputObject.PSObject.Properties |
            Where-Object { $_.MemberType -in @('NoteProperty', 'Property', 'ScriptProperty') } |
            ForEach-Object Name
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

function Assert-DesiredState {
    param([Parameter(Mandatory)][object]$DesiredState)

    $topLevelProperties = @(
        '$schema',
        'schemaVersion',
        'repository',
        'repositorySettings',
        'security',
        'rulesets'
    )
    Assert-ClosedObject `
        -InputObject $DesiredState `
        -AllowedProperties $topLevelProperties `
        -RequiredProperties $topLevelProperties `
        -Context 'Desired state'
    Assert-StringValue -Value $DesiredState.'$schema' -Expected '../schemas/github-ruleset.schema.json' -Context 'Desired state $schema'
    Assert-StringValue -Value $DesiredState.schemaVersion -Expected '1.0' -Context 'Desired state schemaVersion'
    Assert-StringValue -Value $DesiredState.repository -Expected $expectedRepository -Context 'Desired state repository'

    $settingProperties = @(
        'defaultBranch',
        'allowMergeCommit',
        'allowRebaseMerge',
        'allowSquashMerge',
        'deleteBranchOnMerge',
        'hasProjects'
    )
    Assert-ClosedObject `
        -InputObject $DesiredState.repositorySettings `
        -AllowedProperties $settingProperties `
        -RequiredProperties $settingProperties `
        -Context 'Desired repositorySettings'
    Assert-StringValue -Value $DesiredState.repositorySettings.defaultBranch -Expected 'main' -Context 'Desired default branch'
    Assert-BooleanValue -Value $DesiredState.repositorySettings.allowMergeCommit -Expected $false -Context 'Desired allowMergeCommit'
    Assert-BooleanValue -Value $DesiredState.repositorySettings.allowRebaseMerge -Expected $false -Context 'Desired allowRebaseMerge'
    Assert-BooleanValue -Value $DesiredState.repositorySettings.allowSquashMerge -Expected $true -Context 'Desired allowSquashMerge'
    Assert-BooleanValue -Value $DesiredState.repositorySettings.deleteBranchOnMerge -Expected $true -Context 'Desired deleteBranchOnMerge'
    Assert-BooleanValue -Value $DesiredState.repositorySettings.hasProjects -Expected $false -Context 'Desired hasProjects'

    Assert-ClosedObject `
        -InputObject $DesiredState.security `
        -AllowedProperties @('dependabotSecurityUpdates') `
        -RequiredProperties @('dependabotSecurityUpdates') `
        -Context 'Desired security'
    Assert-BooleanValue `
        -Value $DesiredState.security.dependabotSecurityUpdates `
        -Expected $true `
        -Context 'Desired dependabotSecurityUpdates'

    Assert-ArrayValue -Value $DesiredState.rulesets -Context 'Desired rulesets'
    $rulesets = @($DesiredState.rulesets)
    if ($rulesets.Count -ne 1) {
        throw 'Desired state must contain exactly one ruleset.'
    }

    $ruleset = $rulesets[0]
    $rulesetProperties = @('name', 'target', 'enforcement', 'bypassActors', 'conditions', 'rules')
    Assert-ClosedObject `
        -InputObject $ruleset `
        -AllowedProperties $rulesetProperties `
        -RequiredProperties $rulesetProperties `
        -Context 'Desired ruleset'
    Assert-StringValue -Value $ruleset.name -Expected 'main' -Context 'Desired ruleset name'
    Assert-StringValue -Value $ruleset.target -Expected 'branch' -Context 'Desired ruleset target'
    Assert-StringValue -Value $ruleset.enforcement -Expected 'active' -Context 'Desired ruleset enforcement'
    Assert-ArrayValue -Value $ruleset.bypassActors -Context 'Desired ruleset bypassActors'
    if (@($ruleset.bypassActors).Count -ne 0) {
        throw 'Desired ruleset bypassActors must be empty.'
    }

    Assert-ClosedObject `
        -InputObject $ruleset.conditions `
        -AllowedProperties @('refName') `
        -RequiredProperties @('refName') `
        -Context 'Desired ruleset conditions'
    Assert-ClosedObject `
        -InputObject $ruleset.conditions.refName `
        -AllowedProperties @('include', 'exclude') `
        -RequiredProperties @('include', 'exclude') `
        -Context 'Desired ruleset refName'
    Assert-ExactStringArray `
        -Value $ruleset.conditions.refName.include `
        -Expected @('refs/heads/main') `
        -Context 'Desired ruleset included refs'
    Assert-ExactStringArray `
        -Value $ruleset.conditions.refName.exclude `
        -Expected @() `
        -Context 'Desired ruleset excluded refs'

    Assert-ArrayValue -Value $ruleset.rules -Context 'Desired ruleset rules'
    $rules = @($ruleset.rules)
    if ($rules.Count -ne 4) {
        throw 'Desired ruleset must contain exactly four rules.'
    }
    $expectedRuleTypes = @('deletion', 'non_fast_forward', 'pull_request', 'required_status_checks')
    for ($index = 0; $index -lt $rules.Count; $index++) {
        $requiredProperties = if ($index -lt 2) { @('type') } else { @('type', 'parameters') }
        Assert-ClosedObject `
            -InputObject $rules[$index] `
            -AllowedProperties $requiredProperties `
            -RequiredProperties $requiredProperties `
            -Context "Desired ruleset rule $index"
        Assert-StringValue `
            -Value $rules[$index].type `
            -Expected $expectedRuleTypes[$index] `
            -Context "Desired ruleset rule $index type"
    }

    $pullRequestProperties = @(
        'dismissStaleReviewsOnPush',
        'requireCodeOwnerReview',
        'requireLastPushApproval',
        'requiredApprovingReviewCount',
        'requiredReviewThreadResolution',
        'allowedMergeMethods'
    )
    $pullRequest = $rules[2].parameters
    Assert-ClosedObject `
        -InputObject $pullRequest `
        -AllowedProperties $pullRequestProperties `
        -RequiredProperties $pullRequestProperties `
        -Context 'Desired pull-request rule parameters'
    Assert-BooleanValue -Value $pullRequest.dismissStaleReviewsOnPush -Expected $true -Context 'Desired dismissStaleReviewsOnPush'
    Assert-BooleanValue -Value $pullRequest.requireCodeOwnerReview -Expected $false -Context 'Desired requireCodeOwnerReview'
    Assert-BooleanValue -Value $pullRequest.requireLastPushApproval -Expected $false -Context 'Desired requireLastPushApproval'
    if ($pullRequest.requiredApprovingReviewCount -isnot [long] -and
        $pullRequest.requiredApprovingReviewCount -isnot [int]) {
        throw 'Desired requiredApprovingReviewCount must be an integer.'
    }
    if ([long]$pullRequest.requiredApprovingReviewCount -ne 0) {
        throw 'Desired requiredApprovingReviewCount must be zero.'
    }
    Assert-BooleanValue `
        -Value $pullRequest.requiredReviewThreadResolution `
        -Expected $true `
        -Context 'Desired requiredReviewThreadResolution'
    Assert-ExactStringArray `
        -Value $pullRequest.allowedMergeMethods `
        -Expected @('squash') `
        -Context 'Desired allowedMergeMethods'

    $statusProperties = @(
        'doNotEnforceOnCreate',
        'requiredStatusChecks',
        'strictRequiredStatusChecksPolicy'
    )
    $status = $rules[3].parameters
    Assert-ClosedObject `
        -InputObject $status `
        -AllowedProperties $statusProperties `
        -RequiredProperties $statusProperties `
        -Context 'Desired status-check rule parameters'
    Assert-BooleanValue -Value $status.doNotEnforceOnCreate -Expected $false -Context 'Desired doNotEnforceOnCreate'
    Assert-BooleanValue `
        -Value $status.strictRequiredStatusChecksPolicy `
        -Expected $true `
        -Context 'Desired strictRequiredStatusChecksPolicy'
    Assert-ArrayValue -Value $status.requiredStatusChecks -Context 'Desired requiredStatusChecks'
    $checks = @($status.requiredStatusChecks)
    if ($checks.Count -ne 1) {
        throw 'Desired ruleset must contain exactly one required status check.'
    }
    Assert-ClosedObject `
        -InputObject $checks[0] `
        -AllowedProperties @('context', 'integrationId') `
        -RequiredProperties @('context', 'integrationId') `
        -Context 'Desired required status check'
    Assert-StringValue `
        -Value $checks[0].context `
        -Expected 'Repository setup validation' `
        -Context 'Desired required status check context'
    if (-not (Test-IntegerValue -Value $checks[0].integrationId)) {
        throw 'Desired required status check integrationId must be an integer.'
    }
    if ([long]$checks[0].integrationId -ne 15368) {
        throw 'Desired required status check integrationId does not match GitHub Actions.'
    }

    $ruleset
}

function Invoke-NativeCommandResult {
    param(
        [Parameter(Mandatory)][scriptblock]$Runner,
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$ArgumentList
    )

    $result = & $Runner -FilePath $FilePath -ArgumentList $ArgumentList
    if ($null -eq $result) {
        throw "$FilePath returned no command result."
    }
    foreach ($property in @('ExitCode', 'StdOut', 'StdErr')) {
        if ($null -eq $result.PSObject.Properties[$property]) {
            throw "$FilePath command result is missing $property."
        }
    }
    $result
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory)][scriptblock]$Runner,
        [string]$FilePath = 'gh',
        [Parameter(Mandatory)][string[]]$ArgumentList
    )

    $result = Invoke-NativeCommandResult -Runner $Runner -FilePath $FilePath -ArgumentList $ArgumentList
    if ([int]$result.ExitCode -ne 0) {
        $errorText = [string]$result.StdErr
        if ([string]::IsNullOrWhiteSpace($errorText)) {
            $errorText = 'no stderr'
        }
        throw "$FilePath failed with exit code $($result.ExitCode): $errorText"
    }
    [string]$result.StdOut
}

function Invoke-GhJson {
    param(
        [Parameter(Mandatory)][scriptblock]$Runner,
        [Parameter(Mandatory)][string[]]$ArgumentList,
        [Parameter(Mandatory)][string]$Context
    )

    $text = Invoke-NativeCommand -Runner $Runner -ArgumentList $ArgumentList
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

    $text = Invoke-NativeCommand `
        -Runner $Runner `
        -ArgumentList @('api', '--paginate', '--slurp', $Endpoint)
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

function Invoke-GhPagedPropertyJson {
    param(
        [Parameter(Mandatory)][scriptblock]$Runner,
        [Parameter(Mandatory)][string]$Endpoint,
        [Parameter(Mandatory)][string]$PropertyName,
        [Parameter(Mandatory)][string]$Context
    )

    $text = Invoke-NativeCommand `
        -Runner $Runner `
        -ArgumentList @('api', '--paginate', '--slurp', $Endpoint)
    if ([string]::IsNullOrWhiteSpace($text)) {
        throw "$Context returned no JSON."
    }
    try {
        $pages = $text | ConvertFrom-Json
    }
    catch {
        throw "$Context returned malformed paginated JSON."
    }
    if ($pages -isnot [System.Array] -or $pages.Count -eq 0) {
        throw "$Context must return a non-empty array of pages."
    }

    $expectedTotalCount = $null
    $items = [System.Collections.Generic.List[object]]::new()
    foreach ($page in @($pages)) {
        if ($null -eq $page -or
            $page -is [string] -or
            $page -is [ValueType] -or
            $page -is [System.Array]) {
            throw "$Context must return each page as an object."
        }
        $pageProperties = ConvertTo-PropertyTable -InputObject $page
        if (-not $pageProperties.ContainsKey('total_count')) {
            throw "$Context page is missing total_count."
        }
        if (-not (Test-IntegerValue -Value $pageProperties.total_count) -or
            [long]$pageProperties.total_count -lt 0) {
            throw "$Context page total_count must be a non-negative integer."
        }
        if ($null -eq $expectedTotalCount) {
            $expectedTotalCount = [long]$pageProperties.total_count
        }
        elseif ([long]$pageProperties.total_count -ne $expectedTotalCount) {
            throw "$Context total_count changed between pages."
        }
        if (-not $pageProperties.ContainsKey($PropertyName)) {
            throw "$Context page is missing $PropertyName."
        }
        Assert-ArrayValue -Value $pageProperties[$PropertyName] -Context "$Context page $PropertyName"
        foreach ($item in @($pageProperties[$PropertyName])) {
            $items.Add($item) | Out-Null
        }
    }

    if ($items.Count -ne $expectedTotalCount) {
        throw "$Context total_count does not match retrieved $PropertyName."
    }
    $items.ToArray()
}

function Assert-ValidatorRun {
    param(
        [Parameter(Mandatory)][object]$Run,
        [Parameter(Mandatory)][string]$CurrentMainSha
    )

    if ([string]$Run.path -cne '.github/workflows/validate-repository.yml' -or
        [string]$Run.head_branch -cne 'main' -or
        [string]$Run.head_sha -cne $CurrentMainSha -or
        [string]$Run.status -cne 'completed' -or
        [string]$Run.conclusion -cne 'success') {
        throw 'Validator run must be the successful completed current-main validate-repository workflow.'
    }
}

function Assert-ValidatorJobs {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Jobs
    )

    $matching = @($Jobs | Where-Object {
        [string]$_.name -ceq 'Repository setup validation' -and
        [string]$_.conclusion -ceq 'success'
    })
    if ($matching.Count -ne 1 -or
        @($Jobs | Where-Object { [string]$_.name -ceq 'Repository setup validation' }).Count -ne 1) {
        throw 'Validator run must contain exactly one successful Repository setup validation job.'
    }
}

function Assert-CodeownersMap {
    param([AllowNull()][string]$Content)

    $mapLines = @(
        ([string]$Content -split "\r?\n") |
            ForEach-Object { ($_ -replace '\s+#.*$', '').Trim() } |
            Where-Object { $_ -match '^\S+\s+@\S+' }
    )
    if ($mapLines.Count -eq 0) {
        throw 'Current-main CODEOWNERS must contain a non-empty ownership map.'
    }
}

function New-RulesetPayload {
    param([Parameter(Mandatory)][object]$DesiredRuleset)

    [pscustomobject]([ordered]@{
        name = [string]$DesiredRuleset.name
        target = [string]$DesiredRuleset.target
        enforcement = [string]$DesiredRuleset.enforcement
        bypass_actors = @()
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
    param([Parameter(Mandatory)][object]$Ruleset)

    $bypassActors = @($Ruleset.bypass_actors)
    $rules = @($Ruleset.rules)
    if ($bypassActors.Count -ne 0 -or $rules.Count -ne 4) {
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
        bypass_actors = @()
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

    if ([string]$Ruleset.source_type -cne 'Repository' -or
        [string]$Ruleset.source -cne $expectedRepository) {
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
    ($reviewedPayload | ConvertTo-Json -Depth 30 -Compress) -ceq
        ($ExpectedPayload | ConvertTo-Json -Depth 30 -Compress)
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
    if ($Pattern.StartsWith('~', [System.StringComparison]::Ordinal) -or
        $Pattern.IndexOfAny([char[]]'{}') -ge 0) {
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
                $starCount = $runEnd - $index + 1
                if ($starCount -gt 2) {
                    throw "Unsupported repository ruleset ref pattern '$Pattern'."
                }
                $isGlobstar = $starCount -eq 2 -and
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
                $negated = $classText.StartsWith('!', [System.StringComparison]::Ordinal) -or
                    $classText.StartsWith('^', [System.StringComparison]::Ordinal)
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
                    elseif ($classCharacter -eq '-' -and
                        ($classIndex -eq 0 -or $classIndex -eq $classText.Length - 1)) {
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

    [regex]::IsMatch(
        'refs/heads/main',
        $regex.ToString(),
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
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
    $included = @(
        $include |
            Where-Object {
                Test-RefPatternMatchesMain -Pattern ([string]$_) -DefaultBranch $DefaultBranch
            }
    ).Count -gt 0
    $excluded = @(
        $exclude |
            Where-Object {
                Test-RefPatternMatchesMain -Pattern ([string]$_) -DefaultBranch $DefaultBranch
            }
    ).Count -gt 0
    $included -and -not $excluded
}

function Test-RepositorySettings {
    param(
        [Parameter(Mandatory)][object]$RepositoryState,
        [Parameter(Mandatory)][object]$DesiredSettings
    )

    $propertyTable = ConvertTo-PropertyTable -InputObject $RepositoryState
    foreach ($property in @(
        'allow_merge_commit',
        'allow_rebase_merge',
        'allow_squash_merge',
        'delete_branch_on_merge',
        'has_projects'
    )) {
        if (-not $propertyTable.ContainsKey($property)) {
            throw "Repository settings is missing required property '$property'."
        }
        if ($propertyTable[$property] -isnot [bool]) {
            throw "Repository settings property '$property' must be a JSON boolean."
        }
    }

    [string]$RepositoryState.default_branch -ceq [string]$DesiredSettings.defaultBranch -and
        $propertyTable.allow_merge_commit -eq $DesiredSettings.allowMergeCommit -and
        $propertyTable.allow_rebase_merge -eq $DesiredSettings.allowRebaseMerge -and
        $propertyTable.allow_squash_merge -eq $DesiredSettings.allowSquashMerge -and
        $propertyTable.delete_branch_on_merge -eq $DesiredSettings.deleteBranchOnMerge -and
        $propertyTable.has_projects -eq $DesiredSettings.hasProjects
}

function Get-RepositoryRulesetState {
    param(
        [Parameter(Mandatory)][scriptblock]$Runner,
        [Parameter(Mandatory)][object]$DesiredRuleset,
        [Parameter(Mandatory)][object]$ExpectedPayload,
        [Parameter(Mandatory)][string]$DefaultBranch
    )

    $summaries = @(
        Invoke-GhPagedJson `
            -Runner $Runner `
            -Endpoint "repos/$expectedRepository/rulesets?includes_parents=true&per_page=100" `
            -Context 'Repository rulesets'
    )
    $ownedSummaries = @($summaries | Where-Object {
        [string]$_.source_type -ceq 'Repository' -and [string]$_.source -ceq $expectedRepository
    })
    $named = @($ownedSummaries | Where-Object { [string]$_.name -ceq [string]$DesiredRuleset.name })
    if ($named.Count -gt 1) {
        throw 'Repository contains ambiguous desired-name ruleset matches.'
    }

    $details = [ordered]@{}
    foreach ($summary in $summaries) {
        $id = [string]$summary.id
        $details[$id] = Invoke-GhJson `
            -Runner $Runner `
            -ArgumentList @('api', "repos/$expectedRepository/rulesets/$id") `
            -Context "Repository ruleset $id"
    }

    $existingId = $null
    $existingDetail = $null
    if ($named.Count -eq 1) {
        $existingId = [long]$named[0].id
        $existingDetail = $details[[string]$existingId]
    }

    foreach ($summary in $summaries) {
        if ([string]$summary.enforcement -cne 'active' -or
            ($null -ne $existingId -and [long]$summary.id -eq $existingId)) {
            continue
        }
        $detail = $details[[string]$summary.id]
        if (Test-RulesetAppliesToMain -Ruleset $detail -DefaultBranch $DefaultBranch) {
            throw 'Repository contains an additional active ruleset that applies to main.'
        }
    }

    [pscustomobject]@{
        ExistingRulesetId = $existingId
        ExistingRulesetDetail = $existingDetail
        ExistingRulesetExact = $null -ne $existingDetail -and
            (Test-RulesetReadBack -Ruleset $existingDetail -ExpectedPayload $ExpectedPayload)
        AllRulesetDetails = [pscustomobject]$details
    }
}

function Get-DependabotSecurityUpdatesState {
    param([Parameter(Mandatory)][scriptblock]$Runner)

    $result = Invoke-NativeCommandResult `
        -Runner $Runner `
        -FilePath 'gh' `
        -ArgumentList @('api', '--include', "repos/$expectedRepository/automated-security-fixes")
    $combined = "$($result.StdOut)`n$($result.StdErr)"
    $match = [regex]::Match($combined, '(?im)^HTTP/\S+\s+(?<status>\d{3})\b')
    if (-not $match.Success) {
        throw 'Dependabot security updates status returned no HTTP status.'
    }
    $status = [int]$match.Groups['status'].Value
    if ($status -eq 204 -and [int]$result.ExitCode -eq 0) {
        return $true
    }
    if ($status -eq 404) {
        return $false
    }
    throw "Dependabot security updates status returned HTTP $status."
}

function Assert-ClassicMainBranchProtectionAbsent {
    param([Parameter(Mandatory)][scriptblock]$Runner)

    $result = Invoke-NativeCommandResult `
        -Runner $Runner `
        -FilePath 'gh' `
        -ArgumentList @('api', '--include', "repos/$expectedRepository/branches/main/protection")
    $combined = "$($result.StdOut)`n$($result.StdErr)"
    $match = [regex]::Match($combined, '(?im)^HTTP/\S+\s+(?<status>\d{3})\b')
    if (-not $match.Success) {
        throw 'Classic main branch protection status returned no HTTP status.'
    }

    $status = [int]$match.Groups['status'].Value
    if ($status -eq 404) {
        return 'Absent'
    }
    if ($status -eq 200) {
        throw 'Classic main branch protection must be absent; remove it explicitly before lean governance activation.'
    }
    throw "Classic main branch protection status returned HTTP $status."
}

function Get-GovernanceState {
    param(
        [Parameter(Mandatory)][scriptblock]$Runner,
        [Parameter(Mandatory)][object]$DesiredState,
        [Parameter(Mandatory)][object]$ExpectedPayload
    )

    $classicMainBranchProtection = Assert-ClassicMainBranchProtectionAbsent -Runner $Runner
    $repositoryState = Invoke-GhJson `
        -Runner $Runner `
        -ArgumentList @('api', "repos/$expectedRepository") `
        -Context 'Repository settings'
    $defaultBranch = [string]$repositoryState.default_branch
    if ([string]::IsNullOrWhiteSpace($defaultBranch)) {
        throw 'Repository settings did not return a default branch.'
    }
    $rulesetState = Get-RepositoryRulesetState `
        -Runner $Runner `
        -DesiredRuleset $DesiredState.rulesets[0] `
        -ExpectedPayload $ExpectedPayload `
        -DefaultBranch $defaultBranch
    $dependabotEnabled = Get-DependabotSecurityUpdatesState -Runner $Runner

    [pscustomobject]@{
        ClassicMainBranchProtection = $classicMainBranchProtection
        RepositorySettings = $repositoryState
        RulesetState = $rulesetState
        DependabotSecurityUpdates = $dependabotEnabled
    }
}

function New-RepositorySettingsPayload {
    param([Parameter(Mandatory)][object]$DesiredSettings)

    [pscustomobject]([ordered]@{
        allow_merge_commit = [bool]$DesiredSettings.allowMergeCommit
        allow_rebase_merge = [bool]$DesiredSettings.allowRebaseMerge
        allow_squash_merge = [bool]$DesiredSettings.allowSquashMerge
        delete_branch_on_merge = [bool]$DesiredSettings.deleteBranchOnMerge
        has_projects = [bool]$DesiredSettings.hasProjects
    })
}

function Invoke-GhJsonMutation {
    param(
        [Parameter(Mandatory)][scriptblock]$Runner,
        [Parameter(Mandatory)][ValidateSet('POST', 'PUT', 'PATCH')][string]$Method,
        [Parameter(Mandatory)][string]$Endpoint,
        [Parameter(Mandatory)][object]$Body,
        [Parameter(Mandatory)][string]$Context
    )

    $bodyPath = Join-Path (Get-Location) ".github-governance-$([guid]::NewGuid()).json"
    try {
        [System.IO.File]::WriteAllText(
            $bodyPath,
            ($Body | ConvertTo-Json -Depth 30 -Compress),
            [System.Text.UTF8Encoding]::new($false)
        )
        $text = Invoke-NativeCommand `
            -Runner $Runner `
            -ArgumentList @('api', '--method', $Method, $Endpoint, '--input', $bodyPath)
        if ([string]::IsNullOrWhiteSpace($text)) {
            return $null
        }
        try {
            $text | ConvertFrom-Json
        }
        catch {
            throw "$Context returned malformed JSON."
        }
    }
    finally {
        Remove-Item -LiteralPath $bodyPath -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-GitHubGovernanceCore {
    param(
        [Parameter(Mandatory)][string]$Repository,
        [Parameter(Mandatory)][long]$ValidatorRunId,
        [Parameter(Mandatory)][string]$DesiredStatePath,
        [Parameter(Mandatory)][scriptblock]$NativeCommandRunner,
        [Parameter(Mandatory)][scriptblock]$ShouldProcess,
        [Parameter(Mandatory)][bool]$IsWhatIf
    )

    $expectedRepository = 'urruegg/caldova-hr-frontier'
    if ($Repository -cne $expectedRepository) {
        throw "Repository must be exactly '$expectedRepository'."
    }
    if ($ValidatorRunId -le 0) {
        throw 'ValidatorRunId must be a positive integer.'
    }

    $desiredStateDocument = Read-JsonFile `
        -Path $DesiredStatePath `
        -Context 'GitHub governance desired state'
    $desiredRuleset = Assert-DesiredState -DesiredState $desiredStateDocument.Value
    $desiredState = $desiredStateDocument.Value
    $payload = New-RulesetPayload -DesiredRuleset $desiredRuleset

    $mainRef = Invoke-GhJson `
        -Runner $NativeCommandRunner `
        -ArgumentList @('api', "repos/$expectedRepository/git/ref/heads/main") `
        -Context 'Current main ref'
    $currentMainSha = [string]$mainRef.object.sha
    if ($currentMainSha -cnotmatch '^[0-9a-fA-F]{40}$') {
        throw 'Current main ref did not return a valid commit SHA.'
    }

    $validatorRun = Invoke-GhJson `
        -Runner $NativeCommandRunner `
        -ArgumentList @('api', "repos/$expectedRepository/actions/runs/$ValidatorRunId") `
        -Context 'Validator workflow run'
    Assert-ValidatorRun -Run $validatorRun -CurrentMainSha $currentMainSha
    $validatorJobs = @(
        Invoke-GhPagedPropertyJson `
            -Runner $NativeCommandRunner `
            -Endpoint "repos/$expectedRepository/actions/runs/$ValidatorRunId/jobs?per_page=100" `
            -PropertyName 'jobs' `
            -Context 'Validator workflow jobs'
    )
    Assert-ValidatorJobs -Jobs $validatorJobs

    $codeowners = Invoke-NativeCommand `
        -Runner $NativeCommandRunner `
        -ArgumentList @(
            'api',
            '-H',
            'Accept: application/vnd.github.raw+json',
            "repos/$expectedRepository/contents/.github/CODEOWNERS?ref=$currentMainSha"
        )
    Assert-CodeownersMap -Content $codeowners

    $preState = Get-GovernanceState `
        -Runner $NativeCommandRunner `
        -DesiredState $desiredState `
        -ExpectedPayload $payload
    if ([string]$preState.RepositorySettings.default_branch -cne
        [string]$desiredState.repositorySettings.defaultBranch) {
        throw 'Repository default branch does not match desired state.'
    }

    $repositorySettingsExact = Test-RepositorySettings `
        -RepositoryState $preState.RepositorySettings `
        -DesiredSettings $desiredState.repositorySettings
    $repositoryAction = if ($repositorySettingsExact) { 'None' } else { 'Update' }
    $rulesetAction = if ($null -eq $preState.RulesetState.ExistingRulesetId) {
        'Create'
    }
    elseif (-not $preState.RulesetState.ExistingRulesetExact) {
        'Update'
    }
    else {
        'None'
    }
    $rulesetMethod = if ($rulesetAction -ceq 'Create') {
        'POST'
    }
    elseif ($rulesetAction -ceq 'Update') {
        'PUT'
    }
    else {
        $null
    }
    $rulesetEndpoint = if ($rulesetAction -ceq 'Update') {
        "repos/$expectedRepository/rulesets/$($preState.RulesetState.ExistingRulesetId)"
    }
    else {
        "repos/$expectedRepository/rulesets"
    }
    $dependabotAction = if ($preState.DependabotSecurityUpdates) { 'None' } else { 'Enable' }
    $hasMutation = @($repositoryAction, $rulesetAction, $dependabotAction) -ccontains 'Update' -or
        @($repositoryAction, $rulesetAction, $dependabotAction) -ccontains 'Create' -or
        @($repositoryAction, $rulesetAction, $dependabotAction) -ccontains 'Enable'

    $proposal = [pscustomobject]([ordered]@{
        Repository = $expectedRepository
        ValidatorRunId = $ValidatorRunId
        DesiredStatePath = $desiredStateDocument.Path
        CurrentMainSha = $currentMainSha
        RepositorySettingsAction = $repositoryAction
        RulesetAction = $rulesetAction
        RulesetMethod = $rulesetMethod
        RulesetEndpoint = $rulesetEndpoint
        DependabotSecurityUpdatesAction = $dependabotAction
        RulesetPayload = $payload
        PreviousState = [pscustomobject]([ordered]@{
            ClassicMainBranchProtection = $preState.ClassicMainBranchProtection
            RepositorySettings = $preState.RepositorySettings
            Ruleset = $preState.RulesetState.ExistingRulesetDetail
            AllRulesets = $preState.RulesetState.AllRulesetDetails
            DependabotSecurityUpdates = $preState.DependabotSecurityUpdates
        })
        DesiredState = $desiredState
        Status = if ($hasMutation) { 'Proposed' } else { 'Verified' }
    })

    if ($IsWhatIf -or -not $hasMutation) {
        return $proposal
    }
    if (-not (& $ShouldProcess `
        -Target "$expectedRepository lean governance" `
        -Action 'Apply repository settings, ruleset, and Dependabot security updates')) {
        throw 'GitHub governance mutation was declined.'
    }

    $approvalMainRef = Invoke-GhJson `
        -Runner $NativeCommandRunner `
        -ArgumentList @('api', "repos/$expectedRepository/git/ref/heads/main") `
        -Context 'Pre-mutation current main ref'
    $approvalMainSha = [string]$approvalMainRef.object.sha
    if ($approvalMainSha -cne $currentMainSha) {
        throw 'The current main commit changed before mutation.'
    }
    $approvalRun = Invoke-GhJson `
        -Runner $NativeCommandRunner `
        -ArgumentList @('api', "repos/$expectedRepository/actions/runs/$ValidatorRunId") `
        -Context 'Pre-mutation validator workflow run'
    Assert-ValidatorRun -Run $approvalRun -CurrentMainSha $approvalMainSha

    if ($repositoryAction -ceq 'Update') {
        $repositoryPayload = New-RepositorySettingsPayload `
            -DesiredSettings $desiredState.repositorySettings
        $null = Invoke-GhJsonMutation `
            -Runner $NativeCommandRunner `
            -Method 'PATCH' `
            -Endpoint "repos/$expectedRepository" `
            -Body $repositoryPayload `
            -Context 'Repository settings mutation'
    }

    if ($rulesetAction -ne 'None') {
        $rulesetResult = Invoke-GhJsonMutation `
            -Runner $NativeCommandRunner `
            -Method $rulesetMethod `
            -Endpoint $rulesetEndpoint `
            -Body $payload `
            -Context 'Ruleset mutation'
        if ($rulesetAction -ceq 'Create' -and
            ($null -eq $rulesetResult -or [long]$rulesetResult.id -le 0)) {
            throw 'Ruleset creation did not return a stable ruleset id.'
        }
    }

    if ($dependabotAction -ceq 'Enable') {
        $null = Invoke-NativeCommand `
            -Runner $NativeCommandRunner `
            -ArgumentList @(
                'api',
                '--method',
                'PUT',
                "repos/$expectedRepository/automated-security-fixes"
            )
    }

    $readBack = Get-GovernanceState `
        -Runner $NativeCommandRunner `
        -DesiredState $desiredState `
        -ExpectedPayload $payload
    if (-not (Test-RepositorySettings `
        -RepositoryState $readBack.RepositorySettings `
        -DesiredSettings $desiredState.repositorySettings)) {
        throw 'Repository settings read-back does not match desired state.'
    }
    if ($null -eq $readBack.RulesetState.ExistingRulesetId -or
        -not $readBack.RulesetState.ExistingRulesetExact) {
        throw 'Ruleset read-back does not match desired state.'
    }
    if (-not $readBack.DependabotSecurityUpdates) {
        throw 'Dependabot security updates read-back does not match desired state.'
    }

    $proposal.Status = 'Verified'
    $proposal
}

$nativeCommandRunner = New-DefaultNativeCommandRunner
$invocationCmdlet = $PSCmdlet
$shouldProcess = {
    param(
        [Parameter(Mandatory)][string]$Target,
        [Parameter(Mandatory)][string]$Action
    )
    $invocationCmdlet.ShouldProcess($Target, $Action)
}.GetNewClosure()

Invoke-GitHubGovernanceCore `
    -Repository $Repository `
    -ValidatorRunId $ValidatorRunId `
    -DesiredStatePath $DesiredStatePath `
    -NativeCommandRunner $nativeCommandRunner `
    -ShouldProcess $shouldProcess `
    -IsWhatIf ([bool]$WhatIfPreference)
