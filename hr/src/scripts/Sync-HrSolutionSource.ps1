[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[a-z0-9]+$')]
    [string]$TenantAlias,

    [Parameter(Mandatory)]
    [string]$SolutionUniqueName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-ModuleManifestPath {
    Join-Path $PSScriptRoot 'modules\Caldova.HrFrontier.Solutions\Caldova.HrFrontier.Solutions.psd1'
}

function Get-SolutionsRoot {
    [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\solutions'))
}

Import-Module (Get-ModuleManifestPath) -Force

$temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ("hr-solution-sync-{0}" -f ([guid]::NewGuid().ToString('N')))
[void](New-Item -ItemType Directory -Path $temporaryDirectory -Force)
$temporaryZipPath = Join-Path $temporaryDirectory "$SolutionUniqueName.zip"

try {
    Write-Output "Connecting to Tenant '$TenantAlias' DEV and exporting solution '$SolutionUniqueName'..."
    $exportResult = Export-HrSolutionPackage -TenantAlias $TenantAlias -SolutionUniqueName $SolutionUniqueName -DestinationPath $temporaryZipPath

    Write-Output "Unpacking into hr/src/solutions/$SolutionUniqueName..."
    $solutionsRoot = Get-SolutionsRoot
    $unpackResult = Expand-HrSolutionPackage -ZipPath $exportResult.Path -SolutionUniqueName $SolutionUniqueName -SolutionsRoot $solutionsRoot

    $solutionXmlPath = Join-Path $unpackResult.Folder 'Other\Solution.xml'
    $solutionVersion = 'unknown'
    if (Test-Path -LiteralPath $solutionXmlPath -PathType Leaf) {
        $solutionXml = [xml](Get-Content -LiteralPath $solutionXmlPath -Raw)
        $solutionVersion = $solutionXml.ImportExportXml.SolutionManifest.Version
    }

    Write-Output ("Synced '{0}' version {1} from {2} into {3}" -f $SolutionUniqueName, $solutionVersion, $exportResult.EnvironmentUrl, $unpackResult.Folder)

    $gitCommand = Get-Command git -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($gitCommand) {
        Write-Output '--- git status for the synced folder ---'
        & $gitCommand.Source status --porcelain -- $unpackResult.Folder
    }
}
finally {
    Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
}
