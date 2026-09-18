Set-StrictMode -Version Latest

function Get-ArchitectureSourceInventory {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[string]$SourceRoot,

		[Parameter(Mandatory)]
		[string]$GeneratedUtc
	)

	$timestampFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
	$timestampStyles = [Globalization.DateTimeStyles]::AssumeUniversal -bor
		[Globalization.DateTimeStyles]::AdjustToUniversal
	$parsedGeneratedUtc = [DateTimeOffset]::MinValue
	$isValidGeneratedUtc = [DateTimeOffset]::TryParseExact(
		$GeneratedUtc,
		$timestampFormat,
		[Globalization.CultureInfo]::InvariantCulture,
		$timestampStyles,
		[ref]$parsedGeneratedUtc
	)

	if (-not $isValidGeneratedUtc) {
		throw "GeneratedUtc must use exact UTC format yyyy-MM-dd'T'HH:mm:ss'Z': $GeneratedUtc"
	}

	$canonicalGeneratedUtc = $parsedGeneratedUtc.ToUniversalTime().ToString(
		$timestampFormat,
		[Globalization.CultureInfo]::InvariantCulture
	)
	$resolvedPath = Resolve-Path -LiteralPath $SourceRoot -ErrorAction Stop
	if ($resolvedPath.Provider.Name -ne 'FileSystem') {
		throw "SourceRoot must be a FileSystem directory: $SourceRoot"
	}

	$resolvedRoot = $resolvedPath.ProviderPath
	if (-not (Test-Path -LiteralPath $resolvedRoot -PathType Container)) {
		throw "SourceRoot must be a FileSystem directory: $resolvedRoot"
	}

	$rootItem = Get-Item -LiteralPath $resolvedRoot -Force
	if ($rootItem -isnot [IO.DirectoryInfo]) {
		throw "SourceRoot must be a FileSystem directory: $resolvedRoot"
	}

	if ($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint) {
		throw "Source root must not be a reparse point: $resolvedRoot"
	}

	$entries = @(Get-ChildItem -LiteralPath $resolvedRoot -Force -Recurse -ErrorAction Stop)
	foreach ($entry in $entries) {
		$relativePath = $entry.FullName.Substring($resolvedRoot.Length).TrimStart('\').Replace('\', '/')
		if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) {
			throw "Reparse point is not allowed: $relativePath"
		}
	}

	$gitMetadata = @($entries | Where-Object { $_.Name -ieq '.git' })
	if ($gitMetadata.Count -gt 0) {
		throw 'Nested Git metadata is not allowed in the architecture source.'
	}

	$recordsByPath = [Collections.Generic.Dictionary[string, object]]::new(
		[StringComparer]::Ordinal
	)
	$fileItems = @($entries | Where-Object { -not $_.PSIsContainer })

	foreach ($fileItem in $fileItems) {
		$relativePath = $fileItem.FullName.Substring($resolvedRoot.Length).TrimStart('\').Replace('\', '/')
		$recordsByPath.Add(
			$relativePath,
			[ordered]@{
				relativePath = $relativePath
				bytes = [long]$fileItem.Length
				sha256 = (Get-FileHash -LiteralPath $fileItem.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
			}
		)
	}

	[string[]]$sortedPaths = @($recordsByPath.Keys)
	[Array]::Sort($sortedPaths, [StringComparer]::Ordinal)
	$sorted = @($sortedPaths | ForEach-Object { $recordsByPath[$_] })
	$totalBytes = [long]0

	foreach ($record in $sorted) {
		$totalBytes += [long]$record.bytes
	}

	[ordered]@{
		schemaVersion = '1.0'
		generatedUtc = $canonicalGeneratedUtc
		sourceName = (Split-Path -Leaf $resolvedRoot)
		totalCount = $sorted.Count
		totalBytes = $totalBytes
		files = $sorted
	}
}

Export-ModuleMember -Function Get-ArchitectureSourceInventory
