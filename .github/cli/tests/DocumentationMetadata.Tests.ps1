$null = $null

BeforeAll {
$modulePath = Join-Path $PSScriptRoot '..\modules\DocumentationMetadata.psm1'
$script:metadataScriptPath = Join-Path $PSScriptRoot '..\Set-DocumentationMetadata.ps1'

if (Test-Path -LiteralPath $modulePath -PathType Leaf) {
	Import-Module $modulePath -Force
}
else {
	function Test-DocumentationMetadataEligibility {
		throw 'DocumentationMetadata.psm1 does not exist.'
	}

	function Test-DocumentationMetadataContent {
		throw 'DocumentationMetadata.psm1 does not exist.'
	}

	function Get-DocumentationH1InsertionIndex {
		throw 'DocumentationMetadata.psm1 does not exist.'
	}

	function New-DocumentationMetadataTable {
		throw 'DocumentationMetadata.psm1 does not exist.'
	}
}

function New-ValidMetadataDocument {
	param(
		[string]$Status = 'Active',
		[string]$Scope = 'Repository',
		[string]$References = 'None'
	)

	return @(
		'# Architecture Baseline'
		''
		'| Field | Value |'
		'|---|---|'
		'| **Version** | 1.0 |'
		'| **Date** | 2026-09-18 |'
		'| **Author** | Ada Lovelace |'
		('| **Status** | {0} |' -f $Status)
		('| **Scope** | {0} |' -f $Scope)
		('| **References** | {0} |' -f $References)
		''
		'Body paragraph.'
	) -join "`n"
}

function New-ExpectedMetadataInsertionContent {
	param(
		[string[]]$BodyLines
	)

	return (@(
		'# Architecture Baseline'
		''
		'| Field | Value |'
		'|---|---|'
		'| **Version** | 2.4 |'
		'| **Date** | 2026-09-18 |'
		'| **Author** | Grace Hopper |'
		'| **Status** | Approved |'
		'| **Scope** | Infrastructure |'
		'| **References** | [Architecture](docs/adr/README.md) |'
		''
	) + $BodyLines + @('')) -join "`n"
}

function New-RepositoryTestFile {
	param(
		[Parameter(Mandatory)]
		[string]$RelativePath,

		[Parameter(Mandatory)]
		[string]$Content,

		[Text.Encoding]$Encoding = [Text.UTF8Encoding]::new($false)
	)

	$path = Join-Path $script:testRoot $RelativePath
	$parent = Split-Path -Parent $path
	New-Item -ItemType Directory -Path $parent -Force | Out-Null
	[IO.File]::WriteAllText($path, $Content, $Encoding)
	return $path
}

function Invoke-SetDocumentationMetadata {
	param(
		[Parameter(Mandatory)]
		[string]$Path,

		[string]$References = '[Architecture](docs/adr/README.md)',

		[switch]$WhatIf
	)

	if (-not (Test-Path -LiteralPath $script:metadataScriptPath -PathType Leaf)) {
		throw 'Set-DocumentationMetadata.ps1 does not exist.'
	}

	$parameters = @{
		Path = $Path
		Version = '2.4'
		Date = '2026-09-18'
		Author = 'Grace Hopper'
		Status = 'Approved'
		Scope = 'Infrastructure'
		References = $References
	}
	if ($WhatIf) {
		$parameters.WhatIf = $true
	}

	& $script:metadataScriptPath @parameters
}
}

Describe 'Test-DocumentationMetadataEligibility' {
	It 'returns <Expected> for <Path>' -TestCases @(
		@{ Path = 'README.md'; Expected = $true }
		@{ Path = '.github/agents/docs-agent.agent.md'; Expected = $true }
		@{ Path = '.github/skills/README.md'; Expected = $true }
		@{ Path = '.github\skills\README.md'; Expected = $true }
		@{ Path = './README.md'; Expected = $true }
		@{ Path = '.github/skills/brainstorming/SKILL.md'; Expected = $false }
		@{ Path = '.github/skills/LICENSE.superpowers'; Expected = $false }
		@{ Path = 'LICENSE'; Expected = $false }
		@{ Path = 'infra/evidence/discovery/example.json'; Expected = $false }
		@{ Path = 'docs/architecture.txt'; Expected = $false }
		@{ Path = '.github/skills-not-vendored/example.md'; Expected = $true }
		@{ Path = '../README.md'; Expected = $false }
		@{ Path = 'docs/../README.md'; Expected = $false }
		@{ Path = '/README.md'; Expected = $false }
		@{ Path = 'C:/repo/README.md'; Expected = $false }
	) {
		param($Path, $Expected)

		Test-DocumentationMetadataEligibility -RelativePath $Path |
			Should -Be $Expected
	}
}

Describe 'Test-DocumentationMetadataContent valid documents' {
	It 'accepts an H1, blank line, exact metadata table, and body' {
		@(Test-DocumentationMetadataContent -Content (New-ValidMetadataDocument)).Count |
			Should -Be 0
	}

	It 'accepts agent YAML frontmatter before the H1' {
		$content = @(
			'---'
			'name: docs-agent'
			'description: Documentation agent'
			'---'
			'# Documentation Agent'
			''
			'| Field | Value |'
			'|---|---|'
			'| **Version** | 1.0 |'
			'| **Date** | 2026-09-18 |'
			'| **Author** | Ada Lovelace |'
			'| **Status** | Active |'
			'| **Scope** | Repository |'
			'| **References** | None |'
			''
			'Agent instructions.'
		) -join "`n"

		@(Test-DocumentationMetadataContent -Content $content).Count | Should -Be 0
	}

	It 'accepts an ATX H1 with <IndentCount> leading spaces' -TestCases @(
		@{ IndentCount = 0 }
		@{ IndentCount = 1 }
		@{ IndentCount = 2 }
		@{ IndentCount = 3 }
	) {
		param($IndentCount)

		$heading = (' ' * $IndentCount) + '# Architecture Baseline'
		$content = (New-ValidMetadataDocument).Replace(
			'# Architecture Baseline',
			$heading
		)

		@(Test-DocumentationMetadataContent -Content $content).Count | Should -Be 0
	}

	It 'accepts an ATX H1 whose opening marker is followed by a tab' {
		$content = (New-ValidMetadataDocument).Replace(
			'# Architecture Baseline',
			"#`tArchitecture Baseline"
		)

		@(Test-DocumentationMetadataContent -Content $content).Count | Should -Be 0
	}

	It 'accepts a Setext H1 with underline <Underline>' -TestCases @(
		@{ Underline = '===' }
		@{ Underline = ' ====' }
		@{ Underline = '  ===' }
		@{ Underline = '   ====' }
	) {
		param($Underline)

		$content = (New-ValidMetadataDocument).Replace(
			'# Architecture Baseline',
			("Architecture Baseline`n{0}" -f $Underline)
		)

		@(Test-DocumentationMetadataContent -Content $content).Count | Should -Be 0
	}

	It 'accepts a multiline Setext H1 paragraph' {
		$content = (New-ValidMetadataDocument).Replace(
			'# Architecture Baseline',
			"First title line`nSecond title line`n==="
		)

		@(Test-DocumentationMetadataContent -Content $content).Count | Should -Be 0
	}

	It 'accepts literal None for References' {
		$content = New-ValidMetadataDocument -References 'None'

		@(Test-DocumentationMetadataContent -Content $content).Count | Should -Be 0
	}

	It 'accepts one relative Markdown link for References' {
		$content = New-ValidMetadataDocument `
			-References '[Design](docs/specs/design.md#metadata)'

		@(Test-DocumentationMetadataContent -Content $content).Count | Should -Be 0
	}

	It 'accepts a percent-encoded space in a relative reference destination' {
		$content = New-ValidMetadataDocument `
			-References '[Design](docs/my%20file.md)'

		@(Test-DocumentationMetadataContent -Content $content).Count | Should -Be 0
	}

	It 'accepts multiple comma-separated and semicolon-separated relative links' {
		$content = New-ValidMetadataDocument -References (
			'[Design](docs/specs/design.md), [Plan](docs/plans/plan.md#task-2); [Root](#metadata)'
		)

		@(Test-DocumentationMetadataContent -Content $content).Count | Should -Be 0
	}

	It 'accepts an allowed status prefix with a parenthesized qualifier' {
		$content = New-ValidMetadataDocument `
			-Status 'Active (consolidated from current state)'

		@(Test-DocumentationMetadataContent -Content $content).Count | Should -Be 0
	}

	It 'accepts base status <Status>' -TestCases @(
		@{ Status = 'Draft' }
		@{ Status = 'Proposed Baseline' }
		@{ Status = 'Active' }
		@{ Status = 'Approved' }
		@{ Status = 'Superseded' }
		@{ Status = 'Archived' }
	) {
		param($Status)

		$content = New-ValidMetadataDocument -Status $Status

		@(Test-DocumentationMetadataContent -Content $content).Count | Should -Be 0
	}

	It 'accepts base scope <Scope>' -TestCases @(
		@{ Scope = 'Repository' }
		@{ Scope = 'Cross-cutting (all solution domains)' }
		@{ Scope = 'Infrastructure' }
		@{ Scope = 'HR' }
		@{ Scope = 'Data' }
	) {
		param($Scope)

		$content = New-ValidMetadataDocument -Scope $Scope

		@(Test-DocumentationMetadataContent -Content $content).Count | Should -Be 0
	}

	It 'accepts a nonempty explicitly named custom solution domain' {
		$content = New-ValidMetadataDocument -Scope 'Recruiting Operations'

		@(Test-DocumentationMetadataContent -Content $content).Count | Should -Be 0
	}

	It 'ignores H1 examples inside fenced code blocks' {
		$content = (New-ValidMetadataDocument) + (@(
			''
			'```markdown'
			'```text'
			'# Example only'
			'   # Indented example only'
			'Setext example only'
			'==='
			'```'
		) -join "`n")

		@(Test-DocumentationMetadataContent -Content $content).Count | Should -Be 0
	}
}

Describe 'Test-DocumentationMetadataContent metadata boundary detection' {
	BeforeAll {
		$script:repositoryRoot = [IO.Path]::GetFullPath((
			Join-Path $PSScriptRoot '..\..\..'
		))
		$script:testRootName = '.documentation-metadata-boundary-tests-{0}' -f (
			[Guid]::NewGuid().ToString('N')
		)
		$script:testRoot = Join-Path $script:repositoryRoot $script:testRootName
		New-Item -ItemType Directory -Path $script:testRoot -Force | Out-Null
	}

	AfterAll {
		if (Test-Path -LiteralPath $script:testRoot) {
			Remove-Item -LiteralPath $script:testRoot -Recurse -Force
		}
	}

	It 'treats later body tables with metadata-looking rows as ordinary body content' {
		$content = @(
			'# Architecture Baseline'
			'Introductory body text.'
			''
			'The following example table is part of the body.'
			''
			'| Kind | Value |'
			'|---|---|'
			'| **Version** | 1.0 |'
			'| **Scope** | Example |'
		) -join "`n"
		$path = New-RepositoryTestFile `
			-RelativePath 'later-body-table.md' `
			-Content ($content + "`n")

		$failures = @(Test-DocumentationMetadataContent -Content $content)
		$failures.Count | Should -Be 1
		$failures[0] | Should -BeExactly 'Documentation metadata is missing.'

		Invoke-SetDocumentationMetadata -Path $path | Out-Null
		[IO.File]::ReadAllText($path) | Should -BeExactly (
			New-ExpectedMetadataInsertionContent -BodyLines @(
				'Introductory body text.'
				''
				'The following example table is part of the body.'
				''
				'| Kind | Value |'
				'|---|---|'
				'| **Version** | 1.0 |'
				'| **Scope** | Example |'
			)
		)
	}

	It 'ignores a complete metadata-looking table inside a fenced code block' {
		$content = @(
			'# Architecture Baseline'
			'Body paragraph.'
			''
			'```markdown'
			'| Field | Value |'
			'|---|---|'
			'| **Version** | 1.0 |'
			'| **Date** | 2026-09-18 |'
			'| **Author** | Ada Lovelace |'
			'| **Status** | Active |'
			'| **Scope** | Example |'
			'| **References** | None |'
			'```'
		) -join "`n"
		$expectedBodyLines = @(
			'Body paragraph.'
			''
			'```markdown'
			'| Field | Value |'
			'|---|---|'
			'| **Version** | 1.0 |'
			'| **Date** | 2026-09-18 |'
			'| **Author** | Ada Lovelace |'
			'| **Status** | Active |'
			'| **Scope** | Example |'
			'| **References** | None |'
			'```'
		)
		$path = New-RepositoryTestFile `
			-RelativePath 'fenced-metadata-example.md' `
			-Content ($content + "`n")

		$failures = @(Test-DocumentationMetadataContent -Content $content)
		$failures.Count | Should -Be 1
		$failures[0] | Should -BeExactly 'Documentation metadata is missing.'

		Invoke-SetDocumentationMetadata -Path $path | Out-Null
		[IO.File]::ReadAllText($path) | Should -BeExactly (
			New-ExpectedMetadataInsertionContent -BodyLines $expectedBodyLines
		)
	}

	It 'treats a later body table in a Setext document as ordinary body content' {
		$content = @(
			'Architecture Baseline'
			'==='
			'Body paragraph.'
			''
			'| Kind | Value |'
			'|---|---|'
			'| **Version** | 1.0 |'
			'| **Scope** | Example |'
		) -join "`n"
		$path = New-RepositoryTestFile `
			-RelativePath 'setext-later-body-table.md' `
			-Content ($content + "`n")

		$failures = @(Test-DocumentationMetadataContent -Content $content)
		$failures.Count | Should -Be 1
		$failures[0] | Should -BeExactly 'Documentation metadata is missing.'

		Invoke-SetDocumentationMetadata -Path $path | Out-Null
		$expected = @(
			'Architecture Baseline'
			'==='
			''
			'| Field | Value |'
			'|---|---|'
			'| **Version** | 2.4 |'
			'| **Date** | 2026-09-18 |'
			'| **Author** | Grace Hopper |'
			'| **Status** | Approved |'
			'| **Scope** | Infrastructure |'
			'| **References** | [Architecture](docs/adr/README.md) |'
			''
			'Body paragraph.'
			''
			'| Kind | Value |'
			'|---|---|'
			'| **Version** | 1.0 |'
			'| **Scope** | Example |'
			''
		) -join "`n"
		[IO.File]::ReadAllText($path) | Should -BeExactly $expected
	}

	It 'rejects a partial metadata table immediately after H1 and refuses migration' {
		$content = @(
			'# Architecture Baseline'
			''
			'| Field | Value |'
			'|---|---|'
			'| **Version** | 1.0 |'
			'| **Scope** | Example |'
			''
			'Body paragraph.'
		) -join "`n"
		$path = New-RepositoryTestFile `
			-RelativePath 'partial-metadata-after-h1.md' `
			-Content ($content + "`n")

		$failures = @(Test-DocumentationMetadataContent -Content $content)
		$failures | Should -Contain 'Existing documentation metadata is malformed or partial.'

		{ Invoke-SetDocumentationMetadata -Path $path } |
			Should -Throw '*malformed or partial metadata*'
	}

	It 'rejects a bad-separator metadata table immediately after H1' {
		$content = @(
			'# Architecture Baseline'
			''
			'| Field | Value |'
			'| --- | --- |'
			'| **Version** | 1.0 |'
			'| **Date** | 2026-09-18 |'
			'| **Author** | Ada Lovelace |'
			'| **Status** | Active |'
			'| **Scope** | Repository |'
			'| **References** | None |'
			''
			'Body paragraph.'
		) -join "`n"
		$path = New-RepositoryTestFile `
			-RelativePath 'bad-separator-after-h1.md' `
			-Content ($content + "`n")

		$failures = @(Test-DocumentationMetadataContent -Content $content)
		$failures | Should -Contain 'Metadata table separator must be exactly |---|---|.'
		$failures | Should -Contain 'Existing documentation metadata is malformed or partial.'

		{ Invoke-SetDocumentationMetadata -Path $path } |
			Should -Throw '*malformed or partial metadata*'
	}

	It 'treats a non-metadata body table immediately after H1 as ordinary body content' {
		$content = @(
			'# Architecture Baseline'
			'Body paragraph.'
			''
			'| Kind | Value |'
			'|---|---|'
			'| Label | Example |'
			'| Notes | Ordinary body table |'
		) -join "`n"
		$path = New-RepositoryTestFile `
			-RelativePath 'body-table-after-h1.md' `
			-Content ($content + "`n")

		$failures = @(Test-DocumentationMetadataContent -Content $content)
		$failures.Count | Should -Be 1
		$failures[0] | Should -BeExactly 'Documentation metadata is missing.'

		Invoke-SetDocumentationMetadata -Path $path | Out-Null
		[IO.File]::ReadAllText($path) | Should -BeExactly (
			New-ExpectedMetadataInsertionContent -BodyLines @(
				'Body paragraph.'
				''
				'| Kind | Value |'
				'|---|---|'
				'| Label | Example |'
				'| Notes | Ordinary body table |'
			)
		)
	}
}

Describe 'Test-DocumentationMetadataContent invalid documents' {
	It 'counts empty ATX H1 blocks when enforcing the one-H1 invariant' -TestCases @(
		@{ EmptyHeading = '#' }
		@{ EmptyHeading = '# ' }
	) {
		param($EmptyHeading)

		$content = $EmptyHeading + "`n" + (New-ValidMetadataDocument)
		$failures = @(Test-DocumentationMetadataContent -Content $content)

		$failures | Should -Contain (
			'Document must contain exactly one H1 outside frontmatter and fenced examples; found 2.'
		)
	}

	It 'rejects a sole empty ATX H1 as lacking a usable title' -TestCases @(
		@{ EmptyHeading = '#' }
		@{ EmptyHeading = '# ' }
	) {
		param($EmptyHeading)

		$content = (New-ValidMetadataDocument).Replace(
			'# Architecture Baseline',
			$EmptyHeading
		)

		@(Test-DocumentationMetadataContent -Content $content) |
			Should -Contain 'Document must contain a usable H1 title.'
	}

	It 'rejects a document with no H1' {
		$content = (New-ValidMetadataDocument).Replace(
			'# Architecture Baseline',
			'Architecture Baseline'
		)

		@(Test-DocumentationMetadataContent -Content $content) |
			Should -Not -BeNullOrEmpty
	}

	It 'rejects a four-space indented ATX heading' {
		$content = (New-ValidMetadataDocument).Replace(
			'# Architecture Baseline',
			'    # Not a heading'
		)

		@(Test-DocumentationMetadataContent -Content $content) |
			Should -Not -BeNullOrEmpty
	}

	It 'rejects unclosed YAML frontmatter' {
		$content = @(
			'---'
			'name: docs-agent'
			'# Documentation Agent'
			''
			'| Field | Value |'
		) -join "`n"

		@(Test-DocumentationMetadataContent -Content $content) |
			Should -Not -BeNullOrEmpty
	}

	It 'rejects body content before the metadata table' {
		$content = (New-ValidMetadataDocument).Replace(
			"# Architecture Baseline`n`n| Field | Value |",
			"# Architecture Baseline`n`nPremature body.`n`n| Field | Value |"
		)

		@(Test-DocumentationMetadataContent -Content $content) |
			Should -Not -BeNullOrEmpty
	}

	It 'rejects a nonexact metadata header' {
		$content = (New-ValidMetadataDocument).Replace(
			'| Field | Value |',
			'| Name | Value |'
		)

		@(Test-DocumentationMetadataContent -Content $content) |
			Should -Not -BeNullOrEmpty
	}

	It 'rejects a nonexact metadata separator' {
		$content = (New-ValidMetadataDocument).Replace(
			'|---|---|',
			'| --- | --- |'
		)

		@(Test-DocumentationMetadataContent -Content $content) |
			Should -Not -BeNullOrEmpty
	}

	It 'rejects a missing metadata field' {
		$content = (New-ValidMetadataDocument).Replace(
			"| **Author** | Ada Lovelace |`n",
			''
		)

		@(Test-DocumentationMetadataContent -Content $content) |
			Should -Not -BeNullOrEmpty
	}

	It 'rejects a duplicate metadata field' {
		$content = (New-ValidMetadataDocument).Replace(
			'| **Scope** | Repository |',
			'| **Author** | Grace Hopper |'
		)

		@(Test-DocumentationMetadataContent -Content $content) |
			Should -Not -BeNullOrEmpty
	}

	It 'rejects metadata fields out of order' {
		$content = @(
			'# Architecture Baseline'
			''
			'| Field | Value |'
			'|---|---|'
			'| **Date** | 2026-09-18 |'
			'| **Version** | 1.0 |'
			'| **Author** | Ada Lovelace |'
			'| **Status** | Active |'
			'| **Scope** | Repository |'
			'| **References** | None |'
			''
			'Body paragraph.'
		) -join "`n"

		@(Test-DocumentationMetadataContent -Content $content) |
			Should -Not -BeNullOrEmpty
	}

	It 'rejects an empty metadata field' {
		$content = (New-ValidMetadataDocument).Replace(
			'| **Author** | Ada Lovelace |',
			'| **Author** |  |'
		)

		@(Test-DocumentationMetadataContent -Content $content) |
			Should -Not -BeNullOrEmpty
	}

	It 'rejects an unbolded metadata field label' {
		$content = (New-ValidMetadataDocument).Replace(
			'| **Version** | 1.0 |',
			'| Version | 1.0 |'
		)

		@(Test-DocumentationMetadataContent -Content $content) |
			Should -Not -BeNullOrEmpty
	}

	It 'rejects invalid version <Version>' -TestCases @(
		@{ Version = '1' }
		@{ Version = '1.0.0' }
		@{ Version = '-1.0' }
		@{ Version = '01.0' }
	) {
		param($Version)

		$content = (New-ValidMetadataDocument).Replace(
			'| **Version** | 1.0 |',
			('| **Version** | {0} |' -f $Version)
		)

		@(Test-DocumentationMetadataContent -Content $content) |
			Should -Not -BeNullOrEmpty
	}

	It 'rejects invalid date <Date>' -TestCases @(
		@{ Date = '2026-02-30' }
		@{ Date = '2026-9-18' }
		@{ Date = '18-09-2026' }
	) {
		param($Date)

		$content = (New-ValidMetadataDocument).Replace(
			'| **Date** | 2026-09-18 |',
			('| **Date** | {0} |' -f $Date)
		)

		@(Test-DocumentationMetadataContent -Content $content) |
			Should -Not -BeNullOrEmpty
	}

	It 'rejects invalid status <Status>' -TestCases @(
		@{ Status = 'In Review' }
		@{ Status = 'Active now' }
		@{ Status = 'Approved (' }
		@{ Status = 'Active ()' }
		@{ Status = 'Active ( )' }
		@{ Status = 'Active (reviewed) trailing)' }
		@{ Status = 'Active (reviewed (nested))' }
		@{ Status = 'Active (reviewed))' }
		@{ Status = 'Active ((reviewed)' }
	) {
		param($Status)

		$content = New-ValidMetadataDocument -Status $Status

		@(Test-DocumentationMetadataContent -Content $content) |
			Should -Not -BeNullOrEmpty
	}

	It 'rejects an empty author' {
		$content = (New-ValidMetadataDocument).Replace(
			'| **Author** | Ada Lovelace |',
			'| **Author** |  |'
		)

		@(Test-DocumentationMetadataContent -Content $content) |
			Should -Not -BeNullOrEmpty
	}

	It 'rejects unsafe scope <Scope>' -TestCases @(
		@{ Scope = ' Data' }
		@{ Scope = 'Data ' }
		@{ Scope = 'Data|HR' }
		@{ Scope = "Data$([char]1)Domain" }
	) {
		param($Scope)

		$content = New-ValidMetadataDocument -Scope $Scope

		@(Test-DocumentationMetadataContent -Content $content) |
			Should -Not -BeNullOrEmpty
	}

	It 'rejects invalid References <References>' -TestCases @(
		@{ References = '' }
		@{ References = 'Architecture decision' }
		@{ References = '[External](https://example.com/design)' }
		@{ References = '[Mail](mailto:docs@example.com)' }
		@{ References = '[Broken](docs/specs/design.md' }
		@{ References = '[](docs/specs/design.md)' }
		@{ References = '[Rooted](/docs/specs/design.md)' }
		@{ References = '[Raw space](docs/my file.md)' }
		@{ References = "[Tab](docs/my`tfile.md)" }
		@{ References = "[Control](docs/my$([char]1)file.md)" }
		@{ References = '[Backslash](docs\specs\design.md)' }
		@{ References = '[Drive](C:/docs/specs/design.md)' }
		@{ References = '[Parent](../plans/plan.md)' }
		@{ References = '[Encoded parent](docs/%2E%2E/secrets.md)' }
		@{ References = '[Unsafe|Label](docs/specs/design.md)' }
		@{ References = '[Broken[Label](docs/specs/design.md)' }
	) {
		param($References)

		$content = New-ValidMetadataDocument -References $References

		@(Test-DocumentationMetadataContent -Content $content) |
			Should -Not -BeNullOrEmpty
	}

	It 'rejects an extra metadata row before the body' {
		$content = (New-ValidMetadataDocument).Replace(
			"| **References** | None |`n`nBody paragraph.",
			"| **References** | None |`n| **Owner** | Platform |`n`nBody paragraph."
		)

		@(Test-DocumentationMetadataContent -Content $content) |
			Should -Not -BeNullOrEmpty
	}

	It 'rejects a nonblank line immediately after References' {
		$content = (New-ValidMetadataDocument).Replace(
			"| **References** | None |`n`nBody paragraph.",
			"| **References** | None |`nBody paragraph."
		)

		@(Test-DocumentationMetadataContent -Content $content) |
			Should -Not -BeNullOrEmpty
	}

	It 'rejects more than one rendered H1' {
		$content = (New-ValidMetadataDocument) + "`n`n# Second Title"

		@(Test-DocumentationMetadataContent -Content $content) |
			Should -Not -BeNullOrEmpty
	}

	It 'rejects mixed ATX and Setext H1 styles' {
		$content = (New-ValidMetadataDocument) + "`n`nSecond Title`n==="

		@(Test-DocumentationMetadataContent -Content $content) |
			Should -Not -BeNullOrEmpty
	}
}

Describe 'Source-aware documentation references' {
	BeforeAll {
		$script:repositoryRoot = [IO.Path]::GetFullPath((
			Join-Path $PSScriptRoot '..\..\..'
		))
		$script:testRootName = '.documentation-metadata-source-aware-tests-{0}' -f (
			[Guid]::NewGuid().ToString('N')
		)
		$script:testRoot = Join-Path $script:repositoryRoot $script:testRootName
		New-Item -ItemType Directory -Path $script:testRoot -Force | Out-Null
	}

	AfterAll {
		if (Test-Path -LiteralPath $script:testRoot) {
			Remove-Item -LiteralPath $script:testRoot -Recurse -Force
		}
	}

	It 'accepts a bounded parent reference with document context' -Tag 'SourceAwareReferences' {
		$content = New-ValidMetadataDocument `
			-References '[Spec](../specs/design.md)'

		@(Test-DocumentationMetadataContent `
			-Content $content `
			-DocumentRelativePath 'docs/plans/plan.md').Count | Should -Be 0
	}

	It 'rejects a plain parent reference that escapes the repository root' -Tag 'SourceAwareReferences' {
		$content = New-ValidMetadataDocument `
			-References '[Escape](../secrets.md)'

		@(Test-DocumentationMetadataContent `
			-Content $content `
			-DocumentRelativePath 'README.md') |
			Should -Contain 'References must be None or relative Markdown links only.'
	}

	It 'rejects a percent-encoded parent reference that escapes the repository root' -Tag 'SourceAwareReferences' {
		$content = New-ValidMetadataDocument `
			-References '[Escape](%2E%2E/secrets.md)'

		@(Test-DocumentationMetadataContent `
			-Content $content `
			-DocumentRelativePath 'README.md') |
			Should -Contain 'References must be None or relative Markdown links only.'
	}

	It 'rejects non-normalized document context <DocumentRelativePath>' `
		-Tag 'SourceAwareReferences' `
		-TestCases @(
			@{ DocumentRelativePath = '/docs/plans/plan.md' }
			@{ DocumentRelativePath = 'C:/repo/docs/plans/plan.md' }
			@{ DocumentRelativePath = 'docs\plans\plan.md' }
			@{ DocumentRelativePath = 'docs/./plans/plan.md' }
			@{ DocumentRelativePath = 'docs/../plans/plan.md' }
		) {
		param($DocumentRelativePath)

		$content = New-ValidMetadataDocument

		@(Test-DocumentationMetadataContent `
			-Content $content `
			-DocumentRelativePath $DocumentRelativePath) |
			Should -Contain 'References must be None or relative Markdown links only.'
	}

	It 'rejects parent traversal without document context' -Tag 'SourceAwareReferences' {
		$content = New-ValidMetadataDocument `
			-References '[Spec](../specs/design.md)'

		@(Test-DocumentationMetadataContent -Content $content) |
			Should -Contain 'References must be None or relative Markdown links only.'
	}

	It 'lets the setter migrate a bounded parent reference using the document path' -Tag 'SourceAwareReferences' {
		$path = New-RepositoryTestFile `
			-RelativePath 'docs\plans\plan.md' `
			-Content "# Plan`n`nBody.`n"

		Invoke-SetDocumentationMetadata `
			-Path $path `
			-References '[Spec](../specs/design.md)' | Out-Null

		$relativePath = '{0}/docs/plans/plan.md' -f $script:testRootName
		$content = [IO.File]::ReadAllText($path)
		$content | Should -Match '\| \*\*References\*\* \| \[Spec\]\(\.\./specs/design\.md\) \|'
		@(Test-DocumentationMetadataContent `
			-Content $content `
			-DocumentRelativePath $relativePath).Count | Should -Be 0
	}
}

Describe 'Get-DocumentationH1InsertionIndex CommonMark parsing' {
	It 'does not recognize malformed or non-H1 ATX opening sequences in <Case>' -TestCases @(
		@{ Case = 'missing marker whitespace'; Line = '#Title' }
		@{ Case = 'level-two heading'; Line = '## Title' }
		@{ Case = 'tab-indented code'; Line = "`t# Title" }
	) {
		param($Line)

		{ Get-DocumentationH1InsertionIndex -Content $Line } |
			Should -Throw '*exactly one H1; found 0*'
	}

	It 'does not let a leading tab open a <FenceName>' -TestCases @(
		@{ FenceName = 'backtick fence'; Fence = '```' }
		@{ FenceName = 'tilde fence'; Fence = '~~~' }
	) {
		param($Fence)

		$content = @(
			"`t$Fence"
			'# Visible Title'
		) -join "`n"

		Get-DocumentationH1InsertionIndex -Content $content | Should -Be 1
	}

	It 'opens a <FenceName> with <IndentCount> leading spaces and ignores its H1' -TestCases @(
		@{ FenceName = 'backtick fence'; Fence = '```'; IndentCount = 0 }
		@{ FenceName = 'backtick fence'; Fence = '```'; IndentCount = 1 }
		@{ FenceName = 'backtick fence'; Fence = '```'; IndentCount = 2 }
		@{ FenceName = 'backtick fence'; Fence = '```'; IndentCount = 3 }
		@{ FenceName = 'tilde fence'; Fence = '~~~'; IndentCount = 0 }
		@{ FenceName = 'tilde fence'; Fence = '~~~'; IndentCount = 1 }
		@{ FenceName = 'tilde fence'; Fence = '~~~'; IndentCount = 2 }
		@{ FenceName = 'tilde fence'; Fence = '~~~'; IndentCount = 3 }
	) {
		param($Fence, $IndentCount)

		$content = @(
			((' ' * $IndentCount) + $Fence)
			'# Hidden Example'
			$Fence
			'# Visible Title'
		) -join "`n"

		Get-DocumentationH1InsertionIndex -Content $content | Should -Be 3
	}

	It 'does not open a four-space-indented <FenceName>' -TestCases @(
		@{ FenceName = 'backtick fence'; Fence = '```' }
		@{ FenceName = 'tilde fence'; Fence = '~~~' }
	) {
		param($Fence)

		$content = @(
			("    {0}" -f $Fence)
			'# Visible Title'
		) -join "`n"

		Get-DocumentationH1InsertionIndex -Content $content | Should -Be 1
	}

	It 'uses the Setext underline as the insertion boundary for <Underline>' -TestCases @(
		@{ Underline = '===' }
		@{ Underline = ' ===' }
		@{ Underline = '  ===' }
		@{ Underline = '   ===' }
	) {
		param($Underline)

		Get-DocumentationH1InsertionIndex -Content ("Title`n{0}" -f $Underline) |
			Should -Be 1
	}

	It 'uses the underline after a multiline paragraph as the insertion boundary' {
		$content = "First title line`nSecond title line`n==="

		Get-DocumentationH1InsertionIndex -Content $content | Should -Be 2
	}

	It 'does not form a Setext H1 from <Case>' -TestCases @(
		@{ Case = 'four-space-indented title code'; Content = "    Code title`n===" }
		@{ Case = 'four-space-indented underline'; Content = "Title`n    ===" }
		@{ Case = 'paragraph separated by a blank'; Content = "Title`n`n===" }
		@{ Case = 'a fenced block closing line'; Content = "```text`nFenced title`n````n===" }
		@{ Case = 'a level-two Setext underline'; Content = "Title`n---" }
	) {
		param($Content)

		{ Get-DocumentationH1InsertionIndex -Content $Content } |
			Should -Throw '*exactly one H1; found 0*'
	}

	It 'does not reinterpret an ATX heading as Setext paragraph content' {
		$content = "# ATX Title`n==="

		Get-DocumentationH1InsertionIndex -Content $content | Should -Be 0
	}
}

Describe 'New-DocumentationMetadataTable' {
	It 'returns the exact eight LF-separated lines without a trailing newline' {
		$table = New-DocumentationMetadataTable `
			-Version '9.8' `
			-Date '2026-09-18' `
			-Author 'Katherine Johnson' `
			-Status 'Proposed Baseline' `
			-Scope 'Cross-cutting (all solution domains)' `
			-References '[Decision](docs/adr/0001.md#decision)'
		$expected = @(
			'| Field | Value |'
			'|---|---|'
			'| **Version** | 9.8 |'
			'| **Date** | 2026-09-18 |'
			'| **Author** | Katherine Johnson |'
			'| **Status** | Proposed Baseline |'
			'| **Scope** | Cross-cutting (all solution domains) |'
			'| **References** | [Decision](docs/adr/0001.md#decision) |'
		) -join "`n"

		$table | Should -BeExactly $expected
		$table.EndsWith("`n", [StringComparison]::Ordinal) | Should -BeFalse
		$table.Split("`n").Count | Should -Be 8
		foreach ($value in @(
			'9.8',
			'2026-09-18',
			'Katherine Johnson',
			'Proposed Baseline',
			'Cross-cutting (all solution domains)',
			'[Decision](docs/adr/0001.md#decision)'
		)) {
			[regex]::Matches($table, [regex]::Escape($value)).Count |
				Should -Be 1
		}
	}
}

Describe 'Set-DocumentationMetadata.ps1' {
	BeforeAll {
		$script:repositoryRoot = [IO.Path]::GetFullPath((
			Join-Path $PSScriptRoot '..\..\..'
		))
		$script:testRootName = '.documentation-metadata-tests-{0}' -f (
			[Guid]::NewGuid().ToString('N')
		)
		$script:testRoot = Join-Path $script:repositoryRoot $script:testRootName
		New-Item -ItemType Directory -Path $script:testRoot -Force | Out-Null
	}

	AfterAll {
		if (Test-Path -LiteralPath $script:testRoot) {
			Remove-Item -LiteralPath $script:testRoot -Recurse -Force
		}
	}

	It 'leaves a file byte-identical under WhatIf' {
		$path = New-RepositoryTestFile `
			-RelativePath 'what-if.md' `
			-Content "# What If`r`n`r`nOriginal body.`r`n" `
			-Encoding ([Text.UTF8Encoding]::new($true))
		$before = [IO.File]::ReadAllBytes($path)

		Invoke-SetDocumentationMetadata -Path $path -WhatIf

		[Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) |
			Should -Be ([Convert]::ToBase64String($before))
	}

	It 'rejects excluded repository paths without changing them' -TestCases @(
		@{ RelativePath = 'LICENSE' }
		@{ RelativePath = '.github/skills/LICENSE.superpowers' }
		@{ RelativePath = '.github/skills/brainstorming/SKILL.md' }
	) {
		param($RelativePath)

		$path = Join-Path $script:repositoryRoot $RelativePath
		$before = [IO.File]::ReadAllBytes($path)

		{ Invoke-SetDocumentationMetadata -Path $path } |
			Should -Throw '*not eligible*'
		[Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) |
			Should -Be ([Convert]::ToBase64String($before))
	}

	It 'rejects a document with no H1 without changing it' {
		$path = New-RepositoryTestFile `
			-RelativePath 'missing-h1.md' `
			-Content "Body without a title.`n"
		$before = [IO.File]::ReadAllBytes($path)

		{ Invoke-SetDocumentationMetadata -Path $path } |
			Should -Throw '*exactly one H1*'
		[Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) |
			Should -Be ([Convert]::ToBase64String($before))
	}

	It 'leaves valid metadata byte-identical and prints the exact relative path message' {
		$content = (New-ValidMetadataDocument).Replace("`n", "`r`n") + "`r`n"
		$path = New-RepositoryTestFile `
			-RelativePath 'already-valid.md' `
			-Content $content `
			-Encoding ([Text.UTF8Encoding]::new($true))
		$before = [IO.File]::ReadAllBytes($path)
		$relativePath = '{0}/already-valid.md' -f $script:testRootName

		$output = @(Invoke-SetDocumentationMetadata -Path $path)

		$output.Count | Should -Be 1
		$output[0] | Should -BeExactly "Metadata already valid: $relativePath"
		[Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) |
			Should -Be ([Convert]::ToBase64String($before))
	}

	It 'adds metadata while preserving frontmatter, H1, and body content' {
		$sourceContent = @(
			'---'
			'name: docs-agent'
			'description: Existing agent'
			'---'
			'# Existing Title'
			''
			''
			'Existing body line.'
			'Second body line.'
		) -join "`r`n"
		$path = New-RepositoryTestFile `
			-RelativePath 'nested\add-metadata.agent.md' `
			-Content ($sourceContent + "`r`n") `
			-Encoding ([Text.UTF8Encoding]::new($true))
		$sentinelPath = New-RepositoryTestFile `
			-RelativePath 'nested\sentinel.txt' `
			-Content 'unchanged sentinel'
		$sentinelBefore = [IO.File]::ReadAllBytes($sentinelPath)
		$expected = @(
			'---'
			'name: docs-agent'
			'description: Existing agent'
			'---'
			'# Existing Title'
			''
			'| Field | Value |'
			'|---|---|'
			'| **Version** | 2.4 |'
			'| **Date** | 2026-09-18 |'
			'| **Author** | Grace Hopper |'
			'| **Status** | Approved |'
			'| **Scope** | Infrastructure |'
			'| **References** | [Architecture](docs/adr/README.md) |'
			''
			''
			''
			'Existing body line.'
			'Second body line.'
			''
		) -join "`n"

		Invoke-SetDocumentationMetadata -Path $path | Out-Null

		$bytes = [IO.File]::ReadAllBytes($path)
		[IO.File]::ReadAllText($path) | Should -BeExactly $expected
		($bytes.Length -ge 3 -and
			$bytes[0] -eq 0xEF -and
			$bytes[1] -eq 0xBB -and
			$bytes[2] -eq 0xBF) | Should -BeFalse
		[IO.File]::ReadAllText($path).Contains("`r") | Should -BeFalse
		[Convert]::ToBase64String([IO.File]::ReadAllBytes($sentinelPath)) |
			Should -Be ([Convert]::ToBase64String($sentinelBefore))
		@(Get-ChildItem -LiteralPath (Split-Path -Parent $path) -File -Force).Count |
			Should -Be 2
	}

	It 'inserts metadata after an ATX H1 with <IndentCount> leading spaces' -TestCases @(
		@{ IndentCount = 1; RelativePath = 'indented-atx-1.md' }
		@{ IndentCount = 2; RelativePath = 'indented-atx-2.md' }
		@{ IndentCount = 3; RelativePath = 'indented-atx-3.md' }
	) {
		param($IndentCount, $RelativePath)

		$heading = (' ' * $IndentCount) + '# Indented Title'
		$path = New-RepositoryTestFile `
			-RelativePath $RelativePath `
			-Content ($heading + "`r`n`r`nBody line.`r`n") `
			-Encoding ([Text.UTF8Encoding]::new($true))
		$expected = @(
			$heading
			''
			'| Field | Value |'
			'|---|---|'
			'| **Version** | 2.4 |'
			'| **Date** | 2026-09-18 |'
			'| **Author** | Grace Hopper |'
			'| **Status** | Approved |'
			'| **Scope** | Infrastructure |'
			'| **References** | [Architecture](docs/adr/README.md) |'
			''
			''
			'Body line.'
			''
		) -join "`n"

		Invoke-SetDocumentationMetadata -Path $path | Out-Null

		[IO.File]::ReadAllText($path) | Should -BeExactly $expected
	}

	It 'rejects a four-space indented ATX heading without changing the file' {
		$path = New-RepositoryTestFile `
			-RelativePath 'indented-atx-4.md' `
			-Content "    # Not a heading`n`nBody line.`n"
		$before = [IO.File]::ReadAllBytes($path)

		{ Invoke-SetDocumentationMetadata -Path $path } |
			Should -Throw '*exactly one H1*'
		[Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) |
			Should -Be ([Convert]::ToBase64String($before))
	}

	It 'rejects a sole empty ATX H1 with a usable-title error without changing it' -TestCases @(
		@{ EmptyHeading = '#'; RelativePath = 'empty-atx.md' }
		@{ EmptyHeading = '# '; RelativePath = 'empty-atx-space.md' }
	) {
		param($EmptyHeading, $RelativePath)

		$path = New-RepositoryTestFile `
			-RelativePath $RelativePath `
			-Content ($EmptyHeading + "`n`nBody line.`n")
		$before = [IO.File]::ReadAllBytes($path)

		{ Invoke-SetDocumentationMetadata -Path $path } |
			Should -Throw '*usable H1 title*'
		[Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) |
			Should -Be ([Convert]::ToBase64String($before))
	}

	It 'inserts metadata after a Setext H1 underline' {
		$path = New-RepositoryTestFile `
			-RelativePath 'setext-h1.md' `
			-Content "Setext Title`r`n===`r`n`r`nBody line.`r`n" `
			-Encoding ([Text.UTF8Encoding]::new($true))
		$expected = @(
			'Setext Title'
			'==='
			''
			'| Field | Value |'
			'|---|---|'
			'| **Version** | 2.4 |'
			'| **Date** | 2026-09-18 |'
			'| **Author** | Grace Hopper |'
			'| **Status** | Approved |'
			'| **Scope** | Infrastructure |'
			'| **References** | [Architecture](docs/adr/README.md) |'
			''
			''
			'Body line.'
			''
		) -join "`n"

		Invoke-SetDocumentationMetadata -Path $path | Out-Null

		[IO.File]::ReadAllText($path) | Should -BeExactly $expected
	}

	It 'keeps frontmatter before a Setext H1 and inserts after its indented underline' {
		$sourceContent = @(
			'---'
			'name: docs-agent'
			'description: Existing agent'
			'---'
			'Setext Agent'
			'   ===='
			''
			'Body line.'
		) -join "`r`n"
		$path = New-RepositoryTestFile `
			-RelativePath 'setext-frontmatter.agent.md' `
			-Content ($sourceContent + "`r`n") `
			-Encoding ([Text.UTF8Encoding]::new($true))
		$expected = @(
			'---'
			'name: docs-agent'
			'description: Existing agent'
			'---'
			'Setext Agent'
			'   ===='
			''
			'| Field | Value |'
			'|---|---|'
			'| **Version** | 2.4 |'
			'| **Date** | 2026-09-18 |'
			'| **Author** | Grace Hopper |'
			'| **Status** | Approved |'
			'| **Scope** | Infrastructure |'
			'| **References** | [Architecture](docs/adr/README.md) |'
			''
			''
			'Body line.'
			''
		) -join "`n"

		Invoke-SetDocumentationMetadata -Path $path | Out-Null

		[IO.File]::ReadAllText($path) | Should -BeExactly $expected
		$bytes = [IO.File]::ReadAllBytes($path)
		($bytes.Length -ge 3 -and
			$bytes[0] -eq 0xEF -and
			$bytes[1] -eq 0xBB -and
			$bytes[2] -eq 0xBF) | Should -BeFalse
		[IO.File]::ReadAllText($path).Contains("`r") | Should -BeFalse
	}

	It 'inserts metadata after a multiline Setext H1 and preserves its complete title' {
		$sourceContent = @(
			'First title line'
			'Second title line'
			'==='
			''
			'Existing body line.'
			'Second body line.'
		) -join "`r`n"
		$path = New-RepositoryTestFile `
			-RelativePath 'multiline-setext.md' `
			-Content ($sourceContent + "`r`n") `
			-Encoding ([Text.UTF8Encoding]::new($true))
		$expected = @(
			'First title line'
			'Second title line'
			'==='
			''
			'| Field | Value |'
			'|---|---|'
			'| **Version** | 2.4 |'
			'| **Date** | 2026-09-18 |'
			'| **Author** | Grace Hopper |'
			'| **Status** | Approved |'
			'| **Scope** | Infrastructure |'
			'| **References** | [Architecture](docs/adr/README.md) |'
			''
			''
			'Existing body line.'
			'Second body line.'
			''
		) -join "`n"

		Invoke-SetDocumentationMetadata -Path $path | Out-Null

		[IO.File]::ReadAllText($path) | Should -BeExactly $expected
		$bytes = [IO.File]::ReadAllBytes($path)
		($bytes.Length -ge 3 -and
			$bytes[0] -eq 0xEF -and
			$bytes[1] -eq 0xBB -and
			$bytes[2] -eq 0xBF) | Should -BeFalse
		[IO.File]::ReadAllText($path).Contains("`r") | Should -BeFalse
	}

	It 'inserts after an ATX H1 without consuming a following equals line' {
		$path = New-RepositoryTestFile `
			-RelativePath 'atx-followed-by-equals.md' `
			-Content "# ATX Title`r`n===`r`nBody line.`r`n" `
			-Encoding ([Text.UTF8Encoding]::new($true))
		$expected = @(
			'# ATX Title'
			''
			'| Field | Value |'
			'|---|---|'
			'| **Version** | 2.4 |'
			'| **Date** | 2026-09-18 |'
			'| **Author** | Grace Hopper |'
			'| **Status** | Approved |'
			'| **Scope** | Infrastructure |'
			'| **References** | [Architecture](docs/adr/README.md) |'
			''
			'==='
			'Body line.'
			''
		) -join "`n"

		Invoke-SetDocumentationMetadata -Path $path | Out-Null

		[IO.File]::ReadAllText($path) | Should -BeExactly $expected
	}

	It 'ignores ATX and Setext headings in fences when migrating a Setext document' {
		$sourceContent = @(
			'```markdown'
			'# Fenced ATX'
			'Fenced Setext'
			'==='
			'```'
			'Setext Title'
			'===='
			''
			'Body line.'
		) -join "`n"
		$path = New-RepositoryTestFile `
			-RelativePath 'setext-after-fence.md' `
			-Content ($sourceContent + "`n")

		Invoke-SetDocumentationMetadata -Path $path | Out-Null

		$updated = [IO.File]::ReadAllText($path)
		$updated | Should -Match "Setext Title`n====`n`n\| Field \| Value \|"
		$updated | Should -Match 'Fenced Setext\n===\n```'
	}

	It 'rejects mixed ATX and Setext H1 styles without changing the file' {
		$content = @(
			'# First Title'
			''
			'Body line.'
			''
			'Second Title'
			'==='
			''
		) -join "`n"
		$path = New-RepositoryTestFile `
			-RelativePath 'mixed-h1-styles.md' `
			-Content $content
		$before = [IO.File]::ReadAllBytes($path)

		{ Invoke-SetDocumentationMetadata -Path $path } |
			Should -Throw '*exactly one H1*'
		[Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) |
			Should -Be ([Convert]::ToBase64String($before))
	}

	It 'rejects malformed existing metadata instead of stacking another table' {
		$content = @(
			'# Partial Metadata'
			''
			'| Field | Value |'
			'|---|---|'
			'| **Version** | 1.0 |'
			''
			'Body paragraph.'
			''
		) -join "`n"
		$path = New-RepositoryTestFile `
			-RelativePath 'partial-metadata.md' `
			-Content $content
		$before = [IO.File]::ReadAllBytes($path)

		{ Invoke-SetDocumentationMetadata -Path $path } |
			Should -Throw '*malformed or partial metadata*'
		[Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) |
			Should -Be ([Convert]::ToBase64String($before))
	}

	It 'rejects a path outside the repository' {
		$path = Join-Path $TestDrive 'outside.md'
		[IO.File]::WriteAllText(
			$path,
			"# Outside`n`nBody.`n",
			[Text.UTF8Encoding]::new($false)
		)

		{ Invoke-SetDocumentationMetadata -Path $path } |
			Should -Throw '*inside the repository*'
	}

	It 'rejects a reparse-point ancestor without changing its target' {
		$targetDirectory = Join-Path $TestDrive 'reparse-target'
		$junctionPath = Join-Path $script:testRoot 'reparse-link'
		New-Item -ItemType Directory -Path $targetDirectory -Force | Out-Null
		$targetPath = Join-Path $targetDirectory 'linked.md'
		[IO.File]::WriteAllText(
			$targetPath,
			"# Linked`n`nBody.`n",
			[Text.UTF8Encoding]::new($false)
		)
		$before = [IO.File]::ReadAllBytes($targetPath)
		$mklinkOutput = & cmd.exe /d /c "mklink /J `"$junctionPath`" `"$targetDirectory`"" 2>&1
		$mklinkExitCode = $LASTEXITCODE

		if ($mklinkExitCode -ne 0) {
			Set-ItResult -Skipped -Because (
				'Real Windows junction creation is unavailable: {0}' -f ($mklinkOutput -join ' ')
			)
			return
		}

		try {
			$linkedPath = Join-Path $junctionPath 'linked.md'

			{ Invoke-SetDocumentationMetadata -Path $linkedPath } |
				Should -Throw '*Reparse point is not allowed*'
			[Convert]::ToBase64String([IO.File]::ReadAllBytes($targetPath)) |
				Should -Be ([Convert]::ToBase64String($before))
		}
		finally {
			if (Test-Path -LiteralPath $junctionPath) {
				& cmd.exe /d /c "rmdir `"$junctionPath`"" | Out-Null
			}
		}
	}
}

Describe 'Repository documentation inventory' {
	It 'has valid metadata on every eligible tracked Markdown file' -Tag 'RepositoryInventory' {
		$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
		$gitOutput = @(& git -C $repositoryRoot ls-files -- '*.md' 2>&1)
		$gitExitCode = $LASTEXITCODE
		if ($gitExitCode -ne 0) {
			throw "Unable to enumerate tracked Markdown with Git (exit $gitExitCode): $($gitOutput -join ' ')"
		}
		$paths = @($gitOutput | ForEach-Object { ([string]$_).Replace('\', '/') })
		$failures = [Collections.Generic.List[string]]::new()
		foreach ($relativePath in $paths) {
			if (-not (Test-DocumentationMetadataEligibility -RelativePath $relativePath)) { continue }
			$content = Get-Content -LiteralPath (Join-Path $repositoryRoot $relativePath) -Raw
			foreach ($failure in @(Test-DocumentationMetadataContent `
				-Content $content `
				-DocumentRelativePath $relativePath)) {
				$failures.Add("${relativePath}: $failure")
			}
		}
		$failures | Should -BeNullOrEmpty
	}
}