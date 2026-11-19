param(
  [string]$InstallDir = "$env:LOCALAPPDATA\ClipboardTyper",
  [switch]$KeepConfig
)

$ErrorActionPreference = "Continue"

Get-Process -Name "ClipboardTyper" -ErrorAction SilentlyContinue | ForEach-Object {
  Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
}

$startMenu = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Portapapeles typer.lnk"
$desktop = Join-Path ([Environment]::GetFolderPath('Desktop')) "Portapapeles typer.lnk"
foreach ($link in @($startMenu, $desktop)) {
  if (Test-Path $link) { Remove-Item $link -Force }
}

$unreg = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ClipboardTyper'
if (Test-Path $unreg) { Remove-Item $unreg -Recurse -Force }

if (Test-Path $InstallDir) { Remove-Item $InstallDir -Recurse -Force }

if (-not $KeepConfig) {
  $config = Join-Path $env:APPDATA "ClipboardTyper"
  if (Test-Path $config) { Remove-Item $config -Recurse -Force }
  $local = Join-Path $env:LOCALAPPDATA "ClipboardTyper"
  if (Test-Path $local) { Remove-Item $local -Recurse -Force }
}

Write-Host "Portapapeles typer desinstalado."
