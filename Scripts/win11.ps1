# Install CascadiaCode Nerd Font (one-liner)
Invoke-WebRequest -Uri "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/CascadiaCode.zip" -OutFile "$env:TEMP\CascadiaCode.zip";
Expand-Archive "$env:TEMP\CascadiaCode.zip" -DestinationPath "$env:TEMP\CascadiaCode" -Force;
Get-ChildItem "$env:TEMP\CascadiaCode" -Filter "*.ttf" | ForEach-Object { Copy-Item $_.FullName "$env:WINDIR\Fonts\" -Force };
Remove-Item "$env:TEMP\CascadiaCode.zip", "$env:TEMP\CascadiaCode" -Recurse -Force -ErrorAction SilentlyContinue

# Install Steam
winget install Valve.Steam -e --accept-source-agreements --accept-package-agreements

# Install Neovim
winget install Neovim.Neovim -e --accept-source-agreements --accept-package-agreements

# Setup OpenSSH And Allow through Firewall
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
Set-Service -Name sshd -StartupType 'Automatic'
Start-Service sshd
New-NetFirewallRule -Name 'OpenSSH Server (sshd)' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Action Allow -Protocol TCP -LocalPort 22

# Allow Remote Desktop
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -Value 0;
Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'

# Install Starship via winget
winget install starship -e --accept-source-agreements --accept-package-agreements

# Setup Starship Configuration
$starshipConfigDir = "$env:USERPROFILE\.config"
if (!(Test-Path $starshipConfigDir)) { New-Item -ItemType Directory -Path $starshipConfigDir -Force | Out-Null }

$sourceStarshipConfig = "$PSScriptRoot\.config\starship\dot-starship.toml"
$targetStarshipConfig = "$starshipConfigDir\starship.toml"
if (Test-Path "$sourceStarshipConfig") { 
    Copy-Item "$sourceStarshipConfig" "$targetStarshipConfig" -Force 
    Write-Host "Starship config copied from: $sourceStarshipConfig" -ForegroundColor Green
}
else {
    Write-Warning "Starship config not found at: $sourceStarshipConfig"
}

# Install PowerShell
winget install Microsoft.PowerShell -e --accept-source-agreements --accept-package-agreements

# PowerShell 7 as Default SSH Shell
Set-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name 'DefaultShell' -Value 'C:\Program Files\PowerShell\7\pwsh.exe'

# PowerShell Profile Setup
Write-Host "Setting up PowerShell profiles..." -ForegroundColor Green

# PowerShell 5 Profile Setup
$ps5ProfileDir = "$env:USERPROFILE\Documents\WindowsPowerShell"
$ps5ProfilePath = "$ps5ProfileDir\Microsoft.PowerShell_profile.ps1"
$sourceProfile = "$PSScriptRoot\powershell\dot_msps_profile.ps1"

if (!(Test-Path $ps5ProfileDir)) { 
    New-Item -ItemType Directory -Path $ps5ProfileDir -Force | Out-Null 
}
if (Test-Path $sourceProfile) {
    Copy-Item "$sourceProfile" "$ps5ProfilePath" -Force
    Write-Host "PowerShell 5 profile copied to: $ps5ProfilePath" -ForegroundColor Green
}
else {
    Write-Warning "PowerShell profile not found at: $sourceProfile"
}

# PowerShell 7 Profile Setup
$ps7ProfileDir = "$env:USERPROFILE\Documents\PowerShell"
$ps7ProfilePath = "$ps7ProfileDir\Microsoft.PowerShell_profile.ps1"

if (!(Test-Path $ps7ProfileDir)) { 
    New-Item -ItemType Directory -Path $ps7ProfileDir -Force | Out-Null 
}
if (Test-Path $sourceProfile) {
    Copy-Item "$sourceProfile" "$ps7ProfilePath" -Force
    Write-Host "PowerShell 7 profile copied to: $ps7ProfilePath" -ForegroundColor Green
}
else {
    Write-Warning "PowerShell profile not found at: $sourceProfile"
}