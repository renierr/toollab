param(
  [switch]$Uninstall,
  [switch]$Silent
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$AppName = 'ToolLab'
$ExeName = 'tool_lab.exe'
$Company = 'de.renier'
$InstallDir = Join-Path $env:LOCALAPPDATA $AppName
$StartMenuDir = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
$ShortcutPath = Join-Path $StartMenuDir "$AppName.lnk"
$ScriptPath = $PSCommandPath
$SourceDir = Join-Path $PSScriptRoot 'dist\ToolLab-windows'
$Version = '0.0.0'

if ($Version -eq '0.0.0' -and (Test-Path (Join-Path $PSScriptRoot 'pubspec.yaml'))) {
  $versionLine = Get-Content (Join-Path $PSScriptRoot 'pubspec.yaml') | Select-String -Pattern '^version:\s*'
  if ($versionLine) {
    $Version = ($versionLine.Line -replace '^version:\s*', '').Trim()
  }
}


$FileTypes = @(
  @{ Extension = '.pdf';     ProgId = "$AppName.pdf";     Description = 'PDF Document';     MimeType = 'application/pdf' }
  @{ Extension = '.md';      ProgId = "$AppName.md";      Description = 'Markdown Document'; MimeType = 'text/markdown' }
  @{ Extension = '.markdown'; ProgId = "$AppName.markdown"; Description = 'Markdown Document'; MimeType = 'text/markdown' }
  @{ Extension = '.txt';     ProgId = "$AppName.txt";     Description = 'Text Document';     MimeType = 'text/plain' }
  @{ Extension = '.png';      ProgId = "$AppName.png";      Description = 'PNG Image';         MimeType = 'image/png' }
  @{ Extension = '.jpg';      ProgId = "$AppName.jpg";      Description = 'JPEG Image';        MimeType = 'image/jpeg' }
  @{ Extension = '.jpeg';     ProgId = "$AppName.jpeg";     Description = 'JPEG Image';        MimeType = 'image/jpeg' }
  @{ Extension = '.webp';     ProgId = "$AppName.webp";     Description = 'WebP Image';        MimeType = 'image/webp' }
  @{ Extension = '.bmp';      ProgId = "$AppName.bmp";      Description = 'BMP Image';         MimeType = 'image/bmp' }
  @{ Extension = '.gif';      ProgId = "$AppName.gif";      Description = 'GIF Image';         MimeType = 'image/gif' }
  @{ Extension = '.mod';     ProgId = "$AppName.mod";     Description = 'Tracker Module';    MimeType = 'audio/x-mod' }
  @{ Extension = '.xm';      ProgId = "$AppName.xm";      Description = 'Tracker Module';    MimeType = 'audio/x-xm' }
  @{ Extension = '.it';      ProgId = "$AppName.it";      Description = 'Tracker Module';    MimeType = 'audio/x-it' }
  @{ Extension = '.s3m';     ProgId = "$AppName.s3m";     Description = 'Tracker Module';    MimeType = 'audio/x-s3m' }
)

function Write-Info  { Write-Host "INFO: $($args[0])" -ForegroundColor Cyan }
function Write-Ok    { Write-Host "OK:   $($args[0])" -ForegroundColor Green }
function Write-Warn  { Write-Host "WARN: $($args[0])" -ForegroundColor Yellow }
function Write-Err   { Write-Host "ERR:  $($args[0])" -ForegroundColor Red }

function Stop-App {
  $proc = Get-Process -Name "$([System.IO.Path]::GetFileNameWithoutExtension($ExeName))" -ErrorAction SilentlyContinue
  if ($proc) {
    Write-Info "Stopping running $AppName..."
    $proc | Stop-Process -Force
    Start-Sleep -Seconds 1
  }
}

function Install-Files {
  Stop-App
  if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
  }
  Write-Info "Copying files to $InstallDir..."
  robocopy $SourceDir $InstallDir /MIR /NJH /NJS /NP /NDL /NC /NS
  if ($LASTEXITCODE -ge 8) {
    Write-Err "robocopy failed with exit code $LASTEXITCODE"
    exit 1
  }
  Write-Ok "Files copied ($((Get-ChildItem $InstallDir -Recurse -File).Count) files)"
}

function Register-FileAssociations {
  $exePath = Join-Path $InstallDir $ExeName
  foreach ($ft in $FileTypes) {
    $ext = $ft.Extension
    $progId = $ft.ProgId
    $desc = $ft.Description
    # Extension -> ProgId
    $extKey = "HKCU:\Software\Classes\$ext"
    New-Item -Path $extKey -Force | Out-Null
    Set-ItemProperty -Path $extKey -Name '(default)' -Value $progId -Force
    # PerceivedType
    if ($ext -eq '.txt') {
      Set-ItemProperty -Path $extKey -Name 'PerceivedType' -Value 'text' -Force
    }
    # ProgId
    $progKey = "HKCU:\Software\Classes\$progId"
    New-Item -Path $progKey -Force | Out-Null
    Set-ItemProperty -Path $progKey -Name '(default)' -Value "$desc" -Force
    # FriendlyAppName
    $appKey = "$progKey\Application"
    New-Item -Path $appKey -Force | Out-Null
    Set-ItemProperty -Path $appKey -Name 'FriendlyAppName' -Value $AppName -Force
    Set-ItemProperty -Path $appKey -Name 'ApplicationName' -Value $AppName -Force
    Set-ItemProperty -Path $appKey -Name 'ApplicationIcon' -Value "$exePath,0" -Force
    # DefaultIcon
    $iconKey = "$progKey\DefaultIcon"
    New-Item -Path $iconKey -Force | Out-Null
    Set-ItemProperty -Path $iconKey -Name '(default)' -Value "$exePath,0" -Force
    # shell\open\command
    $cmdKey = "$progKey\shell\open\command"
    New-Item -Path $cmdKey -Force | Out-Null
    Set-ItemProperty -Path $cmdKey -Name '(default)' -Value "`"$exePath`" `"%1`"" -Force
    Write-Ok "Registered $ext → $progId"
  }
}

function Register-OpenWithList {
  foreach ($ft in $FileTypes) {
    $ext = $ft.Extension
    $progId = $ft.ProgId
    $choiceKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext\OpenWithProgids"
    New-Item -Path $choiceKey -Force | Out-Null
    $existing = Get-ItemProperty -Path $choiceKey -Name $progId -ErrorAction SilentlyContinue
    if ($null -eq $existing) {
      New-ItemProperty -Path $choiceKey -Name $progId -PropertyType 'None' -Value ([byte[]]@()) -Force | Out-Null
    }
    New-Item -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext\OpenWithList" -Force | Out-Null
  }
}

function Register-UninstallEntry {
  $uninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$AppName"
  New-Item -Path $uninstallKey -Force | Out-Null
  $exePath = Join-Path $InstallDir $ExeName
  
  # Copy installer script to installation directory so it can be invoked for uninstallation
  $targetScript = Join-Path $InstallDir 'install.ps1'
  Copy-Item -Path $ScriptPath -Destination $targetScript -Force
  
  Set-ItemProperty -Path $uninstallKey -Name 'DisplayName' -Value $AppName
  Set-ItemProperty -Path $uninstallKey -Name 'DisplayVersion' -Value $Version
  Set-ItemProperty -Path $uninstallKey -Name 'DisplayIcon' -Value $exePath
  Set-ItemProperty -Path $uninstallKey -Name 'Publisher' -Value $Company
  Set-ItemProperty -Path $uninstallKey -Name 'InstallLocation' -Value $InstallDir
  
  # Copy to temp, execute silently, and then clean up temp script to avoid locking files
  $uninstallCmd = "powershell -NoProfile -ExecutionPolicy Bypass -Command `"Copy-Item -Path '$targetScript' -Destination '$env:TEMP\uninstall_tool_lab.ps1' -Force; & '$env:TEMP\uninstall_tool_lab.ps1' -Uninstall -Silent; Remove-Item -Path '$env:TEMP\uninstall_tool_lab.ps1' -Force`""
  Set-ItemProperty -Path $uninstallKey -Name 'UninstallString' -Value $uninstallCmd
  
  New-ItemProperty -Path $uninstallKey -Name 'NoModify' -Value 1 -PropertyType DWord -Force | Out-Null
  New-ItemProperty -Path $uninstallKey -Name 'NoRepair' -Value 1 -PropertyType DWord -Force | Out-Null
  $size = [math]::Round((Get-ChildItem $InstallDir -Recurse -File | Measure-Object Length -Sum).Sum / 1KB)
  New-ItemProperty -Path $uninstallKey -Name 'EstimatedSize' -Value $size -PropertyType DWord -Force | Out-Null
  Write-Ok "Registered in Add/Remove Programs"
}

function Install-StartMenuShortcut {
  $exePath = Join-Path $InstallDir $ExeName
  if (-not (Test-Path $StartMenuDir)) {
    New-Item -ItemType Directory -Path $StartMenuDir -Force | Out-Null
  }
  $shell = New-Object -ComObject WScript.Shell
  $shortcut = $shell.CreateShortcut($ShortcutPath)
  $shortcut.TargetPath = $exePath
  $shortcut.WorkingDirectory = $InstallDir
  $shortcut.Description = $AppName
  $shortcut.Save()
  Write-Ok "Start Menu shortcut created"
}

function Uninstall-All {
  Write-Info "Starting uninstall..."
  # Change working directory to temp to prevent locking the installation directory
  Set-Location $env:TEMP
  # Kill running app
  Stop-App
  # Remove file associations
  foreach ($ft in $FileTypes) {
    $ext = $ft.Extension
    $progId = $ft.ProgId
    # Remove ProgId key
    $progKey = "HKCU:\Software\Classes\$progId"
    if (Test-Path $progKey) {
      Remove-Item -Path $progKey -Recurse -Force
      Write-Ok "Removed ProgId $progId"
    }
    # Remove from OpenWithProgids
    $choiceKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\$ext\OpenWithProgids"
    if (Test-Path $choiceKey) {
      $existing = Get-ItemProperty -Path $choiceKey -ErrorAction SilentlyContinue
      if ($existing -and $existing.PSObject.Properties.Name -contains $progId) {
        Remove-ItemProperty -Path $choiceKey -Name $progId -Force
      }
    }
    # Reset extension default if it points to our ProgId
    $extKey = "HKCU:\Software\Classes\$ext"
    if (Test-Path $extKey) {
      $current = Get-ItemProperty -Path $extKey -Name '(default)' -ErrorAction SilentlyContinue
      if ($current.'(default)' -eq $progId) {
        Set-ItemProperty -Path $extKey -Name '(default)' -Value '' -Force
      }
    }
  }
  # Remove uninstall entry
  $uninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\$AppName"
  if (Test-Path $uninstallKey) {
    Remove-Item -Path $uninstallKey -Recurse -Force
    Write-Ok "Removed uninstall entry"
  }
  # Remove Start Menu shortcut
  if (Test-Path $ShortcutPath) {
    Remove-Item -Path $ShortcutPath -Force
    Write-Ok "Removed Start Menu shortcut"
  }
  # Remove install directory
  if (Test-Path $InstallDir) {
    Remove-Item -Path $InstallDir -Recurse -Force
    Write-Ok "Removed $InstallDir"
  }
  Write-Ok "Uninstall complete"
}

function Install-All {
  if (-not (Test-Path $SourceDir)) {
    Write-Err "Source not found: $SourceDir`nRun 'build.sh windows' first."
    exit 1
  }
  if (-not (Test-Path (Join-Path $SourceDir $ExeName))) {
    Write-Err "$ExeName not found in $SourceDir"
    exit 1
  }
  if (-not $Silent) {
    $answer = Read-Host "Install $AppName to $InstallDir and register file associations (.pdf, .md, .markdown, .txt, images, tracker modules)? [Y/n]"
    if ($answer -ne '' -and $answer -notmatch '^[Yy]') {
      Write-Info "Install cancelled"
      exit 0
    }
  }
  Install-Files
  Register-FileAssociations
  Register-OpenWithList
  Install-StartMenuShortcut
  Register-UninstallEntry
  Write-Ok "$AppName installed to $InstallDir"
  Write-Info "Run with '-Uninstall' to remove"
}

# --- Entry point ---
Write-Info "Starting installer for $AppName (v$Version)..."
if ($Uninstall) {
  if (-not $Silent) {
    $answer = Read-Host "Uninstall $AppName from $InstallDir? This will remove all file associations. [y/N]"
    if ($answer -match '^[Yy]') {
      Uninstall-All
    } else {
      Write-Info "Uninstall cancelled"
      exit 0
    }
  } else {
    Uninstall-All
  }
} else {
  # Detect existing install
  if (Test-Path $InstallDir) {
    Write-Info "$AppName is already installed at $InstallDir"
    if (-not $Silent) {
      $answer = Read-Host "Reinstall/update? [Y/n]"
      if ($answer -ne '' -and $answer -notmatch '^[Yy]') {
        Write-Info "Update cancelled"
        exit 0
      }
    }
  }
  Install-All
}
