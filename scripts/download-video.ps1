[CmdletBinding()]
param(
    [string]$Url,
    [string]$BatchFile,
    [string]$OutputDir = 'outputs/media',
    [ValidateRange(144, 4320)]
    [int]$MaxHeight = 1080,
    [switch]$AllowPlaylist,
    [switch]$DryRun
)

. "$PSScriptRoot\MediaTools.ps1"

$videoDir = Ensure-Directory -Path (Join-Path $OutputDir 'videos')
$ffmpegPath = Get-FfmpegPath
$urls = Get-UrlList -Url $Url -BatchFile $BatchFile

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

    Invoke-YtDlp -Arguments $arguments -DryRun:$DryRun
}
