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

function Refresh-Path {
    $machinePath = [System.Environment]::GetEnvironmentVariable("Path", "Machine")
    $userPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    $env:Path = "$machinePath;$userPath"
}

# Check admin
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Log-Error "Please run as Administrator"
    exit 1
}

# TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 1. Install Node.js 22 LTS (using official installer)
Log-Info "Step 1/7: Installing Node.js 22 LTS..."
$nodeInstalled = Get-Command node -ErrorAction SilentlyContinue
if ($nodeInstalled) {
    $nodeVersion = node -v
    $nodeMajorVersion = [int]($nodeVersion -replace 'v(\d+)\..*', '$1')
    if ($nodeMajorVersion -ge 22) {
        Log-Info "Node.js version OK: $nodeVersion"
    } else {
        Log-Warn "Node.js version too old: $nodeVersion"
        $nodeInstalled = $false
    }
}

if (-Not $nodeInstalled) {
    Log-Info "Downloading Node.js 22 LTS installer..."
    $nodeUrl = "https://nodejs.org/dist/v22.14.0/node-v22.14.0-x64.msi"
    $nodeMsi = "$env:TEMP\node-install.msi"
    
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $nodeUrl -OutFile $nodeMsi -UseBasicParsing
        Log-Info "Installing Node.js..."
        Start-Process msiexec.exe -ArgumentList "/i `"$nodeMsi`" /qn /norestart" -Wait
        Remove-Item $nodeMsi -Force -ErrorAction SilentlyContinue
        Log-Info "Node.js installed"
    } catch {
        Log-Error "Failed to download Node.js: $_"
        Log-Info "Please install Node.js manually from: https://nodejs.org/"
        exit 1
    }
}

# Refresh PATH
Refresh-Path

if (Get-Command node -ErrorAction SilentlyContinue) {
    Log-Info "Node.js: $(node -v)"
    Log-Info "npm: $(npm -v)"
} else {
    Log-Error "Node.js installation failed. Please restart PowerShell and try again."
    Log-Info "You may need to add Node.js to PATH manually: C:\Program Files\nodejs\"
    exit 1
}

# 2. Configure npm mirror
Log-Info "Step 2/7: Configuring npm mirror..."
npm config set registry https://registry.npmmirror.com
Log-Info "npm mirror configured"

# 3. Install Git
Log-Info "Step 3/7: Installing Git..."
if (-Not (Get-Command git -ErrorAction SilentlyContinue)) {
    Log-Info "Downloading Git installer..."
    # Try multiple mirrors
    $gitUrls = @(
        "https://mirrors.tuna.tsinghua.edu.cn/github-release/git-for-windows/git/LatestRelease/Git-2.48.1-64-bit.exe",
        "https://mirrors.aliyun.com/github-release/git-for-windows/git/LatestRelease/Git-2.48.1-64-bit.exe",
        "https://github.com/git-for-windows/git/releases/download/v2.48.1.windows.1/Git-2.48.1-64-bit.exe"
    )
    $gitExe = "$env:TEMP\git-install.exe"
    $gitInstalled = $false
    
    foreach ($url in $gitUrls) {
        try {
            Log-Info "Trying mirror: $url"
            Invoke-WebRequest -Uri $url -OutFile $gitExe -UseBasicParsing -TimeoutSec 120
            Log-Info "Installing Git..."
            Start-Process $gitExe -ArgumentList "/VERYSILENT", "/NORESTART" -Wait
            Remove-Item $gitExe -Force -ErrorAction SilentlyContinue
            Refresh-Path
            $gitInstalled = $true
            Log-Info "Git installed"
            break
        } catch {
            Log-Warn "Mirror failed: $url"
        }
    }
    
    if (-Not $gitInstalled) {
        Log-Warn "All Git mirrors failed. Please install manually from: https://git-scm.com/download/win"
        Log-Info "Continuing without Git..."
    }
} else {
    Log-Info "Git already installed: $(git --version)"
}

# 4. Install OpenClaw
Log-Info "Step 4/7: Installing OpenClaw..."
$openclawInstalled = Get-Command openclaw -ErrorAction SilentlyContinue
if ($openclawInstalled) {
    Log-Info "OpenClaw already installed: $(openclaw --version)"
    $reinstall = Read-Host "Reinstall? (y/n)"
    if ($reinstall -eq "y") {
        npm install -g openclaw@latest --registry=https://registry.npmmirror.com
    }
} else {
    Log-Info "Installing OpenClaw via npm..."
    npm install -g openclaw@latest --registry=https://registry.npmmirror.com
}

Refresh-Path

if (Get-Command openclaw -ErrorAction SilentlyContinue) {
    Log-Info "OpenClaw: $(openclaw --version)"
} else {
    Log-Error "OpenClaw installation failed"
    exit 1
}

# 5. Install China IM plugins
Log-Info "Step 5/7: Installing China IM plugins..."
$chinaPluginsPath = "C:\opt\openclaw-china"
if (-Not (Test-Path $chinaPluginsPath)) {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Log-Info "Cloning openclaw-china..."
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
            Log-Warn "Failed to install China plugins: $_"
        }
    } else {
        Log-Warn "Git not available, skipping China plugins"
    }
} else {
    Log-Info "China IM plugins already installed"
}

# 6. Configure auto-start
Log-Info "Step 6/7: Configuring auto-start..."
$openclawHome = "$env:USERPROFILE\.openclaw"
New-Item -ItemType Directory -Force -Path "$openclawHome\config" | Out-Null

$taskName = "OpenClaw Gateway"
$openclawPath = (Get-Command openclaw).Source
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoExit -Command `"$openclawPath gateway start --port 18789`""
$trigger = New-ScheduledTaskTrigger -AtLogon
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType S4U -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 5 -RestartInterval (New-TimeSpan -Minutes 1)

try {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force
    Log-Info "Task Scheduler configured"
} catch {
    Log-Warn "Failed to configure auto-start: $_"
}

# 7. Security configuration
Log-Info "Step 7/7: Configuring security..."
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
    hub = @{ enabled = $false }
    allowLocalOnly = $true
} | ConvertTo-Json -Depth 10

$gatewayConfig | Out-File -FilePath "$openclawHome\config\gateway.json" -Encoding UTF8
$toolsConfig | Out-File -FilePath "$openclawHome\config\tools.json" -Encoding UTF8
$pluginsConfig | Out-File -FilePath "$openclawHome\config\plugins.json" -Encoding UTF8

$initialToken | Out-File -FilePath "$env:USERPROFILE\openclaw-initial-token.txt" -Encoding UTF8

Log-Info "Configuration complete"

# Start OpenClaw Gateway
Log-Info "Starting OpenClaw Gateway..."
Start-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

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
Write-Host "Commands:" -ForegroundColor Yellow
Write-Host "  Start:   openclaw gateway start"
Write-Host "  Stop:    openclaw gateway stop"
Write-Host "  Status:  openclaw gateway status"
Write-Host "  Logs:    openclaw gateway logs"
Write-Host ""
Write-Host "IMPORTANT:" -ForegroundColor Red
Write-Host "  1. Change the Token after first login"
Write-Host "  2. Open port 18789 in firewall if needed for remote access"
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan