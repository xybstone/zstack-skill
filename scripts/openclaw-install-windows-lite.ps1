# OpenClaw Lite Install Script for Windows 11
# Author: Ruochu
# Date: 2026-03-12
# Note: Minimal installation without Git/China plugins

#Requires -RunAsAdministrator

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " OpenClaw Lite Install (Windows 11)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

function Log-Info { param([string]$Message); Write-Host "[INFO] $Message" -ForegroundColor Green }
function Log-Warn { param([string]$Message); Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Log-Error { param([string]$Message); Write-Host "[ERROR] $Message" -ForegroundColor Red }

function Refresh-Path {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

# Check admin
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Log-Error "Please run as Administrator"
    exit 1
}

# TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 1. Install Node.js 22 LTS
Log-Info "Step 1/4: Installing Node.js 22 LTS..."
$nodeInstalled = Get-Command node -ErrorAction SilentlyContinue
if ($nodeInstalled) {
    $nodeMajorVersion = [int](node -v).Split('.')[0].TrimStart('v')
    if ($nodeMajorVersion -ge 22) {
        Log-Info "Node.js OK: $(node -v)"
    } else {
        Log-Warn "Node.js version too old: $(node -v)"
        $nodeInstalled = $false
    }
}

if (-Not $nodeInstalled) {
    Log-Info "Downloading Node.js 22 LTS..."
    $nodeUrl = "https://nodejs.org/dist/v22.14.0/node-v22.14.0-x64.msi"
    $nodeMsi = "$env:TEMP\node-install.msi"
    
    try {
        Invoke-WebRequest -Uri $nodeUrl -OutFile $nodeMsi -UseBasicParsing -TimeoutSec 300
        Log-Info "Installing Node.js..."
        Start-Process msiexec.exe -ArgumentList "/i `"$nodeMsi`" /qn /norestart" -Wait
        Remove-Item $nodeMsi -Force -ErrorAction SilentlyContinue
        Log-Info "Node.js installed"
    } catch {
        Log-Error "Failed to download Node.js: $_"
        Log-Info "Please install manually from: https://nodejs.org/"
        exit 1
    }
}

Refresh-Path

if (-Not (Get-Command node -ErrorAction SilentlyContinue)) {
    Log-Error "Node.js not found in PATH. Please restart PowerShell and run again."
    Log-Info "Or add manually: C:\Program Files\nodejs\ to PATH"
    exit 1
}

Log-Info "Node.js: $(node -v)"
Log-Info "npm: $(npm -v)"

# 2. Configure npm mirror
Log-Info "Step 2/4: Configuring npm mirror..."
npm config set registry https://registry.npmmirror.com
Log-Info "npm mirror configured"

# 3. Install OpenClaw
Log-Info "Step 3/4: Installing OpenClaw..."
if (Get-Command openclaw -ErrorAction SilentlyContinue) {
    Log-Info "OpenClaw already installed: $(openclaw --version)"
    $reinstall = Read-Host "Reinstall? (y/n)"
    if ($reinstall -eq "y") {
        npm install -g openclaw@latest --registry=https://registry.npmmirror.com
    }
} else {
    npm install -g openclaw@latest --registry=https://registry.npmmirror.com
}

Refresh-Path

if (-Not (Get-Command openclaw -ErrorAction SilentlyContinue)) {
    Log-Error "OpenClaw installation failed"
    exit 1
}

Log-Info "OpenClaw: $(openclaw --version)"

# 4. Configure and start
Log-Info "Step 4/4: Configuring OpenClaw..."
$openclawHome = "$env:USERPROFILE\.openclaw"
New-Item -ItemType Directory -Force -Path "$openclawHome\config" | Out-Null

# Generate token
$token = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 32 | ForEach-Object {[char]$_})

# Gateway config
@{
    auth = @{ mode = "token"; token = $token }
    host = "127.0.0.1"
    port = 18789
} | ConvertTo-Json -Depth 10 | Out-File "$openclawHome\config\gateway.json" -Encoding UTF8

# Tools config
@{
    profile = "messaging"
    approval = @{ enabled = $true; patterns = @("rm -rf", "sudo") }
} | ConvertTo-Json -Depth 10 | Out-File "$openclawHome\config\tools.json" -Encoding UTF8

# Save token
$token | Out-File "$env:USERPROFILE\openclaw-initial-token.txt" -Encoding UTF8

Log-Info "Configuration complete"

# Start gateway
Log-Info "Starting OpenClaw Gateway..."
Start-Process powershell -ArgumentList "-NoExit", "-Command", "openclaw gateway start --port 18789"

# Summary
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Installation Complete!" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Versions:" -ForegroundColor Yellow
Write-Host "  Node.js: $(node -v)"
Write-Host "  OpenClaw: $(openclaw --version)"
Write-Host ""
Write-Host "Access:" -ForegroundColor Yellow
Write-Host "  Dashboard: http://localhost:18789"
Write-Host "  Token: $token"
Write-Host "  Token file: $env:USERPROFILE\openclaw-initial-token.txt"
Write-Host ""
Write-Host "Commands:" -ForegroundColor Yellow
Write-Host "  Start:  openclaw gateway start"
Write-Host "  Stop:   openclaw gateway stop"
Write-Host "  Status: openclaw gateway status"
Write-Host "  Logs:   openclaw gateway logs"
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan