function Get-HrAiBuilderTask8ReplayHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$AdapterPath,
        [Parameter(Mandatory)][string]$RawPath
    )

    $capture = Read-HrAiBuilderJson -Path $Path -Description 'Task 8 replay'
    if ([string]$capture.run_id -cne 't2-dev-20260925-001' -or
        [string]$capture.model_name -cne 'PersonalMasterDataFixed' -or
        [string]$capture.model_version -cne '1.0' -or
        @($capture.documents).Count -ne 1 -or
        [string]$capture.documents[0].document -cne 'a01-CAND-2026-0411-brunner.pdf') {
        throw 'Task 8 replay does not have the exact historical run, model, version, and training document.'
    }
    if (-not [IO.Path]::IsPathRooted($AdapterPath) -or
        -not [IO.Path]::IsPathRooted($RawPath) -or
        [string]$capture.adapter_script_path -cne [IO.Path]::GetFullPath($AdapterPath) -or
        [string]$capture.documents[0].source_export_path -cne [IO.Path]::GetFullPath($RawPath)) {
        throw 'Task 8 replay metadata does not match the resolved live adapter and raw artifact paths.'
    }

    $bytes = [IO.File]::ReadAllBytes([IO.Path]::GetFullPath($Path))
    if ([Convert]::ToBase64String($bytes) -cne
        [Convert]::ToBase64String((ConvertTo-HrAiBuilderCanonicalJson -InputObject $capture))) {
        throw 'Task 8 replay is not canonically serialized.'
    }

    # These are historical serialization labels, never filesystem locations to read or execute.
    # Only this already identity-checked Task 8 capture used this namespace in its retained digest.
    $historicalRoot = 'C:\Users\anrizzi\Repositories\caldova-hr-frontier.worktrees\issue-13-ai-builder-setup-worktree'
    $capture.adapter_script_path = $historicalRoot + '\hr\src\scripts\adapters\ConvertFrom-HrAiBuilderEvaluationCapture.ps1'
    $capture.documents[0].source_export_path = $historicalRoot + '\hr\evidence\ai-builder\tenant-2\DEV\t2-dev-20260925-001\capture\cap-20260930094537354Z-34bf8987\cap-20260930094537354Z-34bf8987.ai-builder.raw.json'
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha256.ComputeHash((ConvertTo-HrAiBuilderCanonicalJson -InputObject $capture))
        return ([BitConverter]::ToString($hash)).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha256.Dispose()
    }
}
