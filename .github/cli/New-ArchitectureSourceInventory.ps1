[CmdletBinding()]
param(
	[Parameter(Mandatory)]
	[string]$SourceRoot,

	[Parameter(Mandatory)]
	[string]$OutputPath,

	[string]$GeneratedUtc = [DateTimeOffset]::UtcNow.ToString(
		"yyyy-MM-dd'T'HH:mm:ss'Z'",
		[Globalization.CultureInfo]::InvariantCulture
	)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-CanonicalFileSystemPath {
	param(
		[Parameter(Mandatory)]
		[string]$Path
	)

	$extendedUncPrefix = '\\?\UNC\'
	$extendedLocalPrefix = '\\?\'
	$deviceNamespacePrefix = '\\.\'
	$namespacePath = $Path
	foreach ($separator in [char[]]@('\', '/')) {
		$namespacePath = $namespacePath.Replace(
			$separator,
			[IO.Path]::DirectorySeparatorChar
		)
	}
	$canonicalPath = $Path

	if ($namespacePath.StartsWith(
		$deviceNamespacePrefix,
		[StringComparison]::OrdinalIgnoreCase
	)) {
		throw "Unsupported device namespace in file system path: $Path"
	}

	if ($namespacePath.StartsWith(
		$extendedUncPrefix,
		[StringComparison]::OrdinalIgnoreCase
	)) {
		$canonicalPath = '\\' + $namespacePath.Substring($extendedUncPrefix.Length)
	}
	elseif ($namespacePath.StartsWith(
		$extendedLocalPrefix,
		[StringComparison]::OrdinalIgnoreCase
	)) {
		$canonicalPath = $namespacePath.Substring($extendedLocalPrefix.Length)
		if ($canonicalPath -notmatch '^[A-Za-z]:[\\/]') {
			throw "Unsupported device namespace in file system path: $Path"
		}
	}

	if ([IO.Path]::IsPathRooted($canonicalPath)) {
		return [IO.Path]::GetFullPath($canonicalPath)
	}

	return [IO.Path]::GetFullPath((Join-Path (Get-Location) $canonicalPath))
}

function Test-PathIsAtOrBelow {
	param(
		[Parameter(Mandatory)]
		[string]$Path,

		[Parameter(Mandatory)]
		[string]$Root
	)

	$trimCharacters = [char[]]@(
		[IO.Path]::DirectorySeparatorChar,
		[IO.Path]::AltDirectorySeparatorChar
	)
	$normalizedRoot = $Root.TrimEnd($trimCharacters)
	$rootBoundary = $normalizedRoot + [IO.Path]::DirectorySeparatorChar

	return $Path.Equals($normalizedRoot, [StringComparison]::OrdinalIgnoreCase) -or
		$Path.StartsWith($rootBoundary, [StringComparison]::OrdinalIgnoreCase)
}

function Assert-NoReparsePointInPath {
	param(
		[Parameter(Mandatory)]
		[string]$Path
	)

	$currentPath = $Path
	while (-not [string]::IsNullOrEmpty($currentPath)) {
		if (Test-Path -LiteralPath $currentPath) {
			$item = Get-Item -LiteralPath $currentPath -Force
			if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
				throw "Reparse point is not allowed in OutputPath: $currentPath"
			}
		}

		$parentPath = [IO.Path]::GetDirectoryName($currentPath)
		if ([string]::IsNullOrEmpty($parentPath) -or $parentPath -eq $currentPath) {
			break
		}

		$currentPath = $parentPath
	}
}

Import-Module (Join-Path $PSScriptRoot 'modules\SourceInventory.psm1') -Force

$resolvedSourceRoot = Get-CanonicalFileSystemPath -Path (
	Resolve-Path -LiteralPath $SourceRoot -ErrorAction Stop
).Path
$absoluteOutput = Get-CanonicalFileSystemPath -Path $OutputPath
$outputDirectory = [IO.Path]::GetDirectoryName($absoluteOutput)

if ([string]::IsNullOrEmpty($outputDirectory)) {
	throw "OutputPath must identify a file in a destination directory: $OutputPath"
}

if (Test-PathIsAtOrBelow -Path $absoluteOutput -Root $resolvedSourceRoot) {
	throw "OutputPath must be outside SourceRoot: $absoluteOutput"
}

Assert-NoReparsePointInPath -Path $absoluteOutput

$inventory = Get-ArchitectureSourceInventory `
	-SourceRoot $resolvedSourceRoot `
	-GeneratedUtc $GeneratedUtc
$json = $inventory | ConvertTo-Json -Depth 6
$normalizedJson = ($json -replace "`r`n", "`n" -replace "`r", "`n").TrimEnd(
	[char[]]@("`r", "`n")
) + "`n"

if (-not (Test-Path -LiteralPath $outputDirectory)) {
	New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}

$temporaryOutput = Join-Path $outputDirectory (
	'.{0}.{1}.tmp' -f [IO.Path]::GetFileName($absoluteOutput), [Guid]::NewGuid().ToString('N')
)
$backupOutput = $temporaryOutput + '.backup'

try {
	[IO.File]::WriteAllText(
		$temporaryOutput,
		$normalizedJson,
		[Text.UTF8Encoding]::new($false)
	)

	if ([IO.File]::Exists($absoluteOutput)) {
		[IO.File]::Replace($temporaryOutput, $absoluteOutput, $backupOutput)
	}
	else {
		[IO.File]::Move($temporaryOutput, $absoluteOutput)
	}
}
finally {
	if ([IO.File]::Exists($temporaryOutput)) {
		[IO.File]::Delete($temporaryOutput)
	}

	if ([IO.File]::Exists($backupOutput)) {
		[IO.File]::Delete($backupOutput)
	}
}

Write-Output "Wrote source inventory: $OutputPath"
