function Invoke-AzureFoundationMutation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$Action,
        [Parameter(Mandatory)] [object]$TenantConfiguration,
        [Parameter(Mandatory)] [object]$VerifiedContext,
        [Parameter(Mandatory)] [object]$ToolResolution,
        [Parameter(Mandatory)] [string]$RunDirectory,
        [Parameter(Mandatory)] [scriptblock]$NativeCommandRunner
    )

    if ([string]$VerifiedContext.azure.userType -cne 'user' -or
        [string]$VerifiedContext.azure.subscriptionId -cne [string]$TenantConfiguration.SubscriptionId) {
        throw 'Azure delegated context changed before mutation.'
    }
    switch ([string]$Action.action) {
        'CreateEntraTargetApplication' {
            $name = [string]$Action.providerInput.displayName
            $matches = @(Invoke-CloudNativeCommand -ToolResolution $ToolResolution -ArgumentList @(
                'ad','app','list','--display-name',$name,'--output','json'
            ) -Runner $NativeCommandRunner -Json | Where-Object { [string]$_.displayName -ceq $name })
            if ($matches.Count -ne 0) { throw 'Entra application exact-name absence is not proven.' }
            $created = Invoke-CloudNativeCommand -ToolResolution $ToolResolution -ArgumentList @(
                'ad','app','create','--display-name',$name,'--sign-in-audience','AzureADMyOrg','--output','json'
            ) -Runner $NativeCommandRunner -Json
            $read = Invoke-CloudNativeCommand -ToolResolution $ToolResolution -ArgumentList @(
                'ad','app','show','--id',[string]$created.id,'--output','json'
            ) -Runner $NativeCommandRunner -Json
            if ([string]$read.displayName -cne $name) { throw 'Entra application postcondition failed.' }
            [pscustomobject]@{status='Changed';readBack=[pscustomobject]@{
                service='Entra';targetId=[string]$Action.targetId;status='Changed'
                objectId=[string]$read.id;appId=[string]$read.appId;displayName=[string]$read.displayName
                symmetricAuthCount=@($read.passwordCredentials).Count
                asymmetricAuthCount=@($read.keyCredentials).Count
            }}
        }
        'UpdateEntraTargetApplication' {
            Invoke-CloudNativeCommand -ToolResolution $ToolResolution -ArgumentList @(
                'ad','app','update','--id',[string]$Action.targetId,
                '--display-name',[string]$Action.providerInput.displayName
            ) -Runner $NativeCommandRunner | Out-Null
            $read = Invoke-CloudNativeCommand -ToolResolution $ToolResolution -ArgumentList @(
                'ad','app','show','--id',[string]$Action.targetId,'--output','json'
            ) -Runner $NativeCommandRunner -Json
            [pscustomobject]@{status='Changed';readBack=[pscustomobject]@{
                service='Entra';targetId=[string]$Action.targetId;status='Changed';objectId=[string]$read.id
            }}
        }
        'CreateEntraTargetServicePrincipal' {
            $appId = [string]$Action.providerInput.appId
            if ([string]::IsNullOrWhiteSpace($appId)) { throw 'A reviewed appId is required.' }
            $matches = @(Invoke-CloudNativeCommand -ToolResolution $ToolResolution -ArgumentList @(
                'ad','sp','list','--filter',"appId eq '$appId'",'--output','json'
            ) -Runner $NativeCommandRunner -Json | Where-Object { [string]$_.appId -ceq $appId })
            if ($matches.Count -ne 0) { throw 'Entra service-principal exact-appId absence is not proven.' }
            $created = Invoke-CloudNativeCommand -ToolResolution $ToolResolution -ArgumentList @(
                'ad','sp','create','--id',$appId,'--output','json'
            ) -Runner $NativeCommandRunner -Json
            [pscustomobject]@{status='Changed';readBack=[pscustomobject]@{
                service='Entra';targetId=[string]$Action.targetId;status='Changed'
                objectId=[string]$created.id;appId=[string]$created.appId
            }}
        }
        'DeployAzureFoundation' {
            $templatePath = [IO.Path]::GetFullPath([string]$Action.providerInput.templatePath)
            $parameterPath = [IO.Path]::GetFullPath([string]$Action.providerInput.parameterPath)
            if (-not (Test-RunbookPathWithin -Path $templatePath -Root $RunDirectory) -or
                -not (Test-RunbookPathWithin -Path $parameterPath -Root $RunDirectory)) {
                throw 'Azure deployment artifacts must remain in RunDirectory.'
            }
            if ((Get-FileHash $templatePath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$Action.providerInput.templateDigest -or
                (Get-FileHash $parameterPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$Action.providerInput.parameterDigest) {
                throw 'Azure deployment bytes changed after approval.'
            }
            $deployment = Invoke-CloudNativeCommand -ToolResolution $ToolResolution -ArgumentList @(
                'deployment','sub','create','--name',[string]$Action.providerInput.deploymentName,
                '--location',[string]$Action.providerInput.location,'--template-file',$templatePath,
                '--parameters',$parameterPath,'--output','json'
            ) -Runner $NativeCommandRunner -Json
            $read = Invoke-CloudNativeCommand -ToolResolution $ToolResolution -ArgumentList @(
                'deployment','sub','show','--name',[string]$Action.providerInput.deploymentName,
                '--query','{id:id,name:name,provisioningState:properties.provisioningState,outputs:properties.outputs}',
                '--output','json'
            ) -Runner $NativeCommandRunner -Json
            if ([string]$read.provisioningState -cne 'Succeeded') { throw 'Azure deployment postcondition failed.' }
            [pscustomobject]@{status='Changed';readBack=[pscustomobject]@{
                service='Azure';targetId=[string]$Action.targetId;status='Changed'
                deploymentId=[string]$read.id;deploymentName=[string]$read.name
                provisioningState=[string]$read.provisioningState;bodyDigest=[string]$Action.bodyDigest
            }}
        }
        default { throw 'Azure action is not allowlisted.' }
    }
}
