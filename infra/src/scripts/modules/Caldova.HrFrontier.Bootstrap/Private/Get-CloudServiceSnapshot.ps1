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
    $rulesetsAvailable=$true
    try {
        $rulesets = @(Invoke-CloudNativeCommand -ToolResolution $ToolResolutions.gh `
            -ArgumentList @('api',"$githubUri/rulesets") -Runner $NativeCommandRunner -Json)
    }
    catch {
        $rulesetsAvailable=$false
        $rulesets=@()
    }
    $desiredRuleset = $null
    if ($TenantConfiguration.PSObject.Properties.Name -contains 'CloudFoundation' -and
        $null -ne $TenantConfiguration.CloudFoundation -and
        $TenantConfiguration.CloudFoundation.PSObject.Properties.Name -contains 'GitHubRuleset') {
        $desiredRuleset = $TenantConfiguration.CloudFoundation.GitHubRuleset
    }
    else {
        $defaultPath = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\..\config\github\main-ruleset.json'))
        if (Test-Path -LiteralPath $defaultPath) {
            $desiredDocument = Get-Content -Raw -LiteralPath $defaultPath | ConvertFrom-Json
            $reviewedRulesets=@($desiredDocument.rulesets)
            if($reviewedRulesets.Count -eq 1){
                $reviewed=$reviewedRulesets[0]
                $desiredRuleset=[pscustomobject][ordered]@{
                    name=[string]$reviewed.name;target=[string]$reviewed.target
                    enforcement=[string]$reviewed.enforcement
                    bypass_actors=@($reviewed.bypassActors)
                    conditions=[pscustomobject]@{ref_name=$reviewed.conditions.refName}
                    rules=@($reviewed.rules)
                }
            }
        }
    }
    $rulesetAssessment = $null
    if ($null -ne $desiredRuleset) {
        $matches = @($rulesets | Where-Object { [string]$_.name -ceq [string]$desiredRuleset.name })
        if (-not $rulesetsAvailable) {
            $rulesetAssessment = [pscustomobject][ordered]@{
                state='Blocked';id=[string]$desiredRuleset.name;uri="$githubUri/rulesets"
                providerInput=$desiredRuleset
            }
        }
        elseif ($matches.Count -eq 1) {
            $rulesetUri = "$githubUri/rulesets/$($matches[0].id)"
            $current = Invoke-CloudNativeCommand -ToolResolution $ToolResolutions.gh `
                -ArgumentList @('api',$rulesetUri) -Runner $NativeCommandRunner -Json
            $allowedKeys = @('name','target','enforcement','bypass_actors','conditions','rules')
            $currentInput = [ordered]@{}
            foreach ($key in $allowedKeys) {
                if ($current.PSObject.Properties.Name -contains $key) { $currentInput[$key]=$current.$key }
            }
            $state = if ((Get-RunbookContentDigest ([pscustomobject]$currentInput)) -ceq
                (Get-RunbookContentDigest $desiredRuleset)) { 'Exact' } else { 'Drift' }
            $rulesetAssessment = [pscustomobject][ordered]@{
                state=$state;id=[string]$matches[0].id;uri=$rulesetUri;providerInput=$desiredRuleset
            }
        }
        elseif ($matches.Count -eq 0) {
            $rulesetAssessment = [pscustomobject][ordered]@{
                state='Missing';id=[string]$desiredRuleset.name;uri="$githubUri/rulesets"
                providerInput=$desiredRuleset
            }
        }
        else {
            $rulesetAssessment = [pscustomobject][ordered]@{
                state='Ambiguous';id=[string]$desiredRuleset.name;uri="$githubUri/rulesets"
                providerInput=$desiredRuleset
            }
        }
    }

    $github = [ordered]@{
            repository = [pscustomobject][ordered]@{
                state = if ([string]$repository.id -ceq [string]$TenantConfiguration.GitHub.RepositoryId) { 'Exact' } else { 'Mismatch' }
                id = [string]$repository.id
                uri = $githubUri
            }
    }
    if ($null -ne $rulesetAssessment) { $github.ruleset=$rulesetAssessment }
    [pscustomobject][ordered]@{
        github = [pscustomobject]$github
    }
}
