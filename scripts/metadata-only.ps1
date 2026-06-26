[CmdletBinding()]
param(
    [string]$Url,
    [string]$BatchFile,
    [string]$OutputDir = 'outputs/media',
    [switch]$AllowPlaylist,
    [switch]$DryRun
)

. "$PSScriptRoot\MediaTools.ps1"

$metadataDir = Ensure-Directory -Path (Join-Path $OutputDir 'metadata')
$urls = Get-UrlList -Url $Url -BatchFile $BatchFile

foreach ($item in $urls) {
    $arguments = @(
        '--windows-filenames',
        '--no-overwrites',
        '--skip-download',
        '--write-info-json',
        '--clean-info-json',
        '-o', (Join-Path $metadataDir '%(upload_date>%Y-%m-%d)s_%(title).180B_[%(id)s].%(ext)s')
    )
    $arguments = Add-PlaylistPolicy -Arguments $arguments -AllowPlaylist:$AllowPlaylist
    $arguments += $item

    Invoke-YtDlp -Arguments $arguments -DryRun:$DryRun
}

