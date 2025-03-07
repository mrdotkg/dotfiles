# Install Windows Terminal on Windows 11

# Define the URL for the latest Windows Terminal release
$terminalUrl = "https://github.com/microsoft/terminal/releases/latest/download/Microsoft.WindowsTerminal_8wekyb3d8bbwe.msixbundle"

# Define the installation path
$installPath = "$env:LOCALAPPDATA\Microsoft\WindowsTerminal"

# Create the installation directory if it doesn't exist
if (-Not (Test-Path -Path $installPath)) {
    New-Item -ItemType Directory -Path $installPath
}

# Download the Windows Terminal msixbundle file
$msixFilePath = "$installPath\WindowsTerminal.msixbundle"
Invoke-WebRequest -Uri $terminalUrl -OutFile $msixFilePath

# Install the msixbundle
Add-AppxPackage -Path $msixFilePath

# Remove the msixbundle file after installation
Remove-Item -Path $msixFilePath

# Create a basic Windows Terminal configuration file
$configPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"
if (-Not (Test-Path -Path $configPath)) {
    New-Item -ItemType Directory -Path $configPath
}

$configFile = "$configPath\settings.json"
$configContent = @"
{
    "profiles": {
        "defaults": {
            "fontFace": "Consolas",
            "fontSize": 12
        },
        "list": [
            {
                "guid": "{0caa0dad-35be-5f56-a8ff-afceeeaa6101}",
                "name": "Windows PowerShell",
                "commandline": "powershell.exe",
                "hidden": false
            }
        ]
    },
    "schemes": [
        {
            "name": "Campbell",
            "background": "#0C0C0C",
            "foreground": "#CCCCCC",
            "black": "#0C0C0C",
            "blue": "#0037DA",
            "cyan": "#3A96DD",
            "green": "#13A10E",
            "purple": "#881798",
            "red": "#C50F1F",
            "white": "#CCCCCC",
            "yellow": "#C19C00",
            "brightBlack": "#767676",
            "brightBlue": "#3B78FF",
            "brightCyan": "#61D6D6",
            "brightGreen": "#16C60C",
            "brightPurple": "#B4009E",
            "brightRed": "#E74856",
            "brightWhite": "#F2F2F2",
            "brightYellow": "#F9F1A5"
        }
    ]
}
"@

Set-Content -Path $configFile -Value $configContent

Write-Output "Windows Terminal installation and configuration completed successfully."
