param(
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Release",
    [ValidateSet("win-arm64", "win-x64", "all")]
    [string]$Runtime = "all",
    [switch]$Run
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$appProject = Join-Path $root "QuickTextWindows\QuickTextWindows.csproj"
$setupProject = Join-Path $root "QuickTextSetup\QuickTextSetup.csproj"
$runtimes = if ($Runtime -eq "all") { @("win-arm64", "win-x64") } else { @($Runtime) }

if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) {
    throw "Das .NET 8 SDK fehlt. Installiere es von https://dotnet.microsoft.com/download/dotnet/8.0"
}

$version = (& dotnet --version)
if (-not $version.StartsWith("8.")) {
    Write-Warning "Erwartet wird .NET SDK 8.x, gefunden: $version"
}

foreach ($rid in $runtimes) {
    $artifact = Join-Path $root "QuickText-Windows-11-$rid"
    $appPayload = Join-Path $artifact "app"

    if (Test-Path $artifact) { Remove-Item $artifact -Recurse -Force }
    New-Item $appPayload -ItemType Directory -Force | Out-Null

    dotnet publish $appProject -c $Configuration -r $rid --self-contained true `
        -p:PublishSingleFile=true -p:DebugType=None -p:DebugSymbols=false `
        -o $appPayload

    dotnet publish $setupProject -c $Configuration -r $rid --self-contained true `
        -p:PublishSingleFile=true -p:DebugType=None -p:DebugSymbols=false `
        -o $artifact

    $zipPath = "$artifact.zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Compress-Archive -Path $artifact -DestinationPath $zipPath

    Write-Host "Fertig: $artifact\Quick Text Setup.exe"
    Write-Host "App-Payload: $artifact\app\Quick Text.exe"
    Write-Host "Transfer-Paket: $zipPath"
}

if ($Run) {
    $firstRuntime = $runtimes[0]
    Start-Process (Join-Path $root "QuickText-Windows-11-$firstRuntime\Quick Text Setup.exe")
}
