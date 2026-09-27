function Get-CloudServiceSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$TenantConfiguration,
        [Parameter(Mandatory)] [object]$VerifiedContext,
        [Parameter(Mandatory)] [object]$ToolResolutions,
        [Parameter(Mandatory)] [string]$RunDirectory,
        [Parameter(Mandatory)] [scriptblock]$NativeCommandRunner
    )

    if ([string]$VerifiedContext.overallStatus -cne 'Verified') {
        throw 'Cloud service discovery requires a verified delegated context.'
    }
    $githubUri = "repos/$($TenantConfiguration.GitHub.Owner)/$($TenantConfiguration.GitHub.Repository)"
    $repository = Invoke-CloudNativeCommand -ToolResolution $ToolResolutions.gh `
        -ArgumentList @('api',$githubUri) -Runner $NativeCommandRunner -Json
    $rulesets = @(Invoke-CloudNativeCommand -ToolResolution $ToolResolutions.gh `
        -ArgumentList @('api',"$githubUri/rulesets") -Runner $NativeCommandRunner -Json)

    [pscustomobject][ordered]@{
        github = [pscustomobject][ordered]@{
            repository = [pscustomobject][ordered]@{
                state = if ([string]$repository.id -ceq [string]$TenantConfiguration.GitHub.RepositoryId) { 'Exact' } else { 'Mismatch' }
                id = [string]$repository.id
                uri = $githubUri
            }
            rulesets = @($rulesets | ForEach-Object {
                [pscustomobject][ordered]@{ id=[string]$_.id; name=[string]$_.name; enforcement=[string]$_.enforcement }
            })
        }
    }
}
