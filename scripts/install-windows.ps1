param(
  [string]$Ahk2Exe = "",
  [string]$InstallDir = "$env:LOCALAPPDATA\ClipboardTyper",
  [string]$NugetVersion = "1.0.4314.35"
)

$ErrorActionPreference = "Stop"
$Project = Split-Path -Parent $PSScriptRoot
$Src = Join-Path $Project "src"

# 1. Localizar Ahk2Exe (viene con AutoHotkey v2).
if (-not $Ahk2Exe) {
  $candidates = @(
    "$env:ProgramFiles\AutoHotkey\v2\Compiler\Ahk2Exe.exe",
    "${env:ProgramFiles(x86)}\AutoHotkey\v2\Compiler\Ahk2Exe.exe"
  )
  $Ahk2Exe = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

# 2. WebView2Loader.dll x64 desde el paquete NuGet oficial.
$dll = Join-Path $Project "build\WebView2Loader.dll"
if (-not (Test-Path $dll)) {
  $url = "https://api.nuget.org/v3-flatcontainer/microsoft.web.webview2/$NugetVersion/microsoft.web.webview2.$NugetVersion.nupkg"
  $nupkg = Join-Path $env:TEMP "webview2.nupkg"
  $expand = Join-Path $env:TEMP "webview2-pkg"
  Write-Host "Descargando WebView2Loader.dll..."
  Invoke-WebRequest -Uri $url -OutFile $nupkg -TimeoutSec 90
  if (Test-Path $expand) { Remove-Item $expand -Recurse -Force }
  Expand-Archive -Path $nupkg -DestinationPath $expand -Force
  $dll = Join-Path $expand "build\native\x64\WebView2Loader.dll"
}

# 3. Compilar con Ahk2Exe; si no está, dejar el script como placeholder.
$exe = Join-Path $InstallDir "ClipboardTyper.exe"
if ($Ahk2Exe -and (Test-Path $Ahk2Exe)) {
  Write-Host "Compilando con $Ahk2Exe ..."
  & $Ahk2Exe /in (Join-Path $Src "ClipboardTyper.ahk") /out $exe
} else {
  Copy-Item (Join-Path $Src "ClipboardTyper.ahk") $exe -Force
  Write-Warning "No se encontro Ahk2Exe: Instala AutoHotkey v2 (64-bit) para poder ejecutar el .exe."
}

# 4. Recursos que el host copia/usa en tiempo de ejecución.
Copy-Item (Join-Path $Src "ui.html") $InstallDir -Force
Copy-Item (Join-Path $Src "bridge.testable.js") $InstallDir -Force
Copy-Item $dll (Join-Path $InstallDir "WebView2Loader.dll") -Force

Write-Host "Instalado en: $InstallDir"
Write-Host "Ejecuta: $exe"
Write-Host "Comprueba con: & '$exe' --self-test ; Get-Content '$InstallDir\selftest.log'"
