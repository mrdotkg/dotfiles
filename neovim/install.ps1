# Install Neovim on Windows 11

# Define the URL for the latest Neovim release
$neovimUrl = "https://github.com/neovim/neovim/releases/latest/download/nvim-win64.zip"

# Define the installation path
$installPath = "$env:LOCALAPPDATA\Neovim"

# Create the installation directory if it doesn't exist
if (-Not (Test-Path -Path $installPath)) {
    New-Item -ItemType Directory -Path $installPath
}

# Download the Neovim zip file
$zipFilePath = "$installPath\nvim-win64.zip"
Invoke-WebRequest -Uri $neovimUrl -OutFile $zipFilePath

# Extract the zip file
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($zipFilePath, $installPath)

# Remove the zip file after extraction
Remove-Item -Path $zipFilePath

# Add Neovim to the PATH environment variable
$envPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
if (-Not $envPath.Contains($installPath)) {
    [System.Environment]::SetEnvironmentVariable("Path", "$envPath;$installPath", [System.EnvironmentVariableTarget]::User)
}

# Create a basic Neovim configuration file
$configPath = "$env:LOCALAPPDATA\nvim"
if (-Not (Test-Path -Path $configPath)) {
    New-Item -ItemType Directory -Path $configPath
}

$configFile = "$configPath\init.vim"
$configContent = @"
" Neovim Configuration
set number
syntax on
set tabstop=4
set shiftwidth=4
set expandtab
"@

Set-Content -Path $configFile -Value $configContent

Write-Output "Neovim installation and configuration completed successfully."
