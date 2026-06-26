Set-StrictMode -Version Latest

$script:DefaultYtDlpPath = 'C:\Users\shaino\Documents\Codex\2026-06-25\yt-dlp\tools\media\yt-dlp.exe'
$script:DefaultFfmpegPath = 'C:\Users\shaino\Documents\Codex\2026-06-25\yt-dlp\tools\media\ffmpeg.exe'

function Get-ProjectRoot {
    return (Split-Path -Parent $PSScriptRoot)
}

function Resolve-MediaTool {
    param(
        [Parameter(Mandatory = $true)][string]$CommandName,
        [Parameter(Mandatory = $true)][string]$EnvironmentVariable,
        [Parameter(Mandatory = $true)][string]$DefaultPath
    )

    $configured = [Environment]::GetEnvironmentVariable($EnvironmentVariable)
    if (-not [string]::IsNullOrWhiteSpace($configured)) {
        $expanded = [Environment]::ExpandEnvironmentVariables($configured)
        if (Test-Path -LiteralPath $expanded -PathType Leaf) {
            return (Resolve-Path -LiteralPath $expanded).Path
        }

        throw "$EnvironmentVariable points to a missing file: $expanded"
    }

    $command = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($null -ne $command -and -not [string]::IsNullOrWhiteSpace($command.Source)) {
        return $command.Source
    }

    if (Test-Path -LiteralPath $DefaultPath -PathType Leaf) {
        return (Resolve-Path -LiteralPath $DefaultPath).Path
    }

    throw "Cannot find $CommandName. Set $EnvironmentVariable to the executable path."
}

function Get-YtDlpPath {
    return Resolve-MediaTool -CommandName 'yt-dlp' -EnvironmentVariable 'YTDLP_PATH' -DefaultPath $script:DefaultYtDlpPath
}

function Get-FfmpegPath {
    return Resolve-MediaTool -CommandName 'ffmpeg' -EnvironmentVariable 'FFMPEG_PATH' -DefaultPath $script:DefaultFfmpegPath
}

function Resolve-ProjectRelativePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    $currentPath = Join-Path (Get-Location).Path $Path
    if (Test-Path -LiteralPath $currentPath) {
        return $currentPath
    }

    return (Join-Path (Get-ProjectRoot) $Path)
}

function Ensure-Directory {
    param([Parameter(Mandatory = $true)][string]$Path)

    $resolved = Resolve-ProjectRelativePath -Path $Path
    New-Item -ItemType Directory -Force -Path $resolved | Out-Null
    return (Resolve-Path -LiteralPath $resolved).Path
}

function Get-UrlList {
    param(
        [string]$Url,
        [string]$BatchFile
    )

    $urls = New-Object System.Collections.Generic.List[string]

    if (-not [string]::IsNullOrWhiteSpace($Url)) {
        $urls.Add($Url.Trim())
    }

    if (-not [string]::IsNullOrWhiteSpace($BatchFile)) {
        $batchPath = Resolve-ProjectRelativePath -Path $BatchFile
        if (-not (Test-Path -LiteralPath $batchPath -PathType Leaf)) {
            throw "Batch file not found: $batchPath"
        }

        Get-Content -LiteralPath $batchPath -Encoding UTF8 | ForEach-Object {
            $line = $_.Trim()
            if ($line.Length -gt 0 -and -not $line.StartsWith('#')) {
                $urls.Add($line)
            }
        }
    }

    if ($urls.Count -eq 0) {
        throw "Provide -Url or -BatchFile."
    }

    return $urls.ToArray()
}

function Add-PlaylistPolicy {
    param(
        [string[]]$Arguments,
        [switch]$AllowPlaylist
    )

    if ($AllowPlaylist) {
        return $Arguments
    }

    return @($Arguments + '--no-playlist')
}

function Format-CommandPreview {
    param(
        [Parameter(Mandatory = $true)][string]$Executable,
        [Parameter(Mandatory = $true)][string[]]$Arguments
    )

    $parts = @($Executable) + $Arguments
    return ($parts | ForEach-Object {
        if ($_ -match '\s') {
            "'" + ($_ -replace "'", "''") + "'"
        } else {
            $_
        }
    }) -join ' '
}

function Invoke-YtDlp {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [switch]$DryRun
    )

    $ytDlp = Get-YtDlpPath

    if ($DryRun) {
        Write-Host (Format-CommandPreview -Executable $ytDlp -Arguments $Arguments)
        return
    }

    & $ytDlp @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "yt-dlp failed with exit code $LASTEXITCODE"
    }
}

