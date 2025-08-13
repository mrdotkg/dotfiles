# 🔤 Font Installation: Download and install CascadiaCode Nerd Font for terminal display rendering typography
Invoke-WebRequest -Uri "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.1.1/CascadiaCode.zip" -OutFile "$env:TEMP\CascadiaCode.zip";
Expand-Archive "$env:TEMP\CascadiaCode.zip" -DestinationPath "$env:TEMP\CascadiaCode" -Force;
Get-ChildItem "$env:TEMP\CascadiaCode" -Filter "*.ttf" | ForEach-Object { Copy-Item $_.FullName "$env:WINDIR\Fonts\" -Force };
Remove-Item "$env:TEMP\CascadiaCode.zip", "$env:TEMP\CascadiaCode" -Recurse -Force -ErrorAction SilentlyContinue

# 🎮 Gaming Platform: Install Steam for game library management launcher overlay controller
winget install Valve.Steam -e --accept-source-agreements --accept-package-agreements

# 📝 Text Editor: Install Neovim for advanced text editing capabilities keybindings shortcuts vim
winget install Neovim.Neovim -e --accept-source-agreements --accept-package-agreements

# 🔐 SSH Configuration: Setup OpenSSH server client daemon authentication keys cryptography security
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
Set-Service -Name sshd -StartupType 'Automatic'
Start-Service sshd
New-NetFirewallRule -Name 'OpenSSH Server (sshd)' -DisplayName 'OpenSSH Server (sshd)' -Enabled True -Direction Inbound -Action Allow -Protocol TCP -LocalPort 22

# 🖥️ Remote Access: Enable Remote Desktop Protocol RDP connections terminal services display
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -Value 0;
Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'

# ⭐ Shell Enhancement: Install Starship for customizable command prompt terminal theme appearance
winget install starship -e --accept-source-agreements --accept-package-agreements

# ⚙️ Starship Config: Setup custom configuration for enhanced terminal prompt display formatting theme
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

# 💻 PowerShell Upgrade: Install latest PowerShell version for improved features cmdlets performance
winget install Microsoft.PowerShell -e --accept-source-agreements --accept-package-agreements

# 🛡️ SSH Security: Set PowerShell 7 as default SSH shell for secure connections terminal registry
Set-ItemProperty -Path 'HKLM:\SOFTWARE\OpenSSH' -Name 'DefaultShell' -Value 'C:\Program Files\PowerShell\7\pwsh.exe'

# 🔧 Profile Configuration: Setup PowerShell profiles for custom environment variables functions aliases
Write-Host "Setting up PowerShell profiles..." -ForegroundColor Green

# 📁 PowerShell 5 Setup: Configure legacy PowerShell profile for compatibility modules cmdlets
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

# 🚀 PowerShell 7 Setup: Configure modern PowerShell profile for enhanced functionality cross-platform
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