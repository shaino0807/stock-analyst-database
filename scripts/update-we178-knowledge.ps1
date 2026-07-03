[CmdletBinding()]
param(
    [string]$ChannelUrl = 'https://www.youtube.com/@we178/videos',
    [string]$BatchFile = 'batch-list-we178.txt',
    [string]$NewMetadataBatchFile = 'batch-list-we178-new-metadata.txt',
    [string]$RemainingMetadataBatchFile = 'batch-list-we178-remaining-metadata.txt',
    [string]$MissingBatchFile = 'batch-list-we178-missing-transcripts.txt',
    [string]$OutputDir = 'outputs/media/we178',
    [string]$KnowledgeDir = 'knowledge/we178',
    [string]$KnowledgeTitle = '',
    [string]$DefaultTopic = 'Public finance news and market commentary',
    [string]$SubtitleLanguages = 'zh-TW,zh-Hant,zh-Hans,en,zh',
    [switch]$SkipChannelRefresh,
    [switch]$SkipMetadata,
    [switch]$SkipSubtitles,
    [switch]$RetryMissingSubtitles,
    [switch]$ContinueOnSubtitleError
)

. "$PSScriptRoot\MediaTools.ps1"

function Get-JsonlRows {
    param([Parameter(Mandatory = $true)][string]$Path)

    $resolved = Resolve-ProjectRelativePath -Path $Path
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
        return @()
    }

    return @(Get-Content -LiteralPath $resolved -Encoding UTF8 |
        Where-Object { $_.Trim().Length -gt 0 } |
        ForEach-Object { $_ | ConvertFrom-Json })
}

function ConvertFrom-Codepoints {
    param([Parameter(Mandatory = $true)][string]$Codepoints)

    $chars = $Codepoints.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
        [char][Convert]::ToInt32($_, 16)
    }
    return -join $chars
}

function Get-YoutubeVideoId {
    param([Parameter(Mandatory = $true)][string]$Url)

    if ($Url -match '[?&]v=([^&]+)') {
        return $matches[1]
    }

    return $null
}

function Get-ExistingMetadataIds {
    param([Parameter(Mandatory = $true)][string]$MetadataDir)

    $resolved = Resolve-ProjectRelativePath -Path $MetadataDir
    $ids = @{}
    if (-not (Test-Path -LiteralPath $resolved -PathType Container)) {
        return $ids
    }

    Get-ChildItem -LiteralPath $resolved -File -Filter '*.info.json' | ForEach-Object {
        try {
            $metadata = Get-Content -LiteralPath $_.FullName -Encoding UTF8 -Raw | ConvertFrom-Json
            if (-not [string]::IsNullOrWhiteSpace([string]$metadata.id)) {
                $ids[[string]$metadata.id] = $true
            }
        }
        catch {
            Write-Warning "Could not read metadata id from $($_.FullName): $($_.Exception.Message)"
        }
    }

    return $ids
}

function Set-UrlBatchFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$Urls,
        [Parameter(Mandatory = $true)][string]$Source
    )

    $header = @(
        "# Source: $Source"
        "# Updated: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))"
        '# One public YouTube video URL per line.'
    )
    Set-Content -LiteralPath (Resolve-ProjectRelativePath -Path $Path) -Value ($header + $Urls) -Encoding UTF8
}

function Get-ChannelUrls {
    param([Parameter(Mandatory = $true)][string]$Url)

    $ytDlp = Get-YtDlpPath
    $arguments = Add-JavaScriptRuntimePolicy -Arguments @(
        '--flat-playlist',
        '--print',
        'https://www.youtube.com/watch?v=%(id)s',
        $Url
    )

    $previousPythonIoEncoding = [Environment]::GetEnvironmentVariable('PYTHONIOENCODING')
    $previousConsoleOutputEncoding = [Console]::OutputEncoding
    [Environment]::SetEnvironmentVariable('PYTHONIOENCODING', 'utf-8')
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    try {
        $urls = & $ytDlp @arguments
        if ($LASTEXITCODE -ne 0) {
            throw "yt-dlp failed while listing channel videos with exit code $LASTEXITCODE"
        }
    }
    finally {
        [Console]::OutputEncoding = $previousConsoleOutputEncoding
        [Environment]::SetEnvironmentVariable('PYTHONIOENCODING', $previousPythonIoEncoding)
    }

    return @($urls | Where-Object { $_ -match '^https://www\.youtube\.com/watch\?v=' } | Select-Object -Unique)
}

$projectRoot = Get-ProjectRoot
$defaultKnowledgeTitle = ConvertFrom-Codepoints '80A1 7968 5206 6790 5E2B 8CC7 6599 5EAB'
if ([string]::IsNullOrWhiteSpace($KnowledgeTitle)) {
    $KnowledgeTitle = $defaultKnowledgeTitle
}
$metadataDir = Join-Path $OutputDir 'metadata'
$subtitleDir = Join-Path $OutputDir 'subtitles'
$textSourceDir = Join-Path $OutputDir 'text-sources'

if (-not $SkipChannelRefresh) {
    Write-Host "Updating $KnowledgeTitle video list from $ChannelUrl"
    $channelUrls = Get-ChannelUrls -Url $ChannelUrl
    if ($channelUrls.Count -eq 0) {
        throw "No video URLs found for $ChannelUrl"
    }
    Set-UrlBatchFile -Path $BatchFile -Urls $channelUrls -Source $ChannelUrl
} else {
    $batchPath = Resolve-ProjectRelativePath -Path $BatchFile
    if (-not (Test-Path -LiteralPath $batchPath -PathType Leaf)) {
        throw "Batch file not found: $batchPath"
    }
    $channelUrls = @(Get-Content -LiteralPath $batchPath -Encoding UTF8 | Where-Object { $_ -match '^https?://' })
}

$channelUrls = @($channelUrls | Select-Object -Unique)
$metadataIds = Get-ExistingMetadataIds -MetadataDir $metadataDir
$newMetadataUrls = @($channelUrls | Where-Object {
    $id = Get-YoutubeVideoId -Url $_
    [string]::IsNullOrWhiteSpace($id) -or -not $metadataIds.ContainsKey($id)
})
Set-UrlBatchFile -Path $NewMetadataBatchFile -Urls $newMetadataUrls -Source "$BatchFile missing local metadata subset"

$metadataScript = Join-Path $projectRoot 'scripts\metadata-only.ps1'
$subtitlesScript = Join-Path $projectRoot 'scripts\extract-subtitles.ps1'
$textSourcesScript = Join-Path $projectRoot 'scripts\build-text-sources.ps1'
$secondaryScript = Join-Path $projectRoot 'scripts\build-secondary-knowledge.ps1'

if (-not $SkipMetadata -and $newMetadataUrls.Count -gt 0) {
    & $metadataScript -BatchFile (Resolve-ProjectRelativePath -Path $NewMetadataBatchFile) -OutputDir $OutputDir
    if (-not $?) {
        throw "metadata-only.ps1 failed"
    }
}

$subtitleTargets = @()
if ($RetryMissingSubtitles) {
    $missingPath = Resolve-ProjectRelativePath -Path $MissingBatchFile
    if (Test-Path -LiteralPath $missingPath -PathType Leaf) {
        $subtitleTargets = @(Get-Content -LiteralPath $missingPath -Encoding UTF8 | Where-Object { $_ -match '^https?://' })
    }
} else {
    $subtitleTargets = $newMetadataUrls
}

if (-not $SkipSubtitles -and $subtitleTargets.Count -gt 0) {
    $subtitleBatchPath = Resolve-ProjectRelativePath -Path 'batch-list-we178-subtitle-targets.txt'
    Set-UrlBatchFile -Path $subtitleBatchPath -Urls $subtitleTargets -Source "$KnowledgeTitle subtitle targets from update-we178-knowledge.ps1"
    & $subtitlesScript -BatchFile $subtitleBatchPath -OutputDir $OutputDir -SubtitleLanguages $SubtitleLanguages -IncludeAutoGenerated -ContinueOnError:$ContinueOnSubtitleError
    if (-not $?) {
        throw "extract-subtitles.ps1 failed"
    }
}

& $textSourcesScript -MetadataDir $metadataDir -SubtitleDir $subtitleDir -OutputDir $textSourceDir
if (-not $?) {
    throw "build-text-sources.ps1 failed"
}

& $secondaryScript -IndexPath (Join-Path $textSourceDir 'index.jsonl') -OutputDir $KnowledgeDir -CollectionTitle $KnowledgeTitle -DefaultTopic $DefaultTopic -ClassificationProfile mixed
if (-not $?) {
    throw "build-secondary-knowledge.ps1 failed"
}

$sourceRows = Get-JsonlRows -Path (Join-Path $textSourceDir 'index.jsonl')
$knowledgeRows = Get-JsonlRows -Path (Join-Path $KnowledgeDir 'index.jsonl')
$missing = @($sourceRows | Where-Object { [bool]$_.transcript_missing } | Sort-Object upload_date)

Set-UrlBatchFile -Path $MissingBatchFile -Urls @($missing | ForEach-Object { [string]$_.url }) -Source 'outputs/media/we178/text-sources/index.jsonl transcript_missing subset'

$metadataIds = Get-ExistingMetadataIds -MetadataDir $metadataDir
$remainingMetadataUrls = @($channelUrls | Where-Object {
    $id = Get-YoutubeVideoId -Url $_
    [string]::IsNullOrWhiteSpace($id) -or -not $metadataIds.ContainsKey($id)
})
Set-UrlBatchFile -Path $RemainingMetadataBatchFile -Urls $remainingMetadataUrls -Source "$BatchFile missing local metadata subset"

$missingLines = New-Object System.Collections.Generic.List[string]
$missingLines.Add("# $KnowledgeTitle Transcript Missing")
$missingLines.Add('')
$missingLines.Add("Generated: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))")
$missingLines.Add('')
$missingLines.Add("Missing transcript count: $($missing.Count)")
$missingLines.Add('')
$missingLines.Add('These videos did not expose public subtitles in the requested languages during local subtitle sweeps. Use this list for audio extraction/transcription only after reviewing storage impact.')
$missingLines.Add('')
$missingLines.Add('| Date | Title | URL |')
$missingLines.Add('| --- | --- | --- |')
foreach ($row in $missing) {
    $title = ([string]$row.title) -replace '\|', '/'
    $missingLines.Add("| $($row.upload_date) | $title | $($row.url) |")
}
Set-Content -LiteralPath (Resolve-ProjectRelativePath -Path (Join-Path $KnowledgeDir 'transcript-missing.md')) -Value $missingLines -Encoding UTF8

$urlCount = $channelUrls.Count
$metadataCount = @(Get-ChildItem -LiteralPath (Resolve-ProjectRelativePath -Path $metadataDir) -File -Filter '*.info.json' -ErrorAction SilentlyContinue).Count
$subtitleCount = if (Test-Path -LiteralPath (Resolve-ProjectRelativePath -Path $subtitleDir) -PathType Container) {
    @(Get-ChildItem -LiteralPath (Resolve-ProjectRelativePath -Path $subtitleDir) -File -Filter '*.srt' -ErrorAction SilentlyContinue).Count
} else {
    0
}
$transcriptReady = @($sourceRows | Where-Object { -not [bool]$_.transcript_missing }).Count

$status = @(
    "# $KnowledgeTitle Ingestion Status"
    ''
    "Updated: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss zzz'))"
    ''
    '## Source'
    ''
    ('- Channel: {0}' -f $ChannelUrl)
    ('- Public video URLs listed: {0}' -f $urlCount)
    ('- Batch list: `{0}`' -f $BatchFile)
    ''
    '## Coverage'
    ''
    '| Layer | Count | Status |'
    '| --- | ---: | --- |'
    ('| Public video URLs | {0} | Complete for latest local channel refresh |' -f $urlCount)
    ('| Metadata JSON | {0} | Complete when this equals URL count |' -f $metadataCount)
    ('| Subtitle files | {0} | Public subtitles only |' -f $subtitleCount)
    ('| Text source records | {0} | Search source layer |' -f $sourceRows.Count)
    ('| Text sources with transcript | {0} | Uses public subtitles only |' -f $transcriptReady)
    ('| Text sources missing transcript | {0} | Needs subtitle retry or ASR audio transcription |' -f $missing.Count)
    ('| Secondary knowledge notes | {0} | Search and retrieval layer |' -f $knowledgeRows.Count)
    ('| Remaining metadata URLs | {0} | Listed in `{1}` |' -f $remainingMetadataUrls.Count, $RemainingMetadataBatchFile)
    ''
    '## Search And Retrieval'
    ''
    '- Browse: `knowledge/we178/index.md`'
    '- Machine index: `knowledge/we178/index.jsonl`'
    '- Per-video secondary notes: `knowledge/we178/notes/`'
    '- Missing transcript report: `knowledge/we178/transcript-missing.md`'
    '- Search help: `knowledge/we178/SEARCH.md`'
    ''
    '## Daily Refresh'
    ''
    '- Suggested task name: `WE178DailyKnowledgeUpdate`'
    '- Entry point: `scripts/run-we178-daily-update.ps1`'
    '- Installer: `scripts/install-we178-daily-task.ps1`'
    '- Daily behavior: refreshes the channel video list, fetches metadata/subtitles only for newly discovered videos, rebuilds text sources and secondary knowledge, and updates missing-transcript lists.'
    '- It does not download audio or original videos.'
    ''
    '## Resume Commands'
    ''
    "Run the $KnowledgeTitle refresh manually:"
    ''
    '```powershell'
    'powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\update-we178-knowledge.ps1 -ContinueOnSubtitleError'
    '```'
    ''
    'Retry missing public subtitles later, without downloading audio/video:'
    ''
    '```powershell'
    'powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\update-we178-knowledge.ps1 -SkipChannelRefresh -SkipMetadata -RetryMissingSubtitles -ContinueOnSubtitleError'
    '```'
    ''
    '## Notes'
    ''
    '- Audio extraction/transcription is intentionally separate. Use `extract-audio.ps1 -EstimateOnly` first and only download audio with `-ConfirmStorageImpact` after reviewing the size estimate.'
    '- Original video downloads are also blocked by default until storage impact is estimated and `-ConfirmStorageImpact` is supplied.'
)
Set-Content -LiteralPath (Resolve-ProjectRelativePath -Path (Join-Path $KnowledgeDir 'INGESTION_STATUS.md')) -Value $status -Encoding UTF8

[pscustomobject]@{
    urls = $urlCount
    new_metadata_targets = $newMetadataUrls.Count
    subtitle_targets = $subtitleTargets.Count
    metadata = $metadataCount
    subtitles = $subtitleCount
    text_sources = $sourceRows.Count
    transcript_ready = $transcriptReady
    transcript_missing = $missing.Count
    knowledge_notes = $knowledgeRows.Count
    remaining_metadata = $remainingMetadataUrls.Count
}
