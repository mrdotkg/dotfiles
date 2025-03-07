# Uninstall fonts on Windows 11

# Define the fonts directory
$fontsDir = "$PSScriptRoot"

# Get all font files in the directory
$fontFiles = Get-ChildItem -Path $fontsDir -Filter *.ttf

# Uninstall each font
foreach ($fontFile in $fontFiles) {
    $fontDest = "$env:SystemRoot\Fonts\$($fontFile.Name)"
    if (Test-Path $fontDest) {
        Remove-Item -Path $fontDest -Force
        $fontRegKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
        $fontName = $fontFile.BaseName
        Remove-ItemProperty -Path $fontRegKey -Name $fontName -ErrorAction SilentlyContinue
    }
}

Write-Output "Fonts uninstallation completed successfully."
