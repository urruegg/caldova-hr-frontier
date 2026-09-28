function Get-AzureDevOpsCreateProjectPermission {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$OrganizationUrl,
        [Parameter(Mandatory)] [string]$SubjectDescriptor,
        [Parameter(Mandatory)] [object]$ToolResolution,
        [Parameter(Mandatory)] [scriptblock]$NativeCommandRunner
    )

    $namespaceId = '52d39943-cb85-4d7f-8fa8-c6baac873819'
    $token = '$PROJECT:vstfs:///Classification/TeamProject/'
    try {
        $namespaces = @(Invoke-CloudNativeCommand -ToolResolution $ToolResolution -ArgumentList @(
            'devops','security','permission','namespace','list',
            '--organization',$OrganizationUrl,'--output','json'
        ) -Runner $NativeCommandRunner -Json | Where-Object {
            [string]$_.namespaceId -ceq $namespaceId
        })
        if ($namespaces.Count -ne 1) {
            return [pscustomobject]@{ state='Ambiguous';namespaceId=$namespaceId;permissionBit=$null;token=$token }
        }
        $actions = @($namespaces[0].actions | Where-Object {
            [string]$_.displayName -ceq 'Create new projects'
        })
        if ($actions.Count -ne 1 -or [int64]$actions[0].bit -le 0) {
            return [pscustomobject]@{ state='Ambiguous';namespaceId=$namespaceId;permissionBit=$null;token=$token }
        }
        $bit = [int64]$actions[0].bit
        $entries = @(Invoke-CloudNativeCommand -ToolResolution $ToolResolution -ArgumentList @(
            'devops','security','permission','list','--organization',$OrganizationUrl,
            '--id',$namespaceId,'--subject',$SubjectDescriptor,'--token',$token,'--output','json'
        ) -Runner $NativeCommandRunner -Json | Where-Object { [string]$_.token -ceq $token })
        if ($entries.Count -ne 1) {
            return [pscustomobject]@{ state='Ambiguous';namespaceId=$namespaceId;permissionBit=$bit;token=$token }
        }
        $ace = $entries[0].acesDictionary.PSObject.Properties[$SubjectDescriptor]
        if ($null -eq $ace) {
            return [pscustomobject]@{ state='Unavailable';namespaceId=$namespaceId;permissionBit=$bit;token=$token }
        }
        $allowed = (([int64]$ace.Value.allow -band $bit) -eq $bit)
        $denied = (([int64]$ace.Value.deny -band $bit) -eq $bit)
        $state = if ($denied -or -not $allowed) { 'Denied' } else { 'Allowed' }
        [pscustomobject]@{ state=$state;namespaceId=$namespaceId;permissionBit=$bit;token=$token }
    }
    catch {
        [pscustomobject]@{ state='Unavailable';namespaceId=$namespaceId;permissionBit=$null;token=$token }
    }
}
