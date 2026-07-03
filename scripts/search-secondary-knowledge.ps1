[CmdletBinding()]
param(
    [string]$IndexPath = 'knowledge/sensebar/index.jsonl',
    [string]$Query,
    [string]$Topic,
    [string]$Entity,
    [switch]$TranscriptOnly,
    [switch]$MissingTranscriptOnly,
    [switch]$IncludeSourceText,
    [int]$Limit = 30,
    [switch]$Json
)

. "$PSScriptRoot\MediaTools.ps1"

function Test-TextMatch {
    param(
        [string]$Text,
        [string]$Needle
    )

    if ([string]::IsNullOrWhiteSpace($Needle)) {
        return $true
    }

    if ([string]::IsNullOrWhiteSpace($Text)) {
        return $false
    }

    return $Text.IndexOf($Needle, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
}

$resolvedIndexPath = Resolve-ProjectRelativePath -Path $IndexPath
if (-not (Test-Path -LiteralPath $resolvedIndexPath -PathType Leaf)) {
    throw "Knowledge index not found: $resolvedIndexPath"
}

$rows = Get-Content -LiteralPath $resolvedIndexPath -Encoding UTF8 |
    Where-Object { $_.Trim().Length -gt 0 } |
    ForEach-Object { $_ | ConvertFrom-Json }

$results = foreach ($row in $rows) {
    if ($TranscriptOnly -and [bool]$row.transcript_missing) {
        continue
    }
    if ($MissingTranscriptOnly -and -not [bool]$row.transcript_missing) {
        continue
    }

    $topicText = @($row.topics) -join ' '
    $entityText = @($row.entities) -join ' '
    $stanceText = @($row.stances) -join ' '
    $hashtagText = @($row.hashtags) -join ' '
    $searchText = @($row.title, $row.url, $topicText, $entityText, $stanceText, $hashtagText) -join "`n"

    if ($IncludeSourceText -and -not [string]::IsNullOrWhiteSpace([string]$row.source_text_path) -and (Test-Path -LiteralPath ([string]$row.source_text_path) -PathType Leaf)) {
        $searchText += "`n"
        $searchText += Get-Content -LiteralPath ([string]$row.source_text_path) -Encoding UTF8 -Raw
    }

    if (-not (Test-TextMatch -Text $searchText -Needle $Query)) {
        continue
    }
    if (-not (Test-TextMatch -Text $topicText -Needle $Topic)) {
        continue
    }
    if (-not (Test-TextMatch -Text $entityText -Needle $Entity)) {
        continue
    }

    [pscustomobject]@{
        upload_date = [string]$row.upload_date
        title = [string]$row.title
        url = [string]$row.url
        topics = @($row.topics) -join '; '
        entities = @($row.entities) -join '; '
        stances = @($row.stances) -join '; '
        transcript_missing = [bool]$row.transcript_missing
        secondary_note_path = [string]$row.secondary_note_path
        source_text_path = [string]$row.source_text_path
    }
}

$limited = @($results | Sort-Object upload_date -Descending | Select-Object -First $Limit)

if ($Json) {
    $limited | ConvertTo-Json -Depth 5
} else {
    $limited | Format-Table upload_date, title, topics, transcript_missing, secondary_note_path -AutoSize
}
