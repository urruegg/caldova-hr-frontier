Set-StrictMode -Version Latest

$script:DocumentationMetadataFields = @(
	'Version',
	'Date',
	'Author',
	'Status',
	'Scope',
	'References'
)
$script:DocumentationStatusPrefixes = @(
	'Draft',
	'Proposed Baseline',
	'Active',
	'Approved',
	'Superseded',
	'Archived'
)

function ConvertTo-DocumentationLines {
	param(
		[AllowEmptyString()]
		[string]$Content
	)

	if ($null -eq $Content) {
		$Content = ''
	}
	if ($Content.Length -gt 0 -and $Content[0] -eq [char]0xFEFF) {
		$Content = $Content.Substring(1)
	}
	$normalizedContent = $Content.Replace("`r`n", "`n").Replace("`r", "`n")
	return ,([string[]]$normalizedContent.Split(
		[string[]]@("`n"),
		[StringSplitOptions]::None
	))
}

function Get-LeadingIndentation {
	param(
		[Parameter(Mandatory)]
		[AllowEmptyString()]
		[string]$Line
	)

	$characterCount = 0
	$columns = 0
	while ($characterCount -lt $Line.Length) {
		$character = $Line[$characterCount]
		if ($character -eq [char]' ') {
			$columns++
		}
		elseif ($character -eq [char]"`t") {
			$columns += 4 - ($columns % 4)
		}
		else {
			break
		}
		$characterCount++
	}

	return [pscustomobject]@{
		CharacterCount = $characterCount
		Columns = $columns
	}
}

function Get-FenceDelimiter {
	param(
		[Parameter(Mandatory)]
		[AllowEmptyString()]
		[string]$Line
	)

	$indentation = Get-LeadingIndentation -Line $Line
	if ($indentation.Columns -gt 3) {
		return $null
	}

	$content = $Line.Substring($indentation.CharacterCount)
	if ($content.Length -lt 3) {
		return $null
	}

	$marker = $content[0]
	if ($marker -ne [char]'`' -and $marker -ne [char]'~') {
		return $null
	}

	$length = 0
	while ($length -lt $content.Length -and
		$content[$length] -eq $marker) {
		$length++
	}
	if ($length -lt 3) {
		return $null
	}
	$remainder = $content.Substring($length)
	$isClosing = [string]::IsNullOrWhiteSpace($remainder)
	if (-not $isClosing -and
		$marker -eq [char]'`' -and
		$remainder.IndexOf([char]'`') -ge 0) {
		return $null
	}

	return [pscustomobject]@{
		Marker = $marker
		Length = $length
		IsClosing = $isClosing
	}
}

function Get-RenderedAtxHeading {
	param(
		[Parameter(Mandatory)]
		[AllowEmptyString()]
		[string]$Line
	)

	$indentation = Get-LeadingIndentation -Line $Line
	if ($indentation.Columns -gt 3 -or
		$indentation.CharacterCount -ge $Line.Length -or
		$Line[$indentation.CharacterCount] -ne [char]'#') {
		return $null
	}

	$markerEnd = $indentation.CharacterCount
	while ($markerEnd -lt $Line.Length -and
		$Line[$markerEnd] -eq [char]'#') {
		$markerEnd++
	}
	$level = $markerEnd - $indentation.CharacterCount
	if ($level -gt 6) {
		return $null
	}
	if ($markerEnd -lt $Line.Length -and
		$Line[$markerEnd] -ne [char]' ' -and
		$Line[$markerEnd] -ne [char]"`t") {
		return $null
	}

	$title = if ($markerEnd -lt $Line.Length) {
		$Line.Substring($markerEnd)
	}
	else {
		''
	}
	$title = [regex]::Replace(
		$title,
		'[ \t]+#+[ \t]*$',
		'',
		[Text.RegularExpressions.RegexOptions]::CultureInvariant
	).Trim([char[]]@(' ', "`t"))

	return [pscustomobject]@{
		Level = $level
		HasUsableTitle = -not [string]::IsNullOrWhiteSpace($title)
	}
}

function Test-IsRenderedSetextUnderline {
	param(
		[Parameter(Mandatory)]
		[AllowEmptyString()]
		[string]$Line,

		[Parameter(Mandatory)]
		[char]$Marker
	)

	$indentation = Get-LeadingIndentation -Line $Line
	if ($indentation.Columns -gt 3 -or
		$indentation.CharacterCount -ge $Line.Length -or
		$Line[$indentation.CharacterCount] -ne $Marker) {
		return $false
	}

	$characterIndex = $indentation.CharacterCount
	while ($characterIndex -lt $Line.Length -and
		$Line[$characterIndex] -eq $Marker) {
		$characterIndex++
	}
	while ($characterIndex -lt $Line.Length) {
		if ($Line[$characterIndex] -ne [char]' ' -and
			$Line[$characterIndex] -ne [char]"`t") {
			return $false
		}
		$characterIndex++
	}

	return $true
}

function Get-DocumentationStructure {
	param(
		[AllowEmptyString()]
		[string]$Content
	)

	$lines = ConvertTo-DocumentationLines -Content $Content
	$contentStart = 0
	$frontmatterUnclosed = $false
	if ($lines.Count -gt 0 -and
		$lines[0].Equals('---', [StringComparison]::Ordinal)) {
		$frontmatterEnd = -1
		for ($lineIndex = 1; $lineIndex -lt $lines.Count; $lineIndex++) {
			if ($lines[$lineIndex].Equals('---', [StringComparison]::Ordinal)) {
				$frontmatterEnd = $lineIndex
				break
			}
		}
		if ($frontmatterEnd -lt 0) {
			$frontmatterUnclosed = $true
			$contentStart = $lines.Count
		}
		else {
			$contentStart = $frontmatterEnd + 1
		}
	}

	$renderedLines = [bool[]]::new($lines.Count)
	$h1Blocks = [Collections.Generic.List[object]]::new()
	$insideFence = $false
	$fenceMarker = [char]0
	$fenceLength = 0
	$paragraphStart = -1
	for ($lineIndex = $contentStart; $lineIndex -lt $lines.Count; $lineIndex++) {
		$line = $lines[$lineIndex]
		$delimiter = Get-FenceDelimiter -Line $line
		if ($insideFence) {
			if ($null -ne $delimiter -and
				$delimiter.IsClosing -and
				$delimiter.Marker -eq $fenceMarker -and
				$delimiter.Length -ge $fenceLength) {
				$insideFence = $false
				$fenceMarker = [char]0
				$fenceLength = 0
			}
			$paragraphStart = -1
			continue
		}
		if ($null -ne $delimiter) {
			$insideFence = $true
			$fenceMarker = $delimiter.Marker
			$fenceLength = $delimiter.Length
			$paragraphStart = -1
			continue
		}

		$renderedLines[$lineIndex] = $true
		if ([string]::IsNullOrWhiteSpace($line)) {
			$paragraphStart = -1
			continue
		}

		$indentation = Get-LeadingIndentation -Line $line
		if ($indentation.Columns -ge 4) {
			$paragraphStart = -1
			continue
		}

		$atxHeading = Get-RenderedAtxHeading -Line $line
		if ($null -ne $atxHeading) {
			if ($atxHeading.Level -eq 1) {
				$h1Blocks.Add([pscustomobject]@{
					StartIndex = $lineIndex
					EndIndex = $lineIndex
					Style = 'Atx'
					HasUsableTitle = $atxHeading.HasUsableTitle
				})
			}
			$paragraphStart = -1
			continue
		}

		if (Test-IsRenderedSetextUnderline -Line $line -Marker ([char]'=')) {
			if ($paragraphStart -ge 0) {
				$hasUsableTitle = $false
				for ($titleIndex = $paragraphStart; $titleIndex -lt $lineIndex; $titleIndex++) {
					if (-not [string]::IsNullOrWhiteSpace($lines[$titleIndex])) {
						$hasUsableTitle = $true
						break
					}
				}
				$h1Blocks.Add([pscustomobject]@{
					StartIndex = $paragraphStart
					EndIndex = $lineIndex
					Style = 'Setext'
					HasUsableTitle = $hasUsableTitle
				})
			}
			$paragraphStart = -1
			continue
		}

		if (Test-IsRenderedSetextUnderline -Line $line -Marker ([char]'-')) {
			$paragraphStart = -1
			continue
		}

		if ($paragraphStart -lt 0) {
			$paragraphStart = $lineIndex
		}
	}

	return [pscustomobject]@{
		Lines = $lines
		ContentStart = $contentStart
		FrontmatterUnclosed = $frontmatterUnclosed
		RenderedLines = $renderedLines
		H1Blocks = $h1Blocks.ToArray()
	}
}

function Get-DocumentationH1InsertionIndex {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[AllowEmptyString()]
		[string]$Content
	)

	$structure = Get-DocumentationStructure -Content $Content
	if ($structure.FrontmatterUnclosed) {
		throw 'YAML frontmatter is not closed.'
	}
	if ($structure.H1Blocks.Count -ne 1) {
		throw "Document must contain exactly one H1; found $($structure.H1Blocks.Count)."
	}
	$h1 = $structure.H1Blocks[0]
	if (-not $h1.HasUsableTitle) {
		throw 'Document must contain a usable H1 title.'
	}

	return $h1.EndIndex
}

function ConvertFrom-DocumentationMetadataRow {
	param(
		[Parameter(Mandatory)]
		[AllowEmptyString()]
		[string]$Line
	)

	if (-not $Line.StartsWith('| ', [StringComparison]::Ordinal) -or
		-not $Line.EndsWith(' |', [StringComparison]::Ordinal) -or
		$Line.Length -lt 7) {
		return $null
	}

	$inner = $Line.Substring(2, $Line.Length - 4)
	$separatorIndex = $inner.IndexOf(' | ', [StringComparison]::Ordinal)
	if ($separatorIndex -lt 1) {
		return $null
	}

	$labelToken = $inner.Substring(0, $separatorIndex)
	$value = $inner.Substring($separatorIndex + 3)
	$isBold = $labelToken.Length -gt 4 -and
		$labelToken.StartsWith('**', [StringComparison]::Ordinal) -and
		$labelToken.EndsWith('**', [StringComparison]::Ordinal)
	$label = if ($isBold) {
		$labelToken.Substring(2, $labelToken.Length - 4)
	}
	else {
		$labelToken
	}

	return [pscustomobject]@{
		Label = $label
		Value = $value
		IsBold = $isBold
	}
}

function Test-LineHasMetadataEvidence {
	param(
		[Parameter(Mandatory)]
		[AllowEmptyString()]
		[string]$Line
	)

	if ($Line.Equals('| Field | Value |', [StringComparison]::Ordinal) -or
		$Line.Equals('|---|---|', [StringComparison]::Ordinal)) {
		return $true
	}

	$row = ConvertFrom-DocumentationMetadataRow -Line $Line
	if ($null -eq $row) {
		return $false
	}
	foreach ($field in $script:DocumentationMetadataFields) {
		if ($row.Label.Equals($field, [StringComparison]::Ordinal)) {
			return $true
		}
	}

	return $false
}

function Test-IsSafeMetadataText {
	param(
		[AllowEmptyString()]
		[string]$Value
	)

	if ([string]::IsNullOrWhiteSpace($Value) -or
		-not $Value.Equals($Value.Trim(), [StringComparison]::Ordinal) -or
		$Value.IndexOf([char]'|') -ge 0) {
		return $false
	}
	foreach ($character in $Value.ToCharArray()) {
		if ([char]::IsControl($character)) {
			return $false
		}
	}

	return $true
}

function Test-IsValidVersion {
	param(
		[AllowEmptyString()]
		[string]$Value
	)

	return [regex]::IsMatch(
		$Value,
		'^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$',
		[Text.RegularExpressions.RegexOptions]::CultureInvariant
	)
}

function Test-IsValidDate {
	param(
		[AllowEmptyString()]
		[string]$Value
	)

	$parsedDate = [datetime]::MinValue
	return [datetime]::TryParseExact(
		$Value,
		'yyyy-MM-dd',
		[Globalization.CultureInfo]::InvariantCulture,
		[Globalization.DateTimeStyles]::None,
		[ref]$parsedDate
	)
}

function Test-IsValidStatus {
	param(
		[AllowEmptyString()]
		[string]$Value
	)

	if (-not (Test-IsSafeMetadataText -Value $Value)) {
		return $false
	}
	foreach ($prefix in $script:DocumentationStatusPrefixes) {
		$pattern = '^' + [regex]::Escape($prefix) +
			'(?: \((?<Qualifier>[^\p{Cc}()|]+)\))?$'
		$statusMatch = [regex]::Match(
			$Value,
			$pattern,
			[Text.RegularExpressions.RegexOptions]::CultureInvariant
		)
		if ($statusMatch.Success) {
			$qualifier = $statusMatch.Groups['Qualifier']
			return -not $qualifier.Success -or $qualifier.Value.Equals(
				$qualifier.Value.Trim(),
				[StringComparison]::Ordinal
			)
		}
	}

	return $false
}

function Test-IsValidDocumentRelativePath {
	param(
		[Parameter(Mandatory)]
		[AllowEmptyString()]
		[string]$DocumentRelativePath
	)

	if ([string]::IsNullOrWhiteSpace($DocumentRelativePath) -or
		$DocumentRelativePath.StartsWith('/', [StringComparison]::Ordinal) -or
		$DocumentRelativePath.StartsWith('\', [StringComparison]::Ordinal) -or
		$DocumentRelativePath.IndexOf([char]'\') -ge 0 -or
		[regex]::IsMatch(
			$DocumentRelativePath,
			'^[A-Za-z]:',
			[Text.RegularExpressions.RegexOptions]::CultureInvariant
		)) {
		return $false
	}

	$absoluteUri = $null
	if ([uri]::TryCreate(
		$DocumentRelativePath,
		[UriKind]::Absolute,
		[ref]$absoluteUri
	)) {
		return $false
	}
	foreach ($character in $DocumentRelativePath.ToCharArray()) {
		if ([char]::IsControl($character)) {
			return $false
		}
	}
	foreach ($segment in $DocumentRelativePath.Split([char]'/')) {
		if ([string]::IsNullOrEmpty($segment) -or
			$segment.Equals('.', [StringComparison]::Ordinal) -or
			$segment.Equals('..', [StringComparison]::Ordinal)) {
			return $false
		}
	}

	return $true
}

function Test-IsValidReferenceTarget {
	param(
		[Parameter(Mandatory)]
		[string]$Target,

		[string]$DocumentRelativePath
	)

	$hasDocumentContext = $PSBoundParameters.ContainsKey('DocumentRelativePath')
	if ($hasDocumentContext -and
		-not (Test-IsValidDocumentRelativePath `
			-DocumentRelativePath $DocumentRelativePath)) {
		return $false
	}

	if ([string]::IsNullOrEmpty($Target) -or
		$Target.StartsWith('/', [StringComparison]::Ordinal) -or
		$Target.StartsWith('\', [StringComparison]::Ordinal) -or
		$Target.IndexOf([char]'\') -ge 0 -or
		[regex]::IsMatch(
			$Target,
			'^[A-Za-z]:',
			[Text.RegularExpressions.RegexOptions]::CultureInvariant
		)) {
		return $false
	}
	foreach ($character in $Target.ToCharArray()) {
		if ([char]::IsWhiteSpace($character) -or
			[char]::IsControl($character) -or
			$character -eq [char]'|') {
			return $false
		}
	}

	$absoluteUri = $null
	if ([uri]::TryCreate($Target, [UriKind]::Absolute, [ref]$absoluteUri)) {
		return $false
	}

	$pathEnd = $Target.Length
	foreach ($separator in [char[]]@('?', '#')) {
		$separatorIndex = $Target.IndexOf($separator)
		if ($separatorIndex -ge 0 -and $separatorIndex -lt $pathEnd) {
			$pathEnd = $separatorIndex
		}
	}
	try {
		$decodedPath = [uri]::UnescapeDataString($Target.Substring(0, $pathEnd))
	}
	catch {
		return $false
	}

	$decodedAbsoluteUri = $null
	if ($decodedPath.StartsWith('/', [StringComparison]::Ordinal) -or
		$decodedPath.StartsWith('\', [StringComparison]::Ordinal) -or
		$decodedPath.IndexOf([char]'\') -ge 0 -or
		[regex]::IsMatch(
			$decodedPath,
			'^[A-Za-z]:',
			[Text.RegularExpressions.RegexOptions]::CultureInvariant
		) -or
		[uri]::TryCreate(
			$decodedPath,
			[UriKind]::Absolute,
			[ref]$decodedAbsoluteUri
		)) {
		return $false
	}
	foreach ($character in $decodedPath.ToCharArray()) {
		if ([char]::IsControl($character)) {
			return $false
		}
	}

	$normalizedSegments = [Collections.Generic.List[string]]::new()
	if ($hasDocumentContext) {
		$documentSegments = $DocumentRelativePath.Split([char]'/')
		for ($segmentIndex = 0; $segmentIndex -lt $documentSegments.Count - 1; $segmentIndex++) {
			$normalizedSegments.Add($documentSegments[$segmentIndex])
		}
	}
	foreach ($segment in $decodedPath.Split([char]'/')) {
		if ($segment.Equals('..', [StringComparison]::Ordinal)) {
			if (-not $hasDocumentContext -or $normalizedSegments.Count -eq 0) {
				return $false
			}
			$normalizedSegments.RemoveAt($normalizedSegments.Count - 1)
		}
		elseif (-not [string]::IsNullOrEmpty($segment) -and
			-not $segment.Equals('.', [StringComparison]::Ordinal)) {
			$normalizedSegments.Add($segment)
		}
	}

	return $true
}

function Test-IsValidReferences {
	param(
		[AllowEmptyString()]
		[string]$Value,

		[string]$DocumentRelativePath
	)

	if (-not (Test-IsSafeMetadataText -Value $Value)) {
		return $false
	}
	$hasDocumentContext = $PSBoundParameters.ContainsKey('DocumentRelativePath')
	if ($hasDocumentContext -and
		-not (Test-IsValidDocumentRelativePath `
			-DocumentRelativePath $DocumentRelativePath)) {
		return $false
	}
	if ($Value.Equals('None', [StringComparison]::Ordinal)) {
		return $true
	}

	$position = 0
	while ($position -lt $Value.Length) {
		if ($Value[$position] -ne [char]'[') {
			return $false
		}

		$labelEnd = $Value.IndexOf(']', $position + 1)
		if ($labelEnd -lt 0) {
			return $false
		}
		$label = $Value.Substring($position + 1, $labelEnd - $position - 1)
		if (-not (Test-IsSafeMetadataText -Value $label) -or
			$label.IndexOf([char]'[') -ge 0) {
			return $false
		}

		$targetStart = $labelEnd + 1
		if ($targetStart -ge $Value.Length -or
			$Value[$targetStart] -ne [char]'(') {
			return $false
		}
		$targetEnd = $Value.IndexOf(')', $targetStart + 1)
		if ($targetEnd -lt 0) {
			return $false
		}
		$target = $Value.Substring(
			$targetStart + 1,
			$targetEnd - $targetStart - 1
		)
		$targetParameters = @{ Target = $target }
		if ($hasDocumentContext) {
			$targetParameters.DocumentRelativePath = $DocumentRelativePath
		}
		if (-not (Test-IsValidReferenceTarget @targetParameters)) {
			return $false
		}

		$position = $targetEnd + 1
		if ($position -eq $Value.Length) {
			return $true
		}
		if ($Value[$position] -ne [char]',' -and
			$Value[$position] -ne [char]';') {
			return $false
		}

		$position++
		while ($position -lt $Value.Length -and
			[char]::IsWhiteSpace($Value[$position])) {
			$position++
		}
		if ($position -eq $Value.Length) {
			return $false
		}
	}

	return $false
}

function Test-DocumentationMetadataEligibility {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[string]$RelativePath
	)

	if ([string]::IsNullOrWhiteSpace($RelativePath)) {
		return $false
	}

	$normalizedPath = $RelativePath.Replace('\', '/')
	if ($normalizedPath.StartsWith('./', [StringComparison]::Ordinal)) {
		$normalizedPath = $normalizedPath.Substring(2)
	}
	if ([string]::IsNullOrWhiteSpace($normalizedPath) -or
		$normalizedPath.StartsWith('/', [StringComparison]::Ordinal) -or
		$normalizedPath.StartsWith('//', [StringComparison]::Ordinal) -or
		[regex]::IsMatch(
			$normalizedPath,
			'^[A-Za-z]:',
			[Text.RegularExpressions.RegexOptions]::CultureInvariant
		)) {
		return $false
	}

	$segments = $normalizedPath.Split([char]'/')
	foreach ($segment in $segments) {
		if ([string]::IsNullOrEmpty($segment) -or
			$segment.Equals('.', [StringComparison]::Ordinal) -or
			$segment.Equals('..', [StringComparison]::Ordinal)) {
			return $false
		}
		foreach ($character in $segment.ToCharArray()) {
			if ([char]::IsControl($character)) {
				return $false
			}
		}
	}

	if (-not $normalizedPath.EndsWith(
		'.md',
		[StringComparison]::OrdinalIgnoreCase
	)) {
		return $false
	}
	if ($normalizedPath.Equals('LICENSE', [StringComparison]::OrdinalIgnoreCase) -or
		$normalizedPath.Equals(
			'.github/skills/LICENSE.superpowers',
			[StringComparison]::OrdinalIgnoreCase
		)) {
		return $false
	}
	if ($normalizedPath.StartsWith(
		'infra/evidence/',
		[StringComparison]::OrdinalIgnoreCase
	)) {
		return $false
	}
	if ($normalizedPath.StartsWith(
		'.github/skills/',
		[StringComparison]::OrdinalIgnoreCase
	) -and -not $normalizedPath.Equals(
		'.github/skills/README.md',
		[StringComparison]::OrdinalIgnoreCase
	)) {
		return $false
	}

	return $true
}

function Test-DocumentationMetadataContent {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[AllowEmptyString()]
		[string]$Content,

		[string]$DocumentRelativePath
	)

	$failures = [Collections.Generic.List[string]]::new()
	$structure = Get-DocumentationStructure -Content $Content
	if ($structure.FrontmatterUnclosed) {
		$failures.Add('YAML frontmatter is not closed.')
		return $failures.ToArray()
	}
	if ($structure.H1Blocks.Count -ne 1) {
		$failures.Add((
			'Document must contain exactly one H1 outside frontmatter and fenced examples; found {0}.' -f
				$structure.H1Blocks.Count
		))
		return $failures.ToArray()
	}

	$h1 = $structure.H1Blocks[0]
	if (-not $h1.HasUsableTitle) {
		$failures.Add('Document must contain a usable H1 title.')
		return $failures.ToArray()
	}
	for ($lineIndex = $structure.ContentStart; $lineIndex -lt $h1.StartIndex; $lineIndex++) {
		if ($structure.RenderedLines[$lineIndex] -and
			-not [string]::IsNullOrWhiteSpace($structure.Lines[$lineIndex])) {
			$failures.Add('Only blank lines may appear before the rendered H1.')
			break
		}
	}

	$tableStart = $h1.EndIndex + 1
	while ($tableStart -lt $structure.Lines.Count -and
		[string]::IsNullOrWhiteSpace($structure.Lines[$tableStart])) {
		$tableStart++
	}
	if ($tableStart -ge $structure.Lines.Count) {
		$failures.Add('Documentation metadata is missing.')
		return $failures.ToArray()
	}

	$tableEnd = $tableStart
	while ($tableEnd -lt $structure.Lines.Count -and
		-not [string]::IsNullOrWhiteSpace($structure.Lines[$tableEnd])) {
		$tableEnd++
	}

	if (-not $structure.RenderedLines[$tableStart]) {
		$failures.Add('Documentation metadata is missing.')
		return $failures.ToArray()
	}

	if ($structure.Lines[$tableStart].Equals(
		'| Field | Value |',
		[StringComparison]::Ordinal
	)) {
		$separatorIndex = $tableStart + 1
		if ($separatorIndex -ge $tableEnd -or
			-not $structure.Lines[$separatorIndex].Equals(
				'|---|---|',
				[StringComparison]::Ordinal
			)) {
			$failures.Add('Metadata table separator must be exactly |---|---|.')
		}

		$values = @{}
		$seenFields = [Collections.Generic.HashSet[string]]::new(
			[StringComparer]::Ordinal
		)
		for ($fieldIndex = 0; $fieldIndex -lt $script:DocumentationMetadataFields.Count; $fieldIndex++) {
			$expectedField = $script:DocumentationMetadataFields[$fieldIndex]
			$rowIndex = $tableStart + 2 + $fieldIndex
			if ($rowIndex -ge $tableEnd) {
				$failures.Add("Metadata field '$expectedField' is missing.")
				continue
			}

			$row = ConvertFrom-DocumentationMetadataRow -Line $structure.Lines[$rowIndex]
			if ($null -eq $row) {
				$failures.Add("Metadata row for '$expectedField' has invalid formatting.")
				continue
			}
			if (-not $row.IsBold) {
				$failures.Add("Metadata field '$($row.Label)' must be bolded.")
			}
			if (-not $seenFields.Add($row.Label)) {
				$failures.Add("Metadata field '$($row.Label)' is duplicated.")
			}
			if (-not $row.Label.Equals($expectedField, [StringComparison]::Ordinal)) {
				$failures.Add((
					"Metadata fields are out of order: expected '$expectedField', found '$($row.Label)'."
				))
				continue
			}

			$values[$expectedField] = $row.Value
		}

		foreach ($field in $script:DocumentationMetadataFields) {
			if (-not $values.ContainsKey($field)) {
				$failures.Add("Metadata field '$field' is missing.")
			}
		}

		$lineAfterReferences = $tableStart + 8
		if ($lineAfterReferences -ge $structure.Lines.Count -or
			-not [string]::IsNullOrWhiteSpace($structure.Lines[$lineAfterReferences])) {
			if ($lineAfterReferences -lt $structure.Lines.Count -and
				$structure.Lines[$lineAfterReferences].StartsWith(
					'|',
					[StringComparison]::Ordinal
				)) {
				$failures.Add('Metadata table contains an extra row.')
			}
			$failures.Add('A blank line must immediately follow References.')
		}

		if ($values.ContainsKey('Version') -and
			-not (Test-IsValidVersion -Value $values.Version)) {
			$failures.Add('Version must use nonnegative major.minor form.')
		}
		if ($values.ContainsKey('Date') -and
			-not (Test-IsValidDate -Value $values.Date)) {
			$failures.Add('Date must be a real date in yyyy-MM-dd form.')
		}
		if ($values.ContainsKey('Author') -and
			-not (Test-IsSafeMetadataText -Value $values.Author)) {
			$failures.Add('Author must be trimmed, nonempty, and safe for a table cell.')
		}
		if ($values.ContainsKey('Status') -and
			-not (Test-IsValidStatus -Value $values.Status)) {
			$failures.Add('Status does not use an allowed prefix.')
		}
		if ($values.ContainsKey('Scope') -and
			-not (Test-IsSafeMetadataText -Value $values.Scope)) {
			$failures.Add('Scope must be trimmed, nonempty, and free of unsafe characters.')
		}
		$referenceParameters = @{}
		if ($values.ContainsKey('References')) {
			$referenceParameters.Value = $values.References
		}
		if ($PSBoundParameters.ContainsKey('DocumentRelativePath')) {
			$referenceParameters.DocumentRelativePath = $DocumentRelativePath
		}
		if ($values.ContainsKey('References') -and
			-not (Test-IsValidReferences @referenceParameters)) {
			$failures.Add('References must be None or relative Markdown links only.')
		}
		if ($failures.Count -gt 0 -and
			-not $failures.Contains('Existing documentation metadata is malformed or partial.')) {
			$failures.Add('Existing documentation metadata is malformed or partial.')
		}

		return $failures.ToArray()
	}

	$metadataEvidenceFound = $false
	for ($lineIndex = $tableStart; $lineIndex -lt $tableEnd; $lineIndex++) {
		if (Test-LineHasMetadataEvidence -Line $structure.Lines[$lineIndex]) {
			$metadataEvidenceFound = $true
			break
		}
	}
	if ($metadataEvidenceFound) {
		$failures.Add('Existing documentation metadata is malformed or partial.')
	}
	else {
		$failures.Add('Documentation metadata is missing.')
	}

	return $failures.ToArray()
}

function New-DocumentationMetadataTable {
	[CmdletBinding()]
	param(
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
		[string]$References,

		[string]$DocumentRelativePath
	)

	if (-not (Test-IsValidVersion -Value $Version)) {
		throw 'Version must use nonnegative major.minor form.'
	}
	if (-not (Test-IsValidDate -Value $Date)) {
		throw 'Date must be a real date in yyyy-MM-dd form.'
	}
	if (-not (Test-IsSafeMetadataText -Value $Author)) {
		throw 'Author must be trimmed, nonempty, and safe for a table cell.'
	}
	if (-not (Test-IsValidStatus -Value $Status)) {
		throw 'Status does not use an allowed prefix.'
	}
	if (-not (Test-IsSafeMetadataText -Value $Scope)) {
		throw 'Scope must be trimmed, nonempty, and free of unsafe characters.'
	}
	$referenceParameters = @{ Value = $References }
	if ($PSBoundParameters.ContainsKey('DocumentRelativePath')) {
		$referenceParameters.DocumentRelativePath = $DocumentRelativePath
	}
	if (-not (Test-IsValidReferences @referenceParameters)) {
		throw 'References must be None or relative Markdown links only.'
	}

	return @(
		'| Field | Value |'
		'|---|---|'
		('| **Version** | {0} |' -f $Version)
		('| **Date** | {0} |' -f $Date)
		('| **Author** | {0} |' -f $Author)
		('| **Status** | {0} |' -f $Status)
		('| **Scope** | {0} |' -f $Scope)
		('| **References** | {0} |' -f $References)
	) -join "`n"
}

Export-ModuleMember -Function @(
	'Test-DocumentationMetadataEligibility',
	'Test-DocumentationMetadataContent',
	'Get-DocumentationH1InsertionIndex',
	'New-DocumentationMetadataTable'
)