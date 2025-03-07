# Install Vim on Windows 11

# Define the URL for the latest Vim release
$vimUrl = "https://github.com/vim/vim-win32-installer/releases/latest/download/gvim_8.2.2825_x64.zip"

# Define the installation path
$installPath = "$env:LOCALAPPDATA\Vim"

# Create the installation directory if it doesn't exist
if (-Not (Test-Path -Path $installPath)) {
    New-Item -ItemType Directory -Path $installPath
}

# Download the Vim zip file
$zipFilePath = "$installPath\Vim.zip"
Invoke-WebRequest -Uri $vimUrl -OutFile $zipFilePath

# Extract the zip file
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($zipFilePath, $installPath)

# Remove the zip file after extraction
Remove-Item -Path $zipFilePath

# Add Vim to the PATH environment variable
$envPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
if (-Not $envPath.Contains($installPath)) {
    [System.Environment]::SetEnvironmentVariable("Path", "$envPath;$installPath", [System.EnvironmentVariableTarget]::User)
}

# Create a basic Vim configuration file
$configPath = "$env:USERPROFILE\vimfiles"
if (-Not (Test-Path -Path $configPath)) {
    New-Item -ItemType Directory -Path $configPath
}

$configFile = "$configPath\_vimrc"
$configContent = @"
" Vim Configuration
set number
syntax on
set tabstop=4
set shiftwidth=4
set expandtab
"@

Set-Content -Path $configFile -Value $configContent

Write-Output "Vim installation and configuration completed successfully."
