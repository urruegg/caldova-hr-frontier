function Invoke-AzureFoundationMutation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$Action,
        [Parameter(Mandatory)] [object]$TenantConfiguration,
        [Parameter(Mandatory)] [object]$VerifiedContext,
        [Parameter(Mandatory)] [object]$ToolResolution,
        [Parameter(Mandatory)] [string]$RunDirectory,
        [Parameter(Mandatory)] [string]$RepositoryRoot,
        [Parameter(Mandatory)] [scriptblock]$NativeCommandRunner,
        [scriptblock]$WhatIfValidator
    )

    if ([string]$VerifiedContext.azure.userType -cne 'user' -or
        [string]$VerifiedContext.azure.subscriptionId -cne [string]$TenantConfiguration.SubscriptionId) {
        throw 'Azure delegated context changed before mutation.'
    }
    if ([string]$Action.action -in @(
        'CreateEntraTargetApplication','UpdateEntraTargetApplication',
        'CreateEntraTargetServicePrincipal'
    )) {
        $eligibleRoles=@(
            'cf1c38e5-3621-4004-a7cb-879624dced7c',
            '158c047a-c907-4556-b7ef-446551a6b5f7'
        )
        if(@($VerifiedContext.entra.activeDirectoryRoleTemplateIds |
            Where-Object { $_ -cin $eligibleRoles }).Count -eq 0) {
            throw 'An active delegated Entra application-administrator role is required.'
        }
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
            if ($read.PSObject.Properties.Name -notcontains 'passwordCredentials' -or
                $read.PSObject.Properties.Name -notcontains 'keyCredentials') {
                throw 'Entra application credential-free postcondition was unavailable.'
            }
            $symmetricAuthCount=@($read.passwordCredentials).Count
            $asymmetricAuthCount=@($read.keyCredentials).Count
            if ([string]$read.displayName -cne $name -or
                $symmetricAuthCount -ne 0 -or $asymmetricAuthCount -ne 0) {
                throw 'Entra application postcondition failed.'
            }
            [pscustomobject]@{status='Changed';readBack=[pscustomobject]@{
                service='Entra';targetId=[string]$Action.targetId;status='Changed'
                objectId=[string]$read.id;appId=[string]$read.appId;displayName=[string]$read.displayName
                symmetricAuthCount=$symmetricAuthCount
                asymmetricAuthCount=$asymmetricAuthCount
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
            if ($read.PSObject.Properties.Name -notcontains 'passwordCredentials' -or
                $read.PSObject.Properties.Name -notcontains 'keyCredentials') {
                throw 'Entra application credential-free postcondition was unavailable.'
            }
            $symmetricAuthCount=@($read.passwordCredentials).Count
            $asymmetricAuthCount=@($read.keyCredentials).Count
            if ([string]$read.displayName -cne [string]$Action.providerInput.displayName -or
                $symmetricAuthCount -ne 0 -or $asymmetricAuthCount -ne 0) {
                throw 'Entra application postcondition failed.'
            }
            [pscustomobject]@{status='Changed';readBack=[pscustomobject]@{
                service='Entra';targetId=[string]$Action.targetId;status='Changed'
                objectId=[string]$read.id;appId=[string]$read.appId;displayName=[string]$read.displayName
                symmetricAuthCount=$symmetricAuthCount
                asymmetricAuthCount=$asymmetricAuthCount
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
            $sourcePath = [IO.Path]::GetFullPath([string]$Action.providerInput.sourcePath)
            $templatePath = [IO.Path]::GetFullPath([string]$Action.providerInput.templatePath)
            $parameterPath = [IO.Path]::GetFullPath([string]$Action.providerInput.parameterPath)
            $whatIfPath = [IO.Path]::GetFullPath([string]$Action.providerInput.whatIfPath)
            if (-not (Test-RunbookPathWithin -Path $templatePath -Root $RunDirectory) -or
                -not (Test-RunbookPathWithin -Path $parameterPath -Root $RunDirectory) -or
                -not (Test-RunbookPathWithin -Path $whatIfPath -Root $RunDirectory) -or
                (-not (Test-RunbookPathWithin -Path $sourcePath -Root $RunDirectory) -and
                 -not (Test-RunbookPathWithin -Path $sourcePath -Root $RepositoryRoot))) {
                throw 'Azure deployment artifacts must remain in RunDirectory.'
            }
            if ((Get-FileHash $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$Action.providerInput.sourceDigest -or
                (Get-FileHash $templatePath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$Action.providerInput.templateDigest -or
                (Get-FileHash $parameterPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$Action.providerInput.parameterDigest -or
                (Get-FileHash $whatIfPath -Algorithm SHA256).Hash.ToLowerInvariant() -cne [string]$Action.providerInput.whatIfDigest) {
                throw 'Azure deployment bytes changed after approval.'
            }
            $valid = if ($null -ne $WhatIfValidator) {
                & $WhatIfValidator $whatIfPath
            } else {
                $validatorPath=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..\Test-WhatIfBoundary.ps1'))
                & $validatorPath -WhatIfPayloadPath $whatIfPath `
                    -ExpectedPrincipalObjectId ([string]$Action.providerInput.validationPrincipalId)
                $true
            }
            if (-not $valid) { throw 'Azure what-if boundary validation failed.' }
            $deployment = Invoke-CloudNativeCommand -ToolResolution $ToolResolution -ArgumentList @(
                'deployment','sub','create','--name',[string]$Action.providerInput.deploymentName,
                '--location',[string]$Action.providerInput.location,'--template-file',$templatePath,
                '--parameters',"@$parameterPath",'--output','json'
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
