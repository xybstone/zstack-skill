# OpenClaw Windows 11 安装指南

## 使用方法

### 方式一：PowerShell 直接运行

1. **以管理员身份打开 PowerShell**
   - 右键点击 PowerShell → 以管理员身份运行

2. **执行安装脚本**
   ```powershell
   # 设置执行策略（首次需要）
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   
   # 下载并运行脚本
   iwr -useb https://raw.githubusercontent.com/xybstone/zstack-skill/main/scripts/openclaw-install-windows.ps1 -OutFile $env:TEMP\openclaw-install.ps1
   powershell -ExecutionPolicy Bypass -File $env:TEMP\openclaw-install.ps1
   ```

### 方式二：本地运行

1. **下载脚本**
   ```powershell
   iwr -useb https://raw.githubusercontent.com/xybstone/zstack-skill/main/scripts/openclaw-install-windows.ps1 -OutFile openclaw-install-windows.ps1
   ```

2. **以管理员身份运行**
   - 右键点击 `openclaw-install-windows.ps1` → 以管理员身份运行
   - 或在管理员 PowerShell 中执行：
     ```powershell
     Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
     .\openclaw-install-windows.ps1
     ```

## 安装流程

脚本会自动完成以下步骤：

1. ✅ 检查包管理器 (Winget)
2. ✅ 安装 Node.js 22 LTS
3. ✅ 配置 npm 国内镜像 (npmmirror)
4. ✅ 安装 Git
5. ✅ 安装 OpenClaw
6. ✅ 安装中国 IM 插件集 (openclaw-china)
7. ✅ 配置开机自启 (Windows 任务计划程序)
8. ✅ 安全加固配置 (Token、审批规则)

## 安装后

### 查看服务状态
```powershell
Get-ScheduledTask -TaskName "OpenClaw Gateway"
```

### 查看日志
```powershell
# OpenClaw Gateway 日志
openclaw gateway logs
```

### 访问 Dashboard
- URL: http://localhost:18789
- Token: 查看 `$env:USERPROFILE\openclaw-initial-token.txt`

### 防火墙配置
如果需要远程访问，手动开放 18789 端口：
```powershell
New-NetFirewallRule -DisplayName "OpenClaw Gateway" -Direction Inbound -LocalPort 18789 -Protocol TCP -Action Allow
```

## 常见问题

### Q: 提示"无法加载文件，因为在此系统上禁止运行脚本"
A: 执行以下命令：
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Q: Winget 未安装
A: 从 GitHub 安装：https://github.com/microsoft/winget-cli/releases

### Q: GitHub 克隆超时
A: 脚本会自动跳过 openclaw-china 安装，可以稍后手动安装：
```powershell
git clone https://github.com/BytePioneer-AI/openclaw-china.git C:\opt\openclaw-china
cd C:\opt\openclaw-china
npm install --registry=https://registry.npmmirror.com
npm run build
openclaw plugins install -l .\packages\channels
```

### Q: 如何卸载
A: 
```powershell
# 删除任务计划
Unregister-ScheduledTask -TaskName "OpenClaw Gateway" -Confirm:$false

# 卸载 OpenClaw
npm uninstall -g openclaw

# 删除配置目录
Remove-Item -Recurse -Force $env:USERPROFILE\.openclaw
```

## 与 Ubuntu 版本的主要差异

| 项目 | Ubuntu | Windows 11 |
|------|--------|-----------|
| 脚本格式 | Bash (.sh) | PowerShell (.ps1) |
| 包管理器 | apt | Winget |
| 服务管理 | systemd | 任务计划程序 |
| 配置文件路径 | /home/openclaw/.openclaw | $env:USERPROFILE\.openclaw |
| 防火墙 | ufw | Windows Defender Firewall |
| 用户权限 | root/sudo | 管理员权限 |

## 安全建议

1. 首次登录后立即修改 Token
2. 默认监听 127.0.0.1，如需远程访问请配置反向代理
3. 定期更新 OpenClaw：`openclaw update`
4. 审查工具审批规则，根据需要调整
