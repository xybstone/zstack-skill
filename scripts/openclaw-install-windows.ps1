# OpenClaw 自动化安装脚本 (Windows 11)
# 适用系统：Windows 11
# 作者：若初 🤙
# 日期：2026-03-12

#Requires -RunAsAdministrator

Write-Host "============================================" -ForegroundColor Cyan
Write-Host " OpenClaw 自动化安装脚本 (Windows 11)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# 日志函数
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

# 检查管理员权限
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Log-Error "请以管理员身份运行此脚本（右键 -> 以管理员身份运行）"
    exit 1
}

# 设置 TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# 1. 检查并安装 Winget
Log-Info "Step 1/8: 检查包管理器..."
if (-Not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Log-Error "Winget 未安装，请先安装 Windows Package Manager"
    Log-Error "访问：https://github.com/microsoft/winget-cli/releases"
    exit 1
}
Log-Info "Winget 可用"

# 2. 安装 Node.js 22 LTS
Log-Info "Step 2/8: 安装 Node.js 22 LTS..."
$nodeInstalled = Get-Command node -ErrorAction SilentlyContinue
if ($nodeInstalled) {
    $nodeVersion = node -v
    $nodeMajorVersion = ($nodeVersion -replace 'v(\d+)\..*', '$1') -as [int]
    if ($nodeMajorVersion -ge 22) {
        Log-Info "Node.js 版本已满足要求：$nodeVersion"
    } else {
        Log-Warn "Node.js 版本过低：$nodeVersion，需要升级至 22"
        winget install -e --id OpenJS.NodeJS.LTS --force
    }
} else {
    winget install -e --id OpenJS.NodeJS.LTS
}

# 刷新环境变量
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

if (Get-Command node -ErrorAction SilentlyContinue) {
    Log-Info "Node.js 安装完成：$(node -v)"
    Log-Info "npm 版本：$(npm -v)"
} else {
    Log-Error "Node.js 安装失败"
    exit 1
}

# 3. 配置 npm 国内镜像
Log-Info "Step 3/8: 配置 npm 国内镜像..."
npm config set registry https://registry.npmmirror.com
$registry = npm config get registry
if ($registry -like "*npmmirror*") {
    Log-Info "npm 镜像配置成功"
} else {
    Log-Warn "npm 镜像配置可能失败"
}

# 4. 安装 Git
Log-Info "Step 4/8: 安装 Git..."
if (-Not (Get-Command git -ErrorAction SilentlyContinue)) {
    winget install -e --id Git.Git
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    Log-Info "Git 安装完成"
} else {
    Log-Info "Git 已安装：$(git --version)"
}

# 5. 安装 OpenClaw
Log-Info "Step 5/8: 安装 OpenClaw..."
$openclawInstalled = Get-Command openclaw -ErrorAction SilentlyContinue
if ($openclawInstalled) {
    $openclawVersion = openclaw --version
    Log-Info "OpenClaw 已安装：$openclawVersion"
    $reinstall = Read-Host "是否重新安装？(y/n)"
    if ($reinstall -ne "y") {
        Log-Info "跳过 OpenClaw 安装"
    } else {
        npm install -g openclaw@latest --registry=https://registry.npmmirror.com
    }
} else {
    # 尝试使用官方安装脚本
    try {
        $installScriptUrl = "https://clawd.org.cn/install.sh"
        # Windows 无法直接运行 bash 脚本，使用 npm 安装
        Log-Info "使用 npm 安装 OpenClaw..."
        npm install -g openclaw@latest --registry=https://registry.npmmirror.com
    } catch {
        Log-Error "OpenClaw 安装失败"
        exit 1
    }
}

if (Get-Command openclaw -ErrorAction SilentlyContinue) {
    Log-Info "OpenClaw 安装完成：$(openclaw --version)"
} else {
    Log-Error "OpenClaw 安装失败"
    exit 1
}

# 6. 安装中国 IM 插件集
Log-Info "Step 6/8: 安装中国 IM 插件集..."
$chinaPluginsPath = "C:\opt\openclaw-china"
if (-Not (Test-Path $chinaPluginsPath)) {
    Log-Info "尝试从 GitHub 克隆 openclaw-china..."
    try {
        New-Item -ItemType Directory -Force -Path "C:\opt" | Out-Null
        git clone --depth 1 https://github.com/BytePioneer-AI/openclaw-china.git $chinaPluginsPath
        Set-Location $chinaPluginsPath
        npm install --registry=https://registry.npmmirror.com
        npm run build
        openclaw plugins install -l .\packages\channels
        Log-Info "中国 IM 插件集安装完成"
    } catch {
        Log-Warn "GitHub 连接超时或安装失败，跳过 openclaw-china 安装"
        Log-Warn "你可以稍后手动安装：git clone https://github.com/BytePioneer-AI/openclaw-china.git C:\opt\openclaw-china"
    }
} else {
    Log-Info "中国 IM 插件集已安装，跳过"
}

# 7. 配置 OpenClaw 开机自启（使用 Windows 任务计划程序）
Log-Info "Step 7/8: 配置 OpenClaw 开机自启..."
$openclawHome = "$env:USERPROFILE\.openclaw"
New-Item -ItemType Directory -Force -Path $openclawHome\config | Out-Null

# 创建任务计划程序配置
$taskName = "OpenClaw Gateway"
$openclawPath = (Get-Command openclaw).Source
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoExit -Command & '$openclawPath gateway start --port 18789'"
$trigger = New-ScheduledTaskTrigger -AtLogon
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType S4U -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RestartCount 5 -RestartInterval (New-TimeSpan -Minutes 1)

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force
Log-Info "任务计划程序配置完成"

# 启动 OpenClaw Gateway
Log-Info "启动 OpenClaw Gateway..."
Start-ScheduledTask -TaskName $taskName
Start-Sleep -Seconds 5
Get-ScheduledTask -TaskName $taskName | Select-Object TaskName, State

# 8. 安全加固配置
Log-Info "Step 8/8: 配置安全加固..."
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
        patterns = @("rm -rf", "sudo", "chmod 777", "curl.*|.*sh", "wget.*|.*sh", "dd if=", "mkfs", "shutdown", "reboot")
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

Log-Info "安全加固配置完成"

# 保存初始 Token
$initialToken | Out-File -FilePath "$env:USERPROFILE\openclaw-initial-token.txt" -Encoding UTF8

# 输出总结
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " OpenClaw 安装完成！" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📦 版本信息:" -ForegroundColor Yellow
Write-Host " - Node.js: $(node -v)"
Write-Host " - npm: $(npm -v)"
Write-Host " - OpenClaw: $(openclaw --version)"
Write-Host ""
Write-Host "🔐 初始配置:" -ForegroundColor Yellow
Write-Host " - Dashboard: http://localhost:18789"
Write-Host " - 初始 Token: $initialToken"
Write-Host " - 配置文件：$openclawHome\config\"
Write-Host " - Token 已保存到：$env:USERPROFILE\openclaw-initial-token.txt"
Write-Host ""
Write-Host "📝 服务管理:" -ForegroundColor Yellow
Write-Host " - 查看状态：Get-ScheduledTask -TaskName 'OpenClaw Gateway'"
Write-Host " - 启动服务：Start-ScheduledTask -TaskName 'OpenClaw Gateway'"
Write-Host " - 停止服务：Stop-ScheduledTask -TaskName 'OpenClaw Gateway'"
Write-Host " - 删除任务：Unregister-ScheduledTask -TaskName 'OpenClaw Gateway' -Confirm:`$false"
Write-Host ""
Write-Host "⚠️ 重要提示:" -ForegroundColor Red
Write-Host " 1. 首次登录 Dashboard 后请立即修改 Token"
Write-Host " 2. 初始 Token 已保存到 $env:USERPROFILE\openclaw-initial-token.txt"
Write-Host " 3. 配置文件位于 $openclawHome\"
Write-Host " 4. 防火墙可能需要手动开放 18789 端口"
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
