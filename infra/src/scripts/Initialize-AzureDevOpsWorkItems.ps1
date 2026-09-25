[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9]+$')]
    [string]$TenantAlias,

    [string]$IdeasRoot,

    [string]$RepositoryRootOverride,

    [string]$PlanOutputPath,

    [switch]$ReturnPortfolioOnly,

    [switch]$ReturnProcessCapabilitiesOnly,

    [switch]$ReturnWorkItemPlanOnly,

    [Parameter(DontShow)]
    [scriptblock]$AzRequest,

    [Parameter(DontShow)]
    [scriptblock]$AzureDevOpsRequest,

    [Parameter(DontShow)]
    [scriptblock]$NativeCommandRunner
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RepositoryRoot {
    [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
}

function Get-DefaultIdeasRoot {
    Join-Path (Get-RepositoryRoot) 'hr\docs\ideas'
}

function ConvertTo-RepoRelativeForwardSlashPath {
    param(
        [Parameter(Mandatory)]
        [string]$FullPath,

        [Parameter(Mandatory)]
        [string]$RepositoryRoot
    )

    $normalizedRoot = [System.IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\', '/')
    $normalizedFull = [System.IO.Path]::GetFullPath($FullPath)
    if (-not $normalizedFull.StartsWith($normalizedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path '$FullPath' is not under repository root '$RepositoryRoot'."
    }

    $relative = $normalizedFull.Substring($normalizedRoot.Length).TrimStart('\', '/')
    $relative -replace '\\', '/'
}

function Get-HrIdeaPortfolioItems {
    param(
        [Parameter(Mandatory)]
        [string]$IdeasRoot,

        [string]$RepositoryRoot
    )

    $resolvedRepositoryRoot = if ([string]::IsNullOrWhiteSpace($RepositoryRoot)) { Get-RepositoryRoot } else { $RepositoryRoot }
    $files = @(Get-ChildItem -LiteralPath $IdeasRoot -Filter '*.md' -Recurse -File |
        Where-Object { $_.Name -cmatch '^uc-\d{4}-' } |
        Sort-Object FullName)

    if ($files.Count -eq 0) {
        throw "No idea files matching 'uc-NNNN-*.md' were found under '$IdeasRoot'."
    }

    $items = [System.Collections.Generic.List[object]]::new()
    foreach ($file in $files) {
        $content = [System.IO.File]::ReadAllText($file.FullName)
        $lines = $content -split "`r?`n"

        $headingLine = $lines | Where-Object { $_ -cmatch '^#\s+(UC-\d{4})\s*[-\u2013\u2014]\s*(.+)$' } | Select-Object -First 1
        if (-not $headingLine) {
            throw "Idea file '$($file.FullName)' has no H1 line matching '# UC-NNNN - Title'."
        }
        $null = $headingLine -cmatch '^#\s+(UC-\d{4})\s*[-\u2013\u2014]\s*(.+)$'
        $useCaseId = $Matches[1]
        $title = $Matches[2].Trim()

        $statusLine = $lines | Where-Object { $_ -cmatch '^>\s*\*\*Status:\*\*\s*(.+)$' } | Select-Object -First 1
        if (-not $statusLine) {
            throw "Idea file '$($file.FullName)' ($useCaseId) has no '> **Status:** ...' blockquote line."
        }
        $null = $statusLine -cmatch '^>\s*\*\*Status:\*\*\s*(.+)$'
        $statusText = $Matches[1].Trim()

        $status =
            if ($statusText -match 'Selected as MVP') { 'MVP' }
            elseif ($statusText -match 'IN MVP SCOPE') { 'MVP-Candidate' }
            elseif ($statusText -match 'Runs alongside the MVP') { 'MVP-Adjacent' }
            else { 'Candidate' }

        $stageLine = $lines | Where-Object { $_ -cmatch '^>\s*\*\*Journey stage:\*\*\s*(.+)$' } | Select-Object -First 1
        if (-not $stageLine) {
            throw "Idea file '$($file.FullName)' ($useCaseId) has no '> **Journey stage:** ...' blockquote line."
        }
        $null = $stageLine -cmatch '^>\s*\*\*Journey stage:\*\*\s*(.+)$'
        $journeyStage = ($Matches[1].Trim()) -replace '\s+[-\u2013\u2014]\s+', ' - '

        $ideaHeadingIndex = 0..($lines.Count - 1) | Where-Object { $lines[$_] -cmatch '^##\s+1\.\s+The Idea\s*$' } | Select-Object -First 1
        if ($null -eq $ideaHeadingIndex) {
            throw "Idea file '$($file.FullName)' ($useCaseId) has no '## 1. The Idea' heading."
        }
        $summary = $null
        for ($i = [int]$ideaHeadingIndex + 1; $i -lt $lines.Count; $i++) {
            if (-not [string]::IsNullOrWhiteSpace($lines[$i])) {
                $summary = $lines[$i].Trim()
                break
            }
        }
        if ($null -eq $summary) {
            throw "Idea file '$($file.FullName)' ($useCaseId) has no summary paragraph after '## 1. The Idea'."
        }

        $items.Add([pscustomobject]@{
            UseCaseId = $useCaseId
            Title = $title
            Status = $status
            JourneyStage = $journeyStage
            SourcePath = ConvertTo-RepoRelativeForwardSlashPath -FullPath $file.FullName -RepositoryRoot $resolvedRepositoryRoot
            Summary = $summary
        }) | Out-Null
    }

    @($items | Sort-Object UseCaseId)
}

function Get-ResponseBodyOrNull {
    param(
        [Parameter(Mandatory)]
        [object]$Response
    )

    $responseTable = ConvertTo-Hashtable -InputObject $Response
    if ($responseTable.ContainsKey('Body')) { $responseTable['Body'] } else { $null }
}

function ConvertTo-Hashtable {
    param(
        [AllowNull()]
        [object]$InputObject
    )

    if ($null -eq $InputObject) {
        return @{}
    }

    if ($InputObject -is [hashtable]) {
        return $InputObject
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        $table = @{}
        foreach ($key in $InputObject.Keys) {
            $table[[string]$key] = $InputObject[$key]
        }

        return $table
    }

    $table = @{}
    foreach ($property in $InputObject.PSObject.Properties) {
        if ($property.MemberType -in @('NoteProperty', 'Property', 'ScriptProperty')) {
            $table[$property.Name] = $property.Value
        }
    }

    $table
}

function ConvertTo-AzureDevOpsWorkItemTypeItems {
    param(
        [AllowNull()]
        [object]$Node
    )

    if ($null -eq $Node) {
        return @()
    }

    $entries = ConvertTo-Hashtable -InputObject $Node
    if ($entries.ContainsKey('value')) {
        return @($entries['value'])
    }

    @($Node)
}

function Invoke-NativeCommand {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Runner,

        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string[]]$ArgumentList
    )

    $result = & $Runner -FilePath $FilePath -ArgumentList $ArgumentList
    $resultTable = ConvertTo-Hashtable -InputObject $result
    if (-not $resultTable.ContainsKey('ExitCode')) {
        throw "Native command '$FilePath' did not return ExitCode."
    }

    [pscustomobject]@{
        ExitCode = [int]$resultTable.ExitCode
        StdOut = if ($resultTable.ContainsKey('StdOut')) { [string]$resultTable.StdOut } else { '' }
        StdErr = if ($resultTable.ContainsKey('StdErr')) { [string]$resultTable.StdErr } else { '' }
    }
}

function Invoke-NativeJsonCommand {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Runner,

        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string[]]$ArgumentList
    )

    $commandResult = Invoke-NativeCommand -Runner $Runner -FilePath $FilePath -ArgumentList $ArgumentList
    if ($commandResult.ExitCode -ne 0) {
        throw "$FilePath $($ArgumentList -join ' ') failed with exit code $($commandResult.ExitCode): $($commandResult.StdErr)"
    }

    [pscustomobject]@{
        StatusCode = 200
        Headers = @{}
        Body = if ([string]::IsNullOrWhiteSpace($commandResult.StdOut)) { $null } else { $commandResult.StdOut | ConvertFrom-Json }
    }
}

function New-DefaultNativeCommandRunner {
    {
        param(
            [Parameter(Mandatory)]
            [string]$FilePath,

            [Parameter(Mandatory)]
            [string[]]$ArgumentList
        )

        $merged = & $FilePath @ArgumentList 2>&1
        [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            StdOut = ($merged | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
            StdErr = ''
        }
    }
}

function New-DefaultAzureDevOpsRequest {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$NativeRunner
    )

    {
        param($Operation, $Arguments)

        switch ($Operation) {
            'ListWorkItemTypes' {
                return (Invoke-NativeJsonCommand -Runner $NativeRunner -FilePath 'az' -ArgumentList @(
                    'devops', 'invoke',
                    '--organization', [string]$Arguments['OrganizationUrl'],
                    '--area', 'wit',
                    '--resource', 'workitemtypes',
                    '--route-parameters', "project=$([string]$Arguments['ProjectName'])",
                    '--api-version', '7.1',
                    '--output', 'json'
                ))
            }
            'QueryWorkItemsByTag' {
                $wiqlQuery = "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = '$([string]$Arguments['ProjectName'])' AND [System.WorkItemType] = 'Epic' AND [System.Tags] CONTAINS '$([string]$Arguments['Tag'])'"
                $wiqlBody = @{ query = $wiqlQuery } | ConvertTo-Json -Compress
                $tempFile = [System.IO.Path]::GetTempFileName()
                try {
                    [System.IO.File]::WriteAllText($tempFile, $wiqlBody)
                    return (Invoke-NativeJsonCommand -Runner $NativeRunner -FilePath 'az' -ArgumentList @(
                        'devops', 'invoke',
                        '--organization', [string]$Arguments['OrganizationUrl'],
                        '--area', 'wit',
                        '--resource', 'wiql',
                        '--route-parameters', "project=$([string]$Arguments['ProjectName'])",
                        '--http-method', 'POST',
                        '--in-file', $tempFile,
                        '--api-version', '7.1',
                        '--output', 'json'
                    ))
                }
                finally {
                    Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
                }
            }
            'CreateWorkItem' {
                $patchBody = @(
                    @{ op = 'add'; path = '/fields/System.Title'; value = [string]$Arguments['Title'] }
                    @{ op = 'add'; path = '/fields/System.Description'; value = [string]$Arguments['Description'] }
                    @{ op = 'add'; path = '/fields/System.Tags'; value = [string]$Arguments['Tags'] }
                ) | ConvertTo-Json -Compress
                $tempFile = [System.IO.Path]::GetTempFileName()
                try {
                    [System.IO.File]::WriteAllText($tempFile, $patchBody)
                    return (Invoke-NativeJsonCommand -Runner $NativeRunner -FilePath 'az' -ArgumentList @(
                        'devops', 'invoke',
                        '--organization', [string]$Arguments['OrganizationUrl'],
                        '--area', 'wit',
                        '--resource', 'workitems',
                        '--route-parameters', "project=$([string]$Arguments['ProjectName'])", "type=$([string]$Arguments['WorkItemType'])",
                        '--http-method', 'POST',
                        '--in-file', $tempFile,
                        '--api-version', '7.1',
                        '--output', 'json'
                    ))
                }
                finally {
                    Remove-Item -LiteralPath $tempFile -Force -ErrorAction SilentlyContinue
                }
            }
            'AddHyperlinkRelation' {
                return (Invoke-NativeJsonCommand -Runner $NativeRunner -FilePath 'az' -ArgumentList @(
                    'boards', 'work-item', 'relation', 'add',
                    '--id', [string]$Arguments['WorkItemId'],
                    '--relation-type', 'Hyperlink',
                    '--target-url', [string]$Arguments['Url'],
                    '--organization', [string]$Arguments['OrganizationUrl'],
                    '--output', 'json'
                ))
            }
            'ShowWorkItem' {
                return (Invoke-NativeJsonCommand -Runner $NativeRunner -FilePath 'az' -ArgumentList @(
                    'boards', 'work-item', 'show',
                    '--id', [string]$Arguments['WorkItemId'],
                    '--expand', 'all',
                    '--organization', [string]$Arguments['OrganizationUrl'],
                    '--output', 'json'
                ))
            }
            default {
                throw "Unsupported AzureDevOps operation '$Operation'."
            }
        }
    }.GetNewClosure()
}

function Get-AzureDevOpsProcessCapabilities {
    param(
        [Parameter(Mandatory)]
        [string]$OrganizationUrl,

        [Parameter(Mandatory)]
        [string]$ProjectName,

        [Parameter(Mandatory)]
        [scriptblock]$Request
    )

    $response = & $Request 'ListWorkItemTypes' @{ OrganizationUrl = $OrganizationUrl; ProjectName = $ProjectName }
    $body = Get-ResponseBodyOrNull -Response $response
    $types = @(ConvertTo-AzureDevOpsWorkItemTypeItems -Node $body)
    $typeNames = @($types | ForEach-Object { [string](ConvertTo-Hashtable -InputObject $_)['name'] })

    if ($typeNames -notcontains 'Epic') {
        throw "Azure DevOps project '$ProjectName' has no 'Epic' work item type. Observed types: $($typeNames -join ', ')."
    }

    [pscustomobject]@{ EpicWorkItemTypeName = 'Epic' }
}

function Get-AzureDevOpsWorkItemPlan {
    param(
        [Parameter(Mandatory)]
        [string]$OrganizationUrl,

        [Parameter(Mandatory)]
        [string]$ProjectName,

        [Parameter(Mandatory)]
        [object[]]$PortfolioItems,

        [Parameter(Mandatory)]
        [scriptblock]$Request
    )

    $plan = [System.Collections.Generic.List[object]]::new()
    foreach ($item in $PortfolioItems) {
        $response = & $Request 'QueryWorkItemsByTag' @{ OrganizationUrl = $OrganizationUrl; ProjectName = $ProjectName; Tag = $item.UseCaseId }
        $body = Get-ResponseBodyOrNull -Response $response
        $bodyTable = ConvertTo-Hashtable -InputObject $body
        $workItems = if ($bodyTable.ContainsKey('workItems')) { @($bodyTable['workItems']) } else { @() }

        $ids = @($workItems | ForEach-Object { [int](ConvertTo-Hashtable -InputObject $_)['id'] })
        if ($ids.Count -gt 1) {
            throw "Ambiguous existing work items tagged '$($item.UseCaseId)': ids $($ids -join ', ')."
        }

        $existingId = if ($ids.Count -eq 1) { $ids[0] } else { 0 }
        $mode = if ($existingId -gt 0) { 'Existing' } else { 'Create' }

        $plan.Add([pscustomobject]@{
            UseCaseId = $item.UseCaseId
            Title = $item.Title
            Status = $item.Status
            JourneyStage = $item.JourneyStage
            SourcePath = $item.SourcePath
            Summary = $item.Summary
            ExistingWorkItemId = $existingId
            Mode = $mode
            HyperlinkUrl = "https://github.com/urruegg/caldova-hr-frontier/blob/main/$($item.SourcePath)"
        }) | Out-Null
    }

    @($plan)
}

$nativeCommandRunner = if ($NativeCommandRunner) { $NativeCommandRunner } else { New-DefaultNativeCommandRunner }
$azureDevOpsRequest = if ($AzureDevOpsRequest) { $AzureDevOpsRequest } else { New-DefaultAzureDevOpsRequest -NativeRunner $nativeCommandRunner }

$resolvedIdeasRoot = if ([string]::IsNullOrWhiteSpace($IdeasRoot)) { Get-DefaultIdeasRoot } else { $IdeasRoot }
$portfolio = Get-HrIdeaPortfolioItems -IdeasRoot $resolvedIdeasRoot -RepositoryRoot $RepositoryRootOverride

if ($ReturnPortfolioOnly) {
    Write-Output -NoEnumerate $portfolio
    return
}

$organizationUrl = "https://dev.azure.com/$TenantAlias/"
$projectName = 'Caldova HR Frontier'

$capabilities = Get-AzureDevOpsProcessCapabilities -OrganizationUrl $organizationUrl -ProjectName $projectName -Request $azureDevOpsRequest

if ($ReturnProcessCapabilitiesOnly) {
    Write-Output -NoEnumerate $capabilities
    return
}

if ($ReturnWorkItemPlanOnly) {
    $workItemPlan = Get-AzureDevOpsWorkItemPlan -OrganizationUrl $organizationUrl -ProjectName $projectName -PortfolioItems $portfolio -Request $azureDevOpsRequest
    Write-Output -NoEnumerate $workItemPlan
    return
}

function Assert-WorkItemReadBack {
    param(
        [Parameter(Mandatory)]
        [object]$ReadBack,

        [Parameter(Mandatory)]
        [string]$ExpectedTitle,

        [Parameter(Mandatory)]
        [string]$ExpectedDescription,

        [Parameter(Mandatory)]
        [string]$ExpectedTags,

        [Parameter(Mandatory)]
        [string]$ExpectedHyperlinkUrl
    )

    $readBackTable = ConvertTo-Hashtable -InputObject $ReadBack
    $fields = ConvertTo-Hashtable -InputObject $readBackTable['fields']
    if ([string]$fields['System.Title'] -cne $ExpectedTitle) {
        throw "Work item read-back Title mismatch: expected '$ExpectedTitle', observed '$([string]$fields['System.Title'])'."
    }
    if ([string]$fields['System.Description'] -cne $ExpectedDescription) {
        throw "Work item read-back Description mismatch: expected '$ExpectedDescription', observed '$([string]$fields['System.Description'])'."
    }
    if ([string]$fields['System.Tags'] -cne $ExpectedTags) {
        throw "Work item read-back Tags mismatch: expected '$ExpectedTags', observed '$([string]$fields['System.Tags'])'."
    }

    $relations = if ($readBackTable.ContainsKey('relations')) { @($readBackTable['relations']) } else { @() }
    $hyperlinkMatch = @($relations | Where-Object {
        $relationTable = ConvertTo-Hashtable -InputObject $_
        [string]$relationTable['rel'] -ceq 'Hyperlink' -and [string]$relationTable['url'] -ceq $ExpectedHyperlinkUrl
    })
    if ($hyperlinkMatch.Count -eq 0) {
        throw "Work item read-back is missing the expected Hyperlink relation to '$ExpectedHyperlinkUrl'."
    }
}

$workItemPlan = Get-AzureDevOpsWorkItemPlan -OrganizationUrl $organizationUrl -ProjectName $projectName -PortfolioItems $portfolio -Request $azureDevOpsRequest

if ($PlanOutputPath) {
    $resolvedPlanOutputPath = [System.IO.Path]::GetFullPath($PlanOutputPath)
    $allowedRoots = @([System.IO.Path]::GetTempPath())
    if (-not [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
        $allowedRoots += [System.IO.Path]::GetFullPath($env:RUNNER_TEMP)
    }
    $isAllowed = $false
    foreach ($root in $allowedRoots) {
        $normalizedRoot = [System.IO.Path]::GetFullPath($root).TrimEnd('\') + '\'
        if ($resolvedPlanOutputPath.StartsWith($normalizedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            $isAllowed = $true
            break
        }
    }
    if (-not $isAllowed) {
        throw 'PlanOutputPath must resolve under the system temporary directory or RUNNER_TEMP.'
    }

    $json = $workItemPlan | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($resolvedPlanOutputPath, $json, (New-Object System.Text.UTF8Encoding $false))
}

if ($WhatIfPreference) {
    Write-Output -NoEnumerate $workItemPlan
    return
}

foreach ($planItem in $workItemPlan) {
    if ($planItem.Mode -cne 'Create') {
        continue
    }

    $target = "$($planItem.UseCaseId) ($($planItem.Title))"
    if (-not $PSCmdlet.ShouldProcess($target, 'CreateAzureBoardsEpic')) {
        throw "Azure Boards Epic creation for '$target' was declined."
    }

    $tags = "$($planItem.UseCaseId); $($planItem.Status); $($planItem.JourneyStage)"
    Write-Verbose "Creating work item for '$($planItem.Title)'"
    $createResponse = & $azureDevOpsRequest 'CreateWorkItem' @{ 
        OrganizationUrl = $organizationUrl
        ProjectName = $projectName
        WorkItemType = 'Epic'
        Title = $planItem.Title
        Description = $planItem.Summary
        Tags = $tags
    }
    $createdBody = Get-ResponseBodyOrNull -Response $createResponse
    $createdId = [int](ConvertTo-Hashtable -InputObject $createdBody)['id']
    if ($createdId -le 0) {
        throw "Azure Boards Epic creation for '$target' did not return a valid work item id."
    }

    $null = & $azureDevOpsRequest 'AddHyperlinkRelation' @{ OrganizationUrl = $organizationUrl; WorkItemId = $createdId; Url = $planItem.HyperlinkUrl }

    $readBackResponse = & $azureDevOpsRequest 'ShowWorkItem' @{ OrganizationUrl = $organizationUrl; WorkItemId = $createdId }
    $readBackBody = Get-ResponseBodyOrNull -Response $readBackResponse
    Assert-WorkItemReadBack -ReadBack $readBackBody -ExpectedTitle $planItem.Title -ExpectedDescription $planItem.Summary -ExpectedTags $tags -ExpectedHyperlinkUrl $planItem.HyperlinkUrl
}
