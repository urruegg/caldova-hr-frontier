@{
    RootModule = 'Caldova.HrFrontier.Solutions.psm1'
    ModuleVersion = '1.0.0'
    GUID = 'e17e045c-0ec6-4427-84c4-6b244b2687ae'
    Author = 'GitHub Copilot'
    CompanyName = 'Caldova'
    Copyright = '(c) Caldova'
    Description = 'Power Platform solution lifecycle helpers for the Caldova HR Frontier HR domain.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Get-HrTenantPowerPlatformUrl',
        'Connect-HrPowerPlatformEnvironment'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
}
