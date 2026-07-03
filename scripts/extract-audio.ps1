[CmdletBinding()]
param(
    [string]$Url,
    [string]$BatchFile,
    [string]$OutputDir = 'outputs/media',
    [ValidateSet('m4a', 'mp3', 'wav', 'opus', 'flac')]
    [string]$AudioFormat = 'm4a',
    [switch]$AllowPlaylist,
    [switch]$EstimateOnly,
    [switch]$ConfirmStorageImpact,
    [switch]$DryRun
)

. "$PSScriptRoot\MediaTools.ps1"

$audioDir = Ensure-Directory -Path (Join-Path $OutputDir 'audio')
$ffmpegPath = Get-FfmpegPath
$urls = Get-UrlList -Url $Url -BatchFile $BatchFile
$jobs = New-Object System.Collections.Generic.List[object]

foreach ($item in $urls) {
    $arguments = @(
        '--windows-filenames',
        '--no-overwrites',
        '--ffmpeg-location', $ffmpegPath,
        '-f', 'bestaudio/best',
        '-x',
        '--audio-format', $AudioFormat,
        '--audio-quality', '0',
        '-o', (Join-Path $audioDir '%(upload_date>%Y-%m-%d)s_%(title).180B_[%(id)s].%(ext)s')
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
    Write-StorageImpactNotice -Estimates $estimates -MediaKind 'audio' -OutputDirectory $audioDir

    if ($EstimateOnly) {
        return
    }

    throw 'Audio download blocked until storage impact is reviewed. Re-run with -ConfirmStorageImpact to download.'
}

foreach ($job in $jobs) {
    Invoke-YtDlp -Arguments $job.arguments -DryRun:$DryRun
}
