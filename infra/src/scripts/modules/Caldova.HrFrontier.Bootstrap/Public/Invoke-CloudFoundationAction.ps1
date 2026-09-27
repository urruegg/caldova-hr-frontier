function Invoke-CloudFoundationAction {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [object]$Action,
        [Parameter(Mandatory)] [object]$TenantConfiguration,
        [Parameter(Mandatory)] [object]$VerifiedContext,
        [Parameter(Mandatory)] [object]$ToolResolutions,
        [Parameter(Mandatory)] [string]$RunDirectory,
        [Parameter(Mandatory)] [scriptblock]$NativeCommandRunner,
        [scriptblock]$WhatIfValidator,
        [string]$RepositoryRoot = (Get-Location).Path,
        [datetime]$NowUtc = [datetime]::UtcNow
    )

    $providerMap = @{
        UpdateGitHubRepositoryMetadata='GitHub'
        UpsertGitHubNonActionsRuleset='GitHub'
        DeployAzureFoundation='Azure'
        CreateEntraTargetApplication='Azure'
        UpdateEntraTargetApplication='Azure'
        CreateEntraTargetServicePrincipal='Azure'
        CreateAzureDevOpsProject='AzureDevOps'
    }
    $provider = $providerMap[[string]$Action.action]
    if ($null -eq $provider -or [string]$Action.service -cne $provider) {
        throw 'Cloud action is not mapped to its reviewed provider.'
    }
    if ([string]$Action.classification -cnotin @('Create','Update')) {
        throw 'Only Create and Update actions may be dispatched.'
    }
    $digest = Get-RunbookContentDigest -InputObject $Action.providerInput
    if ($digest -cne [string]$Action.bodyDigest) {
        throw 'Cloud action body digest does not match its provider input.'
    }
    $resolvedRunDirectory = Resolve-RunbookReportPath -RunId ([guid]::NewGuid()) `
        -Path $RunDirectory -RepositoryRoot $RepositoryRoot
    if (-not (Test-Path -LiteralPath $resolvedRunDirectory -PathType Container)) {
        throw 'RunDirectory must already exist.'
    }
    if ([string]$VerifiedContext.overallStatus -cne 'Verified') {
        throw 'Cloud action requires a verified delegated context.'
    }
    switch ($provider) {
        'GitHub' {
            Invoke-GitHubFoundationMutation -Action $Action -TenantConfiguration $TenantConfiguration `
                -VerifiedContext $VerifiedContext -ToolResolution $ToolResolutions.gh `
                -RunDirectory $resolvedRunDirectory -NativeCommandRunner $NativeCommandRunner
        }
        'Azure' {
            Invoke-AzureFoundationMutation -Action $Action -TenantConfiguration $TenantConfiguration `
                -VerifiedContext $VerifiedContext -ToolResolution $ToolResolutions.az `
                -RunDirectory $resolvedRunDirectory -RepositoryRoot $RepositoryRoot `
                -NativeCommandRunner $NativeCommandRunner -WhatIfValidator $WhatIfValidator
        }
        'AzureDevOps' {
            Invoke-AzureDevOpsFoundationMutation -Action $Action -TenantConfiguration $TenantConfiguration `
                -VerifiedContext $VerifiedContext -ToolResolution $ToolResolutions.az `
                -NativeCommandRunner $NativeCommandRunner
        }
    }
}
