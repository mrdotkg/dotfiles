# =============================================================================
# Dot's PowerShell Profile
# A comprehensive PowerShell profile for enhanced terminal experience
# Compatible with PowerShell 5.1 and PowerShell 7+
# =============================================================================

# Profile Information
$ProfileInfo = @{
    Name        = "Dot's PowerShell Profile"
    Version     = "1.0.0"
    Author      = "Dot"
    LastUpdated = "2024"
}

Write-Host "Loading $($ProfileInfo.Name) v$($ProfileInfo.Version)..." -ForegroundColor Cyan

# Initialize Starship Prompt (if available)
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
    Write-Host "✓ Starship prompt initialized" -ForegroundColor Green
}
else {
    Write-Warning "Starship not found. Install with: winget install starship"
}

# Enhanced PSReadLine Configuration (PowerShell 5.1+ / 7+)
if (Get-Module -ListAvailable PSReadLine) {
    Import-Module PSReadLine
    
    # Prediction and History
    Set-PSReadLineOption -PredictionSource History
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Set-PSReadLineOption -PredictionViewStyle ListView
    }
    
    # Editing and Navigation
    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    
    # Colors
    Set-PSReadLineOption -Colors @{
        Command   = 'Yellow'
        Parameter = 'Green'
        Operator  = 'Magenta'
        Variable  = 'Blue'
        String    = 'Red'
        Number    = 'Red'
        Type      = 'Cyan'
        Comment   = 'DarkGreen'
    }
    
    Write-Host "✓ PSReadLine configured with enhanced features" -ForegroundColor Green
}
else {
    Write-Warning "PSReadLine not available. Some features may be limited."
}

# Useful Aliases
Set-Alias -Name vim -Value nvim -ErrorAction SilentlyContinue
Set-Alias -Name ll -Value Get-ChildItem
Set-Alias -Name la -Value Get-ChildItem
Set-Alias -Name l -Value Get-ChildItem
Set-Alias -Name grep -Value Select-String
Set-Alias -Name touch -Value New-Item

# Enhanced Functions
function .. { Set-Location .. }
function ... { Set-Location ..\.. }
function .... { Set-Location ..\..\.. }

function Get-PublicIP {
    try {
        $ip = Invoke-RestMethod -Uri "https://ipinfo.io/ip" -TimeoutSec 5
        Write-Host "Public IP: $ip" -ForegroundColor Green
        return $ip
    }
    catch {
        Write-Warning "Could not retrieve public IP"
    }
}

function Get-Weather {
    param([string]$City = "")
    try {
        $uri = if ($City) { "https://wttr.in/$City" } else { "https://wttr.in" }
        Invoke-RestMethod -Uri $uri
    }
    catch {
        Write-Warning "Could not retrieve weather information"
    }
}

function Show-Colors {
    [System.Enum]::GetValues([System.ConsoleColor]) | ForEach-Object {
        Write-Host $_ -ForegroundColor $_
    }
}

function Edit-Profile {
    if (Get-Command code -ErrorAction SilentlyContinue) {
        code $PROFILE
    }
    elseif (Get-Command nvim -ErrorAction SilentlyContinue) {
        nvim $PROFILE
    }
    elseif (Get-Command notepad -ErrorAction SilentlyContinue) {
        notepad $PROFILE
    }
    else {
        Write-Warning "No suitable editor found"
    }
}

function Reload-Profile {
    & $PROFILE
    Write-Host "Profile reloaded!" -ForegroundColor Green
}

# Git shortcuts (if Git is available)
if (Get-Command git -ErrorAction SilentlyContinue) {
    function gs { git status }
    function ga { git add $args }
    function gc { git commit -m $args }
    function gp { git push }
    function gl { git log --oneline -10 }
    function gd { git diff $args }
}

# Docker shortcuts (if Docker is available)
if (Get-Command docker -ErrorAction SilentlyContinue) {
    function dps { docker ps }
    function dpsa { docker ps -a }
    function di { docker images }
    function dc { docker-compose $args }
}

# System Information Function
function Get-SystemInfo {
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $ram = Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
    
    Write-Host "=== System Information ===" -ForegroundColor Cyan
    Write-Host "OS: $($os.Caption) $($os.Version)" -ForegroundColor Yellow
    Write-Host "CPU: $($cpu.Name)" -ForegroundColor Yellow
    Write-Host "RAM: $([math]::Round($ram.Sum / 1GB, 2)) GB" -ForegroundColor Yellow
    Write-Host "PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
    Write-Host "Profile: $($ProfileInfo.Name)" -ForegroundColor Yellow
}

# Welcome Message
Write-Host ""
Write-Host "Welcome to $($ProfileInfo.Name)!" -ForegroundColor Green
Write-Host "Type 'Get-SystemInfo' for system details" -ForegroundColor DarkGray
Write-Host "Type 'Show-Colors' to see available colors" -ForegroundColor DarkGray
Write-Host "Type 'Edit-Profile' to customize this profile" -ForegroundColor DarkGray
Write-Host ""
