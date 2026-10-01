function Measure-HrAiBuilderEvaluation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$ValidationRecords
    )

    $records = @($ValidationRecords)
    $recordCount = $records.Count
    $exactMatchCount = @($records | Where-Object { $_.exact_match }).Count
    $returnedCount = @($records | Where-Object { $_.actual_present }).Count
    $expectedCount = @($records | Where-Object { $_.expected_present }).Count
    $correctReturnedCount = @(
        $records |
            Where-Object { $_.actual_present -and $_.expected_present -and $_.exact_match }
    ).Count
    $expectedAbsentCount = @($records | Where-Object { -not $_.expected_present }).Count
    $correctlyAbsentCount = @(
        $records |
            Where-Object { -not $_.expected_present -and -not $_.actual_present }
    ).Count
    $falseValueCount = @($records | Where-Object { $_.error_class -eq 'false_value' }).Count
    $qualityFindings = @(
        $records |
            Where-Object { $_.error_class -in @('missing', 'incorrect', 'invalid_format') }
    ).Count

    $byField = @(
        $records |
            Group-Object -Property field_name |
            Sort-Object Name |
            ForEach-Object {
                $groupRecords = @($_.Group)
                [ordered]@{
                    field_name = [string]$_.Name
                    validation_record_count = $groupRecords.Count
                    exact_match_accuracy = Get-HrAiBuilderMetricValue -Numerator (@($groupRecords | Where-Object { $_.exact_match }).Count) -Denominator $groupRecords.Count
                    precision = Get-HrAiBuilderMetricValue -Numerator (@($groupRecords | Where-Object { $_.actual_present -and $_.expected_present -and $_.exact_match }).Count) -Denominator (@($groupRecords | Where-Object { $_.actual_present }).Count)
                    recall = Get-HrAiBuilderMetricValue -Numerator (@($groupRecords | Where-Object { $_.actual_present -and $_.expected_present -and $_.exact_match }).Count) -Denominator (@($groupRecords | Where-Object { $_.expected_present }).Count)
                    missing_field_precision = Get-HrAiBuilderMetricValue -Numerator (@($groupRecords | Where-Object { -not $_.expected_present -and -not $_.actual_present }).Count) -Denominator (@($groupRecords | Where-Object { -not $_.expected_present }).Count)
                    false_value_rate = Get-HrAiBuilderMetricValue -Numerator (@($groupRecords | Where-Object { $_.error_class -eq 'false_value' }).Count) -Denominator (@($groupRecords | Where-Object { -not $_.expected_present }).Count)
                    confidence_distribution = @(
                        foreach ($bucketName in @('exact_match', 'missing', 'incorrect', 'false_value', 'invalid_format')) {
                            $bucketRecords = @(
                                $groupRecords |
                                    Where-Object {
                                        if ($bucketName -eq 'exact_match') {
                                            $_.exact_match
                                        }
                                        else {
                                            $_.error_class -eq $bucketName
                                        }
                                    }
                            )
                            New-HrAiBuilderConfidenceDistributionRecord -Outcome $bucketName -Records $bucketRecords
                        }
                    )
                }
            }
    )

    $byCollectionOrFamily = @(
        $records |
            Group-Object -Property collection_or_family |
            Sort-Object Name |
            ForEach-Object {
                $groupRecords = @($_.Group)
                [ordered]@{
                    collection_or_family = [string]$_.Name
                    validation_record_count = $groupRecords.Count
                    exact_match_accuracy = Get-HrAiBuilderMetricValue -Numerator (@($groupRecords | Where-Object { $_.exact_match }).Count) -Denominator $groupRecords.Count
                    precision = Get-HrAiBuilderMetricValue -Numerator (@($groupRecords | Where-Object { $_.actual_present -and $_.expected_present -and $_.exact_match }).Count) -Denominator (@($groupRecords | Where-Object { $_.actual_present }).Count)
                    recall = Get-HrAiBuilderMetricValue -Numerator (@($groupRecords | Where-Object { $_.actual_present -and $_.expected_present -and $_.exact_match }).Count) -Denominator (@($groupRecords | Where-Object { $_.expected_present }).Count)
                    missing_field_precision = Get-HrAiBuilderMetricValue -Numerator (@($groupRecords | Where-Object { -not $_.expected_present -and -not $_.actual_present }).Count) -Denominator (@($groupRecords | Where-Object { -not $_.expected_present }).Count)
                    false_value_rate = Get-HrAiBuilderMetricValue -Numerator (@($groupRecords | Where-Object { $_.error_class -eq 'false_value' }).Count) -Denominator (@($groupRecords | Where-Object { -not $_.expected_present }).Count)
                    confidence_distribution = @(
                        foreach ($bucketName in @('exact_match', 'missing', 'incorrect', 'false_value', 'invalid_format')) {
                            $bucketRecords = @(
                                $groupRecords |
                                    Where-Object {
                                        if ($bucketName -eq 'exact_match') {
                                            $_.exact_match
                                        }
                                        else {
                                            $_.error_class -eq $bucketName
                                        }
                                    }
                            )
                            New-HrAiBuilderConfidenceDistributionRecord -Outcome $bucketName -Records $bucketRecords
                        }
                    )
                }
            }
    )

    return [pscustomobject]([ordered]@{
            validation_record_count = $recordCount
            exact_match_accuracy = Get-HrAiBuilderMetricValue -Numerator $exactMatchCount -Denominator $recordCount
            precision = Get-HrAiBuilderMetricValue -Numerator $correctReturnedCount -Denominator $returnedCount
            recall = Get-HrAiBuilderMetricValue -Numerator $correctReturnedCount -Denominator $expectedCount
            missing_field_precision = Get-HrAiBuilderMetricValue -Numerator $correctlyAbsentCount -Denominator $expectedAbsentCount
            false_value_rate = Get-HrAiBuilderMetricValue -Numerator $falseValueCount -Denominator $expectedAbsentCount
            false_value_count = $falseValueCount
            quality_finding_count = $qualityFindings
            confidence_distribution = @(
                foreach ($bucketName in @('exact_match', 'missing', 'incorrect', 'false_value', 'invalid_format')) {
                    $bucketRecords = @(
                        $records |
                            Where-Object {
                                if ($bucketName -eq 'exact_match') {
                                    $_.exact_match
                                }
                                else {
                                    $_.error_class -eq $bucketName
                                }
                            }
                    )
                    New-HrAiBuilderConfidenceDistributionRecord -Outcome $bucketName -Records $bucketRecords
                }
            )
            by_field = $byField
            by_collection_or_family = $byCollectionOrFamily
        })
}
    function New-HrAiBuilderConfidenceDistributionRecord {
        param(
            [Parameter(Mandatory)]
            [string]$Outcome,

            [AllowEmptyCollection()]
            [object[]]$Records
        )

        $summary = Get-HrAiBuilderConfidenceSummary -Records $Records
        return [pscustomobject]([ordered]@{
                outcome = $Outcome
                count = $summary.count
                minimum = $summary.minimum
                maximum = $summary.maximum
                mean = $summary.mean
            })
    }
