# Install Git on Windows 11

Write-Output "Installing Git..."
choco install git -y --force || { Write-Output "Failed to install Git"; exit 1 }

# Configure Git
Write-Output "Configuring Git..."
if ($env:GIT_USER_NAME) {
    git config --global user.name "$env:GIT_USER_NAME"
}
else {
    Write-Output "GIT_USER_NAME environment variable is not set."
}

if ($env:GIT_USER_EMAIL) {
    git config --global user.email "$env:GIT_USER_EMAIL"
}
else {
    Write-Output "GIT_USER_EMAIL environment variable is not set."
}

git config --global core.autocrlf input
git config --global credential.helper manager-core

Write-Output "Git installation and configuration completed successfully."
