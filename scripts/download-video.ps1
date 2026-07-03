[CmdletBinding()]
param(
    [string]$Url,
    [string]$BatchFile,
    [string]$OutputDir = 'outputs/media',
    [ValidateRange(144, 4320)]
    [int]$MaxHeight = 1080,
    [switch]$AllowPlaylist,
    [switch]$EstimateOnly,
    [switch]$ConfirmStorageImpact,
    [switch]$DryRun
)

. "$PSScriptRoot\MediaTools.ps1"

$videoDir = Ensure-Directory -Path (Join-Path $OutputDir 'videos')
$ffmpegPath = Get-FfmpegPath
$urls = Get-UrlList -Url $Url -BatchFile $BatchFile
$jobs = New-Object System.Collections.Generic.List[object]

foreach ($item in $urls) {
    $arguments = @(
        '--windows-filenames',
        '--no-overwrites',
        '--merge-output-format', 'mp4',
        '--ffmpeg-location', $ffmpegPath,
        '-f', "bv*[height<=$MaxHeight][ext=mp4]+ba[ext=m4a]/bv*[height<=$MaxHeight]+ba/b[height<=$MaxHeight]/best",
        '-o', (Join-Path $videoDir '%(upload_date>%Y-%m-%d)s_%(title).180B_[%(id)s].%(ext)s')
    )
    $arguments = Add-PlaylistPolicy -Arguments $arguments -AllowPlaylist:$AllowPlaylist
    $arguments += $item

    $jobs.Add([pscustomobject]@{
        url = $item
        arguments = $arguments
    })
}

if ($EstimateOnly -or (-not $DryRun -and -not $ConfirmStorageImpact)) {
    $estimates = @($jobs | ForEach-Object {
        Get-YtDlpStorageEstimate -Arguments $_.arguments -Url $_.url
    })
    Write-StorageImpactNotice -Estimates $estimates -MediaKind 'video' -OutputDirectory $videoDir

    if ($EstimateOnly) {
        return
    }

    throw 'Video download blocked until storage impact is reviewed. Re-run with -ConfirmStorageImpact to download.'
}

foreach ($job in $jobs) {
    Invoke-YtDlp -Arguments $job.arguments -DryRun:$DryRun
}
