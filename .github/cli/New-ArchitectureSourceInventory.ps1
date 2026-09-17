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

if (-not ('ArchitectureSourceInventoryInterop.NativeMethods' -as [type])) {
	Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

namespace ArchitectureSourceInventoryInterop
{
	[StructLayout(LayoutKind.Sequential)]
	public struct ByHandleFileInformation
	{
		public uint FileAttributes;
		public System.Runtime.InteropServices.ComTypes.FILETIME CreationTime;
		public System.Runtime.InteropServices.ComTypes.FILETIME LastAccessTime;
		public System.Runtime.InteropServices.ComTypes.FILETIME LastWriteTime;
		public uint VolumeSerialNumber;
		public uint FileSizeHigh;
		public uint FileSizeLow;
		public uint NumberOfLinks;
		public uint FileIndexHigh;
		public uint FileIndexLow;
	}

	public static class NativeMethods
	{
		[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
		public static extern SafeFileHandle CreateFile(
			string fileName,
			uint desiredAccess,
			uint shareMode,
			IntPtr securityAttributes,
			uint creationDisposition,
			uint flagsAndAttributes,
			IntPtr templateFile);

		[DllImport("kernel32.dll", SetLastError = true)]
		[return: MarshalAs(UnmanagedType.Bool)]
		public static extern bool GetFileInformationByHandle(
			SafeFileHandle file,
			out ByHandleFileInformation fileInformation);
	}
}
'@
}

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

function Get-PhysicalDirectoryIdentity {
	param(
		[Parameter(Mandatory)]
		[string]$Path
	)

	$handle = [ArchitectureSourceInventoryInterop.NativeMethods]::CreateFile(
		$Path,
		[uint32]0,
		[uint32]7,
		[IntPtr]::Zero,
		[uint32]3,
		[uint32]0x02000000,
		[IntPtr]::Zero
	)

	try {
		if ($handle.IsInvalid) {
			$errorCode = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
			throw "Unable to inspect directory identity for '$Path' (Win32 error $errorCode)."
		}

		$information = [ArchitectureSourceInventoryInterop.ByHandleFileInformation]::new()
		if (-not [ArchitectureSourceInventoryInterop.NativeMethods]::GetFileInformationByHandle(
			$handle,
			[ref]$information
		)) {
			$errorCode = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
			throw "Unable to inspect directory identity for '$Path' (Win32 error $errorCode)."
		}

		return [pscustomobject]@{
			VolumeSerialNumber = $information.VolumeSerialNumber
			FileIndexHigh = $information.FileIndexHigh
			FileIndexLow = $information.FileIndexLow
		}
	}
	finally {
		if ($null -ne $handle) {
			$handle.Dispose()
		}
	}
}

function Assert-OutputPathOutsideSourceRootByIdentity {
	param(
		[Parameter(Mandatory)]
		[string]$OutputPath,

		[Parameter(Mandatory)]
		[string]$OutputDirectory,

		[Parameter(Mandatory)]
		[string]$SourceRoot
	)

	$sourceIdentity = Get-PhysicalDirectoryIdentity -Path $SourceRoot
	$currentPath = $OutputDirectory
	while (-not [string]::IsNullOrEmpty($currentPath)) {
		if ([IO.Directory]::Exists($currentPath)) {
			$currentIdentity = Get-PhysicalDirectoryIdentity -Path $currentPath
			$isSourceRoot =
				$currentIdentity.VolumeSerialNumber -eq $sourceIdentity.VolumeSerialNumber -and
				$currentIdentity.FileIndexHigh -eq $sourceIdentity.FileIndexHigh -and
				$currentIdentity.FileIndexLow -eq $sourceIdentity.FileIndexLow
			if ($isSourceRoot) {
				throw "OutputPath must be outside SourceRoot: $OutputPath"
			}
		}

		$parentPath = [IO.Path]::GetDirectoryName($currentPath)
		if ([string]::IsNullOrEmpty($parentPath) -or $parentPath -eq $currentPath) {
			break
		}

		$currentPath = $parentPath
	}
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
Assert-OutputPathOutsideSourceRootByIdentity `
	-OutputPath $absoluteOutput `
	-OutputDirectory $outputDirectory `
	-SourceRoot $resolvedSourceRoot

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
