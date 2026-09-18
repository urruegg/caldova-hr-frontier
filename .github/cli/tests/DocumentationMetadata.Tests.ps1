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
		References = '[Architecture](docs/adr/README.md)'
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

	It 'accepts literal None for References' {
		$content = New-ValidMetadataDocument -References 'None'

		@(Test-DocumentationMetadataContent -Content $content).Count | Should -Be 0
	}

	It 'accepts one relative Markdown link for References' {
		$content = New-ValidMetadataDocument `
			-References '[Design](docs/specs/design.md#metadata)'

		@(Test-DocumentationMetadataContent -Content $content).Count | Should -Be 0
	}

	It 'accepts multiple comma-separated and semicolon-separated relative links' {
		$content = New-ValidMetadataDocument -References (
			'[Design](docs/specs/design.md), [Plan](../plans/plan.md#task-2); [Root](#metadata)'
		)

		@(Test-DocumentationMetadataContent -Content $content).Count | Should -Be 0
	}

	It 'accepts an allowed status prefix with a parenthesized qualifier' {
		$content = New-ValidMetadataDocument `
			-Status 'Active (consolidated from current state)'

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
			'```'
		) -join "`n")

		@(Test-DocumentationMetadataContent -Content $content).Count | Should -Be 0
	}
}

Describe 'Test-DocumentationMetadataContent invalid documents' {
	It 'rejects a document with no H1' {
		$content = (New-ValidMetadataDocument).Replace(
			'# Architecture Baseline',
			'Architecture Baseline'
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