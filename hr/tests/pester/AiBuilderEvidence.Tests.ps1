Set-StrictMode -Version Latest

Describe 'AI Builder field and corpus contracts' {
    BeforeAll {
        $script:RepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
        $script:ContractPath = Join-Path $script:RepositoryRoot 'hr\src\ai-builder\contracts\field-contract.json'
        $script:UseCaseRoot = Join-Path $script:RepositoryRoot 'hr\docs\ideas\uc-0001-personal-master-data-completion-agent'
        $script:ExpectedContractVersion = '0.1'
        $script:ExpectedFieldDefinitions = @(
            @{ bom_id = 'BOM-0001-F01'; name = 'candidate_id'; ai_builder_type = 'Text'; normalization = 'text' }
            @{ bom_id = 'BOM-0001-F02'; name = 'last_name'; ai_builder_type = 'Text'; normalization = 'text' }
            @{ bom_id = 'BOM-0001-F03'; name = 'first_name'; ai_builder_type = 'Text'; normalization = 'text' }
            @{ bom_id = 'BOM-0001-F04'; name = 'dob'; ai_builder_type = 'Date'; normalization = 'date_ddMMyyyy' }
            @{ bom_id = 'BOM-0001-F05'; name = 'nationality'; ai_builder_type = 'Text'; normalization = 'text' }
            @{ bom_id = 'BOM-0001-F06'; name = 'marital'; ai_builder_type = 'Text'; normalization = 'text' }
            @{ bom_id = 'BOM-0001-F07'; name = 'heimatort'; ai_builder_type = 'Text'; normalization = 'text' }
            @{ bom_id = 'BOM-0001-F08'; name = 'permit'; ai_builder_type = 'Text'; normalization = 'text' }
            @{ bom_id = 'BOM-0001-F09'; name = 'street'; ai_builder_type = 'Text'; normalization = 'text' }
            @{ bom_id = 'BOM-0001-F10'; name = 'plz'; ai_builder_type = 'Text'; normalization = 'text' }
            @{ bom_id = 'BOM-0001-F11'; name = 'city'; ai_builder_type = 'Text'; normalization = 'text' }
            @{ bom_id = 'BOM-0001-F12'; name = 'ahv'; ai_builder_type = 'Text'; normalization = 'text' }
            @{ bom_id = 'BOM-0001-F13'; name = 'iban'; ai_builder_type = 'Text'; normalization = 'text' }
            @{ bom_id = 'BOM-0001-F14'; name = 'phone'; ai_builder_type = 'Text'; normalization = 'text' }
            @{ bom_id = 'BOM-0001-F15'; name = 'email'; ai_builder_type = 'Text'; normalization = 'text' }
            @{ bom_id = 'BOM-0001-F16'; name = 'ec_name'; ai_builder_type = 'Text'; normalization = 'text' }
            @{ bom_id = 'BOM-0001-F17'; name = 'ec_phone'; ai_builder_type = 'Text'; normalization = 'text' }
        )
    }

    It 'defines the ordered 17-field contract and stable BoM IDs' {
        $script:ContractPath | Should -Exist
        $contract = Get-Content -LiteralPath $script:ContractPath -Raw | ConvertFrom-Json

        $contract.contract_version | Should -Be $script:ExpectedContractVersion
        $contract.field_count | Should -Be 17
        @($contract.fields.name) | Should -Be @($script:ExpectedFieldDefinitions.name)
        @($contract.fields.bom_id) | Should -Be @($script:ExpectedFieldDefinitions.bom_id)

        for ($index = 0; $index -lt $script:ExpectedFieldDefinitions.Count; $index++) {
            $expected = $script:ExpectedFieldDefinitions[$index]
            $actual = $contract.fields[$index]

            $actual.bom_id | Should -Be $expected.bom_id
            $actual.name | Should -Be $expected.name
            $actual.ai_builder_type | Should -Be $expected.ai_builder_type
            $actual.normalization | Should -Be $expected.normalization
        }
    }

    It 'contains 24 fixed PDFs and matching ground-truth rows' {
        $root = Join-Path $script:UseCaseRoot 'gf-aib-fixed-template'
        $truth = Get-Content -LiteralPath (Join-Path $root 'ground-truth.json') -Raw | ConvertFrom-Json
        $pdfs = @(Get-ChildItem -LiteralPath (Join-Path $root 'documents') -Filter '*.pdf' -Recurse)

        $pdfs.Count | Should -Be 24
        @($truth.documents).Count | Should -Be 24
        @($truth.documents.document | Sort-Object) |
            Should -Be @($pdfs.Name | Sort-Object)
    }

    It 'contains 24 general PDFs and matching ground-truth rows' {
        $root = Join-Path $script:UseCaseRoot 'gf-aib-general-documents'
        $truth = Get-Content -LiteralPath (Join-Path $root 'ground-truth.json') -Raw | ConvertFrom-Json
        $pdfs = @(Get-ChildItem -LiteralPath (Join-Path $root 'documents') -Filter '*.pdf' -Recurse)

        $pdfs.Count | Should -Be 24
        @($truth.documents).Count | Should -Be 24
        @($truth.documents.document | Sort-Object) |
            Should -Be @($pdfs.Name | Sort-Object)
    }

    It 'keeps CSV and JSON ground truth equivalent for both supplied packages' {
        foreach ($package in @('gf-aib-fixed-template', 'gf-aib-general-documents')) {
            $root = Join-Path $script:UseCaseRoot $package
            $jsonRows = @(
                (Get-Content -LiteralPath (Join-Path $root 'ground-truth.json') -Raw |
                    ConvertFrom-Json).documents
            )
            $csvRows = @(Import-Csv -LiteralPath (Join-Path $root 'ground-truth.csv'))

            $csvRows.Count | Should -Be $jsonRows.Count
            ($csvRows | ConvertTo-Json -Depth 8) |
                Should -Be ($jsonRows | ConvertTo-Json -Depth 8)
        }
    }

    It 'contains the versioned generator source for each supplied package' {
        $expected = @('gen_fixed.py', 'gen_general.py', 'gen_truth.py', 'personas.py')
        foreach ($package in @('gf-aib-fixed-template', 'gf-aib-general-documents')) {
            $generatorRoot = Join-Path (Join-Path $script:UseCaseRoot $package) 'generators'
            @(
                Get-ChildItem -LiteralPath $generatorRoot -File -Filter '*.py' |
                    Select-Object -ExpandProperty Name |
                    Sort-Object
            ) | Should -Be @($expected | Sort-Object)
        }
    }
}
