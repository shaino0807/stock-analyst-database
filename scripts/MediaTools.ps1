Set-StrictMode -Version Latest

$script:DefaultYtDlpPath = 'C:\Users\shaino\Documents\Codex\2026-06-25\yt-dlp\tools\media\yt-dlp.exe'
$script:DefaultFfmpegPath = 'C:\Users\shaino\Documents\Codex\2026-06-25\yt-dlp\tools\media\ffmpeg.exe'
$script:DefaultNodePath = 'C:\Users\shaino\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe'

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

function Add-JavaScriptRuntimePolicy {
    param([string[]]$Arguments)

    if ($Arguments -contains '--js-runtimes' -or $Arguments -contains '--no-js-runtimes') {
        return $Arguments
    }

    $configured = [Environment]::GetEnvironmentVariable('YTDLP_JS_RUNTIME')
    if (-not [string]::IsNullOrWhiteSpace($configured)) {
        return @('--js-runtimes', $configured) + $Arguments
    }

    $nodePath = $null
    $nodeCommand = Get-Command 'node' -ErrorAction SilentlyContinue
    if ($null -ne $nodeCommand -and -not [string]::IsNullOrWhiteSpace($nodeCommand.Source)) {
        $nodePath = $nodeCommand.Source
    } elseif (Test-Path -LiteralPath $script:DefaultNodePath -PathType Leaf) {
        $nodePath = (Resolve-Path -LiteralPath $script:DefaultNodePath).Path
    }

    if ([string]::IsNullOrWhiteSpace($nodePath)) {
        return $Arguments
    }

    return @('--js-runtimes', "node:$nodePath") + $Arguments
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

function Format-ByteSize {
    param([Nullable[Int64]]$Bytes)

    if ($null -eq $Bytes -or $Bytes -le 0) {
        return 'unknown'
    }

    if ($Bytes -ge 1GB) {
        return ('{0:N2} GB' -f ($Bytes / 1GB))
    }
    if ($Bytes -ge 1MB) {
        return ('{0:N2} MB' -f ($Bytes / 1MB))
    }
    if ($Bytes -ge 1KB) {
        return ('{0:N2} KB' -f ($Bytes / 1KB))
    }

    return "$Bytes B"
}

function Get-FormatByteSize {
    param([object]$Format)

    if ($null -eq $Format) {
        return 0
    }

    $filesizeProperty = $Format.PSObject.Properties['filesize']
    if ($null -ne $filesizeProperty -and $null -ne $filesizeProperty.Value -and [Int64]$filesizeProperty.Value -gt 0) {
        return [Int64]$filesizeProperty.Value
    }
    $approxProperty = $Format.PSObject.Properties['filesize_approx']
    if ($null -ne $approxProperty -and $null -ne $approxProperty.Value -and [Int64]$approxProperty.Value -gt 0) {
        return [Int64]$approxProperty.Value
    }

    return 0
}

function Get-YtDlpStorageEstimate {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$Url
    )

    $ytDlp = Get-YtDlpPath
    $estimateArguments = Add-JavaScriptRuntimePolicy -Arguments (@('--dump-single-json', '--skip-download') + $Arguments)

    $previousPythonIoEncoding = [Environment]::GetEnvironmentVariable('PYTHONIOENCODING')
    $previousConsoleOutputEncoding = [Console]::OutputEncoding
    [Environment]::SetEnvironmentVariable('PYTHONIOENCODING', 'utf-8')
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    try {
        $raw = & $ytDlp @estimateArguments
        if ($LASTEXITCODE -ne 0) {
            throw "yt-dlp failed while estimating storage with exit code $LASTEXITCODE"
        }
    }
    finally {
        [Console]::OutputEncoding = $previousConsoleOutputEncoding
        [Environment]::SetEnvironmentVariable('PYTHONIOENCODING', $previousPythonIoEncoding)
    }

    $jsonText = ($raw | Where-Object { $_ -match '^\s*\{' } | Select-Object -Last 1)
    if ([string]::IsNullOrWhiteSpace($jsonText)) {
        return [pscustomobject]@{
            url = $Url
            title = ''
            bytes = 0
            known = $false
        }
    }

    $info = $jsonText | ConvertFrom-Json
    $bytes = 0
    $requestedFormatsProperty = $info.PSObject.Properties['requested_formats']
    if ($null -ne $requestedFormatsProperty -and $null -ne $requestedFormatsProperty.Value) {
        foreach ($format in $requestedFormatsProperty.Value) {
            $bytes += Get-FormatByteSize -Format $format
        }
    } else {
        $bytes = Get-FormatByteSize -Format $info
    }

    return [pscustomobject]@{
        url = $Url
        title = [string]$info.title
        bytes = [Int64]$bytes
        known = ($bytes -gt 0)
    }
}

function Write-StorageImpactNotice {
    param(
        [Parameter(Mandatory = $true)][object[]]$Estimates,
        [Parameter(Mandatory = $true)][string]$MediaKind,
        [Parameter(Mandatory = $true)][string]$OutputDirectory
    )

    $known = @($Estimates | Where-Object { $_.known })
    $unknown = @($Estimates | Where-Object { -not $_.known })
    $totalBytes = [Int64]0
    foreach ($item in $known) {
        $totalBytes += [Int64]$item.bytes
    }

    Write-Host "Storage impact estimate for $MediaKind downloads:"
    Write-Host "Output directory: $OutputDirectory"
    Write-Host "Items: $($Estimates.Count)"
    Write-Host "Known estimated size: $(Format-ByteSize -Bytes $totalBytes)"
    if ($unknown.Count -gt 0) {
        Write-Warning "Size unavailable for $($unknown.Count) item(s). The final download may be larger than the known estimate."
    }

    $Estimates | Select-Object -First 10 | ForEach-Object {
        $title = if ([string]::IsNullOrWhiteSpace($_.title)) { $_.url } else { $_.title }
        Write-Host ("- {0}: {1}" -f (Format-ByteSize -Bytes $_.bytes), $title)
    }
    if ($Estimates.Count -gt 10) {
        Write-Host "... $($Estimates.Count - 10) more item(s)"
    }
}

function Invoke-YtDlp {
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [switch]$DryRun
    )

    $ytDlp = Get-YtDlpPath
    $resolvedArguments = Add-JavaScriptRuntimePolicy -Arguments $Arguments

    if ($DryRun) {
        Write-Host (Format-CommandPreview -Executable $ytDlp -Arguments $resolvedArguments)
        return
    }

    $previousPythonIoEncoding = [Environment]::GetEnvironmentVariable('PYTHONIOENCODING')
    $previousConsoleOutputEncoding = [Console]::OutputEncoding
    [Environment]::SetEnvironmentVariable('PYTHONIOENCODING', 'utf-8')
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
    try {
        & $ytDlp @resolvedArguments
        if ($LASTEXITCODE -ne 0) {
            throw "yt-dlp failed with exit code $LASTEXITCODE"
        }
    }
    finally {
        [Console]::OutputEncoding = $previousConsoleOutputEncoding
        [Environment]::SetEnvironmentVariable('PYTHONIOENCODING', $previousPythonIoEncoding)
    }
}
