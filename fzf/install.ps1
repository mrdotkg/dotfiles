# Install fzf on Windows 11

Write-Output "Installing fzf..."
choco install fzf -y --force || { Write-Output "Failed to install fzf"; exit 1 }

# Configure fzf
Write-Output "Configuring fzf..."
$fzfConfigPath = "$env:USERPROFILE\.fzf"
if (-Not (Test-Path -Path $fzfConfigPath)) {
    New-Item -ItemType Directory -Path $fzfConfigPath
}

$fzfConfigFile = "$fzfConfigPath\fzf.bat"
$fzfConfigContent = @"
@echo off
set FZF_DEFAULT_COMMAND=rg --files --hidden --follow --glob '!.git/*'
"@

Set-Content -Path $fzfConfigFile -Value $fzfConfigContent

Write-Output "fzf installation and configuration completed successfully."
