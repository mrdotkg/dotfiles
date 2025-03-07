# Windows 11 Ultimate Developer Setup Script
# Run this script as Administrator

param (
    [string]$Tool
)

Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# Function to Print Status
function Write-Status {
    param ($Message)
    Write-Host "[+] $Message" -ForegroundColor Green
}

# Function to handle errors
function Handle-Error {
    param ($Message)
    Write-Host "[-] $Message" -ForegroundColor Red
    exit 1
}

# Function to log messages
function Write-Log {
    param ($Message)
    $logFile = "$env:USERPROFILE\setup-log.txt"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -Append -FilePath $logFile
}

Write-Status "Installing Chocolatey for Package Management..."
Write-Log "Installing Chocolatey for Package Management..."
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1')) || Handle-Error "Failed to install Chocolatey"

# Configure Chocolatey to remember installation arguments
Write-Status "Configuring Chocolatey to remember installation arguments..."
Write-Log "Configuring Chocolatey to remember installation arguments..."
choco feature enable -n=useRememberedArgumentsForUpgrades || Handle-Error "Failed to configure Chocolatey"

# Install Essential Developer Tools
if (-not $Tool) {
    Write-Status "Installing Core Development Tools..."
    Write-Log "Installing Core Development Tools..."
    $devTools = @("git", "fzf", "bat", "ripgrep", "nvm", "oh-my-posh", "pwsh", "wget", "curl",
        "neovim", "vscode", "7zip", "nodejs", "python", "openjdk", "dotnet-sdk", "go",
        "terminal-icons", "posh-git", "docker-desktop", "kubectl", "rust", "hackfont")
    foreach ($tool in $devTools) {
        Write-Status "Installing $tool..."
        Write-Log "Installing $tool..."
        if (-not (choco install $tool -y --force)) {
            Handle-Error "Failed to install $tool"
        }
    }
}
else {
    Write-Status "Installing $Tool..."
    Write-Log "Installing $Tool..."
    if (-not (choco install $Tool -y --force)) {
        Handle-Error "Failed to install $Tool"
    }
}

# Configure Git
Write-Status "Configuring Git..."
Write-Log "Configuring Git..."
if ($env:GIT_USER_NAME) {
    git config --global user.name "$env:GIT_USER_NAME"
}
else {
    Write-Warning "GIT_USER_NAME environment variable is not set."
    Write-Log "GIT_USER_NAME environment variable is not set."
}

if ($env:GIT_USER_EMAIL) {
    git config --global user.email "$env:GIT_USER_EMAIL"
}
else {
    Write-Warning "GIT_USER_EMAIL environment variable is not set."
    Write-Log "GIT_USER_EMAIL environment variable is not set."
}

git config --global core.autocrlf input
git config --global credential.helper manager-core

# Install and Configure WSL2 with Ubuntu 20.04
Write-Status "Installing & Configuring WSL2 with Ubuntu 20.04..."
Write-Log "Installing & Configuring WSL2 with Ubuntu 20.04..."
wsl --install -d Ubuntu-20.04 || Handle-Error "Failed to install WSL2 with Ubuntu 20.04"
wsl --set-default-version 2 || Handle-Error "Failed to set WSL2 as default version"

# Optimize WSL2
Write-Status "Optimizing WSL2 Performance..."
Write-Log "Optimizing WSL2 Performance..."
$wslConfig = @"
[automount]
enabled = true
root = /mnt/
options = "metadata,umask=22,fmask=11"

[network]
generateResolvConf = false

[boot]
systemd = true

[interop]
appendWindowsPath = false
"@
$wslConfig | Out-File -Encoding utf8 "$env:USERPROFILE\.wslconfig"

# Configure Ubuntu inside WSL2
Write-Status "Configuring Ubuntu with essential tools..."
Write-Log "Configuring Ubuntu with essential tools..."
wsl -e bash -c "sudo apt update && sudo apt upgrade -y" || Handle-Error "Failed to update and upgrade Ubuntu"
wsl -e bash -c "sudo apt install -y curl neofetch git zsh tmux build-essential" || Handle-Error "Failed to install essential tools in Ubuntu"

# Install Volta & Node.js Tools
Write-Status "Installing Volta & Node.js in Ubuntu..."
Write-Log "Installing Volta & Node.js in Ubuntu..."
wsl -e bash -c "curl https://get.volta.sh | bash" || Handle-Error "Failed to install Volta"
wsl -e bash -c "export VOLTA_HOME=\$HOME/.volta && export PATH=\$VOLTA_HOME/bin:\$PATH"
wsl -e bash -c "volta install node@lts npm yarn typescript yarn-upgrade-all @nestjs/cli" || Handle-Error "Failed to install Node.js tools with Volta"

# Install Golang & HUGO in Ubuntu
Write-Status "Installing Go & HUGO in Ubuntu..."
Write-Log "Installing Go & HUGO in Ubuntu..."
wsl -e bash -c "wget https://go.dev/dl/go1.22.linux-amd64.tar.gz -O go.tar.gz" || Handle-Error "Failed to download Go"
wsl -e bash -c "sudo tar -C /usr/local -xzf go.tar.gz" || Handle-Error "Failed to extract Go"
wsl -e bash -c "go install github.com/gohugoio/hugo@latest" || Handle-Error "Failed to install HUGO"

# Install & Configure Neovim with Plugins
Write-Status "Installing Neovim and Plugins..."
`Write-Log "Installing Neovim and Plugins..."
wsl -e bash -c "sudo apt install -y neovim" || Handle-Error "Failed to install Neovim"
wsl -e bash -c "mkdir -p ~/.config/nvim"
wsl -e bash -c "curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim" || Handle-Error "Failed to install vim-plug"
wsl -e bash -c "echo 'call plug#begin("~/.config/nvim/plugged")' >> ~/.config/nvim/init.vim"
wsl -e bash -c "echo 'Plug \"preservim/nerdtree\"' >> ~/.config/nvim/init.vim"
wsl -e bash -c "echo 'call plug#end()' >> ~/.config/nvim/init.vim"

# Configure Zsh & Oh My Zsh
Write-Status "Installing & Configuring Oh My Zsh..."
Write-Log "Installing & Configuring Oh My Zsh..."
wsl -e bash -c "sudo apt install -y zsh" || Handle-Error "Failed to install Zsh"
wsl -e bash -c "sh -c \"$(wget -O- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)\" || Handle-Error 'Failed to install Oh My Zsh'"
wsl -e bash -c "git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions"
wsl -e bash -c "echo 'source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh' >> ~/.zshrc"

# Configure Oh My Posh in PowerShell
Write-Status "Configuring Oh My Posh in PowerShell..."
Write-Log "Configuring Oh My Posh in PowerShell..."
oh-my-posh --init --shell pwsh --config "$env:POSH_THEMES_PATH/jandedobbeleer.omp.json" | Out-File -Encoding utf8 -Append "$PROFILE"

# Install & Configure PSReadLine and Terminal-Icons
Write-Status "Installing & Configuring PowerShell Enhancements..."
Write-Log "Installing & Configuring PowerShell Enhancements..."
Install-Module -Name PSReadLine -Force -SkipPublisherCheck || Handle-Error "Failed to install PSReadLine"
Install-Module -Name Terminal-Icons -Force -SkipPublisherCheck || Handle-Error "Failed to install Terminal-Icons"

# Configure Windows Terminal
Write-Status "Configuring Windows Terminal..."
Write-Log "Configuring Windows Terminal..."
wt -d .

# Configure File Explorer Tweaks
Write-Status "Configuring File Explorer..."
Write-Log "Configuring File Explorer..."
New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "HideFileExt" -Value 0 -PropertyType DWord -Force
New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "LaunchTo" -Value 1 -PropertyType DWord -Force
New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" -Name "ShowRecent" -Value 0 -PropertyType DWord -Force

# Restart System
Write-Status "Setup Completed! Restarting System..."
Write-Log "Setup Completed! Restarting System..."
Restart-Computer -Force -ErrorAction SilentlyContinue