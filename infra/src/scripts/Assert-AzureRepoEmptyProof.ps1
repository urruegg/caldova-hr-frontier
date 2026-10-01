[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$AzureRepoId,
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ProjectId,
    [Parameter(Mandatory)][AllowNull()][object]$Repository,
    [Parameter(Mandatory)][AllowNull()][object]$Refs,
    [Parameter(Mandatory)][AllowNull()][object]$Items
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-ResponseTable {
    param(
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string]$Label
    )

    if ($null -eq $InputObject -or $InputObject -is [System.Array] -or
        $InputObject -is [string] -or $InputObject -is [ValueType]) {
        throw "$Label response must be one JSON object."
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
        if ($property.MemberType -in @('NoteProperty', 'Property')) {
            $table[$property.Name] = $property.Value
        }
    }
    if ($table.Keys.Count -eq 0) {
        throw "$Label response must be a non-empty JSON object."
    }

    $table
}

function Test-NumericScalar {
    param(
        [AllowNull()]
        [object]$Value
    )

    $Value -is [System.Byte] -or
        $Value -is [System.SByte] -or
        $Value -is [System.Int16] -or
        $Value -is [System.UInt16] -or
        $Value -is [System.Int32] -or
        $Value -is [System.UInt32] -or
        $Value -is [System.Int64] -or
        $Value -is [System.UInt64] -or
        $Value -is [System.Single] -or
        $Value -is [System.Double] -or
        $Value -is [System.Decimal]
}

function Assert-GuidMatch {
    param(
        [AllowNull()]
        [object]$Observed,

        [Parameter(Mandatory)]
        [string]$Expected,

        [Parameter(Mandatory)]
        [string]$Label
    )

    if ($Observed -isnot [string]) {
        throw "$Label must be a GUID string."
    }

    $observedGuid = [guid]::Empty
    $expectedGuid = [guid]::Empty
    if (-not [guid]::TryParse([string]$Observed, [ref]$observedGuid) -or
        -not [guid]::TryParse($Expected, [ref]$expectedGuid) -or
        $observedGuid -ne $expectedGuid) {
        throw "$Label does not match the attended input."
    }
}

function Assert-EmptyCollectionEnvelope {
    param(
        [AllowNull()]
        [object]$Response,

        [Parameter(Mandatory)]
        [string]$Label
    )

    $table = ConvertTo-ResponseTable -InputObject $Response -Label $Label
    if (-not $table.ContainsKey('count') -or -not (Test-NumericScalar -Value $table['count'])) {
        throw "$Label response count must be an explicit numeric value."
    }
    if (-not $table.ContainsKey('value') -or $table['value'] -isnot [System.Array]) {
        throw "$Label response value must be an explicit array."
    }

    $declaredCount = [decimal]$table['count']
    $actualCount = @($table['value']).Count
    if ($declaredCount -ne $actualCount) {
        throw "$Label response count '$declaredCount' does not match value length '$actualCount'."
    }
    if ($declaredCount -ne 0) {
        throw "$Label response proves the Azure Repo is not empty."
    }

    [int]$actualCount
}

$repositoryTable = ConvertTo-ResponseTable -InputObject $Repository -Label 'Repository'
foreach ($propertyName in @('id', 'name', 'project', 'size', 'defaultBranch')) {
    if (-not $repositoryTable.ContainsKey($propertyName)) {
        throw "Repository response is missing required property '$propertyName'."
    }
}

Assert-GuidMatch -Observed $repositoryTable['id'] -Expected $AzureRepoId -Label 'Repository ID'
if ($repositoryTable['name'] -isnot [string] -or
    [string]::IsNullOrWhiteSpace([string]$repositoryTable['name'])) {
    throw 'Repository name must be a non-empty string.'
}

$projectTable = ConvertTo-ResponseTable -InputObject $repositoryTable['project'] -Label 'Repository project'
if (-not $projectTable.ContainsKey('id')) {
    throw "Repository project response is missing required property 'id'."
}
Assert-GuidMatch -Observed $projectTable['id'] -Expected $ProjectId -Label 'Repository project ID'

if (-not (Test-NumericScalar -Value $repositoryTable['size'])) {
    throw 'Repository size must be an explicit numeric value.'
}
if ([decimal]$repositoryTable['size'] -ne 0) {
    throw 'Repository size is not zero.'
}

$defaultBranch = $repositoryTable['defaultBranch']
if ($null -ne $defaultBranch -and $defaultBranch -isnot [string]) {
    throw 'Repository defaultBranch must be explicitly null or an empty string.'
}
if ($defaultBranch -is [string] -and $defaultBranch.Length -ne 0) {
    throw 'Repository has a default branch.'
}

$refCount = Assert-EmptyCollectionEnvelope -Response $Refs -Label 'Refs'
$itemCount = Assert-EmptyCollectionEnvelope -Response $Items -Label 'Items'

[pscustomobject][ordered]@{
    projectId = $ProjectId
    repositoryId = $AzureRepoId
    repositoryName = [string]$repositoryTable['name']
    size = [decimal]$repositoryTable['size']
    defaultBranch = $defaultBranch
    refCount = $refCount
    itemCount = $itemCount
    predicates = [pscustomobject][ordered]@{
        sizeIsZero = $true
        defaultBranchIsEmpty = $true
        refsAreEmpty = $true
        itemsAreEmpty = $true
    }
}
