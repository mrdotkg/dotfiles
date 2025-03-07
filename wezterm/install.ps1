# Install and configure WezTerm on Windows 11

# Define the URL for the latest WezTerm release
$weztermUrl = "https://github.com/wez/wezterm/releases/latest/download/WezTerm-windows.zip"

# Define the installation path
$installPath = "$env:LOCALAPPDATA\WezTerm"

# Create the installation directory if it doesn't exist
if (-Not (Test-Path -Path $installPath)) {
    New-Item -ItemType Directory -Path $installPath
}

# Download the WezTerm zip file
$zipFilePath = "$installPath\WezTerm.zip"
Invoke-WebRequest -Uri $weztermUrl -OutFile $zipFilePath

# Extract the zip file
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($zipFilePath, $installPath)

# Remove the zip file after extraction
Remove-Item -Path $zipFilePath

# Add WezTerm to the PATH environment variable
$envPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::User)
if (-Not $envPath.Contains($installPath)) {
    [System.Environment]::SetEnvironmentVariable("Path", "$envPath;$installPath", [System.EnvironmentVariableTarget]::User)
}

# Create a basic WezTerm configuration file
$configPath = "$env:USERPROFILE\.wezterm"
if (-Not (Test-Path -Path $configPath)) {
    New-Item -ItemType Directory -Path $configPath
}

$configFile = "$configPath\wezterm.lua"
$configContent = @"
-- WezTerm Configuration
return {
  font_size = 12.0,
  color_scheme = "Builtin Solarized Dark",
  window_padding = {
    left = 5,
    right = 5,
    top = 5,
    bottom = 5,
  },
}
"@

Set-Content -Path $configFile -Value $configContent

Write-Output "WezTerm installation and configuration completed successfully."
