# Install Alacritty on Windows 11

# Define the URL for the latest Alacritty release
$alacrittyUrl = "https://github.com/alacritty/alacritty/releases/latest/download/Alacritty.zip"

# Define the installation path
$installPath = "$env:LOCALAPPDATA\Alacritty"

# Create the installation directory if it doesn't exist
if (-Not (Test-Path -Path $installPath)) {
    New-Item -ItemType Directory -Path $installPath
}

# Download the Alacritty zip file
$zipFilePath = "$installPath\Alacritty.zip"
Invoke-WebRequest -Uri $alacrittyUrl -OutFile $zipFilePath

# Extract the zip file
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($zipFilePath, $installPath)

# Remove the zip file after extraction
Remove-Item -Path $zipFilePath

# Add Alacritty to the PATH environment variable
$envPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
if (-Not $envPath.Contains($installPath)) {
    [System.Environment]::SetEnvironmentVariable("Path", "$envPath;$installPath", [System.EnvironmentVariableTarget]::User)
}

# Create a basic Alacritty configuration file
$configPath = "$env:APPDATA\alacritty"
if (-Not (Test-Path -Path $configPath)) {
    New-Item -ItemType Directory -Path $configPath
}

$configFile = "$configPath\alacritty.yml"
$configContent = @"
# Alacritty Configuration
window:
  dimensions:
    columns: 80
    lines: 24
  padding:
    x: 5
    y: 5
  decorations: full
font:
  normal:
    family: Consolas
    style: Regular
  size: 12.0
colors:
  primary:
    background: '0x1e1e1e'
    foreground: '0xc0c0c0'
"@

Set-Content -Path $configFile -Value $configContent

Write-Output "Alacritty installation and configuration completed successfully."