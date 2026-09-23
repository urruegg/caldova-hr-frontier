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
    LifecycleState = 'IntentReviewed'
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
    Components = @{
        GitHubRepository = @{
            Mode = 'Existing'
            Id = '1371297722'
        }
        EntraApplication = @{
            Mode = 'Create'
        }
        EntraServicePrincipal = @{
            Mode = 'Create'
        }
        EntraFederatedIdentityCredential = @{
            Mode = 'Create'
        }
        GitHubEnvironment = @{
            Mode = 'Create'
        }
        AzureSubscription = @{
            Mode = 'Existing'
            Id = 'edb45a24-408d-47c4-bbc7-685b9b3fc017'
        }
        AzureDevOpsProject = @{
            Mode = 'Existing'
            Id = 'f250378e-597d-487b-854a-fb8338962822'
        }
        AzureDevOpsServicePrincipalEntitlement = @{
            Mode = 'Create'
        }
        AzureDevOpsReadersMembership = @{
            Mode = 'Create'
        }
        PowerPlatformEnvironmentDev = @{
            Mode = 'Existing'
            Id = '346c2cb2-534d-e581-978f-4c293e25a146'
        }
        PowerPlatformEnvironmentTest = @{
            Mode = 'Existing'
            Id = '86fb2f33-4145-e23a-b064-5e0850aba258'
        }
        PowerPlatformEnvironmentProd = @{
            Mode = 'Existing'
            Id = 'c5d83095-c8bf-ec78-94dd-b4e62f34c85e'
        }
    }
}