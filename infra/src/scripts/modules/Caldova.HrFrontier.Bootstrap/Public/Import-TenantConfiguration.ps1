function Get-TenantSchemaPath {
    [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..\config\schemas\tenant.schema.json'))
}

function Get-TenantSchema {
    $cacheVariable = Get-Variable -Scope Script -Name TenantSchemaCache -ErrorAction SilentlyContinue
    if ($null -eq $cacheVariable -or $null -eq $cacheVariable.Value) {
        $schemaPath = Get-TenantSchemaPath
        $script:TenantSchemaCache = Get-Content -Raw -LiteralPath $schemaPath | ConvertFrom-Json
    }

    $script:TenantSchemaCache
}

function Get-ObjectEntryTable {
    param(
        [Parameter(Mandatory)]
        [object]$InputObject
    )

    $entries = [ordered]@{}

    if ($InputObject -is [System.Collections.IDictionary]) {
        foreach ($key in $InputObject.Keys) {
            $entries[[string]$key] = $InputObject[$key]
        }

        return $entries
    }

    foreach ($property in $InputObject.PSObject.Properties) {
        if ($property.MemberType -in @('NoteProperty', 'Property', 'ScriptProperty')) {
            $entries[$property.Name] = $property.Value
        }
    }

    if ($entries.Count -eq 0) {
        throw 'Expected an object or dictionary.'
    }

    $entries
}

function Test-HttpsUri {
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    $uri = $null
    [System.Uri]::TryCreate($Value, [System.UriKind]::Absolute, [ref]$uri) -and $uri.Scheme -eq 'https' -and -not [string]::IsNullOrWhiteSpace($uri.Host)
}

function Assert-SchemaString {
    param(
        [Parameter(Mandatory)]
        [object]$Value,

        [Parameter(Mandatory)]
        [object]$Schema,

        [Parameter(Mandatory)]
        [string]$Path
    )

    if ($Value -isnot [string]) {
        throw "$Path must be a string."
    }

    $schemaProperties = @($Schema.PSObject.Properties.Name)
    if ($schemaProperties -contains 'minLength' -and $Value.Length -lt [int]$Schema.minLength) {
        throw "$Path must not be empty."
    }

    if ($schemaProperties -contains 'const' -and $Value -cne [string]$Schema.const) {
        throw "$Path must equal '$($Schema.const)'."
    }

    if ($schemaProperties -contains 'enum' -and $Value -notin @($Schema.enum)) {
        throw "$Path must be one of: $(@($Schema.enum) -join ', ')."
    }

    if ($schemaProperties -contains 'pattern' -and $Value -notmatch [string]$Schema.pattern) {
        throw "$Path does not match the required pattern."
    }

    if ($schemaProperties -contains 'format') {
        switch ([string]$Schema.format) {
            'uuid' {
                $guid = [guid]::Empty
                if (-not [guid]::TryParse($Value, [ref]$guid)) {
                    throw "$Path must be a GUID."
                }
            }
            'uri' {
                $uri = $null
                if (-not [System.Uri]::TryCreate($Value, [System.UriKind]::Absolute, [ref]$uri)) {
                    throw "$Path must be an absolute URI."
                }
            }
        }
    }
}

function Resolve-SchemaForProperty {
    param(
        [Parameter(Mandatory)]
        [object]$Schema,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    $propertyBag = if ($Schema.PSObject.Properties.Name -contains 'properties' -and $Schema.properties) {
        Get-ObjectEntryTable $Schema.properties
    }
    else {
        [ordered]@{}
    }

    if ($propertyBag.Contains($PropertyName)) {
        return $propertyBag[$PropertyName]
    }

    $patternBag = if ($Schema.PSObject.Properties.Name -contains 'patternProperties' -and $Schema.patternProperties) {
        Get-ObjectEntryTable $Schema.patternProperties
    }
    else {
        [ordered]@{}
    }

    foreach ($pattern in $patternBag.Keys) {
        if ($PropertyName -match $pattern) {
            return $patternBag[$pattern]
        }
    }

    $null
}

function Assert-SchemaValue {
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object]$Value,

        [Parameter(Mandatory)]
        [object]$Schema,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $type = [string]$Schema.type
    if ($type -eq 'object') {
        $entries = Get-ObjectEntryTable $Value
        $required = @()
        if ($Schema.PSObject.Properties.Name -contains 'required' -and $null -ne $Schema.required) {
            $required = @($Schema.required | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
        }

        foreach ($requiredProperty in $required) {
            if (-not $entries.Contains([string]$requiredProperty)) {
                throw "$Path is missing required property '$requiredProperty'."
            }
        }

        foreach ($key in $entries.Keys) {
            $childSchema = Resolve-SchemaForProperty -Schema $Schema -PropertyName $key
            if (-not $childSchema) {
                if ($Schema.PSObject.Properties.Name -contains 'additionalProperties' -and $Schema.additionalProperties -eq $false) {
                    throw "$Path.$key is not allowed by the closed schema."
                }

                continue
            }

            Assert-SchemaValue -Value $entries[$key] -Schema $childSchema -Path "$Path.$key"
        }

        return
    }

    Assert-SchemaString -Value $Value -Schema $Schema -Path $Path
}

function Assert-TenantConfigurationContract {
    param(
        [Parameter(Mandatory)]
        [object]$Configuration,

        [Parameter(Mandatory)]
        [ValidateSet('Discovery', 'Bootstrap')]
        [string]$ValidationStage
    )

    $expectedNamingRoot = '{0}-{1}-{2}' -f $Configuration.CompanyTla, $Configuration.WorkloadName, $Configuration.UniqueSuffix
    if ($Configuration.NamingRoot -cne $expectedNamingRoot) {
        throw 'NamingRoot must be derived from CompanyTla, WorkloadName, and UniqueSuffix.'
    }

    $expectedEnvironmentName = 'bootstrap-{0}' -f $Configuration.TenantAlias
    if ($Configuration.GitHub.EnvironmentName -cne $expectedEnvironmentName) {
        throw 'GitHub.EnvironmentName must be derived from TenantAlias.'
    }

    if (-not (Test-HttpsUri -Value $Configuration.AzureDevOps.OrganizationUrl)) {
        throw 'AzureDevOps.OrganizationUrl must be an HTTPS URL.'
    }

    $powerPlatformUrls = @(
        $Configuration.PowerPlatform.DevUrl,
        $Configuration.PowerPlatform.TestUrl,
        $Configuration.PowerPlatform.ProdUrl
    )
    foreach ($url in $powerPlatformUrls) {
        if (-not (Test-HttpsUri -Value $url)) {
            throw 'PowerPlatform URLs must be HTTPS URLs.'
        }
    }

    if ((@($powerPlatformUrls | Select-Object -Unique)).Count -ne (@($powerPlatformUrls)).Count) {
        throw 'PowerPlatform URLs must be unique.'
    }

    $components = Get-ObjectEntryTable $Configuration.Components
    foreach ($componentName in $components.Keys) {
        $component = Get-ObjectEntryTable $components[$componentName]
        $mode = [string]$component.Mode
        if ($mode -notin @('Existing', 'Create')) {
            throw "Components.$componentName.Mode must be Existing or Create."
        }

        if ($component.Contains('Id') -and [string]::IsNullOrWhiteSpace([string]$component.Id)) {
            throw "Components.$componentName.Id must be a non-empty stable identifier when present."
        }

        if ($mode -eq 'Existing' -and (-not $component.Contains('Id') -or [string]::IsNullOrWhiteSpace([string]$component.Id))) {
            throw "Components.$componentName requires a stable Id in Existing mode."
        }
    }

    if ($ValidationStage -eq 'Bootstrap') {
        if ($Configuration.LifecycleState -cne 'IntentReviewed') {
            throw 'Bootstrap validation requires LifecycleState = IntentReviewed.'
        }

        if ((@($components.Keys)).Count -eq 0) {
            throw 'Bootstrap validation requires at least one reviewed component.'
        }
    }
}

function ConvertTo-ReadOnlyValue {
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return $null
    }

    $propertyCount = 0
    if ($Value -isnot [string]) {
        $propertyCount = @($Value.PSObject.Properties).Count
    }

    $isObject = $Value -is [System.Collections.IDictionary] -or $propertyCount -gt 0
    if (-not $isObject) {
        return $Value
    }

    $entries = Get-ObjectEntryTable $Value
    $readOnlyObject = New-Object psobject

    foreach ($key in $entries.Keys) {
        $memberValue = ConvertTo-ReadOnlyValue -Value $entries[$key]
        $getter = { ,$memberValue }.GetNewClosure()
        Add-Member -InputObject $readOnlyObject -MemberType ScriptProperty -Name $key -Value $getter
    }

    $readOnlyObject
}

function Import-TenantConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [ValidateSet('Discovery', 'Bootstrap')]
        [string]$ValidationStage = 'Discovery'
    )

    $resolvedPath = [System.IO.Path]::GetFullPath($Path)
    $configuration = Import-PowerShellDataFile -LiteralPath $resolvedPath
    $schema = Get-TenantSchema

    Assert-SchemaValue -Value $configuration -Schema $schema -Path 'Configuration'
    Assert-TenantConfigurationContract -Configuration $configuration -ValidationStage $ValidationStage

    ConvertTo-ReadOnlyValue -Value $configuration
}