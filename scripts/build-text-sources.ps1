[CmdletBinding()]
param(
    [string]$MetadataDir = 'outputs/media/nicolasyounglive/metadata',
    [string]$SubtitleDir = 'outputs/media/nicolasyounglive/subtitles',
    [string]$OutputDir = 'outputs/media/nicolasyounglive/text-sources',
    [string]$PreferredLanguages = 'zh-Hant,zh-Hans,zh-TW,zh,en'
)

. "$PSScriptRoot\MediaTools.ps1"

function Get-SafeFileName {
    param([Parameter(Mandatory = $true)][string]$Name)

    $safe = $Name
    foreach ($char in [System.IO.Path]::GetInvalidFileNameChars()) {
        $safe = $safe.Replace($char, '_')
    }

    $safe = $safe.Trim()
    if ($safe.Length -gt 120) {
        return $safe.Substring(0, 120).Trim()
    }

    return $safe
}

function Convert-SrtToPlainText {
    param([Parameter(Mandatory = $true)][string]$Path)

    $lines = Get-Content -LiteralPath $Path -Encoding UTF8
    $textLines = New-Object System.Collections.Generic.List[string]

    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed.Length -eq 0) {
            continue
        }
        if ($trimmed -match '^\d+$') {
            continue
        }
        if ($trimmed -match '^\d{2}:\d{2}:\d{2}[,.]\d{3}\s+-->\s+\d{2}:\d{2}:\d{2}[,.]\d{3}') {
            continue
        }

        $textLines.Add($trimmed)
    }

    return ($textLines -join "`n")
}

$resolvedMetadataDir = Resolve-ProjectRelativePath -Path $MetadataDir
$resolvedSubtitleDir = Resolve-ProjectRelativePath -Path $SubtitleDir
$resolvedOutputDir = Ensure-Directory -Path $OutputDir
$languages = $PreferredLanguages.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 }

if (-not (Test-Path -LiteralPath $resolvedMetadataDir -PathType Container)) {
    throw "Metadata directory not found: $resolvedMetadataDir"
}
if (Test-Path -LiteralPath $resolvedSubtitleDir -PathType Container) {
    $subtitleFiles = Get-ChildItem -LiteralPath $resolvedSubtitleDir -File -Filter '*.srt'
} else {
    Write-Warning "Subtitle directory not found: $resolvedSubtitleDir. Writing metadata-only text sources."
    $subtitleFiles = @()
}

$indexRows = New-Object System.Collections.Generic.List[string]
$written = 0
$missingTranscript = 0

Get-ChildItem -LiteralPath $resolvedMetadataDir -File -Filter '*.info.json' | Sort-Object Name | ForEach-Object {
    $metadata = Get-Content -LiteralPath $_.FullName -Encoding UTF8 -Raw | ConvertFrom-Json
    $videoId = [string]$metadata.id
    $selectedSubtitle = $null
    $selectedLanguage = $null

    foreach ($language in $languages) {
        $pattern = "\[$([regex]::Escape($videoId))\]\.$([regex]::Escape($language))\.srt$"
        $selectedSubtitle = $subtitleFiles | Where-Object { $_.Name -match $pattern } | Select-Object -First 1
        if ($null -ne $selectedSubtitle) {
            $selectedLanguage = $language
            break
        }
    }

    $uploadDate = if ($metadata.upload_date -match '^\d{8}$') {
        '{0}-{1}-{2}' -f $metadata.upload_date.Substring(0, 4), $metadata.upload_date.Substring(4, 2), $metadata.upload_date.Substring(6, 2)
    } else {
        [string]$metadata.upload_date
    }

    $title = [string]$metadata.title
    $webpageUrl = [string]$metadata.webpage_url
    if ([string]::IsNullOrWhiteSpace($webpageUrl)) {
        $webpageUrl = "https://www.youtube.com/watch?v=$videoId"
    }

    $description = [string]$metadata.description
    $transcript = ''
    if ($null -ne $selectedSubtitle) {
        $transcript = Convert-SrtToPlainText -Path $selectedSubtitle.FullName
    } else {
        $missingTranscript += 1
        $transcript = 'Transcript unavailable in this local run. Use subtitles or audio transcription before quote-level analysis.'
    }

    $safeTitle = Get-SafeFileName -Name $title
    $outputName = '{0}_{1}_[{2}].md' -f $uploadDate, $safeTitle, $videoId
    $outputPath = Join-Path $resolvedOutputDir $outputName

    $body = @(
        "---"
        "source_type: youtube_video"
        "channel: `"$($metadata.channel)`""
        "channel_url: `"$($metadata.channel_url)`""
        "video_id: `"$videoId`""
        "url: `"$webpageUrl`""
        "upload_date: `"$uploadDate`""
        "duration_seconds: $($metadata.duration)"
        "subtitle_language: `"$selectedLanguage`""
        "workflow_stage: source"
        "---"
        ""
        "# $title"
        ""
        "Source: $webpageUrl"
        ""
        "## Description"
        ""
        $description
        ""
        "## Transcript"
        ""
        $transcript
        ""
    ) -join "`n"

    Set-Content -LiteralPath $outputPath -Value $body -Encoding UTF8
    $indexRows.Add(([pscustomobject]@{
        video_id = $videoId
        title = $title
        channel = [string]$metadata.channel
        url = $webpageUrl
        upload_date = $uploadDate
        duration_seconds = $metadata.duration
        subtitle_language = $selectedLanguage
        transcript_missing = ($null -eq $selectedSubtitle)
        metadata_path = $_.FullName
        subtitle_path = if ($null -ne $selectedSubtitle) { $selectedSubtitle.FullName } else { $null }
        text_source_path = $outputPath
    } | ConvertTo-Json -Compress))
    $written += 1
}

$indexPath = Join-Path $resolvedOutputDir 'index.jsonl'
Set-Content -LiteralPath $indexPath -Value $indexRows -Encoding UTF8

Write-Host "Wrote $written text source files to $resolvedOutputDir"
Write-Host "Missing transcript files: $missingTranscript"
Write-Host "Wrote index manifest to $indexPath"
