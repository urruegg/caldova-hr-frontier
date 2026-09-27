function Invoke-AzureDevOpsFoundationMutation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$Action,
        [Parameter(Mandatory)] [object]$TenantConfiguration,
        [Parameter(Mandatory)] [object]$VerifiedContext,
        [Parameter(Mandatory)] [object]$ToolResolution,
        [Parameter(Mandatory)] [scriptblock]$NativeCommandRunner
    )

    $input = $Action.providerInput
    if ([string]$input.organizationUrl -cne [string]$TenantConfiguration.AzureDevOps.OrganizationUrl -or
        [string]$VerifiedContext.azureDevOps.organizationUrl -cne [string]$input.organizationUrl -or
        [string]$input.sourceControl -cne 'git') {
        throw 'Azure DevOps organization or project input changed.'
    }
    $escaped = ([string]$input.name).Replace("'","''")
    $matches = @(Invoke-CloudNativeCommand -ToolResolution $ToolResolution -ArgumentList @(
        'devops','project','list','--organization',[string]$input.organizationUrl,
        '--query',"value[?name=='$escaped'].{id:id,name:name,state:state,visibility:visibility}",'--output','json'
    ) -Runner $NativeCommandRunner -Json | Where-Object { [string]$_.name -ceq [string]$input.name })
    if ($matches.Count -ne 0) { throw 'Azure DevOps project exact-name absence is not proven.' }
    $created = Invoke-CloudNativeCommand -ToolResolution $ToolResolution -ArgumentList @(
        'devops','project','create','--organization',[string]$input.organizationUrl,
        '--name',[string]$input.name,'--process',[string]$input.processName,
        '--source-control','git','--visibility',[string]$input.visibility,'--output','json'
    ) -Runner $NativeCommandRunner -Json
    if ([string]::IsNullOrWhiteSpace([string]$created.id)) { throw 'Azure DevOps project create returned no stable ID.' }
    $read = Invoke-CloudNativeCommand -ToolResolution $ToolResolution -ArgumentList @(
        'devops','project','show','--organization',[string]$input.organizationUrl,
        '--project',[string]$created.id,'--output','json'
    ) -Runner $NativeCommandRunner -Json
    if ([string]$read.id -cne [string]$created.id -or [string]$read.name -cne [string]$input.name -or
        [string]$read.visibility -cne [string]$input.visibility -or [string]$read.state -cne 'wellFormed') {
        throw 'Azure DevOps project postcondition failed.'
    }
    [pscustomobject]@{status='Changed';readBack=[pscustomobject]@{
        service='AzureDevOps';targetId=[string]$Action.targetId;status='Changed'
        projectId=[string]$read.id;projectName=[string]$read.name;state=[string]$read.state
        visibility=[string]$read.visibility;organizationUrl=[string]$input.organizationUrl
        processId=[string]$input.processId;bodyDigest=[string]$Action.bodyDigest
    }}
}
