[CmdletBinding()]
param(
    [string]$Url,
    [string]$BatchFile,
    [string]$OutputDir = 'outputs/media',
    [ValidateSet('m4a', 'mp3', 'wav', 'opus', 'flac')]
    [string]$AudioFormat = 'm4a',
    [switch]$AllowPlaylist,
    [switch]$DryRun
)

. "$PSScriptRoot\MediaTools.ps1"

$audioDir = Ensure-Directory -Path (Join-Path $OutputDir 'audio')
$ffmpegPath = Get-FfmpegPath
$urls = Get-UrlList -Url $Url -BatchFile $BatchFile

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

    Invoke-YtDlp -Arguments $arguments -DryRun:$DryRun
}

