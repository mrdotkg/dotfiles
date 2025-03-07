# Install and configure SSH on Windows 11

# Install OpenSSH Client
Write-Output "Installing OpenSSH Client..."
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0

# Configure SSH
Write-Output "Configuring SSH..."
$sshConfigPath = "$env:USERPROFILE\.ssh"
if (-Not (Test-Path -Path $sshConfigPath)) {
    New-Item -ItemType Directory -Path $sshConfigPath
}

# Create a basic SSH configuration file
$configFile = "$sshConfigPath\config"
$configContent = @"
# SSH Configuration
Host *
    ForwardAgent yes
    ForwardX11 yes
    ServerAliveInterval 60
"@

Set-Content -Path $configFile -Value $configContent

Write-Output "SSH installation and configuration completed successfully."
