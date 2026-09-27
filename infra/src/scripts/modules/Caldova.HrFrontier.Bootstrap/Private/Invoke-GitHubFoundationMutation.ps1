function Invoke-GitHubFoundationMutation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$Action,
        [Parameter(Mandatory)] [object]$TenantConfiguration,
        [Parameter(Mandatory)] [object]$VerifiedContext,
        [Parameter(Mandatory)] [object]$ToolResolution,
        [Parameter(Mandatory)] [string]$RunDirectory,
        [Parameter(Mandatory)] [scriptblock]$NativeCommandRunner
    )

    $repositoryUri = "repos/$($TenantConfiguration.GitHub.Owner)/$($TenantConfiguration.GitHub.Repository)"
    if ([string]$Action.uri -notmatch ('^' + [regex]::Escape($repositoryUri) + '(?:/rulesets(?:/\d+)?)?$')) {
        throw 'GitHub action URI is outside the reviewed non-Actions surface.'
    }
    $payloadPath = Join-Path $RunDirectory ("github-{0}.json" -f ([guid]::NewGuid().ToString('N')))
    try {
        $repository = Invoke-CloudNativeCommand -ToolResolution $ToolResolution `
            -ArgumentList @('api',$repositoryUri) -Runner $NativeCommandRunner -Json
        if ([string]$repository.id -cne [string]$TenantConfiguration.GitHub.RepositoryId -or
            -not [bool]$repository.permissions.admin) {
            throw 'GitHub repository identity or administrator permission changed.'
        }

        if ([string]$Action.action -ceq 'UpsertGitHubNonActionsRuleset') {
            $allowedKeys = @('name','target','enforcement','bypass_actors','conditions','rules')
            foreach ($key in $Action.providerInput.PSObject.Properties.Name) {
                if ($key -cnotin $allowedKeys) { throw 'GitHub ruleset payload contains an unsupported field.' }
            }
            foreach ($rule in @($Action.providerInput.rules)) {
                if ([string]$rule.type -cnotin @('deletion','non_fast_forward','pull_request')) {
                    throw 'Only reviewed non-Actions rules are supported.'
                }
            }
            $readBackUri=[string]$Action.uri
            if ([string]$Action.method -ceq 'POST') {
                $currentRulesets=@(Invoke-CloudNativeCommand -ToolResolution $ToolResolution `
                    -ArgumentList @('api',[string]$Action.uri) -Runner $NativeCommandRunner -Json)
                if (@($currentRulesets | Where-Object {
                    [string]$_.name -ceq [string]$Action.providerInput.name
                }).Count -ne 0) {
                    throw 'GitHub ruleset exact-name absence is not proven.'
                }
            }
            else {
                $current = Invoke-CloudNativeCommand -ToolResolution $ToolResolution `
                    -ArgumentList @('api',[string]$Action.uri) -Runner $NativeCommandRunner -Json
                $currentInput = [ordered]@{}
                foreach ($key in $allowedKeys) {
                    if ($current.PSObject.Properties.Name -contains $key) { $currentInput[$key]=$current.$key }
                }
                if ((Get-RunbookContentDigest ([pscustomobject]$currentInput)) -ceq [string]$Action.bodyDigest) {
                    return [pscustomobject][ordered]@{
                        status='NoChange'
                        readBack=[pscustomobject][ordered]@{
                            service='GitHub';targetId=[string]$Action.targetId;status='NoChange'
                            rulesetId=[string]$current.id;bodyDigest=[string]$Action.bodyDigest
                        }
                    }
                }
            }
            Write-CanonicalJson -InputObject $Action.providerInput -Path $payloadPath | Out-Null
            $mutated=Invoke-CloudNativeCommand -ToolResolution $ToolResolution -ArgumentList @(
                'api','--method',[string]$Action.method,[string]$Action.uri,'--input',$payloadPath
            ) -Runner $NativeCommandRunner -Json
            if ([string]$Action.method -ceq 'POST') {
                if ([string]::IsNullOrWhiteSpace([string]$mutated.id)) {
                    throw 'GitHub ruleset create returned no stable ID.'
                }
                $readBackUri="$($Action.uri)/$($mutated.id)"
            }
            $readBack = Invoke-CloudNativeCommand -ToolResolution $ToolResolution `
                -ArgumentList @('api',$readBackUri) -Runner $NativeCommandRunner -Json
            $readInput = [ordered]@{}
            foreach ($key in $allowedKeys) {
                if ($readBack.PSObject.Properties.Name -contains $key) { $readInput[$key]=$readBack.$key }
            }
            if ((Get-RunbookContentDigest ([pscustomobject]$readInput)) -cne [string]$Action.bodyDigest -or
                ([string]$Action.method -cne 'POST' -and
                 [string]$readBack.id -cne [string]$Action.targetId)) {
                throw 'GitHub ruleset postcondition failed.'
            }
            return [pscustomobject][ordered]@{
                status='Changed'
                readBack=[pscustomobject][ordered]@{
                    service='GitHub';targetId=[string]$Action.targetId;status='Changed'
                    rulesetId=[string]$readBack.id;bodyDigest=[string]$Action.bodyDigest
                }
            }
        }

        $metadataKeys = @(
            'description','homepage','has_issues','has_projects','has_wiki',
            'allow_merge_commit','allow_squash_merge','allow_rebase_merge','delete_branch_on_merge'
        )
        foreach ($key in $Action.providerInput.PSObject.Properties.Name) {
            if ($key -cnotin $metadataKeys) { throw 'GitHub repository payload contains an unsupported field.' }
        }
        Write-CanonicalJson -InputObject $Action.providerInput -Path $payloadPath | Out-Null
        Invoke-CloudNativeCommand -ToolResolution $ToolResolution -ArgumentList @(
            'api','--method','PATCH',$repositoryUri,'--input',$payloadPath
        ) -Runner $NativeCommandRunner -Json | Out-Null
        $final = Invoke-CloudNativeCommand -ToolResolution $ToolResolution `
            -ArgumentList @('api',$repositoryUri) -Runner $NativeCommandRunner -Json
        [pscustomobject][ordered]@{
            status='Changed'
            readBack=[pscustomobject][ordered]@{
                service='GitHub';targetId=[string]$Action.targetId;status='Changed'
                repositoryId=[string]$final.id;bodyDigest=[string]$Action.bodyDigest
            }
        }
    }
    finally {
        if (Test-Path -LiteralPath $payloadPath) { Remove-Item -LiteralPath $payloadPath -Force }
    }
}
