# Install and configure Starship on Windows 11

# Define the URL for the latest Starship release
$starshipUrl = "https://starship.rs/install.sh"

# Download and install Starship
Write-Output "Installing Starship..."
Invoke-Expression ((New-Object System.Net.WebClient).DownloadString($starshipUrl))

# Configure Starship
Write-Output "Configuring Starship..."
$starshipConfigPath = "$env:USERPROFILE\.config\starship"
if (-Not (Test-Path -Path $starshipConfigPath)) {
    New-Item -ItemType Directory -Path $starshipConfigPath
}

# Create a basic Starship configuration file
$configFile = "$starshipConfigPath\starship.toml"
$configContent = @"
# Starship Configuration
add_newline = false

[character]
success_symbol = "[➜](bold green)"
error_symbol = "[✗](bold red)"
"@

Set-Content -Path $configFile -Value $configContent

Write-Output "Starship installation and configuration completed successfully."
