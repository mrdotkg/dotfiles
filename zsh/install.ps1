# Install Zsh on Windows 11

# Define the URL for the latest Zsh release
$zshUrl = "https://github.com/romkatv/powerlevel10k/releases/latest/download/powerlevel10k.zip"

# Define the installation path
$installPath = "$env:LOCALAPPDATA\Zsh"

# Create the installation directory if it doesn't exist
if (-Not (Test-Path -Path $installPath)) {
    New-Item -ItemType Directory -Path $installPath
}

# Download the Zsh zip file
$zipFilePath = "$installPath\Zsh.zip"
Invoke-WebRequest -Uri $zshUrl -OutFile $zipFilePath

# Extract the zip file
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($zipFilePath, $installPath)

# Remove the zip file after extraction
Remove-Item -Path $zipFilePath

# Add Zsh to the PATH environment variable
$envPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
if (-Not $envPath.Contains($installPath)) {
    [System.Environment]::SetEnvironmentVariable("Path", "$envPath;$installPath", [System.EnvironmentVariableTarget]::User)
}

# Create a basic Zsh configuration file
$configPath = "$env:USERPROFILE\.zsh"
if (-Not (Test-Path -Path $configPath)) {
    New-Item -ItemType Directory -Path $configPath
}

$configFile = "$configPath\.zshrc"
$configContent = @"
# Zsh Configuration
source $installPath/powerlevel10k/powerlevel10k.zsh-theme
"@

Set-Content -Path $configFile -Value $configContent

Write-Output "Zsh installation and configuration completed successfully."
