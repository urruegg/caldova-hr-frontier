Set-StrictMode -Version Latest

Describe 'Tenant trust bootstrap' {
    BeforeAll {
        $script:RepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:ScriptPath = Join-Path $script:RepositoryRoot 'infra\src\scripts\Initialize-TenantTrust.ps1'
        $script:ModuleManifestPath = Join-Path $script:RepositoryRoot 'infra\src\scripts\modules\Caldova.HrFrontier.Bootstrap\Caldova.HrFrontier.Bootstrap.psd1'

        Import-Module $script:ModuleManifestPath -Force

        function script:New-TestTenantConfigurationContent {
            param(
                [string]$LifecycleState = 'IntentReviewed',
                [string]$ComponentsBody = @"
        @{
            EntraApplication = @{
                Mode = 'Create'
            }
            EntraServicePrincipal = @{
                Mode = 'Create'
            }
            GitHubEnvironment = @{
                Mode = 'Create'
            }
            AzureDevOpsServicePrincipalEntitlement = @{
                Mode = 'Create'
            }
            AzureDevOpsReadersMembership = @{
                Mode = 'Create'
            }
            PowerPlatformEnvironmentDev = @{
                Mode = 'Existing'
                Id = 'pp-env-synthetic-dev-44444444-4444-4444-4444-444444444444'
            }
            PowerPlatformEnvironmentTest = @{
                Mode = 'Existing'
                Id = 'pp-env-synthetic-test-55555555-5555-5555-5555-555555555555'
            }
            PowerPlatformEnvironmentProd = @{
                Mode = 'Existing'
                Id = 'pp-env-synthetic-prod-66666666-6666-6666-6666-666666666666'
            }
        }
"@
            )

            @"
@{
    SchemaVersion = '1.0'
    TenantAlias = 'caldova25156897'
    DisplayName = 'Caldova25156897'
    TenantId = 'e2312862-df63-440c-8bcf-007a2c52859d'
    AdminUpn = 'admin@Caldova25156897.onmicrosoft.com'
    SubscriptionId = 'edb45a24-408d-47c4-bbc7-685b9b3fc017'
    PrimaryLocation = 'switzerlandnorth'
    CompanyTla = 'cal'
    WorkloadName = 'hr-agentic'
    UniqueSuffix = 'bc8rbt'
    NamingRoot = 'cal-hr-agentic-bc8rbt'
    LifecycleState = '$LifecycleState'
    GitHub = @{
        Owner = 'urruegg'
        OwnerId = '46865858'
        Repository = 'caldova-hr-frontier'
        RepositoryId = '1371297722'
        EnvironmentName = 'bootstrap-caldova25156897'
    }
    AzureDevOps = @{
        OrganizationUrl = 'https://dev.azure.com/caldova25156897/'
        ProjectName = 'Caldova HR Frontier'
    }
    PowerPlatform = @{
        DevUrl = 'https://hrfrontierdev.crm17.dynamics.com/'
        TestUrl = 'https://hrfrontiertest.crm17.dynamics.com/'
        ProdUrl = 'https://hrfrontier.crm17.dynamics.com/'
    }
    Components = $ComponentsBody
}
"@
        }

        function script:New-TestTenantConfigurationFile {
            param(
                [string]$Content = (New-TestTenantConfigurationContent)
            )

            $path = Join-Path $TestDrive ([guid]::NewGuid().ToString() + '.psd1')
            [System.IO.File]::WriteAllText($path, $Content, [System.Text.UTF8Encoding]::new($false))
            $path
        }

        function script:New-OrderedMap {
            param([hashtable]$Data)

            $ordered = [ordered]@{}
            foreach ($key in $Data.Keys) {
                $ordered[$key] = $Data[$key]
            }

            $ordered
        }

        function script:New-TrustState {
            param()

            $subject = Get-GitHubOidcSubject -Owner 'urruegg' -OwnerId '46865858' -Repository 'caldova-hr-frontier' -RepositoryId '1371297722' -TenantAlias 'caldova25156897'
            $environmentId = 91234
            $reviewerId = 46865858

            [ordered]@{
                Context = [ordered]@{
                    TenantId = 'e2312862-df63-440c-8bcf-007a2c52859d'
                    SubscriptionId = 'edb45a24-408d-47c4-bbc7-685b9b3fc017'
                    UserPrincipalName = 'admin@Caldova25156897.onmicrosoft.com'
                    UserType = 'user'
                }
                Repository = [ordered]@{
                    Id = '1371297722'
                    Owner = [ordered]@{
                        Login = 'urruegg'
                        Id = '46865858'
                    }
                    Name = 'caldova-hr-frontier'
                    FullName = 'urruegg/caldova-hr-frontier'
                    Permissions = [ordered]@{
                        Admin = $true
                    }
                }
                OidcCustomization = [ordered]@{
                    use_default = $true
                    use_immutable_subject = $true
                    sub_claim_prefix = $subject
                }
                Application = $null
                ApplicationsByDisplayName = @()
                ServicePrincipal = $null
                ServicePrincipalByObjectId = $null
                ApplicationPermissions = @()
                FederatedCredential = $null
                Reviewer = [ordered]@{
                    id = $reviewerId
                    login = 'urruegg'
                }
                Environment = $null
                EnvironmentVariables = [ordered]@{}
                AzureDevOpsEntitlement = $null
                AzureDevOpsReadersGroup = [ordered]@{
                    descriptor = 'vssgp.Uy0xLTktMTU1MTM3NDI0Ni0xMjM0NTY='
                    displayName = 'Readers'
                }
                AzureDevOpsReadersMembership = $false
            }
        }

        function script:ConvertTo-Response {
            param(
                [AllowNull()]
                [object]$Body,

                [int]$StatusCode = 200,

                [hashtable]$Headers = @{}
            )

            [pscustomobject]@{
                StatusCode = $StatusCode
                Headers = [pscustomobject]$Headers
                Body = $Body
            }
        }

        function script:New-RecordingAdapters {
            param(
                [Parameter(Mandatory)]
                [hashtable]$State
            )

            $calls = [System.Collections.Generic.List[object]]::new()
            $convertToResponse = ${function:script:ConvertTo-Response}

            $mutationOperations = [ordered]@{
                Az = @('CreateApplication', 'CreateServicePrincipal', 'AddApplicationPermission', 'GrantAdminConsent', 'CreateFederatedCredential')
                GitHub = @('PutEnvironment', 'SetEnvironmentVariable')
                AzureDevOps = @('CreateServicePrincipalEntitlement', 'AddReadersMembership')
            }

            $azAdapter = {
                param(
                    [Parameter(Mandatory)]
                    [string]$Operation,

                    [Parameter(Mandatory)]
                    [System.Collections.Specialized.OrderedDictionary]$Arguments
                )

                    $calls.Add([pscustomobject]@{ Adapter = 'Az'; Operation = $Operation; Arguments = $Arguments }) | Out-Null

                switch ($Operation) {
                    'GetInteractiveContext' {
                        return & $convertToResponse -Body ([pscustomobject]$State.Context)
                    }
                    'GetApplicationByObjectId' {
                        if ($null -eq $State.Application) {
                            return & $convertToResponse -Body $null -StatusCode 404
                        }

                        return & $convertToResponse -Body ([pscustomobject]$State.Application)
                    }
                    'ListApplicationsByDisplayName' {
                        return & $convertToResponse -Body @($State.ApplicationsByDisplayName | ForEach-Object { [pscustomobject]$_ })
                    }
                    'CreateApplication' {
                        $State.Application = [ordered]@{
                            id = 'app-object-11111111-1111-1111-1111-111111111111'
                            appId = 'app-client-11111111-1111-1111-1111-111111111111'
                            displayName = [string]$Arguments['DisplayName']
                            signInAudience = 'AzureADMyOrg'
                            passwordCredentials = @()
                            keyCredentials = @()
                        }
                        return & $convertToResponse -Body ([pscustomobject]$State.Application) -StatusCode 201
                    }
                    'GetServicePrincipalByAppId' {
                        if ($null -eq $State.ServicePrincipal) {
                            return & $convertToResponse -Body $null -StatusCode 404
                        }

                        return & $convertToResponse -Body ([pscustomobject]$State.ServicePrincipal)
                    }
                    'GetServicePrincipalByObjectId' {
                        if ($null -eq $State.ServicePrincipalByObjectId) {
                            if ($null -eq $State.ServicePrincipal) {
                                return & $convertToResponse -Body $null -StatusCode 404
                            }

                            return & $convertToResponse -Body ([pscustomobject]$State.ServicePrincipal)
                        }

                        return & $convertToResponse -Body ([pscustomobject]$State.ServicePrincipalByObjectId)
                    }
                    'CreateServicePrincipal' {
                        $State.ServicePrincipal = [ordered]@{
                            id = 'sp-object-22222222-2222-2222-2222-222222222222'
                            appId = [string]$Arguments['AppId']
                            displayName = 'cal-hr-agentic-bc8rbt-github-bootstrap'
                        }
                        $State.ServicePrincipalByObjectId = $State.ServicePrincipal
                        return & $convertToResponse -Body ([pscustomobject]$State.ServicePrincipal) -StatusCode 201
                    }
                    'GetApplicationPermissions' {
                        return & $convertToResponse -Body @($State.ApplicationPermissions | ForEach-Object { [pscustomobject]$_ })
                    }
                    'AddApplicationPermission' {
                        $State.ApplicationPermissions = @(
                            [ordered]@{
                                resourceAppId = '00000007-0000-0000-c000-000000000000'
                                resourceDisplayName = 'Microsoft Dataverse'
                                permissionType = 'Scope'
                                permissionName = 'user_impersonation'
                            },
                            [ordered]@{
                                resourceAppId = '00000003-0000-0000-c000-000000000000'
                                resourceDisplayName = 'Microsoft Graph'
                                permissionType = 'Role'
                                permissionName = 'Application.Read.All'
                            }
                        )
                        return & $convertToResponse -Body ([pscustomobject]@{ added = $true }) -StatusCode 201
                    }
                    'GrantAdminConsent' {
                        return & $convertToResponse -Body ([pscustomobject]@{ granted = $true }) -StatusCode 202
                    }
                    'GetFederatedCredential' {
                        if ($null -eq $State.FederatedCredential) {
                            return & $convertToResponse -Body $null -StatusCode 404
                        }

                        return & $convertToResponse -Body ([pscustomobject]$State.FederatedCredential)
                    }
                    'CreateFederatedCredential' {
                        $State.FederatedCredential = [ordered]@{
                            name = 'github-bootstrap'
                            issuer = 'https://token.actions.githubusercontent.com'
                            audiences = @('api://AzureADTokenExchange')
                            subject = [string]$Arguments['Subject']
                        }
                        return & $convertToResponse -Body ([pscustomobject]$State.FederatedCredential) -StatusCode 201
                    }
                    default {
                        throw "Unexpected Az operation: $Operation"
                    }
                }
            }.GetNewClosure()

            $gitHubAdapter = {
                param(
                    [Parameter(Mandatory)]
                    [string]$Operation,

                    [Parameter(Mandatory)]
                    [System.Collections.Specialized.OrderedDictionary]$Arguments
                )

                    $calls.Add([pscustomobject]@{ Adapter = 'GitHub'; Operation = $Operation; Arguments = $Arguments }) | Out-Null

                switch ($Operation) {
                    'GetRepository' {
                        return & $convertToResponse -Body ([pscustomobject]$State.Repository)
                    }
                    'GetOidcCustomization' {
                        return & $convertToResponse -Body ([pscustomobject]$State.OidcCustomization)
                    }
                    'GetUserByLogin' {
                        return & $convertToResponse -Body ([pscustomobject]$State.Reviewer)
                    }
                    'GetEnvironment' {
                        if ($null -eq $State.Environment) {
                            return & $convertToResponse -Body $null -StatusCode 404
                        }

                        return & $convertToResponse -Body ([pscustomobject]$State.Environment)
                    }
                    'PutEnvironment' {
                        if (-not [bool]$State.PreserveEnvironmentMismatchOnWrite) {
                            $State.Environment = [ordered]@{
                                id = 91234
                                name = [string]$Arguments['EnvironmentName']
                                protected_branches = $false
                                custom_branch_policies = $true
                                deployment_branch_policy = [ordered]@{
                                    protected_branches = $false
                                    custom_branch_policies = $true
                                }
                                branch_policy = [ordered]@{
                                    protected_branches = $false
                                    custom_branch_policies = $true
                                }
                                reviewers = @(
                                    [ordered]@{
                                        type = 'User'
                                        reviewer_id = 46865858
                                        login = 'urruegg'
                                    }
                                )
                                prevent_self_review = $false
                                branch_name_patterns = @('main')
                                deployment_policies = @([ordered]@{ id = 1001; name = 'main'; type = 'branch' })
                            }
                        }

                        return & $convertToResponse -Body ([pscustomobject]$State.Environment) -StatusCode 200
                    }
                    'GetEnvironmentVariable' {
                        $name = [string]$Arguments['Name']
                        if (-not $State.EnvironmentVariables.Contains($name)) {
                            return & $convertToResponse -Body $null -StatusCode 404
                        }

                        return & $convertToResponse -Body ([pscustomobject]@{ name = $name; value = [string]$State.EnvironmentVariables[$name] })
                    }
                    'SetEnvironmentVariable' {
                        $name = [string]$Arguments['Name']
                        if (-not [bool]$State.PreserveVariableMismatchOnWrite) {
                            $State.EnvironmentVariables[$name] = [string]$Arguments['Value']
                        }

                        return & $convertToResponse -Body ([pscustomobject]@{ name = $name; value = [string]$State.EnvironmentVariables[$name] }) -StatusCode 204
                    }
                    default {
                        throw "Unexpected GitHub operation: $Operation"
                    }
                }
            }.GetNewClosure()

            $azureDevOpsAdapter = {
                param(
                    [Parameter(Mandatory)]
                    [string]$Operation,

                    [Parameter(Mandatory)]
                    [System.Collections.Specialized.OrderedDictionary]$Arguments
                )

                    $calls.Add([pscustomobject]@{ Adapter = 'AzureDevOps'; Operation = $Operation; Arguments = $Arguments }) | Out-Null

                switch ($Operation) {
                    'GetServicePrincipalEntitlement' {
                        if ($null -eq $State.AzureDevOpsEntitlement) {
                            return & $convertToResponse -Body $null -StatusCode 404
                        }

                        return & $convertToResponse -Body ([pscustomobject]$State.AzureDevOpsEntitlement)
                    }
                    'CreateServicePrincipalEntitlement' {
                        $State.AzureDevOpsEntitlement = [ordered]@{
                            id = 'ado-entitlement-77777777-7777-7777-7777-777777777777'
                            principalId = [string]$Arguments['PrincipalObjectId']
                            accessLevel = [ordered]@{
                                licensingSource = 'account'
                                accountLicenseType = 'express'
                            }
                        }
                        return & $convertToResponse -Body ([pscustomobject]$State.AzureDevOpsEntitlement) -StatusCode 201
                    }
                    'GetProjectReadersGroup' {
                        return & $convertToResponse -Body ([pscustomobject]$State.AzureDevOpsReadersGroup)
                    }
                    'GetReadersMembership' {
                        return & $convertToResponse -Body ([pscustomobject]@{ isMember = [bool]$State.AzureDevOpsReadersMembership })
                    }
                    'AddReadersMembership' {
                        if (-not [bool]$State.PreserveReadersMembershipMismatchOnWrite) {
                            $State.AzureDevOpsReadersMembership = $true
                        }

                        return & $convertToResponse -Body ([pscustomobject]@{ isMember = $true }) -StatusCode 201
                    }
                    default {
                        throw "Unexpected Azure DevOps operation: $Operation"
                    }
                }
            }.GetNewClosure()

            [pscustomobject]@{
                Calls = $calls
                MutationOperations = $mutationOperations
                Az = $azAdapter
                GitHub = $gitHubAdapter
                AzureDevOps = $azureDevOpsAdapter
            }
        }

        function script:Get-MutationCalls {
            param(
                [Parameter(Mandatory)]
                [object]$Adapters
            )

            @(
                foreach ($call in $Adapters.Calls) {
                    if ($Adapters.MutationOperations[$call.Adapter] -contains $call.Operation) {
                        $call
                    }
                }
            )
        }

        function script:Invoke-TrustScript {
            param(
                [Parameter(Mandatory)]
                [string]$TenantConfigurationPath,

                [Parameter(Mandatory)]
                [object]$Adapters,

                [switch]$WhatIf,

                [string]$PlanOutputPath
            )

            $parameters = @{
                TenantAlias = 'caldova25156897'
                TenantConfigurationPath = $TenantConfigurationPath
                AzRequest = $Adapters.Az
                GitHubRequest = $Adapters.GitHub
                AzureDevOpsRequest = $Adapters.AzureDevOps
                Confirm = $false
            }

            if ($WhatIf) {
                $parameters.WhatIf = $true
            }

            if ($PlanOutputPath) {
                $parameters.PlanOutputPath = $PlanOutputPath
            }

            & $script:ScriptPath @parameters
        }

        function script:Invoke-TrustScriptWithDefaultAdapters {
            param(
                [Parameter(Mandatory)]
                [string]$TenantConfigurationPath,

                [Parameter(Mandatory)]
                [object]$Harness,

                [switch]$WhatIf,

                [string]$PlanOutputPath
            )

            $parameters = @{
                TenantAlias = 'caldova25156897'
                TenantConfigurationPath = $TenantConfigurationPath
                NativeCommandRunner = $Harness.NativeRunner
                HttpRequestRunner = $Harness.HttpRunner
                Confirm = $false
            }

            if ($WhatIf) {
                $parameters.WhatIf = $true
            }

            if ($PlanOutputPath) {
                $parameters.PlanOutputPath = $PlanOutputPath
            }

            & $script:ScriptPath @parameters
        }

        function script:ConvertTo-JsonText {
            param([AllowNull()][object]$Value)

            if ($null -eq $Value) {
                return ''
            }

            return ($Value | ConvertTo-Json -Depth 20 -Compress)
        }

        function script:New-DefaultAdapterHarness {
            param(
                [Parameter(Mandatory)]
                [hashtable]$State
            )

            $nativeCalls = [System.Collections.Generic.List[object]]::new()
            $httpCalls = [System.Collections.Generic.List[object]]::new()
            $convertToJsonText = ${function:script:ConvertTo-JsonText}

            $nativeRunner = {
                param(
                    [Parameter(Mandatory)]
                    [string]$FilePath,

                    [Parameter(Mandatory)]
                    [string[]]$ArgumentList
                )

                $nativeCalls.Add([pscustomobject]@{
                    FilePath = $FilePath
                    ArgumentList = @($ArgumentList)
                }) | Out-Null

                $joinedArguments = $ArgumentList -join ' '

                if ($FilePath -eq 'az') {
                    if ($joinedArguments -ceq 'account show --output json') {
                        return [pscustomobject]@{
                            ExitCode = 0
                            StdOut = (& $convertToJsonText ([ordered]@{
                                tenantId = $State.Context.TenantId
                                id = $State.Context.SubscriptionId
                                user = [ordered]@{
                                    name = $State.Context.UserPrincipalName
                                    type = $(if ($State.ContainsKey('ContextUserType')) { $State.ContextUserType } else { 'user' })
                                }
                            }))
                            StdErr = ''
                        }
                    }

                    if ($joinedArguments -ceq 'account get-access-token --resource-type ms-graph --output json') {
                        return [pscustomobject]@{
                            ExitCode = 0
                            StdOut = (& $convertToJsonText ([ordered]@{ accessToken = 'graph-token' }))
                            StdErr = ''
                        }
                    }

                    if ($joinedArguments -ceq 'account get-access-token --resource 499b84ac-1321-427f-aa17-267ca6975798 --output json') {
                        return [pscustomobject]@{
                            ExitCode = 0
                            StdOut = (& $convertToJsonText ([ordered]@{ accessToken = 'ado-token' }))
                            StdErr = ''
                        }
                    }

                    if ($joinedArguments -match '^ad app create ') {
                        $displayName = $ArgumentList[4]
                        $State.Application = [ordered]@{
                            id = 'app-object-11111111-1111-1111-1111-111111111111'
                            appId = 'app-client-11111111-1111-1111-1111-111111111111'
                            displayName = $displayName
                            signInAudience = 'AzureADMyOrg'
                            passwordCredentials = @()
                            keyCredentials = @()
                        }

                        return [pscustomobject]@{
                            ExitCode = 0
                            StdOut = (& $convertToJsonText $State.Application)
                            StdErr = ''
                        }
                    }

                    if ($joinedArguments -match '^ad sp create ') {
                        $appId = $ArgumentList[4]
                        $State.ServicePrincipal = [ordered]@{
                            id = 'sp-object-22222222-2222-2222-2222-222222222222'
                            appId = $appId
                            displayName = 'cal-hr-agentic-bc8rbt-github-bootstrap'
                        }

                        return [pscustomobject]@{
                            ExitCode = 0
                            StdOut = (& $convertToJsonText $State.ServicePrincipal)
                            StdErr = ''
                        }
                    }

                    if ($ArgumentList[0] -ceq 'ad' -and $ArgumentList[1] -ceq 'app' -and $ArgumentList[2] -ceq 'permission' -and $ArgumentList[3] -ceq 'list') {
                        $permissions = if ($State.ApplicationPermissions -is [System.Collections.IDictionary]) {
                            @($State.ApplicationPermissions.Values)
                        }
                        else {
                            @($State.ApplicationPermissions)
                        }

                        return [pscustomobject]@{
                            ExitCode = 0
                            StdOut = (& $convertToJsonText $permissions)
                            StdErr = ''
                        }
                    }

                    if ($ArgumentList[0] -ceq 'ad' -and $ArgumentList[1] -ceq 'app' -and $ArgumentList[2] -ceq 'permission' -and $ArgumentList[3] -ceq 'add') {
                        $permissionTuple = [string]$ArgumentList[9]
                        if ($permissionTuple -ceq 'user_impersonation=Scope') {
                            $State.ApplicationPermissions['Microsoft Dataverse'] = [ordered]@{
                                resourceAppId = '00000007-0000-0000-c000-000000000000'
                                resourceDisplayName = 'Microsoft Dataverse'
                                permissionType = 'Scope'
                                permissionName = 'user_impersonation'
                            }
                        }
                        elseif ($permissionTuple -ceq 'Application.Read.All=Role') {
                            $State.ApplicationPermissions['Microsoft Graph'] = [ordered]@{
                                resourceAppId = '00000003-0000-0000-c000-000000000000'
                                resourceDisplayName = 'Microsoft Graph'
                                permissionType = 'Role'
                                permissionName = 'Application.Read.All'
                            }
                        }

                        return [pscustomobject]@{
                            ExitCode = 0
                            StdOut = ''
                            StdErr = ''
                        }
                    }

                    if ($ArgumentList[0] -ceq 'ad' -and $ArgumentList[1] -ceq 'app' -and $ArgumentList[2] -ceq 'permission' -and $ArgumentList[3] -ceq 'admin-consent') {
                        return [pscustomobject]@{
                            ExitCode = 0
                            StdOut = ''
                            StdErr = ''
                        }
                    }

                    if ($ArgumentList[0] -ceq 'ad' -and $ArgumentList[1] -ceq 'app' -and $ArgumentList[2] -ceq 'federated-credential' -and $ArgumentList[3] -ceq 'create') {
                        $parameters = $ArgumentList[7] | ConvertFrom-Json
                        $State.FederatedCredential = [ordered]@{
                            id = 'fic-id-33333333-3333-3333-3333-333333333333'
                            name = [string]$parameters.name
                            issuer = [string]$parameters.issuer
                            subject = [string]$parameters.subject
                            audiences = @($parameters.audiences)
                        }

                        return [pscustomobject]@{
                            ExitCode = 0
                            StdOut = (& $convertToJsonText $State.FederatedCredential)
                            StdErr = ''
                        }
                    }
                }

                if ($FilePath -eq 'gh') {
                    if ($joinedArguments -ceq 'auth token') {
                        return [pscustomobject]@{
                            ExitCode = 0
                            StdOut = 'gh-token'
                            StdErr = ''
                        }
                    }

                    if ($joinedArguments -match '^variable set (AZURE_CLIENT_ID|AZURE_TENANT_ID|AZURE_SUBSCRIPTION_ID) --env bootstrap-caldova25156897 --body ') {
                        $name = $ArgumentList[2]
                        $value = $ArgumentList[6]
                        $State.EnvironmentVariables[$name] = $value

                        return [pscustomobject]@{
                            ExitCode = 0
                            StdOut = ''
                            StdErr = ''
                        }
                    }
                }

                throw "Unexpected native command: $FilePath $($ArgumentList -join ' ')"
            }.GetNewClosure()

            $httpRunner = {
                param(
                    [Parameter(Mandatory)]
                    [string]$Method,

                    [Parameter(Mandatory)]
                    [string]$Uri,

                    [AllowNull()]
                    [hashtable]$Headers,

                    [AllowNull()]
                    [object]$Body
                )

                $httpCalls.Add([pscustomobject]@{
                    Method = $Method
                    Uri = $Uri
                    Headers = $Headers
                    Body = $Body
                }) | Out-Null

                switch -Regex ("$Method $Uri") {
                    '^GET https://graph.microsoft.com/v1.0/applications\?\$filter=' {
                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = (& $convertToJsonText @{ value = @($State.ApplicationsByDisplayName) }) }
                    }
                    '^GET https://graph.microsoft.com/v1.0/applications/.+\?\$select=requiredResourceAccess$' {
                        $permissionValues = if ($State.ApplicationPermissions -is [System.Collections.IDictionary]) { @($State.ApplicationPermissions.Values) } else { @($State.ApplicationPermissions) }
                        $requirements = @(
                            foreach ($resourceAppId in @($permissionValues | ForEach-Object { if ($_ -is [System.Collections.IDictionary]) { [string]$_['resourceAppId'] } else { [string]$_.resourceAppId } } | Select-Object -Unique)) {
                                $resourcePermissions = @($permissionValues | Where-Object { $(if ($_ -is [System.Collections.IDictionary]) { [string]$_['resourceAppId'] } else { [string]$_.resourceAppId }) -ceq $resourceAppId })
                                [ordered]@{
                                    resourceAppId = $resourceAppId
                                    resourceAccess = @(
                                        foreach ($permission in $resourcePermissions) {
                                            $permissionName = if ($permission -is [System.Collections.IDictionary]) { [string]$permission['permissionName'] } else { [string]$permission.permissionName }
                                            $permissionType = if ($permission -is [System.Collections.IDictionary]) { [string]$permission['permissionType'] } else { [string]$permission.permissionType }
                                            [ordered]@{
                                                id = if ($permissionName -ceq 'user_impersonation') { '11111111-1111-1111-1111-111111111111' } else { '22222222-2222-2222-2222-222222222222' }
                                                type = $permissionType
                                            }
                                        }
                                    )
                                }
                            }
                        )

                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = (& $convertToJsonText ([ordered]@{ requiredResourceAccess = $requirements })) }
                    }
                    '^GET https://graph.microsoft.com/v1.0/applications/[^/?]+$' {
                        if ($null -eq $State.Application) {
                            return [pscustomobject]@{ StatusCode = 404; Headers = @{}; Body = '' }
                        }

                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = (& $convertToJsonText $State.Application) }
                    }
                    '^GET https://graph.microsoft.com/v1.0/servicePrincipals\?\$filter=.+&\$select=displayName,oauth2PermissionScopes,appRoles$' {
                        $resourceAppId = if ($Uri -match '00000007-0000-0000-c000-000000000000') { '00000007-0000-0000-c000-000000000000' } else { '00000003-0000-0000-c000-000000000000' }
                        $permissionValues = if ($State.ApplicationPermissions -is [System.Collections.IDictionary]) { @($State.ApplicationPermissions.Values) } else { @($State.ApplicationPermissions) }
                        $resourcePermissions = @($permissionValues | Where-Object { $(if ($_ -is [System.Collections.IDictionary]) { [string]$_['resourceAppId'] } else { [string]$_.resourceAppId }) -ceq $resourceAppId })
                        $scopeDefinitions = @(
                            foreach ($permission in $resourcePermissions) {
                                $permissionType = if ($permission -is [System.Collections.IDictionary]) { [string]$permission['permissionType'] } else { [string]$permission.permissionType }
                                if ($permissionType -cne 'Scope') { continue }
                                $permissionName = if ($permission -is [System.Collections.IDictionary]) { [string]$permission['permissionName'] } else { [string]$permission.permissionName }
                                [ordered]@{ id = '11111111-1111-1111-1111-111111111111'; value = $permissionName }
                            }
                        )
                        $roleDefinitions = @(
                            foreach ($permission in $resourcePermissions) {
                                $permissionType = if ($permission -is [System.Collections.IDictionary]) { [string]$permission['permissionType'] } else { [string]$permission.permissionType }
                                if ($permissionType -cne 'Role') { continue }
                                $permissionName = if ($permission -is [System.Collections.IDictionary]) { [string]$permission['permissionName'] } else { [string]$permission.permissionName }
                                [ordered]@{ id = '22222222-2222-2222-2222-222222222222'; value = $permissionName }
                            }
                        )
                        $displayName = if ($resourceAppId -ceq '00000007-0000-0000-c000-000000000000') { 'Microsoft Dataverse' } else { 'Microsoft Graph' }
                        $catalog = [ordered]@{ displayName = $displayName; oauth2PermissionScopes = $scopeDefinitions; appRoles = $roleDefinitions }
                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = (& $convertToJsonText ([ordered]@{ value = @($catalog) })) }
                    }
                    '^GET https://graph.microsoft.com/v1.0/servicePrincipals\?\$filter=' {
                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = (& $convertToJsonText @{ value = @($(if ($null -ne $State.ServicePrincipal) { $State.ServicePrincipal })) }) }
                    }
                    '^GET https://graph.microsoft.com/v1.0/servicePrincipals/' {
                        if ($null -eq $State.ServicePrincipal) {
                            return [pscustomobject]@{ StatusCode = 404; Headers = @{}; Body = '' }
                        }

                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = (& $convertToJsonText $State.ServicePrincipal) }
                    }
                    '^GET https://graph.microsoft.com/v1.0/applications/.+/federatedIdentityCredentials/github-bootstrap$' {
                        if ($null -eq $State.FederatedCredential) {
                            return [pscustomobject]@{ StatusCode = 404; Headers = @{}; Body = '' }
                        }

                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = (& $convertToJsonText $State.FederatedCredential) }
                    }
                    '^GET https://api.github.com/repos/urruegg/caldova-hr-frontier$' {
                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = (& $convertToJsonText ([ordered]@{
                            id = $State.Repository.Id
                            name = $State.Repository.Name
                            owner = [ordered]@{ login = $State.Repository.Owner.Login; id = $State.Repository.Owner.Id }
                            full_name = $State.Repository.FullName
                            permissions = [ordered]@{ admin = $State.Repository.Permissions.Admin }
                        })) }
                    }
                    '^GET https://api.github.com/repos/urruegg/caldova-hr-frontier/actions/oidc/customization/sub$' {
                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = (& $convertToJsonText $State.OidcCustomization) }
                    }
                    '^GET https://api.github.com/users/urruegg$' {
                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = (& $convertToJsonText $State.Reviewer) }
                    }
                    '^GET https://api.github.com/repos/urruegg/caldova-hr-frontier/environments/bootstrap-caldova25156897$' {
                        if ($null -eq $State.Environment) {
                            return [pscustomobject]@{ StatusCode = 404; Headers = @{}; Body = '' }
                        }

                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = (& $convertToJsonText ([ordered]@{
                            id = $State.Environment.id
                            name = $State.Environment.name
                            protection_rules = @(
                                [ordered]@{ type = 'required_reviewers'; prevent_self_review = $State.Environment.prevent_self_review; reviewers = @([ordered]@{ type = 'User'; reviewer = [ordered]@{ id = 46865858; login = 'urruegg' } }) }
                            )
                            deployment_branch_policy = [ordered]@{ protected_branches = $State.Environment.protected_branches; custom_branch_policies = $State.Environment.custom_branch_policies }
                        })) }
                    }
                    '^PUT https://api.github.com/repos/urruegg/caldova-hr-frontier/environments/bootstrap-caldova25156897$' {
                        $payload = if ($Body -is [string]) { $Body | ConvertFrom-Json } else { $Body }
                        if (-not [bool]$State.PreserveEnvironmentMismatchOnWrite) {
                            $State.Environment = [ordered]@{
                                id = $(if ($State.ContainsKey('EnvironmentId')) { $State.EnvironmentId } else { 91234 })
                                name = 'bootstrap-caldova25156897'
                                protected_branches = [bool]$payload.deployment_branch_policy.protected_branches
                                custom_branch_policies = [bool]$payload.deployment_branch_policy.custom_branch_policies
                                prevent_self_review = [bool]$payload.prevent_self_review
                                branch_name_patterns = @()
                                deployment_policies = @()
                            }
                        }

                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = (& $convertToJsonText ([ordered]@{ id = $State.Environment.id; name = $State.Environment.name })) }
                    }
                    '^GET https://api.github.com/repos/urruegg/caldova-hr-frontier/environments/bootstrap-caldova25156897/deployment-branch-policies$' {
                        $environmentTable = if ($State.Environment -is [System.Collections.IDictionary]) { $State.Environment } else { @{} }
                        $policies = @()
                        if ($environmentTable.Contains('deployment_policies')) {
                            $policies = @($environmentTable['deployment_policies'])
                        }
                        else {
                            $policies = @($State.Environment.branch_name_patterns | ForEach-Object { [ordered]@{ id = 1001; name = [string]$_; type = 'branch' } })
                        }
                        if ($policies.Count -eq 0) {
                            return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = '{"total_count":0,"branch_policies":[]}' }
                        }

                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = (& $convertToJsonText ([ordered]@{ total_count = $policies.Count; branch_policies = $policies })) }
                    }
                    '^POST https://api.github.com/repos/urruegg/caldova-hr-frontier/environments/bootstrap-caldova25156897/deployment-branch-policies$' {
                        $payload = if ($Body -is [string]) { $Body | ConvertFrom-Json } else { $Body }
                        $State.Environment['branch_name_patterns'] = @([string]$payload.name)
                        $State.Environment['deployment_policies'] = @([ordered]@{ id = 1001; name = [string]$payload.name; type = [string]$payload.type })
                        return [pscustomobject]@{ StatusCode = 201; Headers = @{}; Body = (& $convertToJsonText ([ordered]@{ id = 1001; name = [string]$payload.name; type = [string]$payload.type })) }
                    }
                    '^GET https://api.github.com/repos/urruegg/caldova-hr-frontier/environments/bootstrap-caldova25156897/variables/' {
                        $name = $Uri.Split('/')[-1]
                        if (-not $State.EnvironmentVariables.Contains($name)) {
                            return [pscustomobject]@{ StatusCode = 404; Headers = @{}; Body = '' }
                        }

                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = (& $convertToJsonText ([ordered]@{ name = $name; value = [string]$State.EnvironmentVariables[$name] })) }
                    }
                    '^GET https://vsaex.dev.azure.com/caldova25156897/_apis/userentitlements\?api-version=7.1-preview.3&subjectTypes=servicePrincipal$' {
                        $members = @()
                        if ($null -ne $State.AzureDevOpsEntitlement) {
                            $members += [ordered]@{
                                id = $State.AzureDevOpsEntitlement.id
                                user = [ordered]@{ originId = $State.AzureDevOpsEntitlement.principalId; descriptor = 'aadsp.synthetic-service-principal'; subjectKind = 'servicePrincipal' }
                                accessLevel = $State.AzureDevOpsEntitlement.accessLevel
                            }
                        }

                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = (& $convertToJsonText ([ordered]@{ members = $members })) }
                    }
                    '^POST https://vsaex.dev.azure.com/caldova25156897/_apis/userentitlements\?api-version=7.1-preview.3$' {
                        $payload = if ($Body -is [string]) { $Body | ConvertFrom-Json } else { $Body }
                        $State.AzureDevOpsEntitlement = [ordered]@{
                            id = 'ado-entitlement-77777777-7777-7777-7777-777777777777'
                            principalId = [string]$payload.user.originId
                            accessLevel = [ordered]@{ licensingSource = 'account'; accountLicenseType = 'express' }
                        }

                        return [pscustomobject]@{ StatusCode = 201; Headers = @{}; Body = (& $convertToJsonText ([ordered]@{ id = $State.AzureDevOpsEntitlement.id })) }
                    }
                    '^GET https://dev.azure.com/caldova25156897/Caldova%20HR%20Frontier/_apis/graph/groups\?scopeDescriptor=project&api-version=7.1-preview.1$' {
                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = (& $convertToJsonText ([ordered]@{ value = @([ordered]@{ descriptor = $State.AzureDevOpsReadersGroup.descriptor; displayName = $State.AzureDevOpsReadersGroup.displayName }) })) }
                    }
                    '^GET https://dev.azure.com/caldova25156897/_apis/graph/memberships/.+/.+\?api-version=7.1-preview.1$' {
                        if (-not [bool]$State.AzureDevOpsReadersMembership) {
                            return [pscustomobject]@{ StatusCode = 404; Headers = @{}; Body = '' }
                        }

                        $membershipId = $(if ($State.ContainsKey('AzureDevOpsReadersMembershipId')) { $State.AzureDevOpsReadersMembershipId } else { 'ado-membership-88888888-8888-8888-8888-888888888888' })
                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = (& $convertToJsonText ([ordered]@{ id = $membershipId; isMember = $true })) }
                    }
                    '^PUT https://dev.azure.com/caldova25156897/_apis/graph/memberships/.+/.+\?api-version=7.1-preview.1$' {
                        if (-not [bool]$State.PreserveReadersMembershipMismatchOnWrite) {
                            $State.AzureDevOpsReadersMembership = $true
                            if (-not $State.ContainsKey('AzureDevOpsReadersMembershipId')) {
                                $State.AzureDevOpsReadersMembershipId = 'ado-membership-88888888-8888-8888-8888-888888888888'
                            }
                        }

                        return [pscustomobject]@{ StatusCode = 200; Headers = @{}; Body = (& $convertToJsonText ([ordered]@{ id = $State.AzureDevOpsReadersMembershipId; isMember = $true })) }
                    }
                    default {
                        throw "Unexpected HTTP call: $Method $Uri"
                    }
                }
            }.GetNewClosure()

            [pscustomobject]@{
                NativeCalls = $nativeCalls
                HttpCalls = $httpCalls
                NativeRunner = $nativeRunner
                HttpRunner = $httpRunner
            }
        }
    }

    It 'builds the full attended trust plan under WhatIf with zero mutation adapter calls' {
        $configPath = New-TestTenantConfigurationFile
        $state = New-TrustState
        $adapters = New-RecordingAdapters -State $state

        $result = Invoke-TrustScript -TenantConfigurationPath $configPath -Adapters $adapters -WhatIf

        $mutationCalls = Get-MutationCalls -Adapters $adapters
        $mutationCalls.Count | Should -Be 0

        $result.Plan.Operation | Should -Be @(
            'EnsureEntraApplication',
            'EnsureEntraServicePrincipal',
            'EnsureApplicationPermissions',
            'GrantAdminConsent',
            'EnsureFederatedCredential',
            'EnsureGitHubEnvironment',
            'EnsureGitHubEnvironmentVariable',
            'EnsureGitHubEnvironmentVariable',
            'EnsureGitHubEnvironmentVariable',
            'EnsureAzureDevOpsServicePrincipalEntitlement',
            'EnsureAzureDevOpsReadersMembership'
        )

        $result.Plan.TargetType | Should -Be @(
            'EntraApplication',
            'EntraServicePrincipal',
            'EntraApplicationPermissions',
            'AdminConsent',
            'FederatedCredential',
            'GitHubEnvironment',
            'GitHubEnvironmentVariable',
            'GitHubEnvironmentVariable',
            'GitHubEnvironmentVariable',
            'AzureDevOpsServicePrincipalEntitlement',
            'AzureDevOpsReadersMembership'
        )

        $appItem = $result.Plan | Where-Object Operation -eq 'EnsureEntraApplication'
        $appItem.Properties.DisplayName | Should -Be 'cal-hr-agentic-bc8rbt-github-bootstrap'
        $appItem.Properties.SignInAudience | Should -Be 'AzureADMyOrg'

        $permissionItem = $result.Plan | Where-Object Operation -eq 'EnsureApplicationPermissions'
        $permissionItem.Properties.RequiredPermissions | Should -HaveCount 2
        ($permissionItem.Properties.RequiredPermissions | Where-Object { $_.Resource -eq 'Microsoft Dataverse' }).Permission | Should -Be 'user_impersonation'
        ($permissionItem.Properties.RequiredPermissions | Where-Object { $_.Resource -eq 'Microsoft Graph' }).Permission | Should -Be 'Application.Read.All'

        $consentItem = $result.Plan | Where-Object Operation -eq 'GrantAdminConsent'
        $consentItem.Properties.Attended | Should -BeTrue

        $ficItem = $result.Plan | Where-Object Operation -eq 'EnsureFederatedCredential'
        $ficItem.Properties.Issuer | Should -Be 'https://token.actions.githubusercontent.com'
        $ficItem.Properties.Audience | Should -Be 'api://AzureADTokenExchange'
        $ficItem.Properties.Subject | Should -Be (Get-GitHubOidcSubject -Owner 'urruegg' -OwnerId '46865858' -Repository 'caldova-hr-frontier' -RepositoryId '1371297722' -TenantAlias 'caldova25156897')

        $environmentItem = $result.Plan | Where-Object Operation -eq 'EnsureGitHubEnvironment'
        $environmentItem.Properties.Name | Should -Be 'bootstrap-caldova25156897'
        $environmentItem.Properties.Branches | Should -Be @('main')
        $environmentItem.Properties.PreventSelfReview | Should -BeFalse
        $environmentItem.Properties.RequiredReviewers | Should -Be @('urruegg')

        ($result.Plan | Where-Object Operation -eq 'EnsureGitHubEnvironmentVariable').Properties.Name | Should -Be @('AZURE_CLIENT_ID', 'AZURE_TENANT_ID', 'AZURE_SUBSCRIPTION_ID')

        $entitlementItem = $result.Plan | Where-Object Operation -eq 'EnsureAzureDevOpsServicePrincipalEntitlement'
        $entitlementItem.Properties.AccessLevel | Should -Be 'Basic'
        $entitlementItem.Properties.ProjectName | Should -Be 'Caldova HR Frontier'

        $membershipItem = $result.Plan | Where-Object Operation -eq 'EnsureAzureDevOpsReadersMembership'
        $membershipItem.Properties.Group | Should -Be 'Readers'
        $membershipItem.Properties.BroadGroupAssignment | Should -BeFalse

        $result.PowerPlatformPrerequisites.Count | Should -Be 3
        $result.PowerPlatformPrerequisites.TargetType | Should -Be @('PowerPlatformEnvironmentDev', 'PowerPlatformEnvironmentTest', 'PowerPlatformEnvironmentProd')
        $result.PowerPlatformPrerequisites.Properties.RequiredAction | Should -Be @('AddApplicationUser', 'AddApplicationUser', 'AddApplicationUser')
        $result.PowerPlatformPrerequisites.Properties.RequiresExplicitApproval | Should -Be @($true, $true, $true)

        @($adapters.Calls | Where-Object Adapter -eq 'Az').Operation | Should -Contain 'GetInteractiveContext'
        @($adapters.Calls | Where-Object Adapter -eq 'GitHub').Operation | Should -Contain 'GetOidcCustomization'
        @($adapters.Calls | Where-Object Adapter -eq 'AzureDevOps').Operation | Should -Contain 'GetProjectReadersGroup'
    }

    It 'fails when repository metadata or immutable OIDC customization diverges from the reviewed contract' {
        $configPath = New-TestTenantConfigurationFile
        $state = New-TrustState
        $state.OidcCustomization.sub_claim_prefix = 'repo:urruegg@46865858/caldova-hr-frontier@1371297722:environment:bootstrap-other'
        $adapters = New-RecordingAdapters -State $state

        { Invoke-TrustScript -TenantConfigurationPath $configPath -Adapters $adapters -WhatIf } | Should -Throw '*OIDC*'
    }

    It 'fails closed on ambiguous application lookup in Create mode' {
        $configPath = New-TestTenantConfigurationFile
        $state = New-TrustState
        $state.ApplicationsByDisplayName = @(
            [ordered]@{ id = 'app-object-a'; appId = 'app-client-a'; displayName = 'cal-hr-agentic-bc8rbt-github-bootstrap'; signInAudience = 'AzureADMyOrg'; passwordCredentials = @(); keyCredentials = @() },
            [ordered]@{ id = 'app-object-b'; appId = 'app-client-b'; displayName = 'cal-hr-agentic-bc8rbt-github-bootstrap'; signInAudience = 'AzureADMyOrg'; passwordCredentials = @(); keyCredentials = @() }
        )
        $adapters = New-RecordingAdapters -State $state

        { Invoke-TrustScript -TenantConfigurationPath $configPath -Adapters $adapters -WhatIf } | Should -Throw '*Ambiguous*'
    }

    It 'implements the production-default adapters through stubbed native and HTTP runners' {
        $configPath = New-TestTenantConfigurationFile
        $state = New-TrustState
        $state.ApplicationsByDisplayName = @()
        $state.ApplicationPermissions = @{}
        $harness = New-DefaultAdapterHarness -State $state

        $result = Invoke-TrustScriptWithDefaultAdapters -TenantConfigurationPath $configPath -Harness $harness

        $result.Plan | Should -HaveCount 11
        ($harness.NativeCalls | Where-Object FilePath -eq 'az' | ForEach-Object { $_.ArgumentList -join ' ' }) | Should -Contain 'account show --output json'
        ($harness.NativeCalls | Where-Object FilePath -eq 'az' | ForEach-Object { $_.ArgumentList -join ' ' }) | Should -Contain 'ad app create --display-name cal-hr-agentic-bc8rbt-github-bootstrap --sign-in-audience AzureADMyOrg --output json'
        ($harness.NativeCalls | Where-Object FilePath -eq 'az' | ForEach-Object { $_.ArgumentList -join ' ' }) | Should -Contain 'ad sp create --id app-client-11111111-1111-1111-1111-111111111111 --output json'
        ($harness.NativeCalls | Where-Object FilePath -eq 'az' | ForEach-Object { $_.ArgumentList -join ' ' }) | Should -Contain 'ad app permission add --id app-client-11111111-1111-1111-1111-111111111111 --api 00000007-0000-0000-c000-000000000000 --api-permissions user_impersonation=Scope'
        ($harness.NativeCalls | Where-Object FilePath -eq 'az' | ForEach-Object { $_.ArgumentList -join ' ' }) | Should -Contain 'ad app permission add --id app-client-11111111-1111-1111-1111-111111111111 --api 00000003-0000-0000-c000-000000000000 --api-permissions Application.Read.All=Role'
        ($harness.NativeCalls | Where-Object FilePath -eq 'az' | ForEach-Object { $_.ArgumentList -join ' ' }) | Should -Contain 'ad app permission admin-consent --id app-client-11111111-1111-1111-1111-111111111111'
        @(($harness.NativeCalls | Where-Object FilePath -eq 'az' | ForEach-Object { $_.ArgumentList -join ' ' }) | Where-Object { $_ -match '^ad app federated-credential create --id app-object-11111111-1111-1111-1111-111111111111 --parameters ' }).Count | Should -Be 1

        ($harness.NativeCalls | Where-Object FilePath -eq 'gh' | ForEach-Object { $_.ArgumentList -join ' ' }) | Should -Contain 'variable set AZURE_CLIENT_ID --env bootstrap-caldova25156897 --body app-client-11111111-1111-1111-1111-111111111111'
        ($harness.NativeCalls | Where-Object FilePath -eq 'gh' | ForEach-Object { $_.ArgumentList -join ' ' }) | Should -Contain 'variable set AZURE_TENANT_ID --env bootstrap-caldova25156897 --body e2312862-df63-440c-8bcf-007a2c52859d'
        ($harness.NativeCalls | Where-Object FilePath -eq 'gh' | ForEach-Object { $_.ArgumentList -join ' ' }) | Should -Contain 'variable set AZURE_SUBSCRIPTION_ID --env bootstrap-caldova25156897 --body edb45a24-408d-47c4-bbc7-685b9b3fc017'

        ($harness.HttpCalls | Where-Object Method -eq 'PUT' | Select-Object -ExpandProperty Uri) | Should -Contain 'https://api.github.com/repos/urruegg/caldova-hr-frontier/environments/bootstrap-caldova25156897'
        $environmentPutCandidates = @($harness.HttpCalls | Where-Object { $_.Method -eq 'PUT' -and $_.Uri -eq 'https://api.github.com/repos/urruegg/caldova-hr-frontier/environments/bootstrap-caldova25156897' })
        $environmentPutCandidates | Should -HaveCount 1
        $environmentPut = $environmentPutCandidates[0]
        $environmentPut.Body.deployment_branch_policy.protected_branches | Should -BeFalse
        $environmentPut.Body.deployment_branch_policy.custom_branch_policies | Should -BeTrue
        ($harness.HttpCalls | Where-Object Method -eq 'POST' | Select-Object -ExpandProperty Uri) | Should -Contain 'https://api.github.com/repos/urruegg/caldova-hr-frontier/environments/bootstrap-caldova25156897/deployment-branch-policies'
        $branchPolicyPostCandidates = @($harness.HttpCalls | Where-Object { $_.Method -eq 'POST' -and $_.Uri -like '*/deployment-branch-policies' })
        $branchPolicyPostCandidates | Should -HaveCount 1
        $branchPolicyPost = $branchPolicyPostCandidates[0]
        $branchPolicyPost.Body.name | Should -Be 'main'
        $branchPolicyPost.Body.type | Should -Be 'branch'
        ($harness.HttpCalls | Where-Object Method -eq 'POST' | Select-Object -ExpandProperty Uri) | Should -Contain 'https://vsaex.dev.azure.com/caldova25156897/_apis/userentitlements?api-version=7.1-preview.3'
        ($harness.HttpCalls | Where-Object Method -eq 'PUT' | Where-Object Uri -Match 'graph/memberships' | Select-Object -ExpandProperty Uri) | Should -HaveCount 1
    }

    It 'fails closed when the production-default adapter sees a non-user Azure context' {
        $configPath = New-TestTenantConfigurationFile
        $state = New-TrustState
        $state.ContextUserType = 'servicePrincipal'
        $harness = New-DefaultAdapterHarness -State $state

        { Invoke-TrustScriptWithDefaultAdapters -TenantConfigurationPath $configPath -Harness $harness -WhatIf } | Should -Throw '*attended*'
    }

    It 'fails closed when an Existing GitHub environment stable id mismatches under production defaults' {
        $configPath = New-TestTenantConfigurationFile -Content (New-TestTenantConfigurationContent -ComponentsBody @"
        @{
            EntraApplication = @{
                Mode = 'Create'
            }
            EntraServicePrincipal = @{
                Mode = 'Create'
            }
            GitHubEnvironment = @{
                Mode = 'Existing'
                Id = 'reviewed-github-environment-id'
            }
            AzureDevOpsServicePrincipalEntitlement = @{
                Mode = 'Create'
            }
            AzureDevOpsReadersMembership = @{
                Mode = 'Create'
            }
            PowerPlatformEnvironmentDev = @{
                Mode = 'Existing'
                Id = 'pp-env-synthetic-dev-44444444-4444-4444-4444-444444444444'
            }
            PowerPlatformEnvironmentTest = @{
                Mode = 'Existing'
                Id = 'pp-env-synthetic-test-55555555-5555-5555-5555-555555555555'
            }
            PowerPlatformEnvironmentProd = @{
                Mode = 'Existing'
                Id = 'pp-env-synthetic-prod-66666666-6666-6666-6666-666666666666'
            }
        }
"@)
        $state = New-TrustState
        $state.Application = [ordered]@{ id = 'app-object-11111111-1111-1111-1111-111111111111'; appId = 'app-client-11111111-1111-1111-1111-111111111111'; displayName = 'cal-hr-agentic-bc8rbt-github-bootstrap'; signInAudience = 'AzureADMyOrg'; passwordCredentials = @(); keyCredentials = @() }
        $state.ServicePrincipal = [ordered]@{ id = 'sp-object-22222222-2222-2222-2222-222222222222'; appId = 'app-client-11111111-1111-1111-1111-111111111111'; displayName = 'cal-hr-agentic-bc8rbt-github-bootstrap' }
        $state.ApplicationPermissions = @{
            'Microsoft Dataverse' = [ordered]@{ resourceAppId = '00000007-0000-0000-c000-000000000000'; resourceDisplayName = 'Microsoft Dataverse'; permissionType = 'Scope'; permissionName = 'user_impersonation' }
            'Microsoft Graph' = [ordered]@{ resourceAppId = '00000003-0000-0000-c000-000000000000'; resourceDisplayName = 'Microsoft Graph'; permissionType = 'Role'; permissionName = 'Application.Read.All' }
        }
        $state.FederatedCredential = [ordered]@{ id = 'fic-id-33333333-3333-3333-3333-333333333333'; name = 'github-bootstrap'; issuer = 'https://token.actions.githubusercontent.com'; audiences = @('api://AzureADTokenExchange'); subject = (Get-GitHubOidcSubject -Owner 'urruegg' -OwnerId '46865858' -Repository 'caldova-hr-frontier' -RepositoryId '1371297722' -TenantAlias 'caldova25156897') }
        $state.Environment = [ordered]@{ id = 'observed-github-environment-id'; name = 'bootstrap-caldova25156897'; protected_branches = $false; custom_branch_policies = $true; prevent_self_review = $false; branch_name_patterns = @('main'); deployment_policies = @([ordered]@{ id = 1001; name = 'main'; type = 'branch' }) }
        $harness = New-DefaultAdapterHarness -State $state

        { Invoke-TrustScriptWithDefaultAdapters -TenantConfigurationPath $configPath -Harness $harness -WhatIf } | Should -Throw '*stable Id*'
    }

    It 'fails closed when an Existing GitHub environment has any non-main deployment policy' {
        $configPath = New-TestTenantConfigurationFile -Content (New-TestTenantConfigurationContent -ComponentsBody @"
        @{
            EntraApplication = @{ Mode = 'Create' }
            EntraServicePrincipal = @{ Mode = 'Create' }
            GitHubEnvironment = @{ Mode = 'Existing'; Id = '91234' }
            AzureDevOpsServicePrincipalEntitlement = @{ Mode = 'Create' }
            AzureDevOpsReadersMembership = @{ Mode = 'Create' }
            PowerPlatformEnvironmentDev = @{ Mode = 'Existing'; Id = 'pp-env-synthetic-dev-44444444-4444-4444-4444-444444444444' }
            PowerPlatformEnvironmentTest = @{ Mode = 'Existing'; Id = 'pp-env-synthetic-test-55555555-5555-5555-5555-555555555555' }
            PowerPlatformEnvironmentProd = @{ Mode = 'Existing'; Id = 'pp-env-synthetic-prod-66666666-6666-6666-6666-666666666666' }
        }
"@)
        $state = New-TrustState
        $state.Application = [ordered]@{ id = 'app-object-11111111-1111-1111-1111-111111111111'; appId = 'app-client-11111111-1111-1111-1111-111111111111'; displayName = 'cal-hr-agentic-bc8rbt-github-bootstrap'; signInAudience = 'AzureADMyOrg'; passwordCredentials = @(); keyCredentials = @() }
        $state.ServicePrincipal = [ordered]@{ id = 'sp-object-22222222-2222-2222-2222-222222222222'; appId = 'app-client-11111111-1111-1111-1111-111111111111'; displayName = 'cal-hr-agentic-bc8rbt-github-bootstrap' }
        $state.ApplicationPermissions = @(
            [ordered]@{ resourceAppId = '00000007-0000-0000-c000-000000000000'; resourceDisplayName = 'Microsoft Dataverse'; permissionType = 'Scope'; permissionName = 'user_impersonation' },
            [ordered]@{ resourceAppId = '00000003-0000-0000-c000-000000000000'; resourceDisplayName = 'Microsoft Graph'; permissionType = 'Role'; permissionName = 'Application.Read.All' }
        )
        $state.FederatedCredential = [ordered]@{ id = 'fic-id-33333333-3333-3333-3333-333333333333'; name = 'github-bootstrap'; issuer = 'https://token.actions.githubusercontent.com'; audiences = @('api://AzureADTokenExchange'); subject = (Get-GitHubOidcSubject -Owner 'urruegg' -OwnerId '46865858' -Repository 'caldova-hr-frontier' -RepositoryId '1371297722' -TenantAlias 'caldova25156897') }
        $state.Environment = [ordered]@{
            id = 91234
            name = 'bootstrap-caldova25156897'
            protected_branches = $false
            custom_branch_policies = $true
            prevent_self_review = $false
            branch_name_patterns = @('main')
            deployment_policies = @(
                [ordered]@{ id = 1001; name = 'main'; type = 'branch' },
                [ordered]@{ id = 1002; name = 'v1.*'; type = 'tag' }
            )
        }
        $harness = New-DefaultAdapterHarness -State $state

        { Invoke-TrustScriptWithDefaultAdapters -TenantConfigurationPath $configPath -Harness $harness -WhatIf } | Should -Throw '*deployment policies*'
    }

    It 'fails closed when an Existing Azure DevOps entitlement stable id mismatches under production defaults' {
        $configPath = New-TestTenantConfigurationFile -Content (New-TestTenantConfigurationContent -ComponentsBody @"
        @{
            EntraApplication = @{
                Mode = 'Create'
            }
            EntraServicePrincipal = @{
                Mode = 'Create'
            }
            GitHubEnvironment = @{
                Mode = 'Create'
            }
            AzureDevOpsServicePrincipalEntitlement = @{
                Mode = 'Existing'
                Id = 'reviewed-entitlement-id'
            }
            AzureDevOpsReadersMembership = @{
                Mode = 'Create'
            }
            PowerPlatformEnvironmentDev = @{
                Mode = 'Existing'
                Id = 'pp-env-synthetic-dev-44444444-4444-4444-4444-444444444444'
            }
            PowerPlatformEnvironmentTest = @{
                Mode = 'Existing'
                Id = 'pp-env-synthetic-test-55555555-5555-5555-5555-555555555555'
            }
            PowerPlatformEnvironmentProd = @{
                Mode = 'Existing'
                Id = 'pp-env-synthetic-prod-66666666-6666-6666-6666-666666666666'
            }
        }
"@)
        $state = New-TrustState
        $state.Application = [ordered]@{ id = 'app-object-11111111-1111-1111-1111-111111111111'; appId = 'app-client-11111111-1111-1111-1111-111111111111'; displayName = 'cal-hr-agentic-bc8rbt-github-bootstrap'; signInAudience = 'AzureADMyOrg'; passwordCredentials = @(); keyCredentials = @() }
        $state.ServicePrincipal = [ordered]@{ id = 'sp-object-22222222-2222-2222-2222-222222222222'; appId = 'app-client-11111111-1111-1111-1111-111111111111'; displayName = 'cal-hr-agentic-bc8rbt-github-bootstrap' }
        $state.ApplicationPermissions = @{
            'Microsoft Dataverse' = [ordered]@{ resourceAppId = '00000007-0000-0000-c000-000000000000'; resourceDisplayName = 'Microsoft Dataverse'; permissionType = 'Scope'; permissionName = 'user_impersonation' }
            'Microsoft Graph' = [ordered]@{ resourceAppId = '00000003-0000-0000-c000-000000000000'; resourceDisplayName = 'Microsoft Graph'; permissionType = 'Role'; permissionName = 'Application.Read.All' }
        }
        $state.FederatedCredential = [ordered]@{ id = 'fic-id-33333333-3333-3333-3333-333333333333'; name = 'github-bootstrap'; issuer = 'https://token.actions.githubusercontent.com'; audiences = @('api://AzureADTokenExchange'); subject = (Get-GitHubOidcSubject -Owner 'urruegg' -OwnerId '46865858' -Repository 'caldova-hr-frontier' -RepositoryId '1371297722' -TenantAlias 'caldova25156897') }
        $state.Environment = [ordered]@{ id = 91234; name = 'bootstrap-caldova25156897'; protected_branches = $false; custom_branch_policies = $true; prevent_self_review = $false; branch_name_patterns = @('main'); deployment_policies = @([ordered]@{ id = 1001; name = 'main'; type = 'branch' }) }
        $state.AzureDevOpsEntitlement = [ordered]@{ id = 'observed-entitlement-id'; principalId = 'sp-object-22222222-2222-2222-2222-222222222222'; accessLevel = [ordered]@{ licensingSource = 'account'; accountLicenseType = 'express' } }
        $state.AzureDevOpsReadersMembership = $true
        $state.AzureDevOpsReadersMembershipId = 'ado-membership-88888888-8888-8888-8888-888888888888'
        $harness = New-DefaultAdapterHarness -State $state

        { Invoke-TrustScriptWithDefaultAdapters -TenantConfigurationPath $configPath -Harness $harness -WhatIf } | Should -Throw '*stable Id*'
    }

    It 'fails closed when an Existing Azure DevOps Readers membership stable id mismatches under production defaults' {
        $configPath = New-TestTenantConfigurationFile -Content (New-TestTenantConfigurationContent -ComponentsBody @"
        @{
            EntraApplication = @{
                Mode = 'Create'
            }
            EntraServicePrincipal = @{
                Mode = 'Create'
            }
            GitHubEnvironment = @{
                Mode = 'Create'
            }
            AzureDevOpsServicePrincipalEntitlement = @{
                Mode = 'Create'
            }
            AzureDevOpsReadersMembership = @{
                Mode = 'Existing'
                Id = 'reviewed-membership-id'
            }
            PowerPlatformEnvironmentDev = @{
                Mode = 'Existing'
                Id = 'pp-env-synthetic-dev-44444444-4444-4444-4444-444444444444'
            }
            PowerPlatformEnvironmentTest = @{
                Mode = 'Existing'
                Id = 'pp-env-synthetic-test-55555555-5555-5555-5555-555555555555'
            }
            PowerPlatformEnvironmentProd = @{
                Mode = 'Existing'
                Id = 'pp-env-synthetic-prod-66666666-6666-6666-6666-666666666666'
            }
        }
"@)
        $state = New-TrustState
        $state.Application = [ordered]@{ id = 'app-object-11111111-1111-1111-1111-111111111111'; appId = 'app-client-11111111-1111-1111-1111-111111111111'; displayName = 'cal-hr-agentic-bc8rbt-github-bootstrap'; signInAudience = 'AzureADMyOrg'; passwordCredentials = @(); keyCredentials = @() }
        $state.ServicePrincipal = [ordered]@{ id = 'sp-object-22222222-2222-2222-2222-222222222222'; appId = 'app-client-11111111-1111-1111-1111-111111111111'; displayName = 'cal-hr-agentic-bc8rbt-github-bootstrap' }
        $state.ApplicationPermissions = @{
            'Microsoft Dataverse' = [ordered]@{ resourceAppId = '00000007-0000-0000-c000-000000000000'; resourceDisplayName = 'Microsoft Dataverse'; permissionType = 'Scope'; permissionName = 'user_impersonation' }
            'Microsoft Graph' = [ordered]@{ resourceAppId = '00000003-0000-0000-c000-000000000000'; resourceDisplayName = 'Microsoft Graph'; permissionType = 'Role'; permissionName = 'Application.Read.All' }
        }
        $state.FederatedCredential = [ordered]@{ id = 'fic-id-33333333-3333-3333-3333-333333333333'; name = 'github-bootstrap'; issuer = 'https://token.actions.githubusercontent.com'; audiences = @('api://AzureADTokenExchange'); subject = (Get-GitHubOidcSubject -Owner 'urruegg' -OwnerId '46865858' -Repository 'caldova-hr-frontier' -RepositoryId '1371297722' -TenantAlias 'caldova25156897') }
        $state.Environment = [ordered]@{ id = 91234; name = 'bootstrap-caldova25156897'; protected_branches = $false; custom_branch_policies = $true; prevent_self_review = $false; branch_name_patterns = @('main'); deployment_policies = @([ordered]@{ id = 1001; name = 'main'; type = 'branch' }) }
        $state.AzureDevOpsEntitlement = [ordered]@{ id = 'ado-entitlement-77777777-7777-7777-7777-777777777777'; principalId = 'sp-object-22222222-2222-2222-2222-222222222222'; accessLevel = [ordered]@{ licensingSource = 'account'; accountLicenseType = 'express' } }
        $state.AzureDevOpsReadersMembership = $true
        $state.AzureDevOpsReadersMembershipId = 'observed-membership-id'
        $harness = New-DefaultAdapterHarness -State $state

        { Invoke-TrustScriptWithDefaultAdapters -TenantConfigurationPath $configPath -Harness $harness -WhatIf } | Should -Throw '*stable Id*'
    }

    It 'fails closed when an Existing application id resolves to a different object' {
        $configPath = New-TestTenantConfigurationFile -Content (New-TestTenantConfigurationContent -ComponentsBody @"
        @{
            EntraApplication = @{
                Mode = 'Existing'
                Id = 'app-object-reviewed-99999999-9999-9999-9999-999999999999'
            }
            EntraServicePrincipal = @{
                Mode = 'Existing'
                Id = 'sp-object-22222222-2222-2222-2222-222222222222'
            }
            GitHubEnvironment = @{
                Mode = 'Create'
            }
            AzureDevOpsServicePrincipalEntitlement = @{
                Mode = 'Create'
            }
            AzureDevOpsReadersMembership = @{
                Mode = 'Create'
            }
            PowerPlatformEnvironmentDev = @{
                Mode = 'Existing'
                Id = 'pp-env-synthetic-dev-44444444-4444-4444-4444-444444444444'
            }
            PowerPlatformEnvironmentTest = @{
                Mode = 'Existing'
                Id = 'pp-env-synthetic-test-55555555-5555-5555-5555-555555555555'
            }
            PowerPlatformEnvironmentProd = @{
                Mode = 'Existing'
                Id = 'pp-env-synthetic-prod-66666666-6666-6666-6666-666666666666'
            }
        }
"@)
        $state = New-TrustState
        $state.Application = [ordered]@{
            id = 'app-object-11111111-1111-1111-1111-111111111111'
            appId = 'app-client-11111111-1111-1111-1111-111111111111'
            displayName = 'cal-hr-agentic-bc8rbt-github-bootstrap'
            signInAudience = 'AzureADMyOrg'
            passwordCredentials = @()
            keyCredentials = @()
        }
        $adapters = New-RecordingAdapters -State $state

        { Invoke-TrustScript -TenantConfigurationPath $configPath -Adapters $adapters -WhatIf } | Should -Throw '*stable Id*'
    }

    It 'rejects non-empty password or key credential collections' {
        $configPath = New-TestTenantConfigurationFile
        $state = New-TrustState
        $state.Application = [ordered]@{
            id = 'app-object-11111111-1111-1111-1111-111111111111'
            appId = 'app-client-11111111-1111-1111-1111-111111111111'
            displayName = 'cal-hr-agentic-bc8rbt-github-bootstrap'
            signInAudience = 'AzureADMyOrg'
            passwordCredentials = @([ordered]@{ keyId = 'cred-1' })
            keyCredentials = @()
        }
        $state.ApplicationsByDisplayName = @($state.Application)
        $state.ServicePrincipal = [ordered]@{
            id = 'sp-object-22222222-2222-2222-2222-222222222222'
            appId = 'app-client-11111111-1111-1111-1111-111111111111'
            displayName = 'cal-hr-agentic-bc8rbt-github-bootstrap'
        }
        $adapters = New-RecordingAdapters -State $state

        { Invoke-TrustScript -TenantConfigurationPath $configPath -Adapters $adapters -WhatIf } | Should -Throw '*credential*'
    }

    It 'writes a BOM-free machine-readable plan without prohibited secret data' {
        $configPath = New-TestTenantConfigurationFile
        $state = New-TrustState
        $adapters = New-RecordingAdapters -State $state
        $planPath = Join-Path $TestDrive 'trust-plan.json'

        $null = Invoke-TrustScript -TenantConfigurationPath $configPath -Adapters $adapters -WhatIf -PlanOutputPath $planPath

        Test-Path -LiteralPath $planPath | Should -BeTrue
        $bytes = [System.IO.File]::ReadAllBytes($planPath)
        ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) | Should -BeFalse

        $text = [System.Text.Encoding]::UTF8.GetString($bytes)
        { $text | ConvertFrom-Json } | Should -Not -Throw
        $text | Should -Not -Match 'AZURE_CLIENT_SECRET|client secret|certificate|token\s*[:=]|password\s*[:=]'
    }

    It 'fails closed when automated read-back mismatches reviewed state' -ForEach @(
        @{
            Name = 'federated credential subject'
            Configure = {
                param($state)
                $state.Application = [ordered]@{ id = 'app-object-11111111-1111-1111-1111-111111111111'; appId = 'app-client-11111111-1111-1111-1111-111111111111'; displayName = 'cal-hr-agentic-bc8rbt-github-bootstrap'; signInAudience = 'AzureADMyOrg'; passwordCredentials = @(); keyCredentials = @() }
                $state.ApplicationsByDisplayName = @($state.Application)
                $state.ServicePrincipal = [ordered]@{ id = 'sp-object-22222222-2222-2222-2222-222222222222'; appId = 'app-client-11111111-1111-1111-1111-111111111111'; displayName = 'cal-hr-agentic-bc8rbt-github-bootstrap' }
                $state.ApplicationPermissions = @(
                    [ordered]@{ resourceAppId = '00000007-0000-0000-c000-000000000000'; resourceDisplayName = 'Microsoft Dataverse'; permissionType = 'Scope'; permissionName = 'user_impersonation' },
                    [ordered]@{ resourceAppId = '00000003-0000-0000-c000-000000000000'; resourceDisplayName = 'Microsoft Graph'; permissionType = 'Role'; permissionName = 'Application.Read.All' }
                )
                $state.FederatedCredential = [ordered]@{ name = 'github-bootstrap'; issuer = 'https://token.actions.githubusercontent.com'; audiences = @('api://AzureADTokenExchange'); subject = 'repo:urruegg@46865858/caldova-hr-frontier@1371297722:environment:bootstrap-other' }
            }
            Error = '*federated credential*'
        },
        @{
            Name = 'GitHub environment protection'
            Configure = {
                param($state)
                $state.Application = [ordered]@{ id = 'app-object-11111111-1111-1111-1111-111111111111'; appId = 'app-client-11111111-1111-1111-1111-111111111111'; displayName = 'cal-hr-agentic-bc8rbt-github-bootstrap'; signInAudience = 'AzureADMyOrg'; passwordCredentials = @(); keyCredentials = @() }
                $state.ApplicationsByDisplayName = @($state.Application)
                $state.ServicePrincipal = [ordered]@{ id = 'sp-object-22222222-2222-2222-2222-222222222222'; appId = 'app-client-11111111-1111-1111-1111-111111111111'; displayName = 'cal-hr-agentic-bc8rbt-github-bootstrap' }
                $state.ApplicationPermissions = @(
                    [ordered]@{ resourceAppId = '00000007-0000-0000-c000-000000000000'; resourceDisplayName = 'Microsoft Dataverse'; permissionType = 'Scope'; permissionName = 'user_impersonation' },
                    [ordered]@{ resourceAppId = '00000003-0000-0000-c000-000000000000'; resourceDisplayName = 'Microsoft Graph'; permissionType = 'Role'; permissionName = 'Application.Read.All' }
                )
                $state.FederatedCredential = [ordered]@{ name = 'github-bootstrap'; issuer = 'https://token.actions.githubusercontent.com'; audiences = @('api://AzureADTokenExchange'); subject = (Get-GitHubOidcSubject -Owner 'urruegg' -OwnerId '46865858' -Repository 'caldova-hr-frontier' -RepositoryId '1371297722' -TenantAlias 'caldova25156897') }
                $state.Environment = [ordered]@{ id = 91234; name = 'bootstrap-caldova25156897'; protected_branches = $false; custom_branch_policies = $true; reviewers = @(); prevent_self_review = $true; branch_name_patterns = @('dev'); deployment_policies = @([ordered]@{ id = 1002; name = 'dev'; type = 'branch' }) }
                $state.PreserveEnvironmentMismatchOnWrite = $true
            }
            Error = '*GitHub Environment*'
        },
        @{
            Name = 'GitHub environment variables'
            Configure = {
                param($state)
                $state.Application = [ordered]@{ id = 'app-object-11111111-1111-1111-1111-111111111111'; appId = 'app-client-11111111-1111-1111-1111-111111111111'; displayName = 'cal-hr-agentic-bc8rbt-github-bootstrap'; signInAudience = 'AzureADMyOrg'; passwordCredentials = @(); keyCredentials = @() }
                $state.ApplicationsByDisplayName = @($state.Application)
                $state.ServicePrincipal = [ordered]@{ id = 'sp-object-22222222-2222-2222-2222-222222222222'; appId = 'app-client-11111111-1111-1111-1111-111111111111'; displayName = 'cal-hr-agentic-bc8rbt-github-bootstrap' }
                $state.ApplicationPermissions = @(
                    [ordered]@{ resourceAppId = '00000007-0000-0000-c000-000000000000'; resourceDisplayName = 'Microsoft Dataverse'; permissionType = 'Scope'; permissionName = 'user_impersonation' },
                    [ordered]@{ resourceAppId = '00000003-0000-0000-c000-000000000000'; resourceDisplayName = 'Microsoft Graph'; permissionType = 'Role'; permissionName = 'Application.Read.All' }
                )
                $state.FederatedCredential = [ordered]@{ name = 'github-bootstrap'; issuer = 'https://token.actions.githubusercontent.com'; audiences = @('api://AzureADTokenExchange'); subject = (Get-GitHubOidcSubject -Owner 'urruegg' -OwnerId '46865858' -Repository 'caldova-hr-frontier' -RepositoryId '1371297722' -TenantAlias 'caldova25156897') }
                $state.Environment = [ordered]@{ id = 91234; name = 'bootstrap-caldova25156897'; protected_branches = $false; custom_branch_policies = $true; reviewers = @([ordered]@{ type = 'User'; reviewer_id = 46865858; login = 'urruegg' }); prevent_self_review = $false; branch_name_patterns = @('main'); deployment_policies = @([ordered]@{ id = 1001; name = 'main'; type = 'branch' }) }
                $state.EnvironmentVariables['AZURE_CLIENT_ID'] = 'wrong-client'
                $state.EnvironmentVariables['AZURE_TENANT_ID'] = 'e2312862-df63-440c-8bcf-007a2c52859d'
                $state.EnvironmentVariables['AZURE_SUBSCRIPTION_ID'] = 'edb45a24-408d-47c4-bbc7-685b9b3fc017'
                $state.PreserveVariableMismatchOnWrite = $true
            }
            Error = '*environment variable*'
        },
        @{
            Name = 'Azure DevOps entitlement'
            Configure = {
                param($state)
                $state.Application = [ordered]@{ id = 'app-object-11111111-1111-1111-1111-111111111111'; appId = 'app-client-11111111-1111-1111-1111-111111111111'; displayName = 'cal-hr-agentic-bc8rbt-github-bootstrap'; signInAudience = 'AzureADMyOrg'; passwordCredentials = @(); keyCredentials = @() }
                $state.ApplicationsByDisplayName = @($state.Application)
                $state.ServicePrincipal = [ordered]@{ id = 'sp-object-22222222-2222-2222-2222-222222222222'; appId = 'app-client-11111111-1111-1111-1111-111111111111'; displayName = 'cal-hr-agentic-bc8rbt-github-bootstrap' }
                $state.ApplicationPermissions = @(
                    [ordered]@{ resourceAppId = '00000007-0000-0000-c000-000000000000'; resourceDisplayName = 'Microsoft Dataverse'; permissionType = 'Scope'; permissionName = 'user_impersonation' },
                    [ordered]@{ resourceAppId = '00000003-0000-0000-c000-000000000000'; resourceDisplayName = 'Microsoft Graph'; permissionType = 'Role'; permissionName = 'Application.Read.All' }
                )
                $state.FederatedCredential = [ordered]@{ name = 'github-bootstrap'; issuer = 'https://token.actions.githubusercontent.com'; audiences = @('api://AzureADTokenExchange'); subject = (Get-GitHubOidcSubject -Owner 'urruegg' -OwnerId '46865858' -Repository 'caldova-hr-frontier' -RepositoryId '1371297722' -TenantAlias 'caldova25156897') }
                $state.Environment = [ordered]@{ id = 91234; name = 'bootstrap-caldova25156897'; protected_branches = $false; custom_branch_policies = $true; reviewers = @([ordered]@{ type = 'User'; reviewer_id = 46865858; login = 'urruegg' }); prevent_self_review = $false; branch_name_patterns = @('main'); deployment_policies = @([ordered]@{ id = 1001; name = 'main'; type = 'branch' }) }
                $state.EnvironmentVariables['AZURE_CLIENT_ID'] = 'app-client-11111111-1111-1111-1111-111111111111'
                $state.EnvironmentVariables['AZURE_TENANT_ID'] = 'e2312862-df63-440c-8bcf-007a2c52859d'
                $state.EnvironmentVariables['AZURE_SUBSCRIPTION_ID'] = 'edb45a24-408d-47c4-bbc7-685b9b3fc017'
                $state.AzureDevOpsEntitlement = [ordered]@{ id = 'ado-entitlement-1'; principalId = 'sp-object-22222222-2222-2222-2222-222222222222'; accessLevel = [ordered]@{ licensingSource = 'account'; accountLicenseType = 'stakeholder' } }
                $state.AzureDevOpsReadersMembership = $true
            }
            Error = '*Azure DevOps entitlement*'
        },
        @{
            Name = 'Azure DevOps Readers membership'
            Configure = {
                param($state)
                $state.Application = [ordered]@{ id = 'app-object-11111111-1111-1111-1111-111111111111'; appId = 'app-client-11111111-1111-1111-1111-111111111111'; displayName = 'cal-hr-agentic-bc8rbt-github-bootstrap'; signInAudience = 'AzureADMyOrg'; passwordCredentials = @(); keyCredentials = @() }
                $state.ApplicationsByDisplayName = @($state.Application)
                $state.ServicePrincipal = [ordered]@{ id = 'sp-object-22222222-2222-2222-2222-222222222222'; appId = 'app-client-11111111-1111-1111-1111-111111111111'; displayName = 'cal-hr-agentic-bc8rbt-github-bootstrap' }
                $state.ApplicationPermissions = @(
                    [ordered]@{ resourceAppId = '00000007-0000-0000-c000-000000000000'; resourceDisplayName = 'Microsoft Dataverse'; permissionType = 'Scope'; permissionName = 'user_impersonation' },
                    [ordered]@{ resourceAppId = '00000003-0000-0000-c000-000000000000'; resourceDisplayName = 'Microsoft Graph'; permissionType = 'Role'; permissionName = 'Application.Read.All' }
                )
                $state.FederatedCredential = [ordered]@{ name = 'github-bootstrap'; issuer = 'https://token.actions.githubusercontent.com'; audiences = @('api://AzureADTokenExchange'); subject = (Get-GitHubOidcSubject -Owner 'urruegg' -OwnerId '46865858' -Repository 'caldova-hr-frontier' -RepositoryId '1371297722' -TenantAlias 'caldova25156897') }
                $state.Environment = [ordered]@{ id = 91234; name = 'bootstrap-caldova25156897'; protected_branches = $false; custom_branch_policies = $true; reviewers = @([ordered]@{ type = 'User'; reviewer_id = 46865858; login = 'urruegg' }); prevent_self_review = $false; branch_name_patterns = @('main'); deployment_policies = @([ordered]@{ id = 1001; name = 'main'; type = 'branch' }) }
                $state.EnvironmentVariables['AZURE_CLIENT_ID'] = 'app-client-11111111-1111-1111-1111-111111111111'
                $state.EnvironmentVariables['AZURE_TENANT_ID'] = 'e2312862-df63-440c-8bcf-007a2c52859d'
                $state.EnvironmentVariables['AZURE_SUBSCRIPTION_ID'] = 'edb45a24-408d-47c4-bbc7-685b9b3fc017'
                $state.AzureDevOpsEntitlement = [ordered]@{ id = 'ado-entitlement-1'; principalId = 'sp-object-22222222-2222-2222-2222-222222222222'; accessLevel = [ordered]@{ licensingSource = 'account'; accountLicenseType = 'express' } }
                $state.AzureDevOpsReadersMembership = $false
                $state.PreserveReadersMembershipMismatchOnWrite = $true
            }
            Error = '*Readers membership*'
        }
    ) {
        $configPath = New-TestTenantConfigurationFile
        $state = New-TrustState
        & $Configure $state
        $adapters = New-RecordingAdapters -State $state

        { Invoke-TrustScript -TenantConfigurationPath $configPath -Adapters $adapters } | Should -Throw $Error
    }

    It 'never contains app credential creation commands or forbidden secret flags' {
        $content = Get-Content -Raw -LiteralPath $script:ScriptPath

        $content | Should -Not -Match 'az\s+ad\s+app\s+credential'
        $content | Should -Not -Match 'credential\s+reset'
        $content | Should -Not -Match '--password|--sdk-auth|AZURE_CLIENT_SECRET|AZURE_CLIENT_CERTIFICATE_PATH'
    }
}