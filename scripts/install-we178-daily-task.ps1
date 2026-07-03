[CmdletBinding()]
param(
    [string]$TaskName = 'WE178DailyKnowledgeUpdate',
    [string]$DailyTime = '09:30'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$runner = Join-Path $projectRoot 'scripts\run-we178-daily-update.ps1'

if (-not (Test-Path -LiteralPath $runner -PathType Leaf)) {
    throw "Daily runner not found: $runner"
}

$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$runner`"" `
    -WorkingDirectory $projectRoot

$trigger = New-ScheduledTaskTrigger -Daily -At $DailyTime
$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -MultipleInstances IgnoreNew

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description 'Refresh WE178 YouTube metadata, public subtitles, text sources, and secondary knowledge. Does not download audio or original videos.' `
    -Force | Out-Null

Write-Host "Installed scheduled task: $TaskName"
Write-Host "Daily time: $DailyTime"
Write-Host "Runner: $runner"
