# New Windows OS Setup Automation Script
Set-Variable -Name GlobalAppList -Scope Global -Value @(
    "AltSnap.AltSnap",
    "Valve.Steam",
    "Microsoft.PowerShell",
    "Neovim.Neovim",
    "Git.Git",
    "Microsoft.VisualStudioCode",
    "WezTerm.WezTerm",
    "Notepads.NotepadsApp",
    "Discord.Discord",
    "Ditto.Ditto",
    "Nvidia.GeForceExperience",
    "AquaSnap.AquaSnap",
    "Whatsapp.Whatsapp",
    "GlazeWM.GlazeWM"
)
function Install-Apps {
    param(
        [string[]]$AppList = $Global:GlobalAppList
    )
    foreach ($app in $AppList) {
        winget install --id $app -e --accept-source-agreements --accept-package-agreements
    }
}
function Set-DisplayScaling {
    # Set display scaling to 100% (manual step for zoom, display, HDR, FPS)
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
}

function Set-DarkTheme {
    # Set dark theme
    New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "AppsUseLightTheme" -PropertyType DWord -Value 0 -Force
    New-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -Name "SystemUsesLightTheme" -PropertyType DWord -Value 0 -Force
}

function Disable-ClearType {
    # Disable ClearType
    Set-ItemProperty -Path "HKCU:\Control Panel\Desktop" -Name "FontSmoothing" -Value 2
}

function Disable-StartupApps {
    # Disable all startup apps
    Get-CimInstance -ClassName Win32_StartupCommand | ForEach-Object { Remove-ItemProperty -Path $_.Location -Name $_.Name -ErrorAction SilentlyContinue }
}

function Enable-OpenSSH {
    # Enable OpenSSH Server and Client
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0

    Start-Service sshd
    Set-Service -Name sshd -StartupType 'Automatic'

    # Allow SSH through Windows Firewall
    if (-not (Get-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -DisplayName "OpenSSH Server (sshd)" `
            -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
    }

    # Set latest PowerShell as default SSH shell
    $pwshPath = (Get-Command pwsh.exe).Source
    $sshdConfig = 'C:\ProgramData\ssh\sshd_config'
    if (Test-Path $sshdConfig) {
        $config = Get-Content $sshdConfig
        if ($config -notmatch '^Subsystem\s+sftp\s+') {
            Add-Content $sshdConfig "`nSubsystem   sftp    sftp-server.exe"
        }
        if ($config -notmatch '^ForceCommand\s+') {
            Add-Content $sshdConfig "`nForceCommand $pwshPath"
        }
    }
    Restart-Service sshd
}

function Set-TaskbarSettings {
    # Hide Search Menu
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" -Name "SearchboxTaskbarMode" -Value 0

    # Disable Widgets, Weather (Windows 11)
    reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /v TaskbarDa /t REG_DWORD /d 0 /f
}

function Remove-BloatApps {
    # Remove bloat apps
    Get-AppxPackage *xbox* | Remove-AppxPackage
    Get-AppxPackage *bing* | Remove-AppxPackage
    Get-AppxPackage *solitaire* | Remove-AppxPackage
    Get-AppxPackage *zune* | Remove-AppxPackage
}

function Setup-Github {
    param(
        [string]$UserName = "mrdot",
        [string]$UserEmail = "grv.rkg@gmail.com"
    )
    git config --global user.name $UserName
    git config --global user.email $UserEmail
    ssh-keygen -t ed25519 -C $UserEmail -f "$env:USERPROFILE\.ssh\id_ed25519" -N ""
}
