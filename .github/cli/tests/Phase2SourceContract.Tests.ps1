BeforeAll {
	$script:inventoryPath = Join-Path $PSScriptRoot '..\..\..\docs\reviews\2026-09-17-architecture-baseline-source-inventory.json'
	$script:inventory = Get-Content -LiteralPath $script:inventoryPath -Raw | ConvertFrom-Json
	$script:repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
	$script:expectedAdrCandidates = @(
		'docs/adr/0001-azure-devops-as-engineering-control-plane.md'
		'docs/adr/0002-github-first-bootstrap-and-the-role-of-azure-repos.md'
		'docs/adr/0003-bicep-and-powershell-for-infrastructure-as-code.md'
		'docs/adr/0004-domain-solution-architecture-and-publisher.md'
	)
	$script:expectedEvaluationPath = 'docs/90-microsoft-best-practice-evaluation.md'

	$script:expected = [ordered]@{
		'README.md' = '5035ac2b1c59ce776de359ac9592483bf0b9e20572dd1bee8a5aae2638ab8605'
		'data/README.md' = '610ab9bc996f3641b14e0832cc5cfced346f7c88b3f3d7c268bac47498d34c77'
		'docs/90-microsoft-best-practice-evaluation.md' = 'fb4d29d4cf75f7cb659c71b21f83e900a484257e8d2cc06e1a006ec40f1b6031'
		'docs/adr/0001-azure-devops-as-engineering-control-plane.md' = '05ba58d6fb202bb0ac67d936e2cedcf8239a1fbb1c995d2f97035a4eebe02410'
		'docs/adr/0002-github-first-bootstrap-and-the-role-of-azure-repos.md' = '515f8c2a3cad2558f8c266228ec33b3df15d9555c3a18aff92044087e2854f9b'
		'docs/adr/0003-bicep-and-powershell-for-infrastructure-as-code.md' = '549aae2bbca2d792171dd0b947d9f63e1acdec86a93a8a541090b1ca04d03f4b'
		'docs/adr/0004-domain-solution-architecture-and-publisher.md' = 'c32161b150c9fd1be080456362e42a7f01c9e7d7de8d21674831dcf24fae7473'
		'docs/operating-model/00-north-star.md' = '7be5151f04031f4f36e58b80d741ad40c8beb2b26a4dd5ddf8363f318fe9f025'
		'docs/operating-model/01-prd.md' = '7fdc213f864cff3cd0e4755e073b0a23fbf797953132b8a94fab55e8548204a3'
		'docs/operating-model/02-system-design.md' = 'e0b6ff1c43ae0954bb51edf1993ddd9a6d81376834849a756335034bdd1d88e6'
		'docs/operating-model/03-agent-operating-model.md' = '556efcd4af83d221fbe055bbea468d20585112e8d302a4b8ada28514867888a7'
		'docs/operating-model/04-hitl-governance.md' = '8c98c9d1d839d92711b01d651b8277cdd67bf61bb81c29c1defb9a5d6eb1de2b'
		'docs/operating-model/05-implementation-roadmap.md' = '8698e90d24f7f2809c7c4208769395e9296f39fe4323f8edbe33b4ec0fb2c509'
		'hr/README.md' = '9ce61a8ae0e0722091bdbad7820591a4b1dade17edecc5cea3715b76fbcc5010'
		'hr/docs/20-hr-employee-journey.md' = '49d6988c476b9866bc3ca6b70cae3d84b48a5e4c6e2918426c5b2b1614464bca'
		'hr/src/solutions/.gitkeep' = 'b3f560ecbb33867e20f4481b6ed3f8a590f5500940c61b9975f806720b790122'
	}
}

Describe 'Phase 2 source contract' {
	It 'matches every reviewed path and hash exactly once' {
		$matchedPaths = [Collections.Generic.List[string]]::new()

		foreach ($entry in $script:expected.GetEnumerator()) {
			$record = @($script:inventory.files | Where-Object { $_.relativePath -ceq $entry.Key })
			$record.Count | Should -Be 1
			$record[0].sha256 | Should -Be $entry.Value
			[void]$matchedPaths.Add($record[0].relativePath)
		}

		$matchedPaths.Count | Should -Be $script:expected.Count
	}

	It 'has not imported the source placeholder target' {
		Test-Path -LiteralPath (Join-Path $script:repositoryRoot 'hr\src\solutions\.gitkeep') | Should -BeFalse
	}
}

Describe 'Imported authority status' {
	It 'imports exactly the four proposed ADR candidates' {
		foreach ($relativePath in $script:expectedAdrCandidates) {
			$path = Join-Path $script:repositoryRoot $relativePath
			Test-Path -LiteralPath $path -PathType Leaf | Should -BeTrue -Because "$relativePath must exist as a regular file"

			$content = Get-Content -LiteralPath $path -Raw
			$content | Should -Match '\| \*\*Status\*\* \| Proposed Baseline \|'
			$content | Should -Not -Match '(?m)^- \*\*Status:\*\* Accepted$'
			@([regex]::Matches($content, '(?m)^## Proposed Decision\s*$')).Count | Should -Be 1
			$content | Should -Not -Match '(?m)^## Decision\s*$'
		}

		$discovered = Get-ChildItem -LiteralPath (Join-Path $script:repositoryRoot 'docs\adr') -File |
			Where-Object { $_.Name -match '^000[1-4]-.*\.md$' } |
			ForEach-Object { 'docs/adr/' + $_.Name } |
			Sort-Object
		$discovered | Should -Be ($script:expectedAdrCandidates | Sort-Object)
	}

	It 'imports the Microsoft evaluation as a proposed, source-derived assessment' {
		$path = Join-Path $script:repositoryRoot $script:expectedEvaluationPath
		Test-Path -LiteralPath $path -PathType Leaf | Should -BeTrue -Because "$script:expectedEvaluationPath must exist as a regular file"

		$content = Get-Content -LiteralPath $path -Raw
		$content | Should -Match '\| \*\*Status\*\* \| Proposed Baseline \|'
		$content | Should -Match 'source-derived Proposed Baseline assessment'
		$content | Should -Match 'documented design, not proof of deployed controls'
		$content | Should -Match 'deployment/configuration claims remain planned or not yet verified'
	}
}

Describe 'Root product and agent workflow map' {
	BeforeAll {
		$script:rootReadmePath = Join-Path $script:repositoryRoot 'README.md'
		$script:rootReadmeContent = Get-Content -LiteralPath $script:rootReadmePath -Raw
	}

	It 'preserves the repository workflow and publishes the proposed product baseline map' {
		$requiredConcepts = @(
			'Superpowers'
			'v6.3.0'
			'.github/skills'
			'verify-repository-setup.ps1'
			'Caldova HR Frontier'
			'Insight -> Decision -> Delivery -> Outcome -> Learning -> Insight'
			'Proposed Baseline'
			'docs/operating-model/00-north-star.md'
			'docs/operating-model/01-prd.md'
			'docs/operating-model/02-system-design.md'
			'docs/operating-model/03-agent-operating-model.md'
			'docs/operating-model/04-hitl-governance.md'
			'docs/operating-model/05-implementation-roadmap.md'
			'docs/adr/0001-azure-devops-as-engineering-control-plane.md'
			'docs/adr/0002-github-first-bootstrap-and-the-role-of-azure-repos.md'
			'docs/adr/0003-bicep-and-powershell-for-infrastructure-as-code.md'
			'docs/adr/0004-domain-solution-architecture-and-publisher.md'
			'docs/90-microsoft-best-practice-evaluation.md'
			'data/README.md'
			'hr/README.md'
			'hr/docs/20-hr-employee-journey.md'
			'hr/src/solutions/README.md'
			'No personal data'
			'No secrets'
			'agents never decide employment matters'
			'Phase 2 imported documentation only'
			'no Azure resources, Power Platform solutions, pipelines, seed data, or tenant controls were deployed or provisioned'
		)

		foreach ($concept in $requiredConcepts) {
			$script:rootReadmeContent | Should -Match ([regex]::Escape($concept))
		}
	}
}