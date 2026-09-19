function Remove-TemporaryRoleAssignments {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [object]$BootstrapResult,

        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
        [string]$ExpectedRunId,

        [Parameter(Mandatory)]
        [ValidatePattern('^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')]
        [string]$ExpectedPrincipalObjectId,

        [Parameter(Mandatory)]
        [ValidatePattern('^/subscriptions/[0-9a-fA-F-]{36}$')]
        [string]$ExpectedScope,

        [Parameter(Mandatory)]
        [ValidateCount(2, 2)]
        [string[]]$ApprovedRoleAssignmentIds,

        [Parameter(DontShow)]
        [scriptblock]$ReadRoleAssignment,

        [Parameter(DontShow)]
        [scriptblock]$RemoveRoleAssignment,

        [Parameter(DontShow)]
        [scriptblock]$NativeCommandRunner,

        [Parameter(DontShow)]
        [scriptblock]$Sleep,

        [Parameter(DontShow)]
        [scriptblock]$Clock,

        [int]$TimeoutSeconds = 30
    )

    function Get-Entries {
        param([object]$Value)

        if ($null -eq $Value) {
            return [ordered]@{}
        }

        if ($Value -is [System.Collections.IDictionary]) {
            $entries = [ordered]@{}
            foreach ($key in $Value.Keys) {
                $entries[[string]$key] = $Value[$key]
            }

            return $entries
        }

        $entries = [ordered]@{}
        foreach ($property in $Value.PSObject.Properties) {
            if ($property.MemberType -in @('NoteProperty', 'Property', 'ScriptProperty')) {
                $entries[$property.Name] = $property.Value
            }
        }

        $entries
    }

    function Assert-ExactProperties {
        param(
            [Parameter(Mandatory)]
            [System.Collections.Specialized.OrderedDictionary]$Entries,

            [Parameter(Mandatory)]
            [string[]]$ExpectedProperties,

            [Parameter(Mandatory)]
            [string]$Label
        )

        $actualProperties = @($Entries.Keys | ForEach-Object { [string]$_ })
        $missingProperties = @($ExpectedProperties | Where-Object { $_ -cnotin $actualProperties })
        if ($missingProperties.Count -gt 0) {
            throw ("{0} is missing required properties: {1}." -f $Label, ($missingProperties -join ', '))
        }

        $unsupportedProperties = @($actualProperties | Where-Object { $_ -cnotin $ExpectedProperties })
        if ($unsupportedProperties.Count -gt 0) {
            throw ("{0} contains unsupported properties: {1}." -f $Label, ($unsupportedProperties -join ', '))
        }
    }

    function Test-GuidValue {
        param([string]$Value)

        $parsedValue = [guid]::Empty
        [guid]::TryParse($Value, [ref]$parsedValue) -and $parsedValue -ne [guid]::Empty
    }

    function Test-TimestampValue {
        param([string]$Value)

        $parsedValue = [datetimeoffset]::MinValue
        [datetimeoffset]::TryParse(
            $Value,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::RoundtripKind,
            [ref]$parsedValue
        )
    }

    function Get-NowUtc {
        if ($Clock) {
            return (& $Clock).ToUniversalTime()
        }

        [datetime]::UtcNow
    }

    function Invoke-NativeCommand {
        param(
            [Parameter(Mandatory)]
            [string]$FilePath,

            [Parameter(Mandatory)]
            [string[]]$ArgumentList
        )

        if (-not $NativeCommandRunner) {
            $stdoutPath = [System.IO.Path]::GetTempFileName()
            $stderrPath = [System.IO.Path]::GetTempFileName()
            try {
                & $FilePath @ArgumentList 1> $stdoutPath 2> $stderrPath
                return [pscustomobject]@{
                    ExitCode = $LASTEXITCODE
                    StdOut = [System.IO.File]::ReadAllText($stdoutPath)
                    StdErr = [System.IO.File]::ReadAllText($stderrPath)
                    StatusCode = $null
                    ErrorCode = ''
                }
            }
            finally {
                Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue
            }
        }

        $result = & $NativeCommandRunner -FilePath $FilePath -ArgumentList $ArgumentList
        $resultEntries = Get-Entries -Value $result
        [pscustomobject]@{
            ExitCode = [int]$result.ExitCode
            StdOut = [string]$result.StdOut
            StdErr = [string]$result.StdErr
            StatusCode = if ($resultEntries.Contains('StatusCode')) { $resultEntries.StatusCode } else { $null }
            ErrorCode = if ($resultEntries.Contains('ErrorCode')) { [string]$resultEntries.ErrorCode } else { '' }
        }
    }

    function ConvertFrom-LiveRoleAssignment {
        param(
            [Parameter(Mandatory)]
            [object]$Assignment,

            [Parameter(Mandatory)]
            [string]$ExpectedRoleName,

            [Parameter(Mandatory)]
            [string]$ExpectedScope
        )

        $entries = Get-Entries -Value $Assignment
        $properties = Get-Entries -Value $entries.properties
        $roleDefinitionId = [string]$properties.roleDefinitionId
        if ([string]::IsNullOrWhiteSpace($roleDefinitionId)) {
            $roleDefinitionId = [string]$entries.roleDefinitionId
        }

        $principalObjectId = [string]$properties.principalId
        if ([string]::IsNullOrWhiteSpace($principalObjectId)) {
            $principalObjectId = [string]$entries.principalId
        }

        $scope = [string]$properties.scope
        if ([string]::IsNullOrWhiteSpace($scope)) {
            $scope = [string]$entries.scope
        }

        $id = [string]$entries.id
        if ([string]::IsNullOrWhiteSpace($id)) {
            $id = [string]$entries.Id
        }

        [pscustomobject]@{
            Id = $id
            RoleName = $ExpectedRoleName
            RoleDefinitionId = $roleDefinitionId
            PrincipalObjectId = $principalObjectId
            Scope = $scope
        }
    }

    function Test-NativeAssignmentAbsent {
        param([Parameter(Mandatory)][object]$Result)

        if ($null -ne $Result.StatusCode -and [int]$Result.StatusCode -eq 404) {
            return $true
        }
        if ([string]$Result.ErrorCode -in @('RoleAssignmentNotFound', 'ResourceNotFound')) {
            return $true
        }

        foreach ($payloadText in @([string]$Result.StdOut, [string]$Result.StdErr)) {
            if ([string]::IsNullOrWhiteSpace($payloadText)) {
                continue
            }

            try {
                $payloadEntries = Get-Entries -Value ($payloadText | ConvertFrom-Json)
                $errorEntries = if ($payloadEntries.Contains('error')) { Get-Entries -Value $payloadEntries.error } else { $payloadEntries }
                $statusCode = if ($errorEntries.Contains('statusCode')) { [int]$errorEntries.statusCode } elseif ($payloadEntries.Contains('statusCode')) { [int]$payloadEntries.statusCode } else { 0 }
                $errorCode = if ($errorEntries.Contains('code')) { [string]$errorEntries.code } else { '' }
                if ($statusCode -eq 404 -or $errorCode -in @('RoleAssignmentNotFound', 'ResourceNotFound')) {
                    return $true
                }
            }
            catch {
            }
        }

        $false
    }

    function Read-ExactAssignment {
        param([string]$Id)

        if ($ReadRoleAssignment) {
            return & $ReadRoleAssignment $Id
        }

        $result = Invoke-NativeCommand -FilePath 'az' -ArgumentList @(
            'rest',
            '--method', 'get',
            '--url', ("{0}?api-version=2022-04-01" -f $Id),
            '--output', 'json'
        )
        if ($result.ExitCode -ne 0) {
            if (Test-NativeAssignmentAbsent -Result $result) {
                return $null
            }

            throw "Failed to read role assignment $Id. $($result.StdErr)"
        }

        if ([string]::IsNullOrWhiteSpace($result.StdOut)) {
            throw "Role assignment read for $Id returned empty output."
        }

        $result.StdOut | ConvertFrom-Json
    }

    function Remove-ExactAssignment {
        param([object]$Assignment)

        if ($RemoveRoleAssignment) {
            & $RemoveRoleAssignment $Assignment
            return
        }

        $result = Invoke-NativeCommand -FilePath 'az' -ArgumentList @(
            'role',
            'assignment',
            'delete',
            '--ids', ([string]$Assignment.Id),
            '--output', 'none'
        )
        if ($result.ExitCode -ne 0) {
            throw "Failed to delete role assignment $([string]$Assignment.Id). $($result.StdErr)"
        }
    }

    $resultEntries = Get-Entries -Value $BootstrapResult
    Assert-ExactProperties -Entries $resultEntries -ExpectedProperties @(
        'SchemaVersion',
        'RunId',
        'TenantAlias',
        'TenantId',
        'SubscriptionId',
        'PrincipalObjectId',
        'Scope',
        'CreatedUtc',
        'Assignments'
    ) -Label 'BootstrapResult'

    if ([string]$resultEntries.SchemaVersion -cne '1.0') {
        throw 'BootstrapResult.SchemaVersion must equal 1.0.'
    }
    if (-not (Test-GuidValue -Value ([string]$resultEntries.RunId)) -or [string]$resultEntries.RunId -cne $ExpectedRunId) {
        throw 'BootstrapResult.RunId must match the reviewed run id.'
    }
    if ([string]$resultEntries.TenantAlias -cnotmatch '^[a-z0-9]+$') {
        throw 'BootstrapResult.TenantAlias is invalid.'
    }
    if (-not (Test-GuidValue -Value ([string]$resultEntries.TenantId))) {
        throw 'BootstrapResult.TenantId must be a UUID.'
    }
    if (-not (Test-GuidValue -Value ([string]$resultEntries.SubscriptionId))) {
        throw 'BootstrapResult.SubscriptionId must be a UUID.'
    }
    if (-not (Test-GuidValue -Value ([string]$resultEntries.PrincipalObjectId)) -or [string]$resultEntries.PrincipalObjectId -cne $ExpectedPrincipalObjectId) {
        throw 'BootstrapResult.PrincipalObjectId must match the reviewed principal.'
    }
    if ([string]$resultEntries.Scope -cne $ExpectedScope) {
        throw 'BootstrapResult.Scope must match the reviewed subscription scope.'
    }
    if ($ExpectedScope -cne "/subscriptions/$([string]$resultEntries.SubscriptionId)") {
        throw 'BootstrapResult.SubscriptionId must match the reviewed subscription scope.'
    }
    if (-not (Test-TimestampValue -Value ([string]$resultEntries.CreatedUtc))) {
        throw 'BootstrapResult.CreatedUtc must be a timestamp.'
    }

    $expectedPrincipalObjectId = $ExpectedPrincipalObjectId
    $expectedScope = $ExpectedScope
    $assignments = @($resultEntries.Assignments)
    if ($assignments.Count -ne 2) {
        throw 'BootstrapResult must contain exactly two assignment records.'
    }

    $assignmentIdPattern = '^' + [regex]::Escape("$expectedScope/providers/Microsoft.Authorization/roleAssignments/") + '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
    $approvedIds = @($ApprovedRoleAssignmentIds)
    $seenApprovedIds = @{}
    foreach ($approvedId in $approvedIds) {
        if ([string]$approvedId -cnotmatch $assignmentIdPattern) {
            throw 'ApprovedRoleAssignmentIds must contain well-formed exact assignment ids at the reviewed subscription scope.'
        }
        if ($seenApprovedIds.ContainsKey([string]$approvedId)) {
            throw 'ApprovedRoleAssignmentIds must be unique.'
        }

        $seenApprovedIds[[string]$approvedId] = $true
    }

    $expectedRoleDefinitionIds = @{
        Contributor = "$expectedScope/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c"
        'Role Based Access Control Administrator' = "$expectedScope/providers/Microsoft.Authorization/roleDefinitions/f58310d9-a9f6-439a-9e8d-f62e7b41a168"
    }
    $assignmentsByRole = @{}
    $seenAssignmentIds = @{}
    for ($assignmentIndex = 0; $assignmentIndex -lt $assignments.Count; $assignmentIndex++) {
        $assignment = $assignments[$assignmentIndex]
        $assignmentEntries = Get-Entries -Value $assignment
        Assert-ExactProperties -Entries $assignmentEntries -ExpectedProperties @(
            'Id',
            'RoleName',
            'RoleDefinitionId',
            'PrincipalObjectId',
            'Scope',
            'CreatedUtc'
        ) -Label "BootstrapResult.Assignments[$assignmentIndex]"

        $assignmentId = [string]$assignmentEntries.Id
        if ($assignmentId -cnotmatch $assignmentIdPattern) {
            throw 'BootstrapResult assignments require well-formed exact Id values at the reviewed subscription scope.'
        }
        if ($seenAssignmentIds.ContainsKey($assignmentId)) {
            throw 'BootstrapResult assignment ids must be unique.'
        }
        $seenAssignmentIds[$assignmentId] = $true

        $roleName = [string]$assignmentEntries.RoleName
        if ($roleName -notin @('Contributor', 'Role Based Access Control Administrator')) {
            throw "Unexpected role in cleanup provenance: $roleName"
        }

        if ($assignmentsByRole.ContainsKey($roleName)) {
            throw "Duplicate cleanup provenance for role $roleName."
        }

        if ([string]$assignmentEntries.PrincipalObjectId -cne $expectedPrincipalObjectId) {
            throw 'BootstrapResult assignment PrincipalObjectId must match the reviewed principal.'
        }
        if ([string]$assignmentEntries.Scope -cne $expectedScope) {
            throw 'BootstrapResult assignment Scope must match the reviewed subscription scope.'
        }
        if ([string]$assignmentEntries.RoleDefinitionId -cne [string]$expectedRoleDefinitionIds[$roleName]) {
            throw "BootstrapResult assignment RoleDefinitionId is not the pinned built-in definition for $roleName."
        }
        if (-not (Test-TimestampValue -Value ([string]$assignmentEntries.CreatedUtc))) {
            throw 'BootstrapResult assignment CreatedUtc must be a timestamp.'
        }

        $assignmentsByRole[$roleName] = $assignmentEntries
    }

    foreach ($requiredRole in @('Contributor', 'Role Based Access Control Administrator')) {
        if (-not $assignmentsByRole.ContainsKey($requiredRole)) {
            throw "Cleanup provenance is missing role $requiredRole."
        }
    }

    $unapprovedIds = @($seenAssignmentIds.Keys | Where-Object { [string]$_ -cnotin $approvedIds })
    $missingApprovedIds = @($approvedIds | Where-Object { [string]$_ -cnotin @($seenAssignmentIds.Keys) })
    if ($unapprovedIds.Count -gt 0 -or $missingApprovedIds.Count -gt 0) {
        throw 'BootstrapResult approved role-assignment ids must exactly match the reviewed assignment ids.'
    }

    $removedAssignments = [System.Collections.Generic.List[object]]::new()
    $absentAssignmentIds = [System.Collections.Generic.List[string]]::new()
    $orderedAssignments = @($assignmentsByRole['Contributor'], $assignmentsByRole['Role Based Access Control Administrator'])

    foreach ($assignment in $orderedAssignments) {
        $expectedId = [string]$assignment.Id
        $liveAssignment = Read-ExactAssignment -Id $expectedId
        if ($null -eq $liveAssignment) {
            $absentAssignmentIds.Add($expectedId) | Out-Null
            continue
        }

        $liveEntries = if ($ReadRoleAssignment) {
            Get-Entries -Value $liveAssignment
        }
        else {
            Get-Entries -Value (ConvertFrom-LiveRoleAssignment -Assignment $liveAssignment -ExpectedRoleName ([string]$assignment.RoleName) -ExpectedScope $expectedScope)
        }
        $expectedRoleDefinitionId = [string]$expectedRoleDefinitionIds[[string]$assignment.RoleName]
        if ([string]$liveEntries.PrincipalObjectId -cne $expectedPrincipalObjectId) {
            throw "PrincipalObjectId mismatch for $expectedId."
        }
        if ([string]$liveEntries.Scope -cne $expectedScope) {
            throw "Scope mismatch for $expectedId."
        }
        if ([string]$liveEntries.RoleName -cne [string]$assignment.RoleName) {
            throw "RoleName mismatch for $expectedId."
        }
        if ([string]$liveEntries.RoleDefinitionId -cne $expectedRoleDefinitionId) {
            throw "RoleDefinitionId mismatch for $expectedId."
        }

        if ($PSCmdlet.ShouldProcess($expectedId, "Remove temporary role assignment $([string]$assignment.RoleName)")) {
            $assignmentToRemove = if ($ReadRoleAssignment) { $liveAssignment } else { [pscustomobject]@{ Id = $expectedId } }
            Remove-ExactAssignment -Assignment $assignmentToRemove
            $removedAssignments.Add([pscustomobject]@{ Id = $expectedId; RoleName = [string]$assignment.RoleName }) | Out-Null
        }
    }

    $deadlineUtc = (Get-NowUtc).AddSeconds($TimeoutSeconds)
    $pollAttempts = 0
    $maxPollAttempts = [Math]::Max($TimeoutSeconds + 1, 2)
    while ($true) {
        $pollAttempts++
        $allAbsent = $true
        foreach ($assignment in $orderedAssignments) {
            $expectedId = [string]$assignment.Id
            $liveAssignment = Read-ExactAssignment -Id $expectedId
            if ($null -eq $liveAssignment) {
                if ($expectedId -notin @($absentAssignmentIds)) {
                    $absentAssignmentIds.Add($expectedId) | Out-Null
                }

                continue
            }

            $allAbsent = $false
            $liveEntries = if ($ReadRoleAssignment) {
                Get-Entries -Value $liveAssignment
            }
            else {
                Get-Entries -Value (ConvertFrom-LiveRoleAssignment -Assignment $liveAssignment -ExpectedRoleName ([string]$assignment.RoleName) -ExpectedScope $expectedScope)
            }
            $expectedRoleDefinitionId = [string]$expectedRoleDefinitionIds[[string]$assignment.RoleName]
            if ([string]$liveEntries.PrincipalObjectId -cne $expectedPrincipalObjectId) {
                throw "PrincipalObjectId mismatch for $expectedId."
            }
            if ([string]$liveEntries.Scope -cne $expectedScope) {
                throw "Scope mismatch for $expectedId."
            }
            if ([string]$liveEntries.RoleName -cne [string]$assignment.RoleName) {
                throw "RoleName mismatch for $expectedId."
            }
            if ([string]$liveEntries.RoleDefinitionId -cne $expectedRoleDefinitionId) {
                throw "RoleDefinitionId mismatch for $expectedId."
            }
        }

        if ($allAbsent) {
            return [pscustomobject]@{
                RemovedAssignments = $removedAssignments.ToArray()
                AbsentAssignmentIds = $absentAssignmentIds.ToArray()
            }
        }

        if ((Get-NowUtc) -ge $deadlineUtc -or $pollAttempts -ge $maxPollAttempts) {
            throw 'Cleanup timeout waiting for temporary role assignments to disappear.'
        }

        if ($Sleep) {
            & $Sleep
        }
        else {
            Start-Sleep -Seconds 1
        }
    }
}