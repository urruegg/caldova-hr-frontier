$modulePath = Join-Path $PSScriptRoot '..\modules\SourceInventory.psm1'

if (Test-Path -LiteralPath $modulePath) {
	Import-Module $modulePath -Force
}
else {
	function Get-ArchitectureSourceInventory {
		throw 'SourceInventory.psm1 does not exist.'
	}
}

Describe 'Get-ArchitectureSourceInventory' {
	BeforeEach {
		$source = Join-Path $TestDrive 'source'
		if (Test-Path -LiteralPath $source) {
			Remove-Item -LiteralPath $source -Recurse -Force
		}

		New-Item -ItemType Directory -Path (Join-Path $source 'nested') -Force | Out-Null
		[IO.File]::WriteAllText(
			(Join-Path $source 'b.txt'),
			'beta',
			[Text.UTF8Encoding]::new($false)
		)
		[IO.File]::WriteAllText(
			(Join-Path $source 'nested\a.txt'),
			'alpha',
			[Text.UTF8Encoding]::new($false)
		)
		[IO.File]::WriteAllText(
			(Join-Path $source 'z.txt'),
			'',
			[Text.UTF8Encoding]::new($false)
		)
		[IO.File]::WriteAllText(
			(Join-Path $source 'ä.txt'),
			'',
			[Text.UTF8Encoding]::new($false)
		)
	}

	It 'returns ordinally sorted relative paths, byte counts, and lowercase SHA-256 values' {
		$originalCulture = [Threading.Thread]::CurrentThread.CurrentCulture
		try {
			[Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo(
				'de-DE'
			)
			$result = Get-ArchitectureSourceInventory `
				-SourceRoot $source `
				-GeneratedUtc '2026-09-17T12:00:00Z'
		}
		finally {
			[Threading.Thread]::CurrentThread.CurrentCulture = $originalCulture
		}

		$result.schemaVersion | Should -Be '1.0'
		$result.generatedUtc | Should -Be '2026-09-17T12:00:00Z'
		$result.files.relativePath | Should -Be @('b.txt', 'nested/a.txt', 'z.txt', 'ä.txt')
		$result.files[0].bytes | Should -Be 4
		$result.files[1].bytes | Should -Be 5
		$result.files[0].sha256 | Should -Be 'f44e64e75f3948e9f73f8dfa94721c4ce8cbb4f265c4790c702b2d41cfbf2753'
		$result.files[1].sha256 | Should -Be '8ed3f6ad685b959ead7022518e1af76cd816f8e8ec7ccdda1ed4018e8f2223f8'
		$result.totalCount | Should -Be 4
		$result.totalBytes | Should -Be 9

		$safeRelativePathPattern = '^(?![A-Za-z]:)(?!/)(?!\\)(?!.*\\)(?!.*(?:^|/)\.\.(?:/|$))[^\\]+$'
		foreach ($record in $result.files) {
			$record.relativePath | Should -Not -BeNullOrEmpty
			$record.relativePath | Should -Match $safeRelativePathPattern
			([long]$record.bytes -ge 0) | Should -BeTrue
			$record.sha256 | Should -Match '^[0-9a-f]{64}$'
		}

		$recordBytes = [long]0
		foreach ($record in $result.files) {
			$recordBytes += [long]$record.bytes
		}

		$result.totalCount | Should -Be $result.files.Count
		$result.totalBytes | Should -Be $recordBytes
	}

	It 'rejects a regular file as SourceRoot' {
		$sourceFile = Join-Path $TestDrive 'source-root.txt'
		[IO.File]::WriteAllText(
			$sourceFile,
			'not-a-directory',
			[Text.UTF8Encoding]::new($false)
		)

		{
			Get-ArchitectureSourceInventory `
				-SourceRoot $sourceFile `
				-GeneratedUtc '2026-09-17T12:00:00Z'
		} | Should -Throw '*SourceRoot must be a FileSystem directory*source-root.txt*'
	}

	It 'rejects a SourceRoot from a non-FileSystem provider' {
		{
			Get-ArchitectureSourceInventory `
				-SourceRoot 'Variable:\PSVersionTable' `
				-GeneratedUtc '2026-09-17T12:00:00Z'
		} | Should -Throw '*SourceRoot must be a FileSystem directory*'
	}

	It 'rejects noncanonical GeneratedUtc values' {
		$invalidValues = @(
			'not-a-date',
			'2026-09-17T12:00:00+00:00',
			'2026-09-17T12:00:00',
			'2026-9-17T12:00:00Z'
		)

		foreach ($invalidValue in $invalidValues) {
			{
				Get-ArchitectureSourceInventory `
					-SourceRoot $source `
					-GeneratedUtc $invalidValue
			} | Should -Throw '*GeneratedUtc must use exact UTC format*'
		}
	}

	It 'retains a valid GeneratedUtc value in exact UTC form' {
		$result = Get-ArchitectureSourceInventory `
			-SourceRoot $source `
			-GeneratedUtc '2026-09-17T12:00:00Z'

		$result.generatedUtc | Should -Be '2026-09-17T12:00:00Z'
	}

	It 'rejects nested Git metadata' {
		$rootGit = Join-Path $source '.git'
		New-Item -ItemType Directory -Path $rootGit | Out-Null

		{
			Get-ArchitectureSourceInventory `
				-SourceRoot $source `
				-GeneratedUtc '2026-09-17T12:00:00Z'
		} | Should -Throw '*Nested Git metadata*'

		Remove-Item -LiteralPath $rootGit -Recurse -Force
		$nestedGit = Join-Path $source 'nested\.git'
		New-Item -ItemType Directory -Path $nestedGit | Out-Null

		{
			Get-ArchitectureSourceInventory `
				-SourceRoot $source `
				-GeneratedUtc '2026-09-17T12:00:00Z'
		} | Should -Throw '*Nested Git metadata*'
	}

	It 'rejects a nested junction directory before selecting regular files' {
		$junctionTarget = Join-Path $TestDrive 'junction-target'
		$junctionPath = Join-Path $source 'nested-link'
		New-Item -ItemType Directory -Path $junctionTarget | Out-Null
		[IO.File]::WriteAllText(
			(Join-Path $junctionTarget 'outside.txt'),
			'outside',
			[Text.UTF8Encoding]::new($false)
		)

		$mklinkOutput = & cmd.exe /d /c "mklink /J `"$junctionPath`" `"$junctionTarget`"" 2>&1
		$mklinkExitCode = $LASTEXITCODE

		if ($mklinkExitCode -ne 0) {
			Set-ItResult -Skipped -Because (
				'Real Windows junction creation is unavailable: {0}' -f ($mklinkOutput -join ' ')
			)
			return
		}

		try {
			{
				Get-ArchitectureSourceInventory `
					-SourceRoot $source `
					-GeneratedUtc '2026-09-17T12:00:00Z'
			} | Should -Throw '*Reparse point is not allowed*nested-link*'
		}
		finally {
			if (Test-Path -LiteralPath $junctionPath) {
				& cmd.exe /d /c "rmdir `"$junctionPath`"" | Out-Null
			}
		}
	}
}

Describe 'New-ArchitectureSourceInventory.ps1 output safety' {
	BeforeAll {
		$script:entryScriptPath = Join-Path $PSScriptRoot '..\New-ArchitectureSourceInventory.ps1'

		if (-not ('SourceInventoryTests.NativeMethods' -as [type])) {
			Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
using System.Text;

namespace SourceInventoryTests
{
    public static class NativeMethods
    {
        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern uint GetShortPathName(
            string longPath,
            StringBuilder shortPath,
            uint shortPathLength);
    }
}
'@
		}

		function Get-TestShortPathName {
			param(
				[Parameter(Mandatory)]
				[string]$Path
			)

			$buffer = [Text.StringBuilder]::new(260)
			$length = [SourceInventoryTests.NativeMethods]::GetShortPathName(
				$Path,
				$buffer,
				[uint32]$buffer.Capacity
			)

			if ($length -eq 0) {
				return $null
			}

			if ($length -ge $buffer.Capacity) {
				$buffer = [Text.StringBuilder]::new([int]$length + 1)
				$length = [SourceInventoryTests.NativeMethods]::GetShortPathName(
					$Path,
					$buffer,
					[uint32]$buffer.Capacity
				)
				if ($length -eq 0) {
					return $null
				}
			}

			return $buffer.ToString()
		}
	}

	BeforeEach {
		$scriptSource = Join-Path $TestDrive ('script-source-{0}' -f [Guid]::NewGuid().ToString('N'))
		New-Item -ItemType Directory -Path $scriptSource -Force | Out-Null
		[IO.File]::WriteAllText(
			(Join-Path $scriptSource 'source.txt'),
			'source-content',
			[Text.UTF8Encoding]::new($false)
		)
	}

	It 'rejects an output path that is an existing source file before writing' {
		$sourceFile = Join-Path $scriptSource 'source.txt'

		{
			& $script:entryScriptPath `
				-SourceRoot $scriptSource `
				-OutputPath $sourceFile `
				-GeneratedUtc '2026-09-17T12:00:00Z' | Out-Null
		} | Should -Throw '*OutputPath must be outside SourceRoot*'

		[IO.File]::ReadAllText($sourceFile) | Should -Be 'source-content'
	}

	It 'rejects an administrative-share alias of an existing source file before writing' {
		$sourceFile = [IO.Path]::GetFullPath((Join-Path $scriptSource 'source.txt'))
		$sourceRoot = [IO.Path]::GetPathRoot($sourceFile)
		if ($sourceRoot -notmatch '^[A-Za-z]:\\$') {
			Set-ItResult -Skipped -Because 'The TestDrive source is not on a local drive.'
			return
		}

		$driveLetter = $sourceRoot.Substring(0, 1)
		$relativeSourceFile = $sourceFile.Substring($sourceRoot.Length)
		$shareHosts = @('localhost')
		if (-not [string]::IsNullOrWhiteSpace($env:COMPUTERNAME) -and
			$env:COMPUTERNAME -notin $shareHosts) {
			$shareHosts += $env:COMPUTERNAME
		}

		$aliasedSourceFile = $null
		foreach ($shareHost in $shareHosts) {
			$candidate = '\\{0}\{1}$\{2}' -f $shareHost, $driveLetter, $relativeSourceFile
			if ([IO.File]::Exists($candidate)) {
				$aliasedSourceFile = $candidate
				break
			}
		}

		if ([string]::IsNullOrEmpty($aliasedSourceFile)) {
			Set-ItResult -Skipped -Because (
				'Local administrative shares are unavailable or inaccessible for the TestDrive source.'
			)
			return
		}

		$sourceBytesBefore = [IO.File]::ReadAllBytes($sourceFile)
		{
			& $script:entryScriptPath `
				-SourceRoot $scriptSource `
				-OutputPath $aliasedSourceFile `
				-GeneratedUtc '2026-09-17T12:00:00Z' | Out-Null
		} | Should -Throw '*OutputPath must be outside SourceRoot*'

		[Convert]::ToBase64String([IO.File]::ReadAllBytes($sourceFile)) |
			Should -Be ([Convert]::ToBase64String($sourceBytesBefore))
		$remainingFiles = @(Get-ChildItem -LiteralPath $scriptSource -File -Force)
		$remainingFiles.Count | Should -Be 1
		$remainingFiles[0].FullName | Should -Be $sourceFile
	}

	It 'rejects a new output path under an 8.3 alias of the source root' {
		$longSourceDirectory = Join-Path $TestDrive (
			'source-directory-with-a-long-name-{0}' -f [Guid]::NewGuid().ToString('N')
		)
		New-Item -ItemType Directory -Path $longSourceDirectory -Force | Out-Null
		[IO.File]::WriteAllText(
			(Join-Path $longSourceDirectory 'source.txt'),
			'source-content',
			[Text.UTF8Encoding]::new($false)
		)

		$longSourceDirectory = [IO.Path]::GetFullPath($longSourceDirectory)
		$shortSourceDirectory = Get-TestShortPathName -Path $longSourceDirectory
		if ([string]::IsNullOrEmpty($shortSourceDirectory) -or
			$shortSourceDirectory.Equals(
				$longSourceDirectory,
				[StringComparison]::OrdinalIgnoreCase
			)) {
			Set-ItResult -Skipped -Because (
				'8.3 naming is disabled or no distinct short alias was assigned to the source directory.'
			)
			return
		}

		$localOutputDirectory = Join-Path $longSourceDirectory 'generated'
		$localOutputPath = Join-Path $localOutputDirectory 'inventory.json'
		$aliasedOutputPath = Join-Path $shortSourceDirectory 'generated\inventory.json'
		{
			& $script:entryScriptPath `
				-SourceRoot $longSourceDirectory `
				-OutputPath $aliasedOutputPath `
				-GeneratedUtc '2026-09-17T12:00:00Z' | Out-Null
		} | Should -Throw '*OutputPath must be outside SourceRoot*'

		Test-Path -LiteralPath $localOutputDirectory | Should -BeFalse
		Test-Path -LiteralPath $localOutputPath -PathType Leaf | Should -BeFalse
	}

	It 'rejects the <Alias> alias of an existing source file before writing' -ForEach @(
		@{
			Alias = '\\?\'
			NamespacePrefix = '\\?\'
			UseForwardSeparators = $false
			ExpectedError = '*OutputPath must be outside SourceRoot*'
		},
		@{
			Alias = '//?/'
			NamespacePrefix = '//?/'
			UseForwardSeparators = $true
			ExpectedError = '*OutputPath must be outside SourceRoot*'
		},
		@{
			Alias = '\\.\'
			NamespacePrefix = '\\.\'
			UseForwardSeparators = $false
			ExpectedError = '*Unsupported device namespace*'
		},
		@{
			Alias = '//./'
			NamespacePrefix = '//./'
			UseForwardSeparators = $true
			ExpectedError = '*Unsupported device namespace*'
		}
	) {
		param($NamespacePrefix, $UseForwardSeparators, $ExpectedError)

		$sourceFile = [IO.Path]::GetFullPath((Join-Path $scriptSource 'source.txt'))
		$pathBody = if ($UseForwardSeparators) {
			$sourceFile.Replace('\', '/')
		}
		else {
			$sourceFile
		}
		$aliasedSourceFile = $NamespacePrefix + $pathBody
		$sourceBytesBefore = [IO.File]::ReadAllBytes($sourceFile)

		{
			& $script:entryScriptPath `
				-SourceRoot $scriptSource `
				-OutputPath $aliasedSourceFile `
				-GeneratedUtc '2026-09-17T12:00:00Z' | Out-Null
		} | Should -Throw $ExpectedError

		[Convert]::ToBase64String([IO.File]::ReadAllBytes($sourceFile)) |
			Should -Be ([Convert]::ToBase64String($sourceBytesBefore))
		$remainingFiles = @(Get-ChildItem -LiteralPath $scriptSource -File -Force)
		$remainingFiles.Count | Should -Be 1
		$remainingFiles[0].FullName | Should -Be $sourceFile
	}

	It 'rejects a regular file as SourceRoot without writing output' {
		$sourceFile = Join-Path $TestDrive 'entry-source-root.txt'
		$outputPath = Join-Path $TestDrive 'entry-source-root-output.json'
		[IO.File]::WriteAllText(
			$sourceFile,
			'not-a-directory',
			[Text.UTF8Encoding]::new($false)
		)

		{
			& $script:entryScriptPath `
				-SourceRoot $sourceFile `
				-OutputPath $outputPath `
				-GeneratedUtc '2026-09-17T12:00:00Z' | Out-Null
		} | Should -Throw '*SourceRoot must be a FileSystem directory*entry-source-root.txt*'

		Test-Path -LiteralPath $outputPath | Should -BeFalse
	}

	It 'rejects a new output path anywhere inside the source root' {
		$insideOutput = Join-Path $scriptSource 'generated\inventory.json'

		{
			& $script:entryScriptPath `
				-SourceRoot $scriptSource `
				-OutputPath $insideOutput `
				-GeneratedUtc '2026-09-17T12:00:00Z' | Out-Null
		} | Should -Throw '*OutputPath must be outside SourceRoot*'

		Test-Path -LiteralPath $insideOutput | Should -BeFalse
	}

	It 'rejects an output parent that is a junction' {
		$outputTarget = Join-Path $TestDrive 'output-target'
		$outputJunction = Join-Path $TestDrive 'output-link'
		$outputPath = Join-Path $outputJunction 'inventory.json'
		New-Item -ItemType Directory -Path $outputTarget | Out-Null

		$mklinkOutput = & cmd.exe /d /c "mklink /J `"$outputJunction`" `"$outputTarget`"" 2>&1
		$mklinkExitCode = $LASTEXITCODE

		if ($mklinkExitCode -ne 0) {
			Set-ItResult -Skipped -Because (
				'Real Windows junction creation is unavailable: {0}' -f ($mklinkOutput -join ' ')
			)
			return
		}

		try {
			{
				& $script:entryScriptPath `
					-SourceRoot $scriptSource `
					-OutputPath $outputPath `
					-GeneratedUtc '2026-09-17T12:00:00Z' | Out-Null
			} | Should -Throw '*Reparse point is not allowed*output-link*'

			Test-Path -LiteralPath (Join-Path $outputTarget 'inventory.json') | Should -BeFalse
		}
		finally {
			if (Test-Path -LiteralPath $outputJunction) {
				& cmd.exe /d /c "rmdir `"$outputJunction`"" | Out-Null
			}
		}
	}

	It 'writes only the requested output when a prefix-sharing sibling is outside the source root' {
		$outputDirectory = $scriptSource + '-output'
		$outputPath = Join-Path $outputDirectory 'inventory.json'
		$filesBefore = @(
			Get-ChildItem -LiteralPath $TestDrive -File -Recurse -Force |
				ForEach-Object { $_.FullName }
		)

		& $script:entryScriptPath `
			-SourceRoot $scriptSource `
			-OutputPath $outputPath `
			-GeneratedUtc '2026-09-17T12:00:00Z' | Out-Null

		$filesAfter = @(
			Get-ChildItem -LiteralPath $TestDrive -File -Recurse -Force |
				ForEach-Object { $_.FullName }
		)
		$createdFiles = @($filesAfter | Where-Object { $_ -notin $filesBefore })

		Test-Path -LiteralPath $outputPath -PathType Leaf | Should -BeTrue
		$createdFiles | Should -Be @($outputPath)

		$outputBytes = [IO.File]::ReadAllBytes($outputPath)
		$hasBom = ($outputBytes.Length -ge 3) -and
			($outputBytes[0] -eq 0xEF) -and
			($outputBytes[1] -eq 0xBB) -and
			($outputBytes[2] -eq 0xBF)
		$outputText = [Text.UTF8Encoding]::new($false, $true).GetString($outputBytes)

		$hasBom | Should -BeFalse
		$outputText.Contains("`r") | Should -BeFalse
		$outputText.EndsWith("`n") | Should -BeTrue
		$outputText.EndsWith("`n`n") | Should -BeFalse
	}

	It 'replaces an existing destination without leaving temporary siblings' {
		$outputDirectory = $scriptSource + '-replacement-output'
		$outputPath = Join-Path $outputDirectory 'inventory.json'
		New-Item -ItemType Directory -Path $outputDirectory | Out-Null
		[IO.File]::WriteAllText(
			$outputPath,
			'stale',
			[Text.UTF8Encoding]::new($false)
		)

		& $script:entryScriptPath `
			-SourceRoot $scriptSource `
			-OutputPath $outputPath `
			-GeneratedUtc '2026-09-17T12:00:00Z' | Out-Null

		$destinationFiles = @(Get-ChildItem -LiteralPath $outputDirectory -File -Force)
		$destinationFiles.Count | Should -Be 1
		$destinationFiles[0].FullName | Should -Be $outputPath
		[IO.File]::ReadAllText($outputPath) | Should -Not -Be 'stale'
	}

	It 'rejects noncanonical GeneratedUtc values without writing output' {
		$invalidValues = @(
			'not-a-date',
			'2026-09-17T12:00:00+00:00',
			'2026-09-17T12:00:00',
			'2026-9-17T12:00:00Z'
		)

		for ($index = 0; $index -lt $invalidValues.Count; $index++) {
			$outputPath = $scriptSource + ".invalid-$index.json"
			{
				& $script:entryScriptPath `
					-SourceRoot $scriptSource `
					-OutputPath $outputPath `
					-GeneratedUtc $invalidValues[$index] | Out-Null
			} | Should -Throw '*GeneratedUtc must use exact UTC format*'

			Test-Path -LiteralPath $outputPath | Should -BeFalse
		}
	}

	It 'retains a valid GeneratedUtc value in exact UTC form' {
		$outputPath = $scriptSource + '.valid-time.json'

		& $script:entryScriptPath `
			-SourceRoot $scriptSource `
			-OutputPath $outputPath `
			-GeneratedUtc '2026-09-17T12:00:00Z' | Out-Null

		$document = [IO.File]::ReadAllText($outputPath) | ConvertFrom-Json
		$document.generatedUtc | Should -Be '2026-09-17T12:00:00Z'
	}

	It 'uses a Gregorian exact UTC default under non-Gregorian current cultures' {
		$format = "yyyy-MM-dd'T'HH:mm:ss'Z'"
		$styles = [Globalization.DateTimeStyles]::AssumeUniversal -bor
			[Globalization.DateTimeStyles]::AdjustToUniversal
		$originalCulture = [Threading.Thread]::CurrentThread.CurrentCulture

		try {
			foreach ($cultureName in @('th-TH', 'ar-SA')) {
				[Threading.Thread]::CurrentThread.CurrentCulture =
					[Globalization.CultureInfo]::GetCultureInfo($cultureName)
				$earliestExpected = [DateTimeOffset]::UtcNow.AddSeconds(-2)
				$outputPath = $scriptSource + ".$cultureName.json"

				& $script:entryScriptPath `
					-SourceRoot $scriptSource `
					-OutputPath $outputPath | Out-Null

				$latestExpected = [DateTimeOffset]::UtcNow.AddSeconds(2)
				$document = [IO.File]::ReadAllText($outputPath) | ConvertFrom-Json
				$document.generatedUtc | Should -Match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$'

				$parsed = [DateTimeOffset]::MinValue
				[DateTimeOffset]::TryParseExact(
					$document.generatedUtc,
					$format,
					[Globalization.CultureInfo]::InvariantCulture,
					$styles,
					[ref]$parsed
				) | Should -BeTrue
				($parsed -ge $earliestExpected) | Should -BeTrue
				($parsed -le $latestExpected) | Should -BeTrue
			}
		}
		finally {
			[Threading.Thread]::CurrentThread.CurrentCulture = $originalCulture
		}
	}
}

Describe 'source inventory schema' {
	It 'enforces the exact generatedUtc representation' {
		$schemaPath = Join-Path $PSScriptRoot '..\schemas\source-inventory.schema.json'
		$schema = [IO.File]::ReadAllText($schemaPath) | ConvertFrom-Json
		$pattern = $schema.properties.generatedUtc.pattern

		$pattern | Should -Not -BeNullOrEmpty
		'2026-09-17T12:00:00Z' | Should -Match $pattern
		foreach ($invalidValue in @(
			'not-a-date',
			'2026-09-17T12:00:00+00:00',
			'2026-09-17T12:00:00',
			'2026-9-17T12:00:00Z'
		)) {
			$invalidValue | Should -Not -Match $pattern
		}
	}
}
