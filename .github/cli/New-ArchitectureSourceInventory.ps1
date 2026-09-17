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
using System.Text;
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

	[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
	public struct ShareInfo2
	{
		[MarshalAs(UnmanagedType.LPWStr)]
		public string NetName;
		public uint Type;
		[MarshalAs(UnmanagedType.LPWStr)]
		public string Remark;
		public uint Permissions;
		public uint MaxUses;
		public uint CurrentUses;
		[MarshalAs(UnmanagedType.LPWStr)]
		public string Path;
		[MarshalAs(UnmanagedType.LPWStr)]
		public string Password;
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

		[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
		public static extern uint GetFinalPathNameByHandle(
			SafeFileHandle file,
			StringBuilder filePath,
			uint filePathLength,
			uint flags);

		[DllImport("Netapi32.dll", CharSet = CharSet.Unicode)]
		public static extern int NetShareGetInfo(
			string serverName,
			string netName,
			int level,
			out IntPtr buffer);

		[DllImport("Netapi32.dll")]
		public static extern int NetApiBufferFree(IntPtr buffer);
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

function Get-FinalPathNameFromHandle {
	param(
		[Parameter(Mandatory)]
		[Microsoft.Win32.SafeHandles.SafeFileHandle]$Handle,

		[Parameter(Mandatory)]
		[string]$InspectedPath
	)

	$capacity = 512
	while ($true) {
		$buffer = [Text.StringBuilder]::new($capacity)
		$length = [ArchitectureSourceInventoryInterop.NativeMethods]::GetFinalPathNameByHandle(
			$Handle,
			$buffer,
			[uint32]$buffer.Capacity,
			[uint32]0
		)

		if ($length -eq 0) {
			$errorCode = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
			throw "Unable to resolve final file system path for '$InspectedPath' (Win32 error $errorCode)."
		}

		if ($length -lt [uint32]$buffer.Capacity) {
			return Get-CanonicalFileSystemPath -Path $buffer.ToString()
		}

		if ($length -ge [int]::MaxValue) {
			throw "Unable to resolve final file system path for '$InspectedPath' because the required buffer is too large."
		}

		$capacity = [int]$length + 1
	}
}

function Get-FinalFileSystemPath {
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
			throw "Unable to open file system path '$Path' for final-path inspection (Win32 error $errorCode)."
		}

		return Get-FinalPathNameFromHandle -Handle $handle -InspectedPath $Path
	}
	finally {
		if ($null -ne $handle) {
			$handle.Dispose()
		}
	}
}

function Get-PhysicalOutputPath {
	param(
		[Parameter(Mandatory)]
		[string]$OutputPath
	)

	$currentPath = $OutputPath
	$suffixSegments = [Collections.Generic.List[string]]::new()
	$finalAncestorPath = $null
	while ([string]::IsNullOrEmpty($finalAncestorPath)) {
		$handle = [ArchitectureSourceInventoryInterop.NativeMethods]::CreateFile(
			$currentPath,
			[uint32]0,
			[uint32]7,
			[IntPtr]::Zero,
			[uint32]3,
			[uint32]0x02000000,
			[IntPtr]::Zero
		)
		$errorCode = 0

		try {
			if (-not $handle.IsInvalid) {
				$finalAncestorPath = Get-FinalPathNameFromHandle `
					-Handle $handle `
					-InspectedPath $currentPath
				continue
			}

			$errorCode = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
		}
		finally {
			if ($null -ne $handle) {
				$handle.Dispose()
			}
		}

		if ($errorCode -ne 2 -and $errorCode -ne 3) {
			throw "Unable to inspect OutputPath ancestor '$currentPath' (Win32 error $errorCode)."
		}

		$segment = [IO.Path]::GetFileName($currentPath)
		$parentPath = [IO.Path]::GetDirectoryName($currentPath)
		if ([string]::IsNullOrEmpty($segment) -or
			[string]::IsNullOrEmpty($parentPath) -or
			$parentPath -eq $currentPath) {
			throw "Unable to locate an existing ancestor for OutputPath: $OutputPath"
		}

		$suffixSegments.Insert(0, $segment)
		$currentPath = $parentPath
	}

	$finalAncestorPath = Resolve-LocalShareFinalPath `
		-FinalPath $finalAncestorPath `
		-ExistingPath $currentPath
	$physicalOutputPath = $finalAncestorPath
	foreach ($segment in $suffixSegments) {
		$physicalOutputPath = [IO.Path]::Combine($physicalOutputPath, $segment)
	}

	return Get-CanonicalFileSystemPath -Path $physicalOutputPath
}

function Assert-OutputPathOutsideSourceRootByFinalPath {
	param(
		[Parameter(Mandatory)]
		[string]$OutputPath,

		[Parameter(Mandatory)]
		[string]$SourceRoot
	)

	$physicalSourceRoot = Resolve-LocalShareFinalPath `
		-FinalPath (Get-FinalFileSystemPath -Path $SourceRoot) `
		-ExistingPath $SourceRoot
	$physicalOutputPath = Get-PhysicalOutputPath -OutputPath $OutputPath
	if (Test-PathIsAtOrBelow -Path $physicalOutputPath -Root $physicalSourceRoot) {
		throw "OutputPath must be outside SourceRoot: $OutputPath"
	}
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

function Test-IsLocalServerName {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[string]$ServerName
	)

	foreach ($localServerName in @(
		'.',
		'localhost',
		[Environment]::MachineName,
		[Net.Dns]::GetHostName()
	)) {
		if ($ServerName.Equals(
			$localServerName,
			[StringComparison]::OrdinalIgnoreCase
		)) {
			return $true
		}
	}

	return $false
}

function Resolve-LocalShareFinalPath {
	param(
		[Parameter(Mandatory)]
		[string]$FinalPath,

		[Parameter(Mandatory)]
		[string]$ExistingPath
	)

	if (-not $FinalPath.StartsWith('\\', [StringComparison]::Ordinal)) {
		return $FinalPath
	}

	$uncRemainder = $FinalPath.Substring(2)
	$serverSeparator = $uncRemainder.IndexOf([IO.Path]::DirectorySeparatorChar)
	if ($serverSeparator -le 0) {
		return $FinalPath
	}

	$serverName = $uncRemainder.Substring(0, $serverSeparator)
	if (-not (Test-IsLocalServerName -ServerName $serverName)) {
		return $FinalPath
	}

	$shareAndPath = $uncRemainder.Substring($serverSeparator + 1)
	$shareSeparator = $shareAndPath.IndexOf([IO.Path]::DirectorySeparatorChar)
	if ($shareSeparator -lt 0) {
		$shareName = $shareAndPath
		$relativePath = ''
	}
	else {
		$shareName = $shareAndPath.Substring(0, $shareSeparator)
		$relativePath = $shareAndPath.Substring($shareSeparator + 1)
	}

	if ([string]::IsNullOrEmpty($shareName)) {
		return $FinalPath
	}

	$buffer = [IntPtr]::Zero
	try {
		$status = [ArchitectureSourceInventoryInterop.NativeMethods]::NetShareGetInfo(
			'\\' + $serverName,
			$shareName,
			2,
			[ref]$buffer
		)
		if ($status -ne 0 -or $buffer -eq [IntPtr]::Zero) {
			return $FinalPath
		}

		$shareInfo = [Runtime.InteropServices.Marshal]::PtrToStructure(
			$buffer,
			[type][ArchitectureSourceInventoryInterop.ShareInfo2]
		)
		if ([string]::IsNullOrEmpty($shareInfo.Path)) {
			return $FinalPath
		}

		$localCandidate = if ([string]::IsNullOrEmpty($relativePath)) {
			$shareInfo.Path
		}
		else {
			[IO.Path]::Combine($shareInfo.Path, $relativePath)
		}
		$localCandidate = Get-CanonicalFileSystemPath -Path $localCandidate
		if (-not [IO.File]::Exists($localCandidate) -and
			-not [IO.Directory]::Exists($localCandidate)) {
			return $FinalPath
		}

		$shareIdentity = Get-PhysicalDirectoryIdentity -Path $ExistingPath
		$localIdentity = Get-PhysicalDirectoryIdentity -Path $localCandidate
		$isSameEntry =
			$shareIdentity.VolumeSerialNumber -eq $localIdentity.VolumeSerialNumber -and
			$shareIdentity.FileIndexHigh -eq $localIdentity.FileIndexHigh -and
			$shareIdentity.FileIndexLow -eq $localIdentity.FileIndexLow
		if ($isSameEntry) {
			return Get-FinalFileSystemPath -Path $localCandidate
		}

		return $FinalPath
	}
	finally {
		if ($buffer -ne [IntPtr]::Zero) {
			[void][ArchitectureSourceInventoryInterop.NativeMethods]::NetApiBufferFree($buffer)
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

function Write-AtomicInventoryFile {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[string]$DestinationPath,

		[Parameter(Mandatory)]
		[string]$Content,

		[scriptblock]$ReplacementOperation = {
			param($TemporaryPath, $DestinationPath, $BackupPath)

			[IO.File]::Replace($TemporaryPath, $DestinationPath, $BackupPath)
		}
	)

	$outputDirectory = [IO.Path]::GetDirectoryName($DestinationPath)
	$temporaryOutput = Join-Path $outputDirectory (
		'.{0}.{1}.tmp' -f
			[IO.Path]::GetFileName($DestinationPath),
			[Guid]::NewGuid().ToString('N')
	)
	$backupOutput = $temporaryOutput + '.backup'
	$replacementSucceeded = $false

	try {
		[IO.File]::WriteAllText(
			$temporaryOutput,
			$Content,
			[Text.UTF8Encoding]::new($false)
		)

		if ([IO.File]::Exists($DestinationPath)) {
			try {
				$null = & $ReplacementOperation `
					$temporaryOutput `
					$DestinationPath `
					$backupOutput
				if (-not [IO.File]::Exists($DestinationPath) -or
					[IO.File]::Exists($temporaryOutput)) {
					throw 'Replacement operation did not complete the destination swap.'
				}

				$replacementSucceeded = $true
			}
			catch {
				$replacementError = $_
				if ([IO.File]::Exists($backupOutput)) {
					if (-not [IO.File]::Exists($DestinationPath)) {
						try {
							[IO.File]::Move($backupOutput, $DestinationPath)
						}
						catch {
							throw (
								"Failed to replace inventory destination '$DestinationPath'. " +
								"The original remains at backup '$backupOutput' because restoration failed. " +
								"Replacement error: $($replacementError.Exception.Message) " +
								"Restoration error: $($_.Exception.Message)"
							)
						}

						throw (
							"Failed to replace inventory destination '$DestinationPath'. " +
							"Original destination restored. $($replacementError.Exception.Message)"
						)
					}

					throw (
						"Failed to replace inventory destination '$DestinationPath'. " +
						"The destination and backup were preserved. Backup: '$backupOutput'. " +
						$replacementError.Exception.Message
					)
				}

				throw (
					"Failed to replace inventory destination '$DestinationPath'. " +
					$replacementError.Exception.Message
				)
			}
		}
		else {
			[IO.File]::Move($temporaryOutput, $DestinationPath)
			$replacementSucceeded = [IO.File]::Exists($DestinationPath) -and
				-not [IO.File]::Exists($temporaryOutput)
		}
	}
	finally {
		if ([IO.File]::Exists($temporaryOutput)) {
			[IO.File]::Delete($temporaryOutput)
		}

		if ($replacementSucceeded -and [IO.File]::Exists($backupOutput)) {
			[IO.File]::Delete($backupOutput)
		}
	}
}

if ($MyInvocation.InvocationName -eq '.') {
	return
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
Assert-OutputPathOutsideSourceRootByFinalPath `
	-OutputPath $absoluteOutput `
	-SourceRoot $resolvedSourceRoot
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

Write-AtomicInventoryFile `
	-DestinationPath $absoluteOutput `
	-Content $normalizedJson

Write-Output "Wrote source inventory: $OutputPath"
