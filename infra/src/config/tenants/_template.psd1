# Non-secret reviewed tenant configuration template.
@{
    SchemaVersion = '1.0'
    TenantAlias = 'example123456'
    DisplayName = 'Example123456'
    TenantId = '11111111-1111-1111-1111-111111111111'
    AdminUpn = 'admin@example123456.onmicrosoft.com'
    SubscriptionId = '22222222-2222-2222-2222-222222222222'
    PrimaryLocation = 'switzerlandnorth'
    CompanyTla = 'exa'
    WorkloadName = 'hr-agentic'
    UniqueSuffix = 'a1b2c3'
    NamingRoot = 'exa-hr-agentic-a1b2c3'
    LifecycleState = 'DiscoveryRequired'
    GitHub = @{
        Owner = 'urruegg'
        OwnerId = '46865858'
        Repository = 'caldova-hr-frontier'
        RepositoryId = '1371297722'
        EnvironmentName = 'bootstrap-example123456'
    }
    AzureDevOps = @{
        OrganizationUrl = 'https://dev.azure.com/example123456/'
        ProjectName = 'Example HR Frontier'
    }
    PowerPlatform = @{
        DevUrl = 'https://exampledev.crm17.dynamics.com/'
        TestUrl = 'https://exampletest.crm17.dynamics.com/'
        ProdUrl = 'https://example.crm17.dynamics.com/'
    }
    Components = @{}
}