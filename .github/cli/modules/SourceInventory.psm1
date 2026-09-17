Set-StrictMode -Version Latest
function Get-ArchitectureSourceInventory {
 [CmdletBinding()] param([Parameter(Mandatory)][string]$SourceRoot,[Parameter(Mandatory)][string]$GeneratedUtc)
 $resolvedRoot=(Resolve-Path -LiteralPath $SourceRoot).Path; $rootItem=Get-Item -LiteralPath $resolvedRoot -Force
 if($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Source root must not be a reparse point: $resolvedRoot"}
 if(Test-Path -LiteralPath (Join-Path $resolvedRoot '.git')){throw 'Nested Git metadata is not allowed in the architecture source.'}
 $gitMetadata=@(Get-ChildItem -LiteralPath $resolvedRoot -Force -Recurse -ErrorAction Stop | Where-Object { $_.Name -ieq '.git' })
 if($gitMetadata.Count -gt 0){throw 'Nested Git metadata is not allowed in the architecture source.'}
 $recordsByPath=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
 foreach($fileItem in @(Get-ChildItem -LiteralPath $resolvedRoot -File -Recurse -Force)){ if($fileItem.Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Reparse point is not allowed: $($fileItem.FullName)"}; $relativePath=$fileItem.FullName.Substring($resolvedRoot.Length).TrimStart('\').Replace('\','/'); $recordsByPath.Add($relativePath,[ordered]@{relativePath=$relativePath;bytes=[long]$fileItem.Length;sha256=(Get-FileHash -LiteralPath $fileItem.FullName -Algorithm SHA256).Hash.ToLowerInvariant()}) }
 [string[]]$sortedPaths=@($recordsByPath.Keys); [Array]::Sort($sortedPaths,[StringComparer]::Ordinal); $sorted=@($sortedPaths|ForEach-Object{$recordsByPath[$_]}); $totalBytes=[long]0; foreach($record in $sorted){$totalBytes += [long]$record.bytes}; [ordered]@{schemaVersion='1.0';generatedUtc=$GeneratedUtc;sourceName=(Split-Path -Leaf $resolvedRoot);totalCount=$sorted.Count;totalBytes=$totalBytes;files=$sorted}
}
Export-ModuleMember -Function Get-ArchitectureSourceInventory