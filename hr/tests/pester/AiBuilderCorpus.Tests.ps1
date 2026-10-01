Set-StrictMode -Version Latest

BeforeAll {
    $script:root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
    $script:ucRoot = Join-Path $script:root (
        'hr\docs\ideas\uc-0001-personal-master-data-completion-agent'
    )
    $script:packages = [ordered]@{
        Fixed = Join-Path $script:ucRoot 'caldova-aib-fixed-template'
        General = Join-Path $script:ucRoot 'caldova-aib-general-documents'
    }
    $script:fieldNames = @(
        'candidate_id', 'last_name', 'first_name', 'dob', 'nationality',
        'marital', 'heimatort', 'permit', 'street', 'plz', 'city', 'ahv',
        'iban', 'phone', 'email', 'ec_name', 'ec_phone'
    )
}

Describe 'AI Builder corpus target paths and truth' {
    It 'has exactly the two Caldova package roots' {
        foreach ($path in $script:packages.Values) {
            $path | Should -Exist
            (Get-Item -LiteralPath $path).PSIsContainer | Should -BeTrue
        }
    }

    It 'uses the target package references in both READMEs and repository safety' {
        $fixedReadme = [IO.File]::ReadAllText(
            (Join-Path $script:packages.Fixed 'README.md')
        )
        $generalReadme = [IO.File]::ReadAllText(
            (Join-Path $script:packages.General 'README.md')
        )
        $safety = [IO.File]::ReadAllText(
            (Join-Path $script:root '.github\cli\tests\RepositorySafety.Tests.ps1')
        )

        $fixedReadme | Should -Match (
            '\.\./caldova-aib-general-documents/README\.md'
        )
        $generalReadme | Should -Match (
            '\.\./caldova-aib-fixed-template/README\.md'
        )
        $safety | Should -Match (
            'caldova-aib-fixed-template/documents/a-personalblatt/' +
            'a01-CAND-2026-0411-brunner\.pdf'
        )
    }

    It 'retains exactly 24 PDFs and 24 truth rows in each package' {
        foreach ($entry in $script:packages.GetEnumerator()) {
            $pdfs = @(Get-ChildItem -LiteralPath (
                Join-Path $entry.Value 'documents'
            ) -Filter '*.pdf' -File -Recurse)
            $csvRows = @(
                Get-Content -LiteralPath (Join-Path $entry.Value 'ground-truth.csv') `
                    -Encoding UTF8 | ConvertFrom-Csv
            )
            $json = Get-Content -LiteralPath (
                Join-Path $entry.Value 'ground-truth.json'
            ) -Raw -Encoding UTF8 | ConvertFrom-Json

            $pdfs.Count | Should -Be 24 -Because "$($entry.Key) PDF count is fixed"
            $csvRows.Count | Should -Be 24
            @($json.documents).Count | Should -Be 24
            [int]$json.field_count | Should -Be 17
        }
    }

    It 'keeps CSV and JSON truth equivalent for every document and field' {
        foreach ($packagePath in $script:packages.Values) {
            $csvRows = @(
                Get-Content -LiteralPath (Join-Path $packagePath 'ground-truth.csv') `
                    -Encoding UTF8 | ConvertFrom-Csv
            )
            $json = Get-Content -LiteralPath (
                Join-Path $packagePath 'ground-truth.json'
            ) -Raw -Encoding UTF8 | ConvertFrom-Json
            $jsonByDocument = @{}
            foreach ($document in $json.documents) {
                $jsonByDocument[[string]$document.document] = $document
            }

            foreach ($row in $csvRows) {
                $jsonByDocument.ContainsKey([string]$row.document) | Should -BeTrue
                $expected = $jsonByDocument[[string]$row.document]
                foreach ($property in @(
                    'document', 'collection_or_layout', 'candidate_id_expected'
                ) + $script:fieldNames) {
                    [string]$row.$property |
                        Should -BeExactly ([string]$expected.$property)
                }
            }
        }
    }
}
