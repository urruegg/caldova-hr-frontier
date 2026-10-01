function New-HrAiBuilderCorpusReviewTemplate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PackagePath,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    $metadata = Get-HrAiBuilderPackageMetadata -PackagePath $PackagePath
    $documents = foreach ($pdf in $metadata.Pdfs | Sort-Object Name) {
        [ordered]@{
            document = $pdf.Name
            status = 'pending'
            values_visible = $false
            absences_confirmed = $false
            reviewer = ''
            notes = ''
        }
    }

    $result = [ordered]@{
        schema_version = '1.0'
        package = $metadata.Package
        documents = @($documents)
    }

    Write-HrAiBuilderJson -InputObject $result -Path $OutputPath
    return Read-HrAiBuilderJson -Path $OutputPath -Description 'Corpus review template'
}
