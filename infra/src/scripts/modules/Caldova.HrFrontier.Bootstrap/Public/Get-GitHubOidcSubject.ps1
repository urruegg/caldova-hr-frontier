function Get-GitHubOidcSubject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$')]
        [string]$Owner,

        [Parameter(Mandatory)]
        [ValidatePattern('^[1-9][0-9]*$')]
        [string]$OwnerId,

        [Parameter(Mandatory)]
        [ValidatePattern('^[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?$')]
        [string]$Repository,

        [Parameter(Mandatory)]
        [ValidatePattern('^[1-9][0-9]*$')]
        [string]$RepositoryId,

        [Parameter(Mandatory)]
        [ValidatePattern('^[a-z0-9]+$')]
        [string]$TenantAlias,

        [switch]$PrefixOnly
    )

    if ($Owner.Trim() -ne $Owner -or $Repository.Trim() -ne $Repository) {
        throw 'Owner and repository names must not include surrounding whitespace.'
    }

    if ($Owner -cnotmatch '^[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?$') {
        throw 'Owner must use the reviewed canonical name syntax.'
    }

    if ($Repository -cnotmatch '^[A-Za-z0-9](?:[A-Za-z0-9._-]*[A-Za-z0-9])?$') {
        throw 'Repository must use the reviewed canonical name syntax.'
    }

    $prefix = "repo:{0}@{1}/{2}@{3}" -f $Owner, $OwnerId, $Repository, $RepositoryId
    if ($PrefixOnly) {
        return $prefix
    }

    "{0}:environment:bootstrap-{1}" -f $prefix, $TenantAlias
}