param(
  [string]$InstallDir = "$env:LOCALAPPDATA\ClipboardTyper",
  [string]$Ahk2Exe = "",
  [string]$NugetVersion = "1.0.4314.35",
  [switch]$SkipDependencies,
  [switch]$NoDesktopShortcut,
  [switch]$NoAutoStart
)

$ErrorActionPreference = "Stop"
$Project = Split-Path -Parent $PSScriptRoot
$Src = Join-Path $Project "src"
$Log = Join-Path $env:TEMP "clipboard-typer-install.log"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
"" | Set-Content $Log
function Say($m) { Write-Host $m; Add-Content $Log $m }

function Get-Winget {
  return (Get-Command winget -ErrorAction SilentlyContinue) -ne $null
}

function Ensure-WebView2 {
  $guid = '{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}'
  $keys = @(
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\$guid",
    "HKLM:\SOFTWARE\Microsoft\EdgeUpdate\Clients\$guid",
    "HKCU:\SOFTWARE\Microsoft\EdgeUpdate\Clients\$guid"
  )
  if ($keys | Where-Object { Test-Path $_ } | Select-Object -First 1) {
    Say "WebView2 Runtime: ya instalado"
    return
  }
  Say "WebView2 Runtime: instalando..."
  if (Get-Winget) {
    winget install --id Microsoft.WebView2Runtime --exact --silent --disable-interactivity --accept-package-agreements --accept-source-agreements | Out-Null
  }
  $still = $keys | Where-Object { Test-Path $_ } | Select-Object -First 1
  if (-not $still) {
    try {
      $boot = Join-Path $env:TEMP "MicrosoftEdgeWebview2Setup.exe"
      Invoke-WebRequest -Uri 'https://go.microsoft.com/fwlink/p/?LinkId=2124703' -OutFile $boot -TimeoutSec 120
      Start-Process -FilePath $boot -ArgumentList '/silent /install' -Wait
    } catch {
      Say "No se pudo instalar WebView2: $_"
    }
  }
  Say "WebView2 Runtime: instalado"
}

function Find-Ahk2Exe {
  $paths = @(
    "$env:ProgramFiles\AutoHotkey\v2\Compiler\Ahk2Exe.exe",
    "${env:ProgramFiles(x86)}\AutoHotkey\v2\Compiler\Ahk2Exe.exe",
    "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\Compiler\Ahk2Exe.exe"
  )
  return $paths | Where-Object { Test-Path $_ } | Select-Object -First 1
}

function Ensure-AutoHotkey {
  $found = Find-Ahk2Exe
  if ($found) { Say "AutoHotkey v2: ya instalado ($found)"; return $found }
  Say "AutoHotkey v2: instalando..."
  if (Get-Winget) {
    winget install --id AutoHotkey.AutoHotkey --exact --silent --disable-interactivity --accept-package-agreements --accept-source-agreements | Out-Null
  }
  $found = Find-Ahk2Exe
  if (-not $found) {
    try {
      $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/AutoHotkey/AutoHotkey/releases/latest' -Headers @{ 'User-Agent' = 'clipboard-typer-installer' }
      $asset = $rel.assets | Where-Object { $_.name -like '*setup.exe' } | Select-Object -First 1
      $setup = Join-Path $env:TEMP $asset.name
      Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $setup -TimeoutSec 180
      Start-Process -FilePath $setup -ArgumentList '/SILENT' -Wait
      $found = Find-Ahk2Exe
    } catch {
      Say "No se pudo descargar AutoHotkey: $_"
    }
  }
  if ($found) { Say "AutoHotkey v2: instalado ($found)"; return $found }
  Say "AutoHotkey v2: NO se pudo instalar; se usara el .ahk como fuente"
  return ""
}

if (-not $SkipDependencies) {
  Ensure-WebView2
  $Ahk2Exe = Ensure-AutoHotkey
}

# WebView2Loader.dll x64 desde el paquete NuGet oficial.
$dll = Join-Path $Project "build\WebView2Loader.dll"
if (-not (Test-Path $dll)) {
  $url = "https://api.nuget.org/v3-flatcontainer/microsoft.web.webview2/$NugetVersion/microsoft.web.webview2.$NugetVersion.nupkg"
  $nupkg = Join-Path $env:TEMP "webview2.nupkg"
  $expand = Join-Path $env:TEMP "webview2-pkg"
  Say "Descargando WebView2Loader.dll..."
  Invoke-WebRequest -Uri $url -OutFile $nupkg -TimeoutSec 90
  if (Test-Path $expand) { Remove-Item $expand -Recurse -Force }
  Expand-Archive -Path $nupkg -DestinationPath $expand -Force
  $dll = Join-Path $expand "build\native\x64\WebView2Loader.dll"
}

# Compilacion (o fallback a fuente si no hay Ahk2Exe).
$exe = Join-Path $InstallDir "ClipboardTyper.exe"
$compiled = $false
if ($Ahk2Exe -and (Test-Path $Ahk2Exe)) {
  Say "Compilando con Ahk2Exe..."
  & $Ahk2Exe /in (Join-Path $Src "ClipboardTyper.ahk") /out $exe
  $compiled = ($LASTEXITCODE -eq 0) -and (Test-Path $exe)
}
if (-not $compiled) {
  Copy-Item (Join-Path $Src "ClipboardTyper.ahk") $exe -Force
  Write-Warning "Sin Ahk2Exe: el .exe es la fuente .ahk. Instala AutoHotkey v2 o vuelve a ejecutar el instalador."
  Say "ADVERTENCIA: exe es placeholder"
}

Copy-Item (Join-Path $Src "ui.html") $InstallDir -Force
Copy-Item (Join-Path $Src "bridge.testable.js") $InstallDir -Force
Copy-Item $dll (Join-Path $InstallDir "WebView2Loader.dll") -Force
Copy-Item (Join-Path $PSScriptRoot "uninstall-windows.ps1") $InstallDir -Force

# Accesos directos.
$startMenu = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
New-Item -ItemType Directory -Force -Path $startMenu | Out-Null
$lnk = Join-Path $startMenu "Portapapeles typer.lnk"
$wsh = New-Object -ComObject WScript.Shell
$sc = $wsh.CreateShortcut($lnk)
if ($compiled) { $sc.TargetPath = $exe; $sc.Arguments = "" }
else { $sc.TargetPath = "powershell.exe"; $sc.Arguments = "-ExecutionPolicy Bypass -File `"$exe`"" }
$sc.WorkingDirectory = $InstallDir
$sc.Description = "Historial del portapapeles con escritura letra por letra"
$sc.Save()
if (-not $NoDesktopShortcut) {
  $desk = $wsh.CreateShortcut((Join-Path ([Environment]::GetFolderPath('Desktop')) "Portapapeles typer.lnk"))
  $desk.TargetPath = $sc.TargetPath
  $desk.Arguments = $sc.Arguments
  $desk.WorkingDirectory = $InstallDir
  $desk.Save()
}

# Registro de desinstalacion (por usuario, sin admin).
$unreg = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ClipboardTyper'
New-Item -Path $unreg -Force | Out-Null
Set-ItemProperty $unreg DisplayName "Portapapeles typer"
Set-ItemProperty $unreg DisplayVersion "1.0.0"
Set-ItemProperty $unreg Publisher "Arath"
Set-ItemProperty $unreg InstallLocation $InstallDir
Set-ItemProperty $unreg UninstallString "powershell.exe -ExecutionPolicy Bypass -File `"$(Join-Path $InstallDir 'uninstall-windows.ps1')`""

Say "Instalado en: $InstallDir"
Say "Log: $Log"
if ($compiled) {
  Say "Autotest:"
  & $exe --self-test
  if (Test-Path (Join-Path $InstallDir "selftest.log")) {
    Get-Content (Join-Path $InstallDir "selftest.log") | ForEach-Object { Say $_ }
  }
}
