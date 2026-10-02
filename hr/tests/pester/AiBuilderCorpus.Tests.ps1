Set-StrictMode -Version Latest

BeforeAll {
    $script:root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
    $script:ucRoot = Join-Path $script:root (
        'hr\docs\use-cases\uc-0001-personal-master-data-completion-agent'
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

    It 'partitions every tracked PDF into 48 corpus files and 7 immutable evidence files' {
        $trackedPdfs = @(
            git -c core.quotepath=false -C $script:root ls-files -- '*.pdf'
        )
        $LASTEXITCODE | Should -Be 0
        $corpusPrefixes = @(
            'hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-fixed-template/documents/'
            'hr/docs/use-cases/uc-0001-personal-master-data-completion-agent/caldova-aib-general-documents/documents/'
        )
        $corpusPdfs = @($trackedPdfs | Where-Object {
            $path = $_
            @($corpusPrefixes | Where-Object {
                $path.StartsWith($_, [StringComparison]::Ordinal)
            }).Count -eq 1
        })
        $evidencePdfs = @($trackedPdfs | Where-Object {
            $_.StartsWith(
                'hr/evidence/ai-builder/',
                [StringComparison]::Ordinal
            )
        })
        $otherPdfs = @($trackedPdfs | Where-Object {
            $_ -notin $corpusPdfs -and $_ -notin $evidencePdfs
        })

        $trackedPdfs.Count | Should -Be 55
        $corpusPdfs.Count | Should -Be 48
        $evidencePdfs.Count | Should -Be 7
        $otherPdfs | Should -BeNullOrEmpty
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

Describe 'AI Builder maintained generator contract' {
    It 'uses a clearly fictional Caldova entity and address in both copies' {
        foreach ($packagePath in $script:packages.Values) {
            foreach ($name in @('gen_fixed.py', 'gen_general.py')) {
                $content = [IO.File]::ReadAllText(
                    (Join-Path $packagePath "generators\$name")
                )
                $content | Should -Match (
                    'FICTIONAL_ENTITY\s*=\s*"Caldova Fictional HR Lab"'
                )
                $content | Should -Match (
                    'FICTIONAL_ADDRESS\s*=\s*"Fictionalstrasse 1, 9999 Musterstadt"'
                )
                $content | Should -Match 'SYNTHETIC TEST DOCUMENT'
                $content | Should -Match 'Not a real person'
            }
        }
    }

    It 'keeps package-local maintained entry points' {
        $fixedGenerator = [IO.File]::ReadAllText(
            (Join-Path $script:packages.Fixed 'generators\gen_fixed.py')
        )
        $generalGenerator = [IO.File]::ReadAllText(
            (Join-Path $script:packages.General 'generators\gen_general.py')
        )
        $fixedTruth = [IO.File]::ReadAllText(
            (Join-Path $script:packages.Fixed 'generators\gen_truth.py')
        )
        $generalTruth = [IO.File]::ReadAllText(
            (Join-Path $script:packages.General 'generators\gen_truth.py')
        )

        $fixedGenerator | Should -Match (
            'build\(os\.path\.join\(PACKAGE_ROOT,\s*"documents"\)\)'
        )
        $generalGenerator | Should -Match (
            'build\(os\.path\.join\(PACKAGE_ROOT,\s*"documents"\)\)'
        )
        $fixedTruth | Should -Match (
            '(?s)write\(\s*PACKAGE_ROOT,.*?"fixed-template"\s*,?\s*\)'
        )
        $generalTruth | Should -Match (
            '(?s)write\(\s*PACKAGE_ROOT,.*?"general-documents"\s*,?\s*\)'
        )
    }
}
