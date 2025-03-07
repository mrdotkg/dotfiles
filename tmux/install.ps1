# Install Tmux on Windows 11

# Define the URL for the latest Tmux release
$tmuxUrl = "https://github.com/gpakosz/.tmux/releases/latest/download/tmux.zip"

# Define the installation path
$installPath = "$env:LOCALAPPDATA\Tmux"

# Create the installation directory if it doesn't exist
if (-Not (Test-Path -Path $installPath)) {
    New-Item -ItemType Directory -Path $installPath
}

# Download the Tmux zip file
$zipFilePath = "$installPath\Tmux.zip"
Invoke-WebRequest -Uri $tmuxUrl -OutFile $zipFilePath

# Extract the zip file
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($zipFilePath, $installPath)

# Remove the zip file after extraction
Remove-Item -Path $zipFilePath

# Add Tmux to the PATH environment variable
$envPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
if (-Not $envPath.Contains($installPath)) {
    [System.Environment]::SetEnvironmentVariable("Path", "$envPath;$installPath", [System.EnvironmentVariableTarget]::User)
}

# Create a basic Tmux configuration file
$configPath = "$env:USERPROFILE\.tmux"
if (-Not (Test-Path -Path $configPath)) {
    New-Item -ItemType Directory -Path $configPath
}

$configFile = "$configPath\tmux.conf"
$configContent = @"
# Tmux Configuration
set -g mouse on
setw -g mode-keys vi
bind r source-file ~/.tmux.conf \; display-message "Config reloaded!"
"@

Set-Content -Path $configFile -Value $configContent

Write-Output "Tmux installation and configuration completed successfully."
