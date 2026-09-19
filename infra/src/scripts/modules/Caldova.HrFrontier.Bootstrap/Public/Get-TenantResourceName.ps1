function Get-TenantResourceName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[a-z]{3}-hr-agentic-[a-z0-9]{6}$')]
        [string]$NamingRoot,

        [Parameter(Mandatory)]
        [ValidateSet('ResourceGroup', 'LogAnalytics', 'DeploymentValidationRole')]
        [string]$ResourceType
    )

    $name = switch ($ResourceType) {
        'ResourceGroup' { "rg-$NamingRoot-platform" }
        'LogAnalytics' { "log-$NamingRoot" }
        'DeploymentValidationRole' { "$NamingRoot-deployment-validation" }
    }

    $constraints = switch ($ResourceType) {
        'ResourceGroup' { @{ MaxLength = 90; Pattern = '^[A-Za-z0-9._()\-]+$' } }
        'LogAnalytics' { @{ MaxLength = 63; Pattern = '^[A-Za-z0-9\-]+$' } }
        'DeploymentValidationRole' { @{ MaxLength = 128; Pattern = '^[A-Za-z0-9\-]+$' } }
    }

    if ($name.Length -gt $constraints.MaxLength -or $name -notmatch $constraints.Pattern) {
        throw "Derived name '$name' violates the $ResourceType naming constraints."
    }

    $name
}