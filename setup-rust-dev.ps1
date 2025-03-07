# Setup-Rust-Dev.ps1 - Script to set up Windows 11 for Rust-based Windows desktop app development

# Function to Print Status
function Write-Status {
    param ($Message)
    Write-Host "[+] $Message" -ForegroundColor Green
}

# Set Execution Policy
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

# Install Chocolatey
Write-Status "Installing Chocolatey for Package Management..."
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install Rust and related tools
Write-Status "Installing Rust and related tools..."
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://sh.rustup.rs') -ArgumentList "-y")

# Install essential development tools via Chocolatey
Write-Status "Installing essential development tools..."
$devTools = @("git", "vscode", "7zip", "curl", "wget", "cmake", "mingw", "python", "nodejs", "openjdk")
foreach ($tool in $devTools) {
    Write-Status "Installing $tool..."
    choco install $tool -y --force
}

# Install Visual Studio Build Tools
Write-Status "Installing Visual Studio Build Tools..."
choco install visualstudio2019buildtools -y --package-parameters "--add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --includeOptional"

# Install Rust GUI libraries
Write-Status "Installing Rust GUI libraries..."
cargo install cargo-edit
cargo install cargo-make
cargo install cargo-generate

# Install Tauri CLI for building Rust-based desktop apps
Write-Status "Installing Tauri CLI..."
cargo install tauri-cli

# Configure Git
Write-Status "Configuring Git..."
if ($env:GIT_USER_NAME) {
    git config --global user.name "$env:GIT_USER_NAME"
}
else {
    Write-Warning "GIT_USER_NAME environment variable is not set."
}

if ($env:GIT_USER_EMAIL) {
    git config --global user.email "$env:GIT_USER_EMAIL"
}
else {
    Write-Warning "GIT_USER_EMAIL environment variable is not set."
}

git config --global core.autocrlf input

# Configure VSCode with Rust extensions
Write-Status "Configuring VSCode with Rust extensions..."
code --install-extension rust-lang.rust
code --install-extension matklad.rust-analyzer
code --install-extension ms-vscode.cpptools

# Set up environment variables
Write-Status "Setting up environment variables..."
[System.Environment]::SetEnvironmentVariable('CARGO_HOME', "$env:USERPROFILE\.cargo", [System.EnvironmentVariableTarget]::User)
[System.Environment]::SetEnvironmentVariable('RUSTUP_HOME', "$env:USERPROFILE\.rustup", [System.EnvironmentVariableTarget]::User)
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")


# Restart System
Write-Status "Setup Completed! Restarting System..."
Restart-Computer -Force
