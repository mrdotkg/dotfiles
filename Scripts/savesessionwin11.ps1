# LMDT-TASK: Save current window session to log file for housekeeping and session management
function Save-Session {
    param(
        [string]$SessionName,
        [string]$Notes
    )
    $sessionEntry = "_____`n$SessionName`n$Notes`n`n"
    $logPath = "$env:USERPROFILE\Documents\Notes\LastSession.txt"
    $logDir = Split-Path $logPath -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    if (Test-Path $logPath) {
        $existingContent = Get-Content -Path $logPath -Raw -Encoding UTF8
        $sessionEntry + $existingContent | Set-Content -Path $logPath -Encoding UTF8
    }
    else {
        $sessionEntry | Set-Content -Path $logPath -Encoding UTF8
    }
    Write-Host "Session logged!" -ForegroundColor Green
    Write-Host "File: $logPath" -ForegroundColor Cyan
}

$windows = Get-Process | Where-Object { 
    $_.MainWindowTitle -and 
    $_.MainWindowTitle.Trim() -ne "" -and
    $_.ProcessName -notmatch "^(dwm|winlogon|csrss|textinputhost|shellexperiencehost|sihost)$"
} | ForEach-Object {
    "[$($_.ProcessName)] $($_.MainWindowTitle)"
} | Sort-Object | Get-Unique

$windows = $windows | Sort-Object | Get-Unique
$defaultNotes = $windows -join "`n"
$sessionName = Get-Date -Format "MMM dd, yyyy - HH:mm"
$notes = $defaultNotes
Save-Session -SessionName $sessionName -Notes $notes