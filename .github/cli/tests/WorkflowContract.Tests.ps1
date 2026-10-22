BeforeAll {
    $script:repositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..\..'))
    $script:workflowRoot = Join-Path $script:repositoryRoot '.github\workflows'
    $script:workflowPath = Join-Path $script:workflowRoot 'validate-repository.yml'
    $script:selectorPath = Join-Path $script:repositoryRoot '.github\cli\Get-MaintainedTestGroups.ps1'
    $script:checkoutSha = '3d3c42e5aac5ba805825da76410c181273ba90b1'
    $script:uploadSha = 'ea165f8d65b6e75b540449e92b4886f43607fa02'

    function script:Get-ScalarValue {
        param(
            [Parameter(Mandatory)][AllowEmptyString()][string[]]$Lines,
            [Parameter(Mandatory)][int]$Indent,
            [Parameter(Mandatory)][string]$Key
        )

        $pattern = '^{0}{1}:\s*(?<value>.*?)\s*$' -f (
            ' ' * $Indent
        ), [regex]::Escape($Key)
        $matches = @($Lines | Where-Object { $_ -match $pattern })
        if ($matches.Count -gt 1) {
            throw "Workflow contract parser found duplicate '$Key' values."
        }
        if ($matches.Count -eq 0) {
            return $null
        }
        [regex]::Match($matches[0], $pattern).Groups['value'].Value
    }

    function script:Get-TopLevelBlock {
        param(
            [Parameter(Mandatory)][AllowEmptyString()][string[]]$Lines,
            [Parameter(Mandatory)][string]$Key,
            [switch]$AllowMissing
        )

        $header = "$Key`:"
        $indices = @(
            for ($index = 0; $index -lt $Lines.Count; $index++) {
                if ($Lines[$index] -ceq $header) {
                    $index
                }
            }
        )
        if ($indices.Count -eq 0 -and $AllowMissing) {
            return [string[]]@()
        }
        if ($indices.Count -ne 1) {
            throw "Workflow contract parser expected one top-level '$Key' block."
        }

        $rows = [Collections.Generic.List[string]]::new()
        for ($index = $indices[0] + 1; $index -lt $Lines.Count; $index++) {
            $line = $Lines[$index]
            if (
                -not [string]::IsNullOrWhiteSpace($line) -and
                $line -cmatch '^\S'
            ) {
                break
            }
            [void]$rows.Add($line)
        }
        [string[]]$rows
    }

    function script:ConvertFrom-ImplicitMappingKey {
        param(
            [Parameter(Mandatory)][string]$RawKey,
            [Parameter(Mandatory)][string]$Context
        )

        try {
            if ($RawKey.StartsWith("'", [StringComparison]::Ordinal)) {
                if (
                    $RawKey.Length -lt 2 -or
                    -not $RawKey.EndsWith(
                        "'",
                        [StringComparison]::Ordinal
                    )
                ) {
                    throw 'Malformed single-quoted key.'
                }
                $innerKey = $RawKey.Substring(1, $RawKey.Length - 2)
                if ($innerKey.Replace("''", '').Contains("'")) {
                    throw 'Malformed single-quoted key.'
                }
                $decodedKey = $innerKey.Replace("''", "'")
            }
            elseif ($RawKey.StartsWith('"', [StringComparison]::Ordinal)) {
                $decodedKey = ConvertFrom-Json `
                    -InputObject $RawKey `
                    -ErrorAction Stop
                if ($decodedKey -isnot [string]) {
                    throw 'Non-string key.'
                }
            }
            elseif ($RawKey -cmatch '[''"]') {
                throw 'Malformed quoted key.'
            }
            else {
                $decodedKey = $RawKey
            }
        }
        catch {
            throw "Workflow contract parser found a malformed mapping key in $Context."
        }

        [string]$decodedKey
    }

    function script:Get-ImplicitMappingKeys {
        param(
            [Parameter(Mandatory)][AllowEmptyString()][string]$Line
        )

        $pattern = [regex]::new(
            '(?:^\s*(?:-\s+)?|[\{\[,]\s*)' +
            '(?<rawKey>' +
            "'(?:[^']|'')*'" +
            '|' +
            '"(?:\\.|[^"\\])*"' +
            '|' +
            '[A-Za-z0-9_-]+' +
            ')\s*:(?=\s|$|[\[\]\{\},])'
        )
        foreach ($mappingMatch in $pattern.Matches($Line)) {
            ConvertFrom-ImplicitMappingKey `
                -RawKey $mappingMatch.Groups['rawKey'].Value `
                -Context 'the workflow structural scan'
        }
    }

    function script:Test-IsSupportedRunBlockContentLine {
        param(
            [Parameter(Mandatory)][AllowEmptyString()][string]$Line
        )

        [string]::IsNullOrEmpty($Line) -or $Line -cmatch '^          '
    }

    function script:Test-IsSupportedRunBlockHeader {
        param(
            [Parameter(Mandatory)][AllowEmptyString()][string]$Line
        )

        if (
            $Line -cnotmatch (
                '^        (?<rawKey>\S[^:]*?):\s*' +
                '(?<scalar>[|>])\s*$'
            )
        ) {
            return $false
        }
        $decodedKey = ConvertFrom-ImplicitMappingKey `
            -RawKey $Matches['rawKey'].Trim() `
            -Context 'the workflow structural scan'
        [string]$decodedKey -ceq 'run'
    }

    function script:Test-ContainsExplicitMappingKeyIndicator {
        param(
            [Parameter(Mandatory)][AllowEmptyString()][string]$Line
        )

        function Test-IsStructuralTokenStart {
            param([Parameter(Mandatory)][int]$Index)

            $previousIndex = $Index - 1
            while (
                $previousIndex -ge 0 -and
                [char]::IsWhiteSpace($Line[$previousIndex])
            ) {
                $previousIndex--
            }
            if (
                $previousIndex -lt 0 -or
                '{[,:'.Contains([string]$Line[$previousIndex])
            ) {
                return $true
            }
            if ($Line[$previousIndex] -cne '-') {
                return $false
            }

            $beforeDash = $previousIndex - 1
            while (
                $beforeDash -ge 0 -and
                [char]::IsWhiteSpace($Line[$beforeDash])
            ) {
                $beforeDash--
            }
            $beforeDash -lt 0
        }

        $insideSingleQuote = $false
        $insideDoubleQuote = $false
        for ($index = 0; $index -lt $Line.Length; $index++) {
            $character = $Line[$index]
            if ($insideSingleQuote) {
                if ($character -ceq "'") {
                    if (
                        $index + 1 -lt $Line.Length -and
                        $Line[$index + 1] -ceq "'"
                    ) {
                        $index++
                    }
                    else {
                        $insideSingleQuote = $false
                    }
                }
                continue
            }
            if ($insideDoubleQuote) {
                if (
                    $character -ceq '\' -and
                    $index + 1 -lt $Line.Length
                ) {
                    $index++
                }
                elseif ($character -ceq '"') {
                    $insideDoubleQuote = $false
                }
                continue
            }
            if (
                $character -ceq "'" -and
                (Test-IsStructuralTokenStart -Index $index)
            ) {
                $insideSingleQuote = $true
                continue
            }
            if (
                $character -ceq '"' -and
                (Test-IsStructuralTokenStart -Index $index)
            ) {
                $insideDoubleQuote = $true
                continue
            }
            if (
                $character -ceq '#' -and
                (
                    $index -eq 0 -or
                    [char]::IsWhiteSpace($Line[$index - 1])
                )
            ) {
                return $false
            }
            if ($character -cne '?') {
                continue
            }

            $nextIsSeparation = (
                $index + 1 -eq $Line.Length -or
                [char]::IsWhiteSpace($Line[$index + 1]) -or
                ',[]{}:'.Contains([string]$Line[$index + 1])
            )
            if (-not $nextIsSeparation) {
                continue
            }
            if (Test-IsStructuralTokenStart -Index $index) {
                return $true
            }
        }

        $false
    }

    function script:Assert-NoUnsupportedMappingKeySyntax {
        param(
            [Parameter(Mandatory)][AllowEmptyString()][string[]]$Lines
        )

        $insideSupportedRunBlock = $false
        foreach ($line in $Lines) {
            if ($insideSupportedRunBlock) {
                if (Test-IsSupportedRunBlockContentLine -Line $line) {
                    continue
                }
                $insideSupportedRunBlock = $false
            }
            if (Test-IsSupportedRunBlockHeader -Line $line) {
                $insideSupportedRunBlock = $true
                continue
            }
            if (Test-ContainsExplicitMappingKeyIndicator -Line $line) {
                throw (
                    'Workflow contract parser rejects an explicit or ' +
                    'multiline mapping key in the workflow.'
                )
            }
            foreach ($decodedKey in @(Get-ImplicitMappingKeys -Line $line)) {
                if (
                    [string]::Equals(
                        [string]$decodedKey,
                        'paths',
                        [StringComparison]::OrdinalIgnoreCase
                    ) -or
                    [string]::Equals(
                        [string]$decodedKey,
                        'paths-ignore',
                        [StringComparison]::OrdinalIgnoreCase
                    )
                ) {
                    throw (
                        "Workflow contract parser rejects path-filter mapping key " +
                        "'$decodedKey'."
                    )
                }
            }
        }
    }

    function script:ConvertFrom-StepLines {
        param(
            [Parameter(Mandatory)][AllowEmptyString()][string[]]$Lines
        )

        $name = Get-ScalarValue -Lines $Lines -Indent 8 -Key 'name'
        if ([string]::IsNullOrWhiteSpace($name)) {
            throw 'Workflow contract parser requires every step to have a name.'
        }

        $with = [ordered]@{}
        $withIndex = -1
        for ($index = 0; $index -lt $Lines.Count; $index++) {
            if ($Lines[$index] -ceq '        with:') {
                if ($withIndex -ne -1) {
                    throw "Workflow contract parser found duplicate with blocks in '$name'."
                }
                $withIndex = $index
            }
        }
        if ($withIndex -ne -1) {
            for ($index = $withIndex + 1; $index -lt $Lines.Count; $index++) {
                $line = $Lines[$index]
                if ([string]::IsNullOrWhiteSpace($line)) {
                    continue
                }
                if ($line -cnotmatch '^          (?<key>[A-Za-z0-9_-]+):\s*(?<value>.*?)\s*$') {
                    break
                }
                $key = $Matches['key']
                if ($with.Contains($key)) {
                    throw "Workflow contract parser found duplicate with key '$key' in '$name'."
                }
                $with[$key] = $Matches['value']
            }
        }

        $runRows = [Collections.Generic.List[object]]::new()
        for ($index = 0; $index -lt $Lines.Count; $index++) {
            $line = $Lines[$index]
            if (
                $line -cmatch (
                    '^        (?<rawKey>\S[^:]*?):\s*' +
                    '(?<scalar>.*?)\s*$'
                )
            ) {
                $rawKey = $Matches['rawKey'].Trim()
                $scalar = $Matches['scalar']
                $decodedKey = ConvertFrom-ImplicitMappingKey `
                    -RawKey $rawKey `
                    -Context "'$name'"

                if ([string]$decodedKey -ceq 'run') {
                    [void]$runRows.Add([pscustomobject]@{
                        Index = $index
                        Scalar = $scalar
                    })
                }
                elseif (
                    [string]$decodedKey -imatch '^run' -or
                    $rawKey -imatch 'run'
                ) {
                    throw "Workflow contract parser rejects alternate run key '$rawKey' in '$name'."
                }
            }
            elseif ($line -cmatch '^        [''"]?run') {
                throw "Workflow contract parser found a malformed run key in '$name'."
            }
        }
        if ($runRows.Count -gt 1) {
            throw "Workflow contract parser found duplicate run scalars in '$name'."
        }

        $run = $null
        if ($runRows.Count -eq 1) {
            $runRow = $runRows[0]
            $contentRows = [Collections.Generic.List[string]]::new()
            for ($index = $runRow.Index + 1; $index -lt $Lines.Count; $index++) {
                $line = $Lines[$index]
                if (-not (Test-IsSupportedRunBlockContentLine -Line $line)) {
                    break
                }
                if ($line.Length -ge 10) {
                    [void]$contentRows.Add($line.Substring(10))
                }
                else {
                    [void]$contentRows.Add('')
                }
            }

            if ($runRow.Scalar -cin @('|', '>')) {
                if (
                    $contentRows.Count -eq 0 -or
                    [string]::IsNullOrWhiteSpace(($contentRows -join "`n"))
                ) {
                    throw "Workflow contract parser found an empty run block in '$name'."
                }

                if ($runRow.Scalar -ceq '|') {
                    $run = $contentRows -join "`n"
                }
                else {
                    foreach ($contentRow in $contentRows) {
                        if (
                            [string]::IsNullOrEmpty($contentRow) -or
                            $contentRow.StartsWith(
                                ' ',
                                [StringComparison]::Ordinal
                            ) -or
                            $contentRow.StartsWith(
                                "`t",
                                [StringComparison]::Ordinal
                            ) -or
                            $contentRow -cmatch '`\s*$'
                        ) {
                            throw "Workflow contract parser cannot prove folded run semantics in '$name'."
                        }
                    }
                    $run = $contentRows -join ' '
                }
            }
            else {
                if (
                    [string]::IsNullOrWhiteSpace($runRow.Scalar) -or
                    $runRow.Scalar -cmatch '^[|>]' -or
                    $contentRows.Count -ne 0 -or
                    $runRow.Scalar -cin @('null', 'Null', 'NULL', '~') -or
                    $runRow.Scalar -cmatch '^[\[\{&*!]'
                ) {
                    throw "Workflow contract parser found an unsupported run scalar in '$name'."
                }
                $scalar = [string]$runRow.Scalar
                if ($scalar.StartsWith("'", [StringComparison]::Ordinal)) {
                    if (
                        $scalar.Length -lt 2 -or
                        -not $scalar.EndsWith("'", [StringComparison]::Ordinal)
                    ) {
                        throw "Workflow contract parser found malformed single-quoted run text in '$name'."
                    }
                    $inner = $scalar.Substring(1, $scalar.Length - 2)
                    if ($inner.Replace("''", '').Contains("'")) {
                        throw "Workflow contract parser found malformed single-quoted run text in '$name'."
                    }
                    $run = $inner.Replace("''", "'")
                }
                elseif ($scalar.StartsWith('"', [StringComparison]::Ordinal)) {
                    try {
                        $decoded = ConvertFrom-Json -InputObject $scalar -ErrorAction Stop
                    }
                    catch {
                        throw "Workflow contract parser found malformed double-quoted run text in '$name'."
                    }
                    if ($decoded -isnot [string]) {
                        throw "Workflow contract parser found a non-string run scalar in '$name'."
                    }
                    $run = [string]$decoded
                }
                else {
                    $run = $scalar
                }
            }
        }

        [pscustomobject]@{
            Name = $name
            Uses = Get-ScalarValue -Lines $Lines -Indent 8 -Key 'uses'
            Shell = Get-ScalarValue -Lines $Lines -Indent 8 -Key 'shell'
            If = Get-ScalarValue -Lines $Lines -Indent 8 -Key 'if'
            With = $with
            Run = $run
            Lines = [string[]]$Lines
        }
    }

    function script:ConvertFrom-JobLines {
        param(
            [Parameter(Mandatory)][string]$Id,
            [Parameter(Mandatory)][AllowEmptyString()][string[]]$Lines
        )

        $permissionRows = @(
            for ($index = 0; $index -lt $Lines.Count; $index++) {
                if ($Lines[$index] -cmatch '^    permissions:\s*(?<inline>.*?)\s*$') {
                    [pscustomobject]@{
                        Index = $index
                        Inline = $Matches['inline']
                    }
                }
            }
        )
        if ($permissionRows.Count -gt 1) {
            throw "Workflow contract parser found duplicate permissions blocks in '$Id'."
        }
        $permissions = [ordered]@{}
        if ($permissionRows.Count -eq 1) {
            if (-not [string]::IsNullOrWhiteSpace($permissionRows[0].Inline)) {
                throw "Workflow contract parser rejects inline job permissions in '$Id'."
            }
            for (
                $index = $permissionRows[0].Index + 1;
                $index -lt $Lines.Count;
                $index++
            ) {
                $line = $Lines[$index]
                if ([string]::IsNullOrWhiteSpace($line)) {
                    continue
                }
                if ($line -cmatch '^      (?<key>[A-Za-z0-9_-]+):\s*(?<value>\S+)\s*$') {
                    $key = $Matches['key']
                    if ($permissions.Contains($key)) {
                        throw "Workflow contract parser found duplicate job permission '$key' in '$Id'."
                    }
                    $permissions[$key] = $Matches['value']
                    continue
                }
                if ($line -cmatch '^      (?!-)') {
                    throw "Workflow contract parser found malformed job permissions in '$Id'."
                }
                break
            }
        }

        $stepStarts = @(
            for ($index = 0; $index -lt $Lines.Count; $index++) {
                if ($Lines[$index] -cmatch '^      - ') {
                    $index
                }
            }
        )
        $namedStepStarts = @(
            $stepStarts | Where-Object {
                $Lines[$_] -cmatch '^      - name:\s*\S'
            }
        )
        if ($stepStarts.Count -ne $namedStepStarts.Count) {
            throw "Workflow contract parser found an unnamed or malformed step in '$Id'."
        }

        $steps = [Collections.Generic.List[object]]::new()
        for ($stepIndex = 0; $stepIndex -lt $stepStarts.Count; $stepIndex++) {
            $start = $stepStarts[$stepIndex]
            $finish = if ($stepIndex + 1 -lt $stepStarts.Count) {
                $stepStarts[$stepIndex + 1] - 1
            }
            else {
                $Lines.Count - 1
            }
            [string[]]$stepLines = @($Lines[$start..$finish])
            $stepLines[0] = $stepLines[0] -replace '^      - ', '        '
            [void]$steps.Add((ConvertFrom-StepLines -Lines $stepLines))
        }

        $needsValue = Get-ScalarValue -Lines $Lines -Indent 4 -Key 'needs'
        [string[]]$needs = @()
        if (-not [string]::IsNullOrWhiteSpace($needsValue)) {
            if ($needsValue -cnotmatch '^\[(?<items>.*?)\]$') {
                throw "Workflow contract parser requires inline needs for '$Id'."
            }
            $needs = [string[]]@(
                $Matches['items'].Split(',') |
                    ForEach-Object { $_.Trim() } |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            )
        }

        [pscustomobject]@{
            Id = $Id
            Name = Get-ScalarValue -Lines $Lines -Indent 4 -Key 'name'
            RunsOn = Get-ScalarValue -Lines $Lines -Indent 4 -Key 'runs-on'
            TimeoutMinutes = Get-ScalarValue -Lines $Lines -Indent 4 -Key 'timeout-minutes'
            If = Get-ScalarValue -Lines $Lines -Indent 4 -Key 'if'
            Needs = $needs
            HasPermissions = $permissionRows.Count -eq 1
            Permissions = $permissions
            Steps = [object[]]$steps
            Lines = [string[]]$Lines
        }
    }

    function script:ConvertFrom-WorkflowLines {
        param(
            [Parameter(Mandatory)][AllowEmptyString()][string[]]$Lines
        )

        Assert-NoUnsupportedMappingKeySyntax -Lines $Lines

        $jobsBlock = Get-TopLevelBlock -Lines $Lines -Key 'jobs'
        $jobStarts = @(
            for ($index = 0; $index -lt $jobsBlock.Count; $index++) {
                if ($jobsBlock[$index] -cmatch '^  (?<id>[a-z][a-z0-9_-]*):\s*$') {
                    [pscustomobject]@{
                        Index = $index
                        Id = $Matches['id']
                    }
                }
            }
        )
        if ($jobStarts.Count -eq 0) {
            throw 'Workflow contract parser found no jobs.'
        }

        $jobs = [ordered]@{}
        for ($jobIndex = 0; $jobIndex -lt $jobStarts.Count; $jobIndex++) {
            $start = $jobStarts[$jobIndex].Index
            $finish = if ($jobIndex + 1 -lt $jobStarts.Count) {
                $jobStarts[$jobIndex + 1].Index - 1
            }
            else {
                $jobsBlock.Count - 1
            }
            $id = $jobStarts[$jobIndex].Id
            if ($jobs.Contains($id)) {
                throw "Workflow contract parser found duplicate job '$id'."
            }
            $jobs[$id] = ConvertFrom-JobLines -Id $id -Lines @(
                $jobsBlock[$start..$finish]
            )
        }

        $permissionsBlock = Get-TopLevelBlock -Lines $Lines -Key 'permissions'
        $permissions = [ordered]@{}
        foreach ($line in $permissionsBlock) {
            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }
            if ($line -cnotmatch '^  (?<key>[A-Za-z0-9_-]+):\s*(?<value>\S+)\s*$') {
                throw 'Workflow contract parser found malformed global permissions.'
            }
            $permissions[$Matches['key']] = $Matches['value']
        }

        $concurrencyBlock = Get-TopLevelBlock `
            -Lines $Lines `
            -Key 'concurrency' `
            -AllowMissing
        $concurrency = [ordered]@{}
        foreach ($line in $concurrencyBlock) {
            if ([string]::IsNullOrWhiteSpace($line)) {
                continue
            }
            if ($line -cnotmatch '^  (?<key>[A-Za-z0-9_-]+):\s*(?<value>.*?)\s*$') {
                throw 'Workflow contract parser found malformed concurrency configuration.'
            }
            $concurrency[$Matches['key']] = $Matches['value']
        }

        [pscustomobject]@{
            Name = Get-ScalarValue -Lines $Lines -Indent 0 -Key 'name'
            OnLines = Get-TopLevelBlock -Lines $Lines -Key 'on'
            Permissions = $permissions
            Concurrency = $concurrency
            Jobs = $jobs
            Lines = [string[]]$Lines
        }
    }

    function script:Get-NamedStep {
        param(
            [Parameter(Mandatory)][object]$Job,
            [Parameter(Mandatory)][string]$Name
        )

        $steps = @($Job.Steps | Where-Object Name -CEQ $Name)
        if ($steps.Count -ne 1) {
            throw "Workflow contract expected one '$Name' step in '$($Job.Id)'."
        }
        $steps[0]
    }

    function script:Assert-WorkflowPermissions {
        param(
            [Parameter(Mandatory)][object]$Workflow
        )

        @($Workflow.Permissions.Keys) | Should -Be @('contents')
        $Workflow.Permissions['contents'] | Should -BeExactly 'read'
        foreach ($job in $Workflow.Jobs.Values) {
            $job.PSObject.Properties.Name |
                Should -Contain 'HasPermissions'
            $job.HasPermissions |
                Should -BeFalse -Because "job '$($job.Id)' must inherit global read-only permissions"
            $job.Permissions.Count | Should -Be 0
        }
    }

    function script:Assert-WorkflowCommandOwnership {
        param(
            [Parameter(Mandatory)][object]$Workflow
        )

        $actionUses = @(
            foreach ($job in $Workflow.Jobs.Values) {
                $job.Steps.Uses |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            }
        )
        foreach ($actionUse in $actionUses) {
            $actionUse | Should -BeIn @(
                "actions/checkout@$($script:checkoutSha)"
                "actions/upload-artifact@$($script:uploadSha)"
            )
        }

        $commandOwners = @{
            'repository::Run repository tests' = @(
                '.github/cli/Install-CiTestDependencies.ps1'
                '.github/cli/Get-MaintainedTestGroups.ps1'
                '.github/cli/Invoke-MaintainedTestGroup.ps1'
            )
            'repository::Run repository safety validation' = @(
                '.github/cli/verify-repository-safety.ps1'
            )
            'repository::Check branch whitespace' = @(
                'git'
            )
            'infrastructure::Run infrastructure tests' = @(
                '.github/cli/Install-CiTestDependencies.ps1'
                '.github/cli/Get-MaintainedTestGroups.ps1'
                '.github/cli/Invoke-MaintainedTestGroup.ps1'
            )
            'infrastructure::Build every maintained Bicep entry point' = @(
                'Get-ChildItem'
                'Sort-Object'
                'az'
                'Out-Null'
            )
            'hr::Run HR tests' = @(
                '.github/cli/Install-CiTestDependencies.ps1'
                '.github/cli/Get-MaintainedTestGroups.ps1'
                '.github/cli/Invoke-MaintainedTestGroup.ps1'
            )
            'lifecycle::Run lifecycle tests' = @(
                '.github/cli/Install-CiTestDependencies.ps1'
                '.github/cli/Get-MaintainedTestGroups.ps1'
                '.github/cli/Invoke-MaintainedTestGroup.ps1'
            )
            'validate::Require every validation domain' = @(
                'Where-Object'
                'ForEach-Object'
            )
        }
        $approvedHelpers = [Collections.Generic.HashSet[string]]::new(
            [string[]]@(
                '.github/cli/Install-CiTestDependencies.ps1'
                '.github/cli/Get-MaintainedTestGroups.ps1'
                '.github/cli/Invoke-MaintainedTestGroup.ps1'
                '.github/cli/verify-repository-safety.ps1'
            ),
            [StringComparer]::OrdinalIgnoreCase
        )
        $memberOwners = @{
            'repository::Run repository tests' = @(
                'True:[IO.Path]::GetFullPath'
            )
            'repository::Check branch whitespace' = @(
                'True:[string]::IsNullOrWhiteSpace'
            )
            'infrastructure::Run infrastructure tests' = @(
                'True:[IO.Path]::GetFullPath'
            )
            'hr::Run HR tests' = @(
                'True:[IO.Path]::GetFullPath'
            )
            'lifecycle::Run lifecycle tests' = @(
                'True:[IO.Path]::GetFullPath'
            )
            'validate::Require every validation domain' = @(
                'False:$results::GetEnumerator'
            )
        }

        foreach ($job in $Workflow.Jobs.Values) {
            foreach ($step in @($job.Steps | Where-Object {
                -not [string]::IsNullOrWhiteSpace($_.Run)
            })) {
                $owner = "$($job.Id)::$($step.Name)"
                if (-not $commandOwners.ContainsKey($owner)) {
                    throw "Workflow command owner is not reviewed: $owner"
                }

                $tokens = $null
                $parseErrors = $null
                $ast = [Management.Automation.Language.Parser]::ParseInput(
                    $step.Run,
                    [ref]$tokens,
                    [ref]$parseErrors
                )
                if ($parseErrors.Count -ne 0) {
                    throw "Workflow run block is not valid PowerShell: $owner"
                }
                if ($null -ne $ast.ScriptRequirements) {
                    throw "Workflow run block contains script requirements: $owner"
                }
                $usingStatements = @($ast.FindAll({
                    param($node)
                    $node -is [Management.Automation.Language.UsingStatementAst]
                }, $true))
                if ($usingStatements.Count -ne 0) {
                    throw "Workflow run block contains a using statement: $owner"
                }
                $commands = @($ast.FindAll({
                    param($node)
                    $node -is [Management.Automation.Language.CommandAst]
                }, $true))
                $allowed = [Collections.Generic.HashSet[string]]::new(
                    [string[]]$commandOwners[$owner],
                    [StringComparer]::OrdinalIgnoreCase
                )
                foreach ($command in $commands) {
                    $commandName = $command.GetCommandName()
                    if (
                        [string]::IsNullOrWhiteSpace($commandName) -or
                        -not $allowed.Contains($commandName)
                    ) {
                        throw "Workflow command is not owned by ${owner}: $commandName"
                    }

                    if (
                        $command.InvocationOperator -eq (
                            [Management.Automation.Language.TokenKind]::Ampersand
                        )
                    ) {
                        $literal = $command.CommandElements[0]
                        if (
                            -not $approvedHelpers.Contains($commandName) -or
                            $literal -isnot (
                                [Management.Automation.Language.StringConstantExpressionAst]
                            ) -or
                            [string]$literal.Value -cne $commandName
                        ) {
                            throw "Workflow call operator target is not an approved literal helper: $owner"
                        }
                    }
                    elseif ($approvedHelpers.Contains($commandName)) {
                        throw "Approved helper must use the call operator: ${owner}: $commandName"
                    }

                    if ($commandName -ieq 'git') {
                        if ($owner -cne 'repository::Check branch whitespace') {
                            throw "Git is not owned by ${owner}."
                        }
                        [string[]]$elements = @(
                            $command.CommandElements |
                                ForEach-Object { $_.Extent.Text }
                        )
                        [string[]]$shape = @(
                            $elements | ForEach-Object {
                                $_.Trim('"')
                            }
                        )
                        $mergeBase = @('git', 'merge-base', '$baseRef', 'HEAD')
                        $diffCheck = @(
                            'git'
                            'diff'
                            '--check'
                            '$mergeBase...HEAD'
                        )
                        if (
                            ($shape -join "`n") -cne ($mergeBase -join "`n") -and
                            ($shape -join "`n") -cne ($diffCheck -join "`n")
                        ) {
                            throw 'Repository Git invocation is not an approved read-only whitespace operation.'
                        }
                    }

                    if ($commandName -ieq 'az') {
                        if (
                            $owner -cne (
                                'infrastructure::' +
                                'Build every maintained Bicep entry point'
                            )
                        ) {
                            throw "Azure CLI is not owned by ${owner}."
                        }
                        [string[]]$elements = @(
                            $command.CommandElements |
                                ForEach-Object { $_.Extent.Text }
                        )
                        [string[]]$expected = @(
                            'az'
                            'bicep'
                            'build'
                            '--file'
                            '$entryPoint.FullName'
                            '--stdout'
                        )
                        if (($elements -join "`n") -cne ($expected -join "`n")) {
                            throw 'Infrastructure Azure CLI invocation is not the reviewed local Bicep build.'
                        }
                    }
                }

                $members = @($ast.FindAll({
                    param($node)
                    $node -is (
                        [Management.Automation.Language.InvokeMemberExpressionAst]
                    )
                }, $true))
                $allowedMembers = [Collections.Generic.HashSet[string]]::new(
                    [StringComparer]::OrdinalIgnoreCase
                )
                if ($memberOwners.ContainsKey($owner)) {
                    foreach ($memberOwner in $memberOwners[$owner]) {
                        [void]$allowedMembers.Add([string]$memberOwner)
                    }
                }
                foreach ($member in $members) {
                    $memberKey = '{0}:{1}::{2}' -f (
                        $member.Static,
                        $member.Expression.Extent.Text,
                        $member.Member.Extent.Text
                    )
                    if (-not $allowedMembers.Contains($memberKey)) {
                        throw "Workflow member invocation is not owned by ${owner}: $memberKey"
                    }
                }
            }
        }

        ($Workflow.Lines -join "`n") | Should -Not -Match (
            '(?m)^\s*(?:environment|secrets):'
        )
    }

    function script:New-PermissionMutatedWorkflow {
        param(
            [Parameter(Mandatory)][ValidateSet('TopLevel', 'Job')][string]$Scope,
            [Parameter(Mandatory)][string]$Permission,
            [Parameter(Mandatory)][string]$JobId
        )

        $lines = [Collections.Generic.List[string]]::new()
        foreach ($line in $script:workflowLines) {
            [void]$lines.Add($line)
        }

        if ($Scope -ceq 'TopLevel') {
            $contentsIndex = $lines.IndexOf('  contents: read')
            if ($contentsIndex -lt 0) {
                throw 'Permission mutation could not find global contents read.'
            }
            if ($Permission -ceq 'contents') {
                $lines[$contentsIndex] = '  contents: write'
            }
            else {
                $lines.Insert($contentsIndex + 1, "  ${Permission}: write")
            }
        }
        else {
            $jobIndex = $lines.IndexOf("  ${JobId}:")
            if ($jobIndex -lt 0) {
                throw "Permission mutation could not find job '$JobId'."
            }
            $lines.Insert($jobIndex + 1, '    permissions:')
            $lines.Insert($jobIndex + 2, "      ${Permission}: write")
        }

        ConvertFrom-WorkflowLines -Lines ([string[]]$lines)
    }

    function script:New-RunCommandMutatedWorkflow {
        param(
            [Parameter(Mandatory)][string]$JobId,
            [Parameter(Mandatory)][string]$StepName,
            [Parameter(Mandatory)][AllowEmptyString()][string]$Command,
            [ValidateSet(
                'Literal',
                'Folded',
                'Inline',
                'Raw',
                'ExplicitPlain',
                'ExplicitSingleQuoted',
                'ExplicitDoubleQuoted',
                'ExplicitMultilineDoubleQuoted'
            )]
            [string]$Style = 'Literal',
            [string]$RunKey = 'run'
        )

        $lines = [Collections.Generic.List[string]]::new()
        foreach ($line in $script:workflowLines) {
            [void]$lines.Add($line)
        }

        $jobStart = $lines.IndexOf("  ${JobId}:")
        if ($jobStart -lt 0) {
            throw "Command mutation could not find job '$JobId'."
        }
        $jobEnd = $lines.Count - 1
        for ($index = $jobStart + 1; $index -lt $lines.Count; $index++) {
            if ($lines[$index] -cmatch '^  [a-z][a-z0-9_-]*:\s*$') {
                $jobEnd = $index - 1
                break
            }
        }

        $stepStart = -1
        $stepHeader = "      - name: $StepName"
        for ($index = $jobStart + 1; $index -le $jobEnd; $index++) {
            if ($lines[$index] -ceq $stepHeader) {
                $stepStart = $index
                break
            }
        }
        if ($stepStart -lt 0) {
            throw "Command mutation could not find step '$StepName' in '$JobId'."
        }

        $stepEnd = $jobEnd
        for ($index = $stepStart + 1; $index -le $jobEnd; $index++) {
            if ($lines[$index] -cmatch '^      - ') {
                $stepEnd = $index - 1
                break
            }
        }
        $runIndex = -1
        for ($index = $stepStart + 1; $index -le $stepEnd; $index++) {
            if ($lines[$index] -cmatch '^        run:\s*\|\s*$') {
                $runIndex = $index
                break
            }
        }
        if ($runIndex -lt 0) {
            throw "Command mutation could not find a run block in '$JobId/$StepName'."
        }

        $contentEnd = $runIndex
        for ($index = $runIndex + 1; $index -le $stepEnd; $index++) {
            if (Test-IsSupportedRunBlockContentLine -Line $lines[$index]) {
                $contentEnd = $index
                continue
            }
            break
        }
        for ($index = $contentEnd; $index -gt $runIndex; $index--) {
            $lines.RemoveAt($index)
        }

        switch ($Style) {
            'Literal' {
                $lines[$runIndex] = "        ${RunKey}: |"
                [string[]]$commandLines = @($Command -split '\r?\n')
                for ($index = 0; $index -lt $commandLines.Count; $index++) {
                    $lines.Insert(
                        $runIndex + 1 + $index,
                        "          $($commandLines[$index])"
                    )
                }
            }
            'Folded' {
                $lines[$runIndex] = "        ${RunKey}: >"
                [string[]]$commandLines = @($Command -split '\r?\n')
                for ($index = 0; $index -lt $commandLines.Count; $index++) {
                    $lines.Insert(
                        $runIndex + 1 + $index,
                        "          $($commandLines[$index])"
                    )
                }
            }
            'Inline' {
                $lines[$runIndex] = "        ${RunKey}: $Command"
            }
            'Raw' {
                $lines[$runIndex] = "        ${RunKey}:$Command"
            }
            'ExplicitPlain' {
                $lines[$runIndex] = "        ? $RunKey"
                $lines.Insert($runIndex + 1, '        : |')
                [string[]]$commandLines = @($Command -split '\r?\n')
                for ($index = 0; $index -lt $commandLines.Count; $index++) {
                    $lines.Insert(
                        $runIndex + 2 + $index,
                        "          $($commandLines[$index])"
                    )
                }
            }
            'ExplicitSingleQuoted' {
                $lines[$runIndex] = "        ? '$RunKey'"
                $lines.Insert($runIndex + 1, '        : |')
                [string[]]$commandLines = @($Command -split '\r?\n')
                for ($index = 0; $index -lt $commandLines.Count; $index++) {
                    $lines.Insert(
                        $runIndex + 2 + $index,
                        "          $($commandLines[$index])"
                    )
                }
            }
            'ExplicitDoubleQuoted' {
                $lines[$runIndex] = "        ? `"$RunKey`""
                $lines.Insert($runIndex + 1, '        : |')
                [string[]]$commandLines = @($Command -split '\r?\n')
                for ($index = 0; $index -lt $commandLines.Count; $index++) {
                    $lines.Insert(
                        $runIndex + 2 + $index,
                        "          $($commandLines[$index])"
                    )
                }
            }
            'ExplicitMultilineDoubleQuoted' {
                if ($RunKey -cne 'run') {
                    throw 'Multiline explicit mutation supports only the run key.'
                }
                $lines[$runIndex] = '        ? "r\'
                $lines.Insert($runIndex + 1, '          un"')
                $lines.Insert($runIndex + 2, '        : |')
                [string[]]$commandLines = @($Command -split '\r?\n')
                for ($index = 0; $index -lt $commandLines.Count; $index++) {
                    $lines.Insert(
                        $runIndex + 3 + $index,
                        "          $($commandLines[$index])"
                    )
                }
            }
        }
        ConvertFrom-WorkflowLines -Lines ([string[]]$lines)
    }

    function script:New-TriggerMappingMutatedWorkflow {
        param(
            [Parameter(Mandatory)][AllowEmptyString()][string[]]$OnLines
        )

        $lines = [Collections.Generic.List[string]]::new()
        foreach ($line in $script:workflowLines) {
            [void]$lines.Add($line)
        }

        $onIndex = $lines.IndexOf('on:')
        $permissionsIndex = $lines.IndexOf('permissions:')
        if (
            $onIndex -lt 0 -or
            $permissionsIndex -le $onIndex
        ) {
            throw 'Trigger mutation could not find the workflow event block.'
        }
        for ($index = $permissionsIndex - 1; $index -gt $onIndex; $index--) {
            $lines.RemoveAt($index)
        }
        for ($index = 0; $index -lt $OnLines.Count; $index++) {
            $lines.Insert($onIndex + 1 + $index, $OnLines[$index])
        }
        $lines.Insert($onIndex + 1 + $OnLines.Count, '')

        ConvertFrom-WorkflowLines -Lines ([string[]]$lines)
    }

    function script:Get-DiscoveredLifecycleCaseId {
        param(
            [Parameter(Mandatory)][string[]]$Path,
            [ValidateSet('All', 'Include', 'Exclude')][string]$Mode
        )

        $configuration = New-PesterConfiguration
        $configuration.Run.Path = $Path
        $configuration.Run.SkipRun = $true
        $configuration.Run.PassThru = $true
        $configuration.Output.Verbosity = 'None'
        if ($Mode -ceq 'Include') {
            $configuration.Filter.Tag = @('CICompatibilitySmoke')
        }
        elseif ($Mode -ceq 'Exclude') {
            $configuration.Filter.ExcludeTag = @('CICompatibilitySmoke')
        }
        $result = Invoke-Pester -Configuration $configuration
        @(
            for ($index = 0; $index -lt $result.Tests.Count; $index++) {
                $test = $result.Tests[$index]
                if (-not $test.ShouldRun) {
                    continue
                }
                '{0:D6}:{1}:{2}::{3}' -f (
                    $index,
                    $test.ScriptBlock.File,
                    ($test.Path -join ' > '),
                    $test.ExpandedName
                )
            }
        )
    }

    function script:Get-ReplacedGateScript {
        param(
            [Parameter(Mandatory)][string]$Run,
            [Parameter(Mandatory)][hashtable]$Results
        )

        $scriptText = $Run
        foreach ($dependency in @('repository', 'infrastructure', 'hr', 'lifecycle')) {
            $token = '${{ needs.' + $dependency + '.result }}'
            $scriptText = $scriptText.Replace($token, [string]$Results[$dependency])
        }
        [scriptblock]::Create($scriptText)
    }

    $script:workflowContent = Get-Content -Raw -LiteralPath $script:workflowPath
    [string[]]$script:workflowLines = @(
        Get-Content -LiteralPath $script:workflowPath
    )
    $script:workflow = ConvertFrom-WorkflowLines -Lines $script:workflowLines
    [string[]]$script:domainIds = @(
        'repository'
        'infrastructure'
        'hr'
        'lifecycle'
    )
}

Describe 'Parallel repository validation workflow' {
    It 'keeps one Validate repository workflow with global contents read' {
        $workflowNames = @(
            Get-ChildItem -LiteralPath $script:workflowRoot -File |
                Where-Object Extension -In @('.yml', '.yaml') |
                Select-Object -ExpandProperty Name
        )
        $workflowNames | Should -Be @('validate-repository.yml')
        $script:workflow.Name | Should -BeExactly 'Validate repository'
        Assert-WorkflowPermissions -Workflow $script:workflow

        $eventNames = @(
            $script:workflow.OnLines |
                ForEach-Object {
                    if ($_ -cmatch '^  (?<event>[a-z_]+):') {
                        $Matches['event']
                    }
                }
        )
        $eventNames | Should -Be @('pull_request', 'push', 'workflow_dispatch')
        ($script:workflow.OnLines -join "`n") |
            Should -Match '(?m)^    branches:\s*\[main\]\s*$'

        $yamlParser = Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue
        if ($null -eq $yamlParser) {
            Write-Verbose 'ConvertFrom-Yaml is unavailable; the repository semantic parser remains authoritative.'
        }
        else {
            $parsed = $script:workflowContent | ConvertFrom-Yaml
            $parsed.jobs | Should -Not -BeNullOrEmpty
            $parsedJobKeys = if ($parsed.jobs -is [Collections.IDictionary]) {
                @($parsed.jobs.Keys)
            }
            else {
                @($parsed.jobs.PSObject.Properties.Name)
            }
            $parsedJobKeys | Should -Be @(
                'repository'
                'infrastructure'
                'hr'
                'lifecycle'
                'validate'
            )
        }
    }

    It 'rejects <Permission> write at <Scope> permissions' -TestCases @(
        @{ Permission = 'contents'; Scope = 'TopLevel'; JobId = 'repository' }
        @{ Permission = 'packages'; Scope = 'TopLevel'; JobId = 'repository' }
        @{ Permission = 'deployments'; Scope = 'TopLevel'; JobId = 'repository' }
        @{ Permission = 'actions'; Scope = 'TopLevel'; JobId = 'repository' }
        @{ Permission = 'pull-requests'; Scope = 'TopLevel'; JobId = 'repository' }
        @{ Permission = 'id-token'; Scope = 'TopLevel'; JobId = 'repository' }
        @{ Permission = 'contents'; Scope = 'Job'; JobId = 'repository' }
        @{ Permission = 'packages'; Scope = 'Job'; JobId = 'infrastructure' }
        @{ Permission = 'deployments'; Scope = 'Job'; JobId = 'hr' }
        @{ Permission = 'actions'; Scope = 'Job'; JobId = 'lifecycle' }
        @{ Permission = 'pull-requests'; Scope = 'Job'; JobId = 'validate' }
        @{ Permission = 'id-token'; Scope = 'Job'; JobId = 'repository' }
    ) {
        param(
            [string]$Permission,
            [string]$Scope,
            [string]$JobId
        )

        $mutated = New-PermissionMutatedWorkflow `
            -Scope $Scope `
            -Permission $Permission `
            -JobId $JobId
        {
            Assert-WorkflowPermissions -Workflow $mutated
        } | Should -Throw
    }

    It 'defines exactly repository infrastructure hr lifecycle and validate jobs' {
        @($script:workflow.Jobs.Keys) | Should -Be @(
            'repository'
            'infrastructure'
            'hr'
            'lifecycle'
            'validate'
        )
    }

    It 'uses exact display names windows-2025 runners and 30 30 30 45 15 timeouts' {
        $expected = [ordered]@{
            repository = @('Repository/documentation validation', '30')
            infrastructure = @('Infrastructure validation', '30')
            hr = @('HR solution validation', '30')
            lifecycle = @('Lifecycle/runbook validation', '45')
            validate = @('Repository setup validation', '15')
        }
        foreach ($jobId in $expected.Keys) {
            $job = $script:workflow.Jobs[$jobId]
            $job.Name | Should -BeExactly $expected[$jobId][0]
            $job.RunsOn | Should -BeExactly 'windows-2025'
            $job.TimeoutMinutes | Should -BeExactly $expected[$jobId][1]
        }
    }

    It 'declares powershell on every run step' {
        $runSteps = @(
            foreach ($job in $script:workflow.Jobs.Values) {
                $job.Steps | Where-Object { $null -ne $_.Run }
            }
        )
        $runSteps.Count | Should -BeGreaterThan 0
        foreach ($step in $runSteps) {
            $step.Shell | Should -BeExactly 'powershell'
        }
    }

    It 'uses pinned checkout and fetch-depth zero on every domain only' {
        foreach ($domainId in $script:domainIds) {
            $job = $script:workflow.Jobs[$domainId]
            $checkoutSteps = @(
                $job.Steps |
                    Where-Object Uses -CEQ "actions/checkout@$($script:checkoutSha)"
            )
            $checkoutSteps.Count | Should -Be 1
            $checkoutSteps[0].With['fetch-depth'] | Should -BeExactly '0'
            $checkoutSteps[0].Run | Should -BeNullOrEmpty
            $checkoutSteps[0].Shell | Should -BeNullOrEmpty
        }

        @($script:workflow.Jobs.validate.Steps | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_.Uses)
        }) | Should -BeNullOrEmpty
    }

    It 'uses the selector installer and runner for every owning domain' {
        $expected = [ordered]@{
            repository = @('Repository', 'test-results/repository/pester.xml', 1)
            infrastructure = @('Infrastructure', 'test-results/infrastructure/pester.xml', 1)
            hr = @('Hr', 'test-results/hr/pester.xml', 1)
            lifecycle = @('Lifecycle', 'test-results/lifecycle/smoke.xml', 2)
        }
        foreach ($domainId in $expected.Keys) {
            $testStep = @(
                $script:workflow.Jobs[$domainId].Steps |
                    Where-Object Name -Like 'Run * tests'
            )
            $testStep.Count | Should -Be 1
            $run = $testStep[0].Run
            $run | Should -Match (
                [regex]::Escape(
                    ".github/cli/Install-CiTestDependencies.ps1 -Group $($expected[$domainId][0]) -MaxAttempts 3"
                )
            )
            $run | Should -Match (
                [regex]::Escape(
                    ".github/cli/Get-MaintainedTestGroups.ps1 -Group $($expected[$domainId][0])"
                )
            )
            @(
                [regex]::Matches(
                    $run,
                    [regex]::Escape('.github/cli/Invoke-MaintainedTestGroup.ps1')
                )
            ).Count | Should -Be $expected[$domainId][2]
            $run | Should -Match ([regex]::Escape($expected[$domainId][1]))
            $run | Should -Not -Match '\bInvoke-Pester\b|Get-ChildItem.+Tests\.ps1'
        }
    }

    It 'keeps Repository safety and merge-base whitespace in repository' {
        $repositoryJob = $script:workflow.Jobs.repository
        $safety = Get-NamedStep -Job $repositoryJob -Name 'Run repository safety validation'
        $safety.Run | Should -Match (
            [regex]::Escape('.github/cli/verify-repository-safety.ps1')
        )
        $safety.Run | Should -Match '\$LASTEXITCODE\s+-ne\s+0'

        $whitespace = Get-NamedStep -Job $repositoryJob -Name 'Check branch whitespace'
        $whitespace.Run | Should -Match '\bgit merge-base\b'
        $whitespace.Run | Should -Match '\bgit diff --check\b'
        $whitespace.Run | Should -Not -Match 'HEAD~\d+'

        $otherRuns = @(
            foreach ($jobId in @('infrastructure', 'hr', 'lifecycle', 'validate')) {
                $script:workflow.Jobs[$jobId].Steps.Run
            }
        ) -join "`n"
        $otherRuns | Should -Not -Match 'verify-repository-safety|git diff --check'
    }

    It 'keeps recursive local Bicep compilation in infrastructure' {
        $build = Get-NamedStep `
            -Job $script:workflow.Jobs.infrastructure `
            -Name 'Build every maintained Bicep entry point'
        $build.Run | Should -Match (
            [regex]::Escape(
                "Get-ChildItem -LiteralPath 'infra/src/bicep' -Filter '*.bicep' -File -Recurse"
            )
        )
        $build.Run | Should -Match 'entryPoints\.Count\s+-eq\s+0'
        $build.Run | Should -Match '\baz bicep build --file\b'

        $otherRuns = @(
            foreach ($jobId in @('repository', 'hr', 'lifecycle', 'validate')) {
                $script:workflow.Jobs[$jobId].Steps.Run
            }
        ) -join "`n"
        $otherRuns | Should -Not -Match '\baz bicep build\b'
    }

    It 'keeps Hr and Lifecycle Python requirements independent' {
        $hrRun = (Get-NamedStep `
            -Job $script:workflow.Jobs.hr `
            -Name 'Run HR tests').Run
        $lifecycleRun = (Get-NamedStep `
            -Job $script:workflow.Jobs.lifecycle `
            -Name 'Run lifecycle tests').Run

        $hrRun | Should -Match (
            [regex]::Escape(
                '.github/cli/Install-CiTestDependencies.ps1 -Group Hr -MaxAttempts 3'
            )
        )
        $lifecycleRun | Should -Match (
            [regex]::Escape(
                '.github/cli/Install-CiTestDependencies.ps1 -Group Lifecycle -MaxAttempts 3'
            )
        )
        $hrRun | Should -Not -Match 'infra/tests/requirements\.txt|\bpip\b'
        $lifecycleRun | Should -Not -Match 'hr/tests/requirements\.txt|\bpip\b'
    }

    It 'partitions lifecycle smoke and remainder without duplicate cases' {
        $run = (Get-NamedStep `
            -Job $script:workflow.Jobs.lifecycle `
            -Name 'Run lifecycle tests').Run
        $run | Should -Match (
            '(?s)test-results/lifecycle/smoke\.xml.*-Tag CICompatibilitySmoke'
        )
        $run | Should -Match (
            '(?s)test-results/lifecycle/remainder\.xml.*-ExcludeTag CICompatibilitySmoke'
        )
        $run | Should -Not -Match 'FullNameFilter|\bInvoke-Pester\b'

        [string[]]$paths = @(& $script:selectorPath -Group Lifecycle)
        [string[]]$all = @(Get-DiscoveredLifecycleCaseId -Path $paths -Mode All)
        [string[]]$smoke = @(Get-DiscoveredLifecycleCaseId -Path $paths -Mode Include)
        [string[]]$remainder = @(Get-DiscoveredLifecycleCaseId -Path $paths -Mode Exclude)
        $all.Count | Should -BeGreaterThan 0
        $smoke.Count | Should -BeGreaterThan 0
        $remainder.Count | Should -BeGreaterThan 0

        $remainderSet = [Collections.Generic.HashSet[string]]::new(
            $remainder,
            [StringComparer]::Ordinal
        )
        @($smoke | Where-Object { $remainderSet.Contains($_) }) |
            Should -BeNullOrEmpty

        $union = [Collections.Generic.HashSet[string]]::new(
            [StringComparer]::Ordinal
        )
        foreach ($caseId in @($smoke + $remainder)) {
            [void]$union.Add($caseId)
        }
        [string[]]$unionRows = @($union)
        [string[]]$allRows = @($all)
        [Array]::Sort($unionRows, [StringComparer]::Ordinal)
        [Array]::Sort($allRows, [StringComparer]::Ordinal)
        $unionRows | Should -Be $allRows
    }

    It 'uploads four unique always-run raw NUnit artifacts for fourteen days' {
        $expected = [ordered]@{
            repository = @('repository-validation-test-results', 'test-results/repository')
            infrastructure = @('infrastructure-validation-test-results', 'test-results/infrastructure')
            hr = @('hr-validation-test-results', 'test-results/hr')
            lifecycle = @('lifecycle-validation-test-results', 'test-results/lifecycle')
        }
        $artifactNames = [Collections.Generic.HashSet[string]]::new(
            [StringComparer]::Ordinal
        )
        foreach ($domainId in $expected.Keys) {
            $uploads = @(
                $script:workflow.Jobs[$domainId].Steps |
                    Where-Object Uses -Like 'actions/upload-artifact@*'
            )
            $uploads.Count | Should -Be 1
            $upload = $uploads[0]
            $upload.If | Should -BeExactly 'always()'
            $upload.With['name'] | Should -BeExactly $expected[$domainId][0]
            $upload.With['path'] | Should -BeExactly $expected[$domainId][1]
            $upload.With['if-no-files-found'] | Should -BeExactly 'warn'
            $upload.With['retention-days'] | Should -BeExactly '14'
            $artifactNames.Add([string]$upload.With['name']) | Should -BeTrue
        }
        $artifactNames.Count | Should -Be 4
    }

    It 'uses the exact reviewed upload-artifact SHA' {
        $uploads = @(
            foreach ($domainId in $script:domainIds) {
                $script:workflow.Jobs[$domainId].Steps |
                    Where-Object Uses -Like 'actions/upload-artifact@*'
            }
        )
        $uploads.Count | Should -Be 4
        foreach ($upload in $uploads) {
            $upload.Uses |
                Should -BeExactly "actions/upload-artifact@$($script:uploadSha)"
        }
    }

    It 'keeps validate a pure result gate over all four dependencies' {
        $validate = $script:workflow.Jobs.validate
        $validate.Needs | Should -Be $script:domainIds
        $validate.If | Should -BeExactly 'always()'
        $validate.Steps.Count | Should -Be 1
        $gate = Get-NamedStep `
            -Job $validate `
            -Name 'Require every validation domain'
        $gate.Uses | Should -BeNullOrEmpty
        $gate.With.Count | Should -Be 0
        foreach ($domainId in $script:domainIds) {
            $gate.Run | Should -Match (
                [regex]::Escape('${{ needs.' + $domainId + '.result }}')
            )
        }
        $gate.Run | Should -Match "Value -cne 'success'"
        $gate.Run | Should -Match '\bthrow\b'
        $gate.Run | Should -Not -Match (
            'checkout|Install-CiTestDependencies|Get-MaintainedTestGroups|' +
            'Invoke-MaintainedTestGroup|upload-artifact|verify-repository-safety|' +
            'bicep|git diff'
        )
    }

    It 'fails validate for failure cancelled or skipped dependencies' {
        $gate = Get-NamedStep `
            -Job $script:workflow.Jobs.validate `
            -Name 'Require every validation domain'
        $success = @{
            repository = 'success'
            infrastructure = 'success'
            hr = 'success'
            lifecycle = 'success'
        }
        {
            & (Get-ReplacedGateScript -Run $gate.Run -Results $success)
        } | Should -Not -Throw

        foreach ($status in @('failure', 'cancelled', 'skipped')) {
            $results = $success.Clone()
            $results['repository'] = $status
            {
                & (Get-ReplacedGateScript -Run $gate.Run -Results $results)
            } | Should -Throw
        }
    }

    It 'uses exact PR-number-or-ref concurrency with cancellation' {
        @($script:workflow.Concurrency.Keys) | Should -Be @(
            'group'
            'cancel-in-progress'
        )
        $script:workflow.Concurrency['group'] | Should -BeExactly (
            '${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}'
        )
        $script:workflow.Concurrency['cancel-in-progress'] |
            Should -BeExactly 'true'
    }

    It 'excludes path filters caches publishers provider operations and deployment authority' {
        ($script:workflow.OnLines -join "`n") |
            Should -Not -Match '(?m)^\s+paths(?:-ignore)?:'

        Assert-WorkflowCommandOwnership -Workflow $script:workflow
    }

    It 'rejects unowned provider command <Command> in <JobId>' -TestCases @(
        @{
            JobId = 'repository'
            StepName = 'Run repository tests'
            Command = 'az vm create'
        }
        @{
            JobId = 'infrastructure'
            StepName = 'Build every maintained Bicep entry point'
            Command = 'az storage account list'
        }
        @{
            JobId = 'hr'
            StepName = 'Run HR tests'
            Command = 'Set-AzContext -Subscription synthetic'
        }
        @{
            JobId = 'lifecycle'
            StepName = 'Run lifecycle tests'
            Command = 'Invoke-AzRestMethod -Path /subscriptions'
        }
        @{
            JobId = 'repository'
            StepName = 'Run repository safety validation'
            Command = 'azd up'
        }
        @{
            JobId = 'validate'
            StepName = 'Require every validation domain'
            Command = 'pac solution import'
        }
    ) {
        param(
            [string]$JobId,
            [string]$StepName,
            [string]$Command
        )

        $mutated = New-RunCommandMutatedWorkflow `
            -JobId $JobId `
            -StepName $StepName `
            -Command $Command
        {
            Assert-WorkflowCommandOwnership -Workflow $mutated
        } | Should -Throw
    }

    It 'routes <Style> run scalar through command ownership' -TestCases @(
        @{ Style = 'Literal'; Command = 'az login'; Expected = 'az login' }
        @{ Style = 'Folded'; Command = "az`nlogin"; Expected = 'az login' }
        @{ Style = 'Inline'; Command = 'az login'; Expected = 'az login' }
    ) {
        param(
            [string]$Style,
            [string]$Command,
            [string]$Expected
        )

        $mutated = New-RunCommandMutatedWorkflow `
            -JobId 'repository' `
            -StepName 'Run repository tests' `
            -Command $Command `
            -Style $Style
        (Get-NamedStep `
            -Job $mutated.Jobs.repository `
            -Name 'Run repository tests').Run |
                Should -BeExactly $Expected
        {
            Assert-WorkflowCommandOwnership -Workflow $mutated
        } | Should -Throw
    }

    It 'rejects unsupported run scalar <Scalar>' -TestCases @(
        @{ Scalar = ' |+' }
        @{ Scalar = ' >-' }
        @{ Scalar = ' >2' }
        @{ Scalar = '' }
        @{ Scalar = ' [az, login]' }
        @{ Scalar = ' {command: az login}' }
        @{ Scalar = ' &anchor az login' }
    ) {
        param([AllowEmptyString()][string]$Scalar)

        {
            New-RunCommandMutatedWorkflow `
                -JobId 'repository' `
                -StepName 'Run repository tests' `
                -Command $Scalar `
                -Style Raw
        } | Should -Throw
    }

    It 'routes quoted inline run scalar <Scalar> through command ownership' -TestCases @(
        @{ Scalar = ' "az login"' }
        @{ Scalar = " 'az login'" }
    ) {
        param([string]$Scalar)

        $mutated = New-RunCommandMutatedWorkflow `
            -JobId 'repository' `
            -StepName 'Run repository tests' `
            -Command $Scalar `
            -Style Raw
        (Get-NamedStep `
            -Job $mutated.Jobs.repository `
            -Name 'Run repository tests').Run |
                Should -BeExactly 'az login'
        {
            Assert-WorkflowCommandOwnership -Workflow $mutated
        } | Should -Throw
    }

    It 'routes quoted key <RunKey> <Style> scalar through command ownership' -TestCases @(
        @{
            RunKey = "'run'"
            Style = 'Literal'
            Command = 'az login'
            Expected = 'az login'
        }
        @{
            RunKey = '"run"'
            Style = 'Folded'
            Command = "az`nlogin"
            Expected = 'az login'
        }
        @{
            RunKey = '"run"'
            Style = 'Inline'
            Command = 'az login'
            Expected = 'az login'
        }
    ) {
        param(
            [string]$RunKey,
            [string]$Style,
            [string]$Command,
            [string]$Expected
        )

        $mutated = New-RunCommandMutatedWorkflow `
            -JobId 'repository' `
            -StepName 'Run repository tests' `
            -Command $Command `
            -Style $Style `
            -RunKey $RunKey
        (Get-NamedStep `
            -Job $mutated.Jobs.repository `
            -Name 'Run repository tests').Run |
                Should -BeExactly $Expected
        {
            Assert-WorkflowCommandOwnership -Workflow $mutated
        } | Should -Throw
    }

    It 'rejects alternate or malformed run key <RunKey>' -TestCases @(
        @{ RunKey = 'Run' }
        @{ RunKey = "'Run'" }
        @{ RunKey = '"RUN"' }
        @{ RunKey = 'runs' }
        @{ RunKey = "'runs'" }
        @{ RunKey = "'run" }
    ) {
        param([string]$RunKey)

        {
            New-RunCommandMutatedWorkflow `
                -JobId 'repository' `
                -StepName 'Run repository tests' `
                -Command 'az login' `
                -Style Inline `
                -RunKey $RunKey
        } | Should -Throw
    }

    It 'rejects unsupported mapping key syntax <Case>' -TestCases @(
        @{
            Case = 'plain explicit run'
            Style = 'ExplicitPlain'
            RunKey = 'run'
            Command = 'az login'
        }
        @{
            Case = 'single-quoted explicit run'
            Style = 'ExplicitSingleQuoted'
            RunKey = 'run'
            Command = 'az login'
        }
        @{
            Case = 'double-quoted explicit run'
            Style = 'ExplicitDoubleQuoted'
            RunKey = 'run'
            Command = 'az login'
        }
        @{
            Case = 'multiline double-quoted explicit run'
            Style = 'ExplicitMultilineDoubleQuoted'
            RunKey = 'run'
            Command = 'az login'
        }
        @{
            Case = 'explicit alternate key'
            Style = 'ExplicitPlain'
            RunKey = 'script'
            Command = (
                '& .github/cli/Get-MaintainedTestGroups.ps1 ' +
                "-Group Repository`naz login"
            )
        }
    ) {
        param(
            [string]$Case,
            [string]$Style,
            [string]$RunKey,
            [string]$Command
        )

        {
            New-RunCommandMutatedWorkflow `
                -JobId 'repository' `
                -StepName 'Run repository tests' `
                -Command $Command `
                -Style $Style `
                -RunKey $RunKey
        } | Should -Throw -ExpectedMessage (
            '*explicit or multiline mapping key*'
        )
    }

    It 'accepts current workflow mapping key syntax' {
        {
            ConvertFrom-WorkflowLines -Lines $script:workflowLines
        } | Should -Not -Throw
    }

    It 'rejects nested explicit trigger key <Case>' -TestCases @(
        @{
            Case = 'pull_request paths'
            OnLines = @(
                '  pull_request:'
                '    ? paths'
                '    : [docs/**]'
                '  push:'
                '    branches: [main]'
                '  workflow_dispatch:'
            )
        }
        @{
            Case = 'push paths-ignore'
            OnLines = @(
                '  pull_request:'
                '  push:'
                '    branches: [main]'
                '    ? paths-ignore'
                '    : [docs/**]'
                '  workflow_dispatch:'
            )
        }
        @{
            Case = 'workflow_dispatch alternate'
            OnLines = @(
                '  pull_request:'
                '  push:'
                '    branches: [main]'
                '  workflow_dispatch:'
                '    ? alternate'
                '    : true'
            )
        }
        @{
            Case = 'quoted paths'
            OnLines = @(
                '  pull_request:'
                '    ? "paths"'
                '    : [docs/**]'
                '  push:'
                '    branches: [main]'
                '  workflow_dispatch:'
            )
        }
        @{
            Case = 'flow explicit paths'
            OnLines = @(
                '  pull_request: { ? paths : [docs/**] }'
                '  push:'
                '    branches: [main]'
                '  workflow_dispatch:'
            )
        }
        @{
            Case = 'flow explicit paths after plain apostrophe'
            OnLines = @(
                "  pull_request: { note: repo's, ? paths : [docs/**] }"
                '  push:'
                '    branches: [main]'
                '  workflow_dispatch:'
            )
        }
        @{
            Case = 'deep workflow_dispatch input'
            OnLines = @(
                '  pull_request:'
                '  push:'
                '    branches: [main]'
                '  workflow_dispatch:'
                '    inputs:'
                '      environment:'
                '        description: Target'
                '        ? required'
                '        : true'
            )
        }
    ) {
        param(
            [string]$Case,
            [string[]]$OnLines
        )

        {
            New-TriggerMappingMutatedWorkflow -OnLines $OnLines
        } | Should -Throw -ExpectedMessage (
            '*explicit or multiline mapping key*'
        )
    }

    It 'rejects decoded path-filter mapping key <Case>' -TestCases @(
        @{
            Case = 'plain paths'
            OnLines = @(
                '  pull_request:'
                '    paths: [docs/**]'
                '  push:'
                '    branches: [main]'
                '  workflow_dispatch:'
            )
        }
        @{
            Case = 'single-quoted paths'
            OnLines = @(
                '  pull_request:'
                "    'paths': [docs/**]"
                '  push:'
                '    branches: [main]'
                '  workflow_dispatch:'
            )
        }
        @{
            Case = 'double-quoted paths'
            OnLines = @(
                '  pull_request:'
                '    "paths": [docs/**]'
                '  push:'
                '    branches: [main]'
                '  workflow_dispatch:'
            )
        }
        @{
            Case = 'escaped double-quoted paths'
            OnLines = @(
                '  pull_request:'
                '    "pa\u0074hs": [docs/**]'
                '  push:'
                '    branches: [main]'
                '  workflow_dispatch:'
            )
        }
        @{
            Case = 'single-quoted paths-ignore'
            OnLines = @(
                '  pull_request:'
                "    'paths-ignore': [docs/**]"
                '  push:'
                '    branches: [main]'
                '  workflow_dispatch:'
            )
        }
        @{
            Case = 'double-quoted paths-ignore'
            OnLines = @(
                '  pull_request:'
                '    "paths-ignore": [docs/**]'
                '  push:'
                '    branches: [main]'
                '  workflow_dispatch:'
            )
        }
        @{
            Case = 'single-quoted mixed-case paths'
            OnLines = @(
                '  pull_request:'
                "    'PaThS': [docs/**]"
                '  push:'
                '    branches: [main]'
                '  workflow_dispatch:'
            )
        }
        @{
            Case = 'double-quoted mixed-case paths-ignore'
            OnLines = @(
                '  pull_request:'
                '    "PaThS-IgNoRe": [docs/**]'
                '  push:'
                '    branches: [main]'
                '  workflow_dispatch:'
            )
        }
        @{
            Case = 'nested single-quoted paths'
            OnLines = @(
                '  pull_request:'
                '    synthetic:'
                '      deeper:'
                "        'paths': [docs/**]"
                '  push:'
                '    branches: [main]'
                '  workflow_dispatch:'
            )
        }
        @{
            Case = 'nested double-quoted paths-ignore'
            OnLines = @(
                '  pull_request:'
                '    synthetic:'
                '      deeper:'
                '        "paths-ignore": [docs/**]'
                '  push:'
                '    branches: [main]'
                '  workflow_dispatch:'
            )
        }
        @{
            Case = 'flow single-quoted paths'
            OnLines = @(
                "  pull_request: { 'paths': [docs/**] }"
                '  push:'
                '    branches: [main]'
                '  workflow_dispatch:'
            )
        }
        @{
            Case = 'nested flow double-quoted paths-ignore'
            OnLines = @(
                '  pull_request: { synthetic: { "paths-ignore": [docs/**] } }'
                '  push:'
                '    branches: [main]'
                '  workflow_dispatch:'
            )
        }
    ) {
        param(
            [string]$Case,
            [string[]]$OnLines
        )

        {
            New-TriggerMappingMutatedWorkflow -OnLines $OnLines
        } | Should -Throw -ExpectedMessage '*path-filter mapping key*'
    }

    It 'does not treat key-shaped <Style> run content as YAML structure' -TestCases @(
        @{
            Style = 'Literal'
            Marker = "'paths': [docs/**]"
        }
        @{
            Style = 'Literal'
            Marker = '"paths-ignore": [docs/**]'
        }
        @{
            Style = 'Folded'
            Marker = "'paths': [docs/**]"
        }
        @{
            Style = 'Folded'
            Marker = '"paths-ignore": [docs/**]'
        }
    ) {
        param(
            [string]$Style,
            [string]$Marker
        )

        $mutated = New-RunCommandMutatedWorkflow `
            -JobId 'repository' `
            -StepName 'Run repository tests' `
            -Command (
                "$Marker`n" +
                '& .github/cli/Get-MaintainedTestGroups.ps1 -Group Repository'
            ) `
            -Style $Style
        (Get-NamedStep `
            -Job $mutated.Jobs.repository `
            -Name 'Run repository tests').Run |
                Should -Match ([regex]::Escape($Marker))
    }

    It 'routes literal run line beginning with <Marker> through script parsing' -TestCases @(
        @{
            Marker = '?'
            Command = (
                "? { `$true }`n" +
                '& .github/cli/Get-MaintainedTestGroups.ps1 -Group Repository'
            )
        }
        @{
            Marker = ':'
            Command = (
                ": synthetic`n" +
                '& .github/cli/Get-MaintainedTestGroups.ps1 -Group Repository'
            )
        }
    ) {
        param(
            [string]$Marker,
            [string]$Command
        )

        $mutated = New-RunCommandMutatedWorkflow `
            -JobId 'repository' `
            -StepName 'Run repository tests' `
            -Command $Command
        (Get-NamedStep `
            -Job $mutated.Jobs.repository `
            -Name 'Run repository tests').Run |
                Should -BeExactly $Command
        {
            Assert-WorkflowCommandOwnership -Workflow $mutated
        } | Should -Throw -ExpectedMessage '*Workflow command is not owned*'
    }

    It 'rejects unsupported folded run form <Reason>' -TestCases @(
        @{
            Reason = 'blank paragraph'
            Command = "az`n`nlogin"
        }
        @{
            Reason = 'more-indented content'
            Command = "az`n  login"
        }
        @{
            Reason = 'backtick paragraph ambiguity'
            Command = (
                'git merge-base $baseRef HEAD `' + "`n`n" +
                'git diff --check "$mergeBase...HEAD"'
            )
        }
    ) {
        param(
            [string]$Reason,
            [string]$Command
        )

        {
            New-RunCommandMutatedWorkflow `
                -JobId 'repository' `
                -StepName 'Check branch whitespace' `
                -Command $Command `
                -Style Folded
        } | Should -Throw
    }

    It 'rejects using statement in <Style> run scalar' -TestCases @(
        @{
            Style = 'Literal'
            Command = (
                "using module .\evil.psm1`n" +
                '& .github/cli/Get-MaintainedTestGroups.ps1 -Group Repository'
            )
        }
        @{
            Style = 'Folded'
            Command = (
                "using module .\evil.psm1;`n" +
                '& .github/cli/Get-MaintainedTestGroups.ps1 -Group Repository'
            )
        }
        @{
            Style = 'Inline'
            Command = (
                'using module .\evil.psm1; ' +
                '& .github/cli/Get-MaintainedTestGroups.ps1 -Group Repository'
            )
        }
    ) {
        param(
            [string]$Style,
            [string]$Command
        )

        $mutated = New-RunCommandMutatedWorkflow `
            -JobId 'repository' `
            -StepName 'Run repository tests' `
            -Command $Command `
            -Style $Style
        {
            Assert-WorkflowCommandOwnership -Workflow $mutated
        } | Should -Throw
    }

    It 'rejects PowerShell script requirement <Requirement>' -TestCases @(
        @{ Requirement = '#requires -Modules .\evil.psm1' }
        @{ Requirement = '#requires -Assembly .\evil.dll' }
        @{ Requirement = '#requires -RunAsAdministrator' }
    ) {
        param([string]$Requirement)

        $mutated = New-RunCommandMutatedWorkflow `
            -JobId 'repository' `
            -StepName 'Run repository tests' `
            -Command (
                "$Requirement`n" +
                '& .github/cli/Get-MaintainedTestGroups.ps1 -Group Repository'
            )
        {
            Assert-WorkflowCommandOwnership -Workflow $mutated
        } | Should -Throw -ExpectedMessage '*script requirements*'
    }

    It 'rejects launch bypass <Command> in <JobId>' -TestCases @(
        @{
            JobId = 'repository'
            StepName = 'Run repository safety validation'
            Command = 'powershell.exe -Command "az login"'
        }
        @{
            JobId = 'repository'
            StepName = 'Run repository tests'
            Command = 'pwsh -Command "az login"'
        }
        @{
            JobId = 'repository'
            StepName = 'Check branch whitespace'
            Command = 'git push origin main'
        }
        @{
            JobId = 'repository'
            StepName = 'Run repository tests'
            Command = 'cmd /c "az login"'
        }
        @{
            JobId = 'repository'
            StepName = 'Run repository tests'
            Command = 'Start-Process az -ArgumentList login'
        }
        @{
            JobId = 'repository'
            StepName = 'Run repository tests'
            Command = 'Invoke-Expression "az login"'
        }
        @{
            JobId = 'repository'
            StepName = 'Run repository tests'
            Command = '[Diagnostics.Process]::Start("az", "login")'
        }
        @{
            JobId = 'repository'
            StepName = 'Run repository tests'
            Command = '& $command'
        }
    ) {
        param(
            [string]$JobId,
            [string]$StepName,
            [string]$Command
        )

        $mutated = New-RunCommandMutatedWorkflow `
            -JobId $JobId `
            -StepName $StepName `
            -Command $Command
        {
            Assert-WorkflowCommandOwnership -Workflow $mutated
        } | Should -Throw
    }

    It 'accepts approved helper read-only git and exact local Bicep commands' {
        {
            Assert-WorkflowCommandOwnership -Workflow $script:workflow
        } | Should -Not -Throw
    }

    It 'allows provider command names in prose and error messages' {
        $mutated = New-RunCommandMutatedWorkflow `
            -JobId 'repository' `
            -StepName 'Run repository safety validation' `
            -Command (
                "throw 'az vm create, Set-AzContext, Invoke-AzRestMethod, " +
                "azd up, and pac solution import are blocked.'"
            )

        {
            Assert-WorkflowCommandOwnership -Workflow $mutated
        } | Should -Not -Throw
    }
}
