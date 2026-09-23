BeforeAll {
	$script:repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
	$script:inventoryPath = Join-Path $script:repositoryRoot 'docs\reviews\2026-09-17-architecture-baseline-source-inventory.json'
	$script:inventory = Get-Content -LiteralPath $script:inventoryPath -Raw | ConvertFrom-Json

	$script:expectedDocuments = [ordered]@{
		'infra/README.md' = 'd801eb852feaa319ab4d77c08954a6486d03e16ab416e8adb96b4b86f127b35a'
		'infra/docs/10-tenant-setup-and-configuration.md' = 'f2346001a7a0f98633b9a00d7dc4c5a40845dfe61b02767d0297ecc705db05bd'
		'infra/docs/11-identity-and-access.md' = '56466efda3ca2aabc3f1fc0e4fde8fc755511f5b3125b9606e5a3f8b9d55b30c'
		'infra/docs/12-power-platform-environments-and-alm.md' = '2299472573fa2fbadaddb1b150ce04436ee3e3f6c27c9cf1992c3c4d229b98f4'
		'infra/docs/13-azure-devops-engineering-control-plane.md' = '6d9ffc8c8d809af374a408bfaba9ee896f29e87b3c92b9779784e539a79423cd'
		'infra/docs/14-github-repository-blueprint.md' = '60737982f4778f8a7bc55a277009d086472c325d3052715f28781cb0f878cd85'
		'infra/docs/15-agent-workload-configuration.md' = 'a62e2b5f464162c5de4bd02c02a149ff49862896333a0180ce55f26144b66d43'
		'infra/docs/16-security-governance-and-compliance.md' = 'df64b8e579cc55aafcbf8d9c9fe556f1e1f703e3d54f25aff3789e2e834d887d'
		'infra/docs/17-bootstrap-and-provisioning.md' = '76ff7a5414873e4cc18b95abf11a140d9265a7cec6d8f87a5f174018d9233a24'
		'infra/docs/18-multi-tenant-provisioning.md' = '55af81a81c502e0aa7d928dde4000e73e458ea4857625ccfc957991b74d73d5e'
	}

	$script:expectedPlaceholders = [ordered]@{
		'infra/src/bicep/.gitkeep' = '309659e7051a8dde1cbfcc5a27403d0bd3b55d6a926547f55ac31ace0fa3ec23'
		'infra/src/config/tenants/.gitkeep' = 'd712e885f4efda5dec517aaa8bd0f24ae10bf44a3dfe3b6afa693b7bb7543258'
		'infra/src/scripts/.gitkeep' = 'b97ec3d3a393fa969666c541d486d6c432a33662b627a1820f5144fb500adc3f'
		'infra/src/solutions/.gitkeep' = '84e98d82dd87a7278e1a7ca46c0c9c51ebb10308eba84dbed1dedfa93d165279'
		'infra/tests/.gitkeep' = 'd285946f97231022b4b0ce730c81b5449b72eae0ada549383130d6b7981df59f'
	}
}

Describe 'Phase 3 source contract' {
	It 'matches all ten substantive source documents exactly once' {
		$matchedPaths = [Collections.Generic.List[string]]::new()

		foreach ($entry in $script:expectedDocuments.GetEnumerator()) {
			$record = @($script:inventory.files | Where-Object { $_.relativePath -ceq $entry.Key })
			$record.Count | Should -Be 1
			$record[0].sha256 | Should -Be $entry.Value
			[void]$matchedPaths.Add($record[0].relativePath)
		}

		$matchedPaths.Count | Should -Be $script:expectedDocuments.Count
	}

	It 'matches all five placeholder source records and does not import their targets' {
		$matchedPaths = [Collections.Generic.List[string]]::new()

		foreach ($entry in $script:expectedPlaceholders.GetEnumerator()) {
			$record = @($script:inventory.files | Where-Object { $_.relativePath -ceq $entry.Key })
			$record.Count | Should -Be 1
			$record[0].sha256 | Should -Be $entry.Value
			[void]$matchedPaths.Add($record[0].relativePath)

			$targetPath = Join-Path $script:repositoryRoot $entry.Key.Replace('/', '\')
			Test-Path -LiteralPath $targetPath | Should -BeFalse
		}

		$matchedPaths.Count | Should -Be $script:expectedPlaceholders.Count
	}
}