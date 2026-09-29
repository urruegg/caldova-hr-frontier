[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)][ValidatePattern('^https://')][string]$OrganizationUrl,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ProjectName,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$TeamName,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$CurrentSprintPath,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$IssueTitle,
    [Parameter(Mandatory)][string]$PlanOutputPath,
    [datetime]$SprintStartDate,
    [datetime]$SprintFinishDate,
    [switch]$Apply,
    [Parameter(DontShow)][scriptblock]$AzureDevOpsRequest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$TraceabilityTag = 'tenant1-lean-platform-traceability'

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

function ConvertTo-UtcIsoString {
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return $null
    }

    ([datetime]$Value).ToUniversalTime().ToString('o')
}

function Assert-OutputPathOutsideRepository {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    $repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..')).TrimEnd('\', '/')
    $repositoryPrefix = $repositoryRoot + [System.IO.Path]::DirectorySeparatorChar
    if ($resolvedPath.Equals($repositoryRoot, [System.StringComparison]::OrdinalIgnoreCase) -or
        $resolvedPath.StartsWith($repositoryPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'PlanOutputPath and Azure DevOps request bodies must be stored outside the repository.'
    }

    $parent = [System.IO.Path]::GetDirectoryName($resolvedPath)
    if ([string]::IsNullOrWhiteSpace($parent)) {
        throw 'PlanOutputPath must include a parent directory.'
    }
    if (-not [System.IO.Directory]::Exists($parent)) {
        [void][System.IO.Directory]::CreateDirectory($parent)
    }

    $resolvedPath
}

function Write-Utf8JsonFile {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Json
    )

    [System.IO.File]::WriteAllText(
        $Path,
        $Json,
        (New-Object System.Text.UTF8Encoding $false)
    )
}

function Invoke-AzJsonCommand {
    param(
        [Parameter(Mandatory)]
        [string[]]$ArgumentList
    )

    $output = @(& az @ArgumentList 2>&1)
    $exitCode = $LASTEXITCODE
    $text = ($output | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    if ($exitCode -ne 0) {
        throw "az $($ArgumentList -join ' ') failed with exit code ${exitCode}: $text"
    }
    if ([string]::IsNullOrWhiteSpace($text)) {
        throw "az $($ArgumentList -join ' ') returned an empty JSON body."
    }

    try {
        $text | ConvertFrom-Json
    }
    catch {
        throw "az $($ArgumentList -join ' ') returned malformed JSON: $($_.Exception.Message)"
    }
}

function New-DefaultAzureDevOpsRequest {
    param(
        [Parameter(Mandatory)]
        [string]$RequestBodyDirectory
    )

    $invokeAzJsonCommandRef = ${function:Invoke-AzJsonCommand}
    $writeUtf8JsonFileRef = ${function:Write-Utf8JsonFile}
    $convertToHashtableRef = ${function:ConvertTo-Hashtable}

    {
        param($Operation, $Arguments)

        $organizationUrl = [string]$Arguments['OrganizationUrl']
        $projectName = [string]$Arguments['ProjectName']
        switch ($Operation) {
            'GetProjectWithCapabilities' {
                return (& $invokeAzJsonCommandRef -ArgumentList @(
                    'devops', 'project', 'show',
                    '--organization', $organizationUrl,
                    '--project', $projectName,
                    '--output', 'json'
                ))
            }
            'GetTeam' {
                return (& $invokeAzJsonCommandRef -ArgumentList @(
                    'devops', 'invoke',
                    '--organization', $organizationUrl,
                    '--area', 'core',
                    '--resource', 'teams',
                    '--route-parameters', "projectId=$projectName", "teamId=$([string]$Arguments['TeamName'])",
                    '--api-version', '7.1',
                    '--output', 'json'
                ))
            }
            'GetProjectRootArea' {
                return (& $invokeAzJsonCommandRef -ArgumentList @(
                    'devops', 'invoke',
                    '--organization', $organizationUrl,
                    '--area', 'wit',
                    '--resource', 'classificationnodes',
                    '--route-parameters', "project=$projectName", 'structureGroup=areas',
                    '--api-version', '7.1',
                    '--output', 'json'
                ))
            }
            'GetIteration' {
                return (& $invokeAzJsonCommandRef -ArgumentList @(
                    'devops', 'invoke',
                    '--organization', $organizationUrl,
                    '--area', 'wit',
                    '--resource', 'classificationnodes',
                    '--route-parameters', "project=$projectName", 'structureGroup=iterations', "path=$([string]$Arguments['IterationPath'])",
                    '--api-version', '7.1',
                    '--output', 'json'
                ))
            }
            'UpdateIterationDates' {
                $bodyPath = Join-Path $RequestBodyDirectory 'iteration-dates-patch.json'
                $body = @{
                    attributes = @{
                        startDate = ([datetime]$Arguments['StartDate']).ToUniversalTime().ToString('o')
                        finishDate = ([datetime]$Arguments['FinishDate']).ToUniversalTime().ToString('o')
                    }
                } | ConvertTo-Json -Depth 5 -Compress
                & $writeUtf8JsonFileRef -Path $bodyPath -Json $body

                return (& $invokeAzJsonCommandRef -ArgumentList @(
                    'devops', 'invoke',
                    '--organization', $organizationUrl,
                    '--area', 'wit',
                    '--resource', 'classificationnodes',
                    '--route-parameters', "project=$projectName", 'structureGroup=iterations', "path=$([string]$Arguments['IterationPath'])",
                    '--http-method', 'PATCH',
                    '--in-file', $bodyPath,
                    '--api-version', '7.1',
                    '--output', 'json'
                ))
            }
            'QueryTraceabilityIssue' {
                $wiqlPath = Join-Path $RequestBodyDirectory 'traceability-issue-query.json'
                $escapedProjectName = $projectName.Replace("'", "''")
                $wiql = @{
                    query = "SELECT [System.Id] FROM WorkItems WHERE [System.TeamProject] = '$escapedProjectName' AND [System.WorkItemType] = 'Issue' AND [System.Tags] CONTAINS 'tenant1-lean-platform-traceability'"
                } | ConvertTo-Json -Compress
                & $writeUtf8JsonFileRef -Path $wiqlPath -Json $wiql

                return (& $invokeAzJsonCommandRef -ArgumentList @(
                    'devops', 'invoke',
                    '--organization', $organizationUrl,
                    '--area', 'wit',
                    '--resource', 'wiql',
                    '--route-parameters', "project=$projectName",
                    '--http-method', 'POST',
                    '--in-file', $wiqlPath,
                    '--api-version', '7.1',
                    '--output', 'json'
                ))
            }
            'CreateTraceabilityIssue' {
                $fields = & $convertToHashtableRef -InputObject $Arguments['Fields']
                $bodyPath = Join-Path $RequestBodyDirectory 'traceability-issue-create.json'
                $patch = @(
                    @{ op = 'add'; path = '/fields/System.Title'; value = [string]$fields['System.Title'] }
                    @{ op = 'add'; path = '/fields/System.AreaPath'; value = [string]$fields['System.AreaPath'] }
                    @{ op = 'add'; path = '/fields/System.IterationPath'; value = [string]$fields['System.IterationPath'] }
                    @{ op = 'add'; path = '/fields/System.Tags'; value = [string]$fields['System.Tags'] }
                ) | ConvertTo-Json -Depth 5 -Compress
                & $writeUtf8JsonFileRef -Path $bodyPath -Json $patch

                return (& $invokeAzJsonCommandRef -ArgumentList @(
                    'devops', 'invoke',
                    '--organization', $organizationUrl,
                    '--area', 'wit',
                    '--resource', 'workitems',
                    '--route-parameters', "project=$projectName", 'type=Issue',
                    '--http-method', 'POST',
                    '--in-file', $bodyPath,
                    '--api-version', '7.1',
                    '--output', 'json'
                ))
            }
            'GetWorkItem' {
                return (& $invokeAzJsonCommandRef -ArgumentList @(
                    'devops', 'invoke',
                    '--organization', $organizationUrl,
                    '--area', 'wit',
                    '--resource', 'workitems',
                    '--route-parameters', "project=$projectName", "id=$([int]$Arguments['WorkItemId'])",
                    '--api-version', '7.1',
                    '--output', 'json'
                ))
            }
            default {
                throw "Unsupported AzureDevOps operation '$Operation'."
            }
        }
    }.GetNewClosure()
}

function Assert-WorkItemReadBack {
    param(
        [Parameter(Mandatory)]
        [object]$WorkItem,

        [Parameter(Mandatory)]
        [int]$ExpectedId,

        [Parameter(Mandatory)]
        [hashtable]$ExpectedFields
    )

    $workItemTable = ConvertTo-Hashtable -InputObject $WorkItem
    $observedId = if ($workItemTable.ContainsKey('id')) { [int]$workItemTable['id'] } else { 0 }
    if ($observedId -le 0 -or $observedId -ne $ExpectedId) {
        throw "Issue read-back ID mismatch: expected '$ExpectedId', observed '$observedId'."
    }

    $fields = if ($workItemTable.ContainsKey('fields')) {
        ConvertTo-Hashtable -InputObject $workItemTable['fields']
    }
    else {
        @{}
    }

    foreach ($fieldName in @(
        'System.WorkItemType',
        'System.Title',
        'System.AreaPath',
        'System.IterationPath'
    )) {
        if ([string]$fields[$fieldName] -cne [string]$ExpectedFields[$fieldName]) {
            $label = $fieldName.Substring('System.'.Length)
            throw "Issue read-back $label mismatch: expected '$([string]$ExpectedFields[$fieldName])', observed '$([string]$fields[$fieldName])'."
        }
    }

    $tags = @([string]$fields['System.Tags'] -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
    if ($tags -cnotcontains [string]$ExpectedFields['System.Tags']) {
        throw "Issue read-back Tags mismatch: expected '$([string]$ExpectedFields['System.Tags'])', observed '$([string]$fields['System.Tags'])'."
    }
}

function Invoke-AzureDevOpsRequest {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$Request,

        [Parameter(Mandatory)]
        [string]$Operation,

        [Parameter(Mandatory)]
        [hashtable]$Arguments
    )

    $response = & $Request $Operation $Arguments
    if ($null -eq $response) {
        return $null
    }

    $responseTable = ConvertTo-Hashtable -InputObject $response
    if (-not $responseTable.ContainsKey('StatusCode')) {
        return $response
    }

    $statusCode = [int]$responseTable['StatusCode']
    if ($statusCode -lt 200 -or $statusCode -ge 300) {
        throw "Azure DevOps operation '$Operation' failed with status code '$statusCode'."
    }
    if (-not $responseTable.ContainsKey('Body')) {
        return $null
    }

    $responseTable['Body']
}

if ($Apply -and $WhatIfPreference) {
    throw 'Apply cannot be combined with WhatIf.'
}

$hasStartDate = $PSBoundParameters.ContainsKey('SprintStartDate')
$hasFinishDate = $PSBoundParameters.ContainsKey('SprintFinishDate')
if ($hasStartDate -xor $hasFinishDate) {
    throw 'Supply both sprint dates or omit both sprint dates.'
}
if ($hasStartDate -and $SprintStartDate -gt $SprintFinishDate) {
    throw 'Sprint start date must be on or before the sprint finish date.'
}

$resolvedPlanOutputPath = Assert-OutputPathOutsideRepository -Path $PlanOutputPath
$requestBodyDirectory = [System.IO.Path]::GetDirectoryName($resolvedPlanOutputPath)
$normalizedOrganizationUrl = $OrganizationUrl.TrimEnd('/') + '/'
$request = if ($AzureDevOpsRequest) {
    $AzureDevOpsRequest
}
else {
    New-DefaultAzureDevOpsRequest -RequestBodyDirectory $requestBodyDirectory
}

$commonArguments = @{
    OrganizationUrl = $normalizedOrganizationUrl
    ProjectName = $ProjectName
}

$project = Invoke-AzureDevOpsRequest -Request $request -Operation 'GetProjectWithCapabilities' -Arguments $commonArguments
if ($null -eq $project) {
    throw "Azure DevOps project '$ProjectName' state is indeterminate."
}
$projectTable = ConvertTo-Hashtable -InputObject $project
$capabilities = if ($projectTable.ContainsKey('capabilities')) {
    ConvertTo-Hashtable -InputObject $projectTable['capabilities']
}
else {
    @{}
}
$processTemplate = if ($capabilities.ContainsKey('processTemplate')) {
    ConvertTo-Hashtable -InputObject $capabilities['processTemplate']
}
else {
    @{}
}
$processName = [string]$processTemplate['templateName']
if ($processName -cne 'Basic') {
    throw "Azure DevOps project '$ProjectName' must use the Basic process; observed '$processName'."
}

$teamArguments = $commonArguments.Clone()
$teamArguments['TeamName'] = $TeamName
$team = Invoke-AzureDevOpsRequest -Request $request -Operation 'GetTeam' -Arguments $teamArguments
if ($null -eq $team) {
    throw "Existing Azure DevOps team '$TeamName' state is indeterminate."
}
$teamTable = ConvertTo-Hashtable -InputObject $team
if ([string]$teamTable['name'] -cne $TeamName) {
    throw "Expected existing team '$TeamName'; observed '$([string]$teamTable['name'])'."
}
if ($teamTable.ContainsKey('projectName') -and [string]$teamTable['projectName'] -cne $ProjectName) {
    throw "Existing team '$TeamName' is not attached to project '$ProjectName'."
}

$area = Invoke-AzureDevOpsRequest -Request $request -Operation 'GetProjectRootArea' -Arguments $commonArguments
if ($null -eq $area) {
    throw "Azure DevOps project root area '$ProjectName' state is indeterminate."
}
$areaTable = ConvertTo-Hashtable -InputObject $area
$areaPath = [string]$areaTable['path']
$normalizedAreaPath = $areaPath.Trim('\', '/')
$isProjectRootArea = $normalizedAreaPath -ceq $ProjectName -or
    $normalizedAreaPath -ceq "$ProjectName\Area"
if ([string]$areaTable['structureType'] -cne 'area' -or -not $isProjectRootArea) {
    throw "Azure DevOps area '$areaPath' is not the exact project root area '$ProjectName'."
}

$iterationArguments = $commonArguments.Clone()
$iterationArguments['IterationPath'] = $CurrentSprintPath
$iteration = Invoke-AzureDevOpsRequest -Request $request -Operation 'GetIteration' -Arguments $iterationArguments
if ($null -eq $iteration) {
    throw "Current sprint iteration '$CurrentSprintPath' state is indeterminate."
}
$iterationTable = ConvertTo-Hashtable -InputObject $iteration
$observedIterationPath = [string]$iterationTable['path']
$normalizedIterationPath = $observedIterationPath.Trim('\', '/')
$projectPrefix = "$ProjectName\"
$relativeIterationPath = if ($CurrentSprintPath.StartsWith($projectPrefix, [System.StringComparison]::Ordinal)) {
    $CurrentSprintPath.Substring($projectPrefix.Length)
}
else {
    $CurrentSprintPath
}
$restIterationPath = "$ProjectName\Iteration\$relativeIterationPath"
$isExactIteration = $normalizedIterationPath -ceq $CurrentSprintPath -or
    $normalizedIterationPath -ceq $restIterationPath
if ([string]$iterationTable['structureType'] -cne 'iteration' -or -not $isExactIteration) {
    throw "Current sprint iteration '$CurrentSprintPath' state is indeterminate; observed '$observedIterationPath'."
}

$attributes = if ($iterationTable.ContainsKey('attributes')) {
    ConvertTo-Hashtable -InputObject $iterationTable['attributes']
}
else {
    @{}
}
$observedStartDate = ConvertTo-UtcIsoString -Value $attributes['startDate']
$observedFinishDate = ConvertTo-UtcIsoString -Value $attributes['finishDate']

$queryArguments = $commonArguments.Clone()
$queryArguments['Tag'] = $TraceabilityTag
$queryResult = Invoke-AzureDevOpsRequest -Request $request -Operation 'QueryTraceabilityIssue' -Arguments $queryArguments
if ($null -eq $queryResult) {
    throw 'Traceability Issue state is indeterminate.'
}
$queryTable = ConvertTo-Hashtable -InputObject $queryResult
$workItems = if ($queryTable.ContainsKey('workItems')) { @($queryTable['workItems']) } else { @() }
$issueIds = @($workItems | ForEach-Object {
    $itemTable = ConvertTo-Hashtable -InputObject $_
    if ($itemTable.ContainsKey('id')) { [int]$itemTable['id'] } else { 0 }
})
if ($issueIds -contains 0) {
    throw 'Traceability Issue query returned an indeterminate work item ID.'
}
if ($issueIds.Count -gt 1) {
    throw "Ambiguous traceability Issue state for tag '$TraceabilityTag': ids $($issueIds -join ', ')."
}

$issueMode = if ($issueIds.Count -eq 1) { 'Reuse' } else { 'Create' }
$issueId = if ($issueIds.Count -eq 1) { [int]$issueIds[0] } else { 0 }
$issueFields = @{
    'System.WorkItemType' = 'Issue'
    'System.Title' = $IssueTitle
    'System.AreaPath' = $ProjectName
    'System.IterationPath' = $CurrentSprintPath
    'System.Tags' = $TraceabilityTag
}

if ($issueMode -ceq 'Reuse') {
    $getWorkItemArguments = $commonArguments.Clone()
    $getWorkItemArguments['WorkItemId'] = $issueId
    $existingIssue = Invoke-AzureDevOpsRequest -Request $request -Operation 'GetWorkItem' -Arguments $getWorkItemArguments
    if ($null -eq $existingIssue) {
        throw "Traceability Issue '$issueId' read-back is indeterminate."
    }
    Assert-WorkItemReadBack -WorkItem $existingIssue -ExpectedId $issueId -ExpectedFields $issueFields
}

$plan = [pscustomobject]@{
    OrganizationUrl = $normalizedOrganizationUrl
    ProjectName = $ProjectName
    ProcessName = $processName
    TeamName = $TeamName
    AreaPath = $ProjectName
    CurrentSprintPath = $CurrentSprintPath
    SprintDateMode = if ($hasStartDate) { 'Update' } else { 'Preserve' }
    SprintStartDate = if ($hasStartDate) { ConvertTo-UtcIsoString -Value $SprintStartDate } else { $observedStartDate }
    SprintFinishDate = if ($hasFinishDate) { ConvertTo-UtcIsoString -Value $SprintFinishDate } else { $observedFinishDate }
    IssueTag = $TraceabilityTag
    IssueTitle = $IssueTitle
    IssueMode = $issueMode
    IssueId = if ($issueId -gt 0) { $issueId } else { $null }
    Status = 'Planned'
}

Write-Utf8JsonFile -Path $resolvedPlanOutputPath -Json ($plan | ConvertTo-Json -Depth 10)

if (-not $Apply) {
    Write-Output -NoEnumerate $plan
    return
}

if ($hasStartDate) {
    if (-not $PSCmdlet.ShouldProcess($CurrentSprintPath, 'Update exact Azure Boards current sprint dates')) {
        throw "Azure Boards current sprint date update for '$CurrentSprintPath' was declined."
    }

    $updateArguments = $iterationArguments.Clone()
    $updateArguments['StartDate'] = $SprintStartDate
    $updateArguments['FinishDate'] = $SprintFinishDate
    $null = Invoke-AzureDevOpsRequest -Request $request -Operation 'UpdateIterationDates' -Arguments $updateArguments

    $updatedIteration = Invoke-AzureDevOpsRequest -Request $request -Operation 'GetIteration' -Arguments $iterationArguments
    if ($null -eq $updatedIteration) {
        throw "Updated current sprint iteration '$CurrentSprintPath' read-back is indeterminate."
    }
    $updatedIterationTable = ConvertTo-Hashtable -InputObject $updatedIteration
    $updatedAttributes = if ($updatedIterationTable.ContainsKey('attributes')) {
        ConvertTo-Hashtable -InputObject $updatedIterationTable['attributes']
    }
    else {
        @{}
    }
    $updatedStartDate = ConvertTo-UtcIsoString -Value $updatedAttributes['startDate']
    $updatedFinishDate = ConvertTo-UtcIsoString -Value $updatedAttributes['finishDate']
    if ($updatedStartDate -cne (ConvertTo-UtcIsoString -Value $SprintStartDate) -or
        $updatedFinishDate -cne (ConvertTo-UtcIsoString -Value $SprintFinishDate)) {
        throw "Iteration read-back sprint dates mismatch for '$CurrentSprintPath'."
    }
}

if ($issueMode -ceq 'Create') {
    if (-not $PSCmdlet.ShouldProcess($IssueTitle, "Create durable Azure Boards Issue tagged '$TraceabilityTag'")) {
        throw "Azure Boards Issue creation for '$IssueTitle' was declined."
    }

    $createArguments = $commonArguments.Clone()
    $createArguments['Fields'] = $issueFields
    $createdIssue = Invoke-AzureDevOpsRequest -Request $request -Operation 'CreateTraceabilityIssue' -Arguments $createArguments
    if ($null -eq $createdIssue) {
        throw 'Created traceability Issue response is indeterminate.'
    }
    $createdIssueTable = ConvertTo-Hashtable -InputObject $createdIssue
    $issueId = if ($createdIssueTable.ContainsKey('id')) { [int]$createdIssueTable['id'] } else { 0 }
    if ($issueId -le 0) {
        throw "Created traceability Issue ID must be a positive integer; observed '$issueId'."
    }

    $getWorkItemArguments = $commonArguments.Clone()
    $getWorkItemArguments['WorkItemId'] = $issueId
    $createdIssueReadBack = Invoke-AzureDevOpsRequest -Request $request -Operation 'GetWorkItem' -Arguments $getWorkItemArguments
    if ($null -eq $createdIssueReadBack) {
        throw "Created traceability Issue '$issueId' read-back is indeterminate."
    }
    Assert-WorkItemReadBack -WorkItem $createdIssueReadBack -ExpectedId $issueId -ExpectedFields $issueFields
}

if ($issueId -le 0) {
    throw "Durable traceability Issue ID must be a positive integer; observed '$issueId'."
}

$plan.IssueId = $issueId
$plan.Status = 'Applied'
Write-Utf8JsonFile -Path $resolvedPlanOutputPath -Json ($plan | ConvertTo-Json -Depth 10)
Write-Output -NoEnumerate $plan
