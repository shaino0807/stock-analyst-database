[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$logDir = Join-Path $projectRoot 'logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logPath = Join-Path $logDir "we178-daily-update-$timestamp.log"

Start-Transcript -LiteralPath $logPath -Force | Out-Null
try {
    Set-Location -LiteralPath $projectRoot
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $projectRoot 'scripts\update-we178-knowledge.ps1') -ContinueOnSubtitleError
}
finally {
    Stop-Transcript | Out-Null
}
