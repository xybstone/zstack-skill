# OpenClaw Auto Install Script for Windows 11
# Author: Ruochu
# Date: 2026-03-12

#Requires -RunAsAdministrator

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " OpenClaw Auto Install Script (Windows 11)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

function Log-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Log-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Log-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Check admin
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Log-Error "Please run as Administrator"
    exit 1
}

# TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 1. Check Winget
Log-Info "Step 1/8: Checking package manager..."
if (-Not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Log-Error "Winget not installed. Please install from: https://github.com/microsoft/winget-cli/releases"
    exit 1
}
Log-Info "Winget available"

# 2. Install Node.js 22 LTS
Log-Info "Step 2/8: Installing Node.js 22 LTS..."
$nodeInstalled = Get-Command node -ErrorAction SilentlyContinue
if ($nodeInstalled) {
    $nodeVersion = node -v
    $nodeMajorVersion = [int]($nodeVersion -replace 'v(\d+)\..*', '$1')
    if ($nodeMajorVersion -ge 22) {
        Log-Info "Node.js version OK: $nodeVersion"
    } else {
        Log-Warn "Node.js version too old: $nodeVersion, upgrading to 22"
        winget install -e --id OpenJS.NodeJS.LTS --force
    }
} else {
    winget install -e --id OpenJS.NodeJS.LTS
}

# Refresh PATH
$machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
$userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
$env:Path = "$machinePath;$userPath"

if (Get-Command node -ErrorAction SilentlyContinue) {
    Log-Info "Node.js installed: $(node -v)"
    Log-Info "npm version: $(npm -v)"
} else {
    Log-Error "Node.js installation failed"
    exit 1
}

# 3. Configure npm mirror
Log-Info "Step 3/8: Configuring npm mirror..."
npm config set registry https://registry.npmmirror.com
Log-Info "npm mirror configured"

# 4. Install Git
Log-Info "Step 4/8: Installing Git..."
if (-Not (Get-Command git -ErrorAction SilentlyContinue)) {
    winget install -e --id Git.Git
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
    Log-Info "Git installed"
} else {
    Log-Info "Git already installed: $(git --version)"
}

# 5. Install OpenClaw
Log-Info "Step 5/8: Installing OpenClaw..."
$openclawInstalled = Get-Command openclaw -ErrorAction SilentlyContinue
if ($openclawInstalled) {
    $openclawVersion = openclaw --version
    Log-Info "OpenClaw already installed: $openclawVersion"
    $reinstall = Read-Host "Reinstall? (y/n)"
    if ($reinstall -ne "y") {
        Log-Info "Skipping OpenClaw installation"
    } else {
        npm install -g openclaw@latest --registry=https://registry.npmmirror.com
    }
} else {
    Log-Info "Installing OpenClaw via npm..."
    npm install -g openclaw@latest --registry=https://registry.npmmirror.com
}

# Refresh PATH again
$machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
$userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
$env:Path = "$machinePath;$userPath"

if (Get-Command openclaw -ErrorAction SilentlyContinue) {
    Log-Info "OpenClaw installed: $(openclaw --version)"
} else {
    Log-Error "OpenClaw installation failed"
    exit 1
}

# 6. Install China IM plugins
Log-Info "Step 6/8: Installing China IM plugins..."
$chinaPluginsPath = "C:\opt\openclaw-china"
if (-Not (Test-Path $chinaPluginsPath)) {
    Log-Info "Cloning openclaw-china from GitHub..."
    try {
        New-Item -ItemType Directory -Force -Path "C:\opt" | Out-Null
        git clone --depth 1 https://github.com/BytePioneer-AI/openclaw-china.git $chinaPluginsPath
        Push-Location $chinaPluginsPath
        npm install --registry=https://registry.npmmirror.com
        npm run build
        openclaw plugins install -l .\packages\channels
        Pop-Location
        Log-Info "China IM plugins installed"
    } catch {
        Log-Warn "GitHub connection failed, skipping openclaw-china"
        Log-Warn "You can install manually later: git clone https://github.com/BytePioneer-AI/openclaw-china.git C:\opt\openclaw-china"
    }
} else {
    Log-Info "China IM plugins already installed, skipping"
}

# 7. Configure auto-start
Log-Info "Step 7/8: Configuring auto-start..."
$openclawHome = "$env:USERPROFILE\.openclaw"
New-Item -ItemType Directory -Force -Path "$openclawHome\config" | Out-Null

$taskName = "OpenClaw Gateway"
$openclawPath = (Get-Command openclaw).Source
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoExit -Command `"$openclawPath gateway start --port 18789`""
$trigger = New-ScheduledTaskTrigger -AtLogon
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType S4U -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 5 -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force
Log-Info "Task Scheduler configured"

# Start OpenClaw Gateway
Log-Info "Starting OpenClaw Gateway..."
Start-ScheduledTask -TaskName $taskName
Start-Sleep -Seconds 5
Get-ScheduledTask -TaskName $taskName | Select-Object TaskName, State

# 8. Security configuration
Log-Info "Step 8/8: Configuring security..."
$initialToken = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})

$gatewayConfig = @{
    auth = @{
        mode = "token"
        token = $initialToken
    }
    host = "127.0.0.1"
    port = 18789
} | ConvertTo-Json -Depth 10

$toolsConfig = @{
    profile = "messaging"
    approval = @{
        enabled = $true
        patterns = @("rm -rf", "sudo", "chmod 777")
    }
} | ConvertTo-Json -Depth 10

$pluginsConfig = @{
    hub = @{
        enabled = $false
    }
    allowLocalOnly = $true
} | ConvertTo-Json -Depth 10

$gatewayConfig | Out-File -FilePath "$openclawHome\config\gateway.json" -Encoding UTF8
$toolsConfig | Out-File -FilePath "$openclawHome\config\tools.json" -Encoding UTF8
$pluginsConfig | Out-File -FilePath "$openclawHome\config\plugins.json" -Encoding UTF8

Log-Info "Security configuration complete"

# Save initial token
$initialToken | Out-File -FilePath "$env:USERPROFILE\openclaw-initial-token.txt" -Encoding UTF8

# Summary
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " OpenClaw Installation Complete!" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Versions:" -ForegroundColor Yellow
Write-Host "  Node.js: $(node -v)"
Write-Host "  npm: $(npm -v)"
Write-Host "  OpenClaw: $(openclaw --version)"
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Dashboard: http://localhost:18789"
Write-Host "  Initial Token: $initialToken"
Write-Host "  Config dir: $openclawHome\config\"
Write-Host "  Token saved to: $env:USERPROFILE\openclaw-initial-token.txt"
Write-Host ""
Write-Host "Service management:" -ForegroundColor Yellow
Write-Host "  Status: Get-ScheduledTask -TaskName 'OpenClaw Gateway'"
Write-Host "  Start:  Start-ScheduledTask -TaskName 'OpenClaw Gateway'"
Write-Host "  Stop:   Stop-ScheduledTask -TaskName 'OpenClaw Gateway'"
Write-Host ""
Write-Host "IMPORTANT:" -ForegroundColor Red
Write-Host "  1. Change the Token after first login"
Write-Host "  2. Open port 18789 in firewall if needed"
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan