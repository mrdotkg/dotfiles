# Uninstall Python from Windows 11

Write-Output "Uninstalling Python..."
$pythonPath = "C:\Python39"
if (Test-Path $pythonPath) {
    Remove-Item -Recurse -Force $pythonPath
    Write-Output "Python uninstalled successfully."
}
else {
    Write-Output "Python is not installed."
}
