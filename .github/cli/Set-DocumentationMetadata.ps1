[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
	[Parameter(Mandatory)]
	[string]$Path,

	[Parameter(Mandatory)]
	[string]$Version,

	[Parameter(Mandatory)]
	[string]$Date,

	[Parameter(Mandatory)]
	[string]$Author,

	[Parameter(Mandatory)]
	[string]$Status,

	[Parameter(Mandatory)]
	[string]$Scope,

	[Parameter(Mandatory)]
	[string]$References
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot 'modules\DocumentationMetadata.psm1'
Import-Module $modulePath -Force

function Test-PathIsAtOrBelow {
	param(
		[Parameter(Mandatory)]
		[string]$CandidatePath,

		[Parameter(Mandatory)]
		[string]$RootPath
	)

	$trimCharacters = [char[]]@(
		[IO.Path]::DirectorySeparatorChar,
		[IO.Path]::AltDirectorySeparatorChar
	)
	$normalizedRoot = $RootPath.TrimEnd($trimCharacters)
	$rootBoundary = $normalizedRoot + [IO.Path]::DirectorySeparatorChar

	return $CandidatePath.Equals(
		$normalizedRoot,
		[StringComparison]::OrdinalIgnoreCase
	) -or $CandidatePath.StartsWith(
		$rootBoundary,
		[StringComparison]::OrdinalIgnoreCase
	)
}

function Resolve-RepositoryDocumentPath {
	param(
		[Parameter(Mandatory)]
		[string]$RequestedPath,

		[Parameter(Mandatory)]
		[string]$RepositoryRoot
	)

	if ([string]::IsNullOrWhiteSpace($RequestedPath) -or
		$RequestedPath.StartsWith('\\?\', [StringComparison]::Ordinal) -or
		$RequestedPath.StartsWith('\\.\', [StringComparison]::Ordinal)) {
		throw "Path must identify a regular repository file: $RequestedPath"
	}

	$candidatePath = if ([IO.Path]::IsPathRooted($RequestedPath)) {
		[IO.Path]::GetFullPath($RequestedPath)
	}
	else {
		[IO.Path]::GetFullPath((Join-Path $RepositoryRoot $RequestedPath))
	}
	if (-not (Test-PathIsAtOrBelow `
		-CandidatePath $candidatePath `
		-RootPath $RepositoryRoot)) {
		throw "Path must be inside the repository: $RequestedPath"
	}
	if (-not [IO.File]::Exists($candidatePath)) {
		throw "Path must identify an existing repository file: $RequestedPath"
	}

	$item = Get-Item -LiteralPath $candidatePath -Force
	if ($item.PSProvider.Name -ne 'FileSystem' -or $item.PSIsContainer) {
		throw "Path must identify a regular repository file: $RequestedPath"
	}

	return $candidatePath
}

function Get-RepositoryRelativePath {
	param(
		[Parameter(Mandatory)]
		[string]$DocumentPath,

		[Parameter(Mandatory)]
		[string]$RepositoryRoot
	)

	$trimCharacters = [char[]]@(
		[IO.Path]::DirectorySeparatorChar,
		[IO.Path]::AltDirectorySeparatorChar
	)
	$rootBoundary = $RepositoryRoot.TrimEnd($trimCharacters) +
		[IO.Path]::DirectorySeparatorChar
	return $DocumentPath.Substring($rootBoundary.Length).Replace('\', '/')
}

function Assert-NoReparsePoints {
	param(
		[Parameter(Mandatory)]
		[string]$DocumentPath,

		[Parameter(Mandatory)]
		[string]$RepositoryRoot
	)

	$currentPath = $DocumentPath
	while ($true) {
		$item = Get-Item -LiteralPath $currentPath -Force
		if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
			throw "Reparse point is not allowed in document path: $currentPath"
		}
		if ($currentPath.Equals(
			$RepositoryRoot,
			[StringComparison]::OrdinalIgnoreCase
		)) {
			break
		}

		$parentPath = [IO.Path]::GetDirectoryName($currentPath)
		if ([string]::IsNullOrEmpty($parentPath) -or
			$parentPath.Equals($currentPath, [StringComparison]::OrdinalIgnoreCase)) {
			throw "Unable to inspect document path ancestors: $DocumentPath"
		}
		$currentPath = $parentPath
	}
}

function ConvertFrom-RepositoryUtf8 {
	param(
		[Parameter(Mandatory)]
		[byte[]]$Bytes,

		[Parameter(Mandatory)]
		[string]$DocumentPath
	)

	$encoding = [Text.UTF8Encoding]::new($false, $true)
	try {
		return $encoding.GetString($Bytes)
	}
	catch {
		throw "Document is not valid UTF-8: $DocumentPath"
	}
}

function ConvertTo-NormalizedDocumentationLines {
	param(
		[AllowEmptyString()]
		[string]$Content
	)

	if ($Content.Length -gt 0 -and $Content[0] -eq [char]0xFEFF) {
		$Content = $Content.Substring(1)
	}
	$normalizedContent = $Content.Replace("`r`n", "`n").Replace("`r", "`n")
	return ,([string[]]$normalizedContent.Split(
		[string[]]@("`n"),
		[StringSplitOptions]::None
	))
}

function Add-DocumentationMetadataTable {
	param(
		[Parameter(Mandatory)]
		[string]$Content,

		[Parameter(Mandatory)]
		[string]$MetadataTable
	)

	$lines = ConvertTo-NormalizedDocumentationLines -Content $Content
	$h1InsertionIndex = Get-DocumentationH1InsertionIndex -Content $Content
	$bodyStart = $h1InsertionIndex + 1

	$outputLines = [Collections.Generic.List[string]]::new()
	for ($lineIndex = 0; $lineIndex -le $h1InsertionIndex; $lineIndex++) {
		$outputLines.Add($lines[$lineIndex])
	}
	$outputLines.Add('')
	foreach ($tableLine in $MetadataTable.Split([char]"`n")) {
		$outputLines.Add($tableLine)
	}
	$outputLines.Add('')
	for ($lineIndex = $bodyStart; $lineIndex -lt $lines.Count; $lineIndex++) {
		$outputLines.Add($lines[$lineIndex])
	}
	while ($outputLines.Count -gt 0 -and
		[string]::IsNullOrWhiteSpace($outputLines[$outputLines.Count - 1])) {
		$outputLines.RemoveAt($outputLines.Count - 1)
	}

	return ($outputLines -join "`n") + "`n"
}

function Test-ByteArraysEqual {
	param(
		[Parameter(Mandatory)]
		[byte[]]$Left,

		[Parameter(Mandatory)]
		[byte[]]$Right
	)

	if ($Left.Length -ne $Right.Length) {
		return $false
	}
	for ($byteIndex = 0; $byteIndex -lt $Left.Length; $byteIndex++) {
		if ($Left[$byteIndex] -ne $Right[$byteIndex]) {
			return $false
		}
	}

	return $true
}

function Write-AtomicDocumentationFile {
	param(
		[Parameter(Mandatory)]
		[string]$DestinationPath,

		[Parameter(Mandatory)]
		[string]$Content,

		[Parameter(Mandatory)]
		[byte[]]$ExpectedOriginalBytes
	)

	$currentBytes = [IO.File]::ReadAllBytes($DestinationPath)
	if (-not (Test-ByteArraysEqual `
		-Left $currentBytes `
		-Right $ExpectedOriginalBytes)) {
		throw "Document changed after validation; refusing to overwrite: $DestinationPath"
	}

	$directory = [IO.Path]::GetDirectoryName($DestinationPath)
	$fileName = [IO.Path]::GetFileName($DestinationPath)
	$operationId = [Guid]::NewGuid().ToString('N')
	$temporaryPath = Join-Path $directory ('.{0}.{1}.tmp' -f $fileName, $operationId)
	$backupPath = Join-Path $directory ('.{0}.{1}.bak' -f $fileName, $operationId)
	$replacementSucceeded = $false

	try {
		[IO.File]::WriteAllText(
			$temporaryPath,
			$Content,
			[Text.UTF8Encoding]::new($false)
		)
		try {
			[IO.File]::Replace(
				$temporaryPath,
				$DestinationPath,
				$backupPath,
				$true
			)
			$replacementSucceeded = $true
		}
		catch {
			$replacementError = $_
			if ([IO.File]::Exists($backupPath)) {
				try {
					if ([IO.File]::Exists($DestinationPath)) {
						[IO.File]::Delete($DestinationPath)
					}
					[IO.File]::Move($backupPath, $DestinationPath)
				}
				catch {
					throw (
						"Atomic replacement failed and backup recovery also failed. " +
						"Backup preserved at '$backupPath'. Replacement error: " +
						$replacementError.Exception.Message
					)
				}
			}
			throw "Atomic replacement failed; original document restored: $($replacementError.Exception.Message)"
		}

		[IO.File]::Delete($backupPath)
	}
	finally {
		if ([IO.File]::Exists($temporaryPath)) {
			[IO.File]::Delete($temporaryPath)
		}
		if ($replacementSucceeded -and [IO.File]::Exists($backupPath)) {
			[IO.File]::Delete($backupPath)
		}
	}
}

$repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$documentPath = Resolve-RepositoryDocumentPath `
	-RequestedPath $Path `
	-RepositoryRoot $repositoryRoot
$relativePath = Get-RepositoryRelativePath `
	-DocumentPath $documentPath `
	-RepositoryRoot $repositoryRoot
if (-not (Test-DocumentationMetadataEligibility -RelativePath $relativePath)) {
	throw "Document path is not eligible for repository metadata: $relativePath"
}

Assert-NoReparsePoints `
	-DocumentPath $documentPath `
	-RepositoryRoot $repositoryRoot

$originalBytes = [IO.File]::ReadAllBytes($documentPath)
$content = ConvertFrom-RepositoryUtf8 `
	-Bytes $originalBytes `
	-DocumentPath $relativePath
$failures = @(
	Test-DocumentationMetadataContent `
		-Content $content `
		-DocumentRelativePath $relativePath
)
if ($failures.Count -eq 0) {
	Write-Output "Metadata already valid: $relativePath"
	return
}

if ($failures -contains 'Existing documentation metadata is malformed or partial.') {
	throw "Document contains malformed or partial metadata: $relativePath"
}
$missingMetadataFailure = 'Documentation metadata is missing.'
if ($failures.Count -ne 1 -or
	-not $failures[0].Equals($missingMetadataFailure, [StringComparison]::Ordinal)) {
	throw "Cannot add documentation metadata to '$relativePath': $($failures -join ' ')"
}

$metadataTable = New-DocumentationMetadataTable `
	-Version $Version `
	-Date $Date `
	-Author $Author `
	-Status $Status `
	-Scope $Scope `
	-References $References `
	-DocumentRelativePath $relativePath
$updatedContent = Add-DocumentationMetadataTable `
	-Content $content `
	-MetadataTable $metadataTable

if ($PSCmdlet.ShouldProcess($relativePath, 'Insert documentation metadata')) {
	Write-AtomicDocumentationFile `
		-DestinationPath $documentPath `
		-Content $updatedContent `
		-ExpectedOriginalBytes $originalBytes
	Write-Output "Metadata added: $relativePath"
}