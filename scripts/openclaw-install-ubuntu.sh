#!/bin/bash
# OpenClaw 自动化安装脚本 (Ubuntu 22.04/24.04)
# 适用系统：Ubuntu 22.04 LTS / 24.04 LTS
# 作者：若初 🤙
# 日期：2026-03-12

set -e

echo "============================================"
echo "  OpenClaw 自动化安装脚本 (Ubuntu)"
echo "============================================"
echo ""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# 检查是否 root 用户
if [ "$EUID" -ne 0 ]; then
  log_error "请使用 root 用户运行此脚本"
  exit 1
fi

# 检查 Ubuntu 版本
if [ ! -f /etc/os-release ]; then
  log_error "无法识别系统版本，此脚本仅支持 Ubuntu 22.04/24.04"
  exit 1
fi

source /etc/os-release
if [[ "$ID" != "ubuntu" ]]; then
  log_error "此脚本仅支持 Ubuntu 系统，当前系统：$ID"
  exit 1
fi

log_info "检测到系统：$PRETTY_NAME"

# 1. 系统更新与基础依赖
log_info "Step 1/7: 更新系统并安装基础依赖..."
apt update
DEBIAN_FRONTEND=noninteractive apt upgrade -y
DEBIAN_FRONTEND=noninteractive apt install -y curl wget git vim net-tools \
  ufw python3 python3-pip jq unzip xz-utils gzip ca-certificates

# 2. 安装 Node.js 22 LTS
log_info "Step 2/7: 安装 Node.js 22 LTS..."

# 检查是否已安装合适版本的 Node.js
NODE_OK=false
if command -v node &> /dev/null; then
  NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
  if [ "$NODE_VERSION" -ge 22 ]; then
    log_info "Node.js 版本已满足要求：$(node -v)"
    NODE_OK=true
  else
    log_warn "Node.js 版本过低：$(node -v)，需要升级至 22"
  fi
fi

if [ "$NODE_OK" = false ]; then
  log_info "安装 Node.js 22 LTS via NodeSource..."
  
  # 先移除旧版本
  apt remove -y nodejs npm 2>/dev/null || true
  
  # 安装 NodeSource 22
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  DEBIAN_FRONTEND=noninteractive apt install -y nodejs
  
  # 刷新环境变量
  export PATH="/usr/bin:$PATH"
  hash -r
  
  log_info "Node.js 安装完成：$(node -v)"
  log_info "npm 版本：$(npm -v)"
fi

# 确保 npm 可用
if ! command -v npm &> /dev/null; then
  log_error "npm 未正确安装，尝试重新安装..."
  DEBIAN_FRONTEND=noninteractive apt install -y npm
  export PATH="/usr/bin:$PATH"
  hash -r
fi

# 3. 配置 npm 国内镜像
log_info "Step 3/7: 配置 npm 国内镜像..."
npm config set registry https://registry.npmmirror.com
npm config get registry | grep -q "npmmirror" && log_info "npm 镜像配置成功"

# 4. 安装 OpenClaw
log_info "Step 4/7: 安装 OpenClaw..."

# 检查是否已安装
if command -v openclaw &> /dev/null; then
  log_info "OpenClaw 已安装：$(openclaw --version)"
  read -p "是否重新安装？(y/n): " REINSTALL
  if [ "$REINSTALL" != "y" ]; then
    log_info "跳过 OpenClaw 安装"
  else
    npm install -g openclaw@latest --registry=https://registry.npmmirror.com
  fi
else
  # 使用官方安装脚本
  if curl -fsSL https://clawd.org.cn/install.sh -o /tmp/openclaw-install.sh; then
    bash /tmp/openclaw-install.sh --registry https://registry.npmmirror.com
    rm -f /tmp/openclaw-install.sh
  else
    # 备用方案：直接 npm 安装
    log_warn "官方安装脚本下载失败，使用 npm 安装..."
    npm install -g openclaw@latest --registry=https://registry.npmmirror.com
  fi
fi

log_info "OpenClaw 安装完成：$(openclaw --version)"

# 5. 安装中国 IM 插件集
log_info "Step 5/7: 安装中国 IM 插件集..."

if [ ! -d "/opt/openclaw-china" ]; then
  log_info "尝试从 GitHub 克隆 openclaw-china..."
  
  # 设置 Git 超时
  export GIT_CURL_VERBOSE=1
  export GIT_TRACE=1
  
  if timeout 60 git clone --depth 1 https://github.com/BytePioneer-AI/openclaw-china.git /opt/openclaw-china 2>&1; then
    cd /opt/openclaw-china
    npm install --registry=https://registry.npmmirror.com || log_warn "npm install 失败，跳过"
    npm run build || log_warn "npm build 失败，跳过"
    
    # 安装插件到 OpenClaw
    openclaw plugins install -l ./packages/channels || log_warn "插件安装失败，跳过"
    log_info "中国 IM 插件集安装完成"
  else
    log_warn "GitHub 连接超时，跳过 openclaw-china 安装"
    log_warn "你可以稍后手动安装：git clone https://github.com/BytePioneer-AI/openclaw-china.git /opt/openclaw-china"
  fi
else
  log_info "中国 IM 插件集已安装，跳过"
fi

# 6. 配置 systemd 开机自启
log_info "Step 6/7: 配置 OpenClaw 开机自启..."

# 创建 openclaw 用户
if ! id "openclaw" &>/dev/null; then
  useradd -r -m -s /bin/bash openclaw
  log_info "创建 openclaw 用户成功"
fi

# 初始化 openclaw 配置
su - openclaw -c "openclaw gateway install"

# 配置 systemd 服务
cat > /etc/systemd/system/openclaw.service <<'EOF'
[Unit]
Description=OpenClaw AI Agent Gateway
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=openclaw
Group=openclaw
WorkingDirectory=/home/openclaw
ExecStart=/usr/bin/openclaw gateway start --port 18789
Restart=always
RestartSec=5
Environment=NODE_ENV=production
Environment=XDG_RUNTIME_DIR=/run/user/1001

# 安全加固
NoNewPrivileges=true
ProtectSystem=strict
ReadWritePaths=/home/openclaw/.openclaw
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable openclaw
systemctl start openclaw

# 等待服务启动
sleep 5
systemctl status openclaw --no-pager | head -10

log_info "OpenClaw 服务配置完成"

# 7. 配置防火墙
log_info "Step 7/7: 配置防火墙..."

systemctl enable --now ufw

# 清除旧规则（可选）
# ufw --force reset

# 开放必要端口
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow http
ufw allow https

# 不直接开放 18789，通过 Nginx 反向代理（后续配置）
# ufw allow 18789/tcp

ufw --force enable

log_info "防火墙配置完成"
ufw status verbose

# 8. 安全加固配置
log_info "配置安全加固..."

# Gateway 认证
su - openclaw -c "openclaw config set gateway.auth.mode token"
INITIAL_TOKEN=$(openssl rand -hex 16)
su - openclaw -c "openclaw config set gateway.auth.token '$INITIAL_TOKEN'"

# 绑定 localhost
su - openclaw -c "openclaw config set gateway.host 127.0.0.1"
su - openclaw -c "openclaw config set gateway.port 18789"

# 工具权限设置为 messaging（最安全）
su - openclaw -c "openclaw config set tools.profile messaging"

# 配置命令审批门
su - openclaw -c "openclaw config set tools.approval.enabled true"
su - openclaw -c 'openclaw config set tools.approval.patterns '\''["rm -rf", "sudo", "chmod 777", "curl.*|.*sh", "wget.*|.*sh", "dd if=", "mkfs", "shutdown", "reboot"]'\'''

# 禁用 ClawHub 在线安装
su - openclaw -c "openclaw config set plugins.hub.enabled false"
su - openclaw -c "openclaw config set plugins.allowLocalOnly true"

log_info "安全加固配置完成"

# 9. 写入首次启动标记
echo "$INITIAL_TOKEN" > /etc/openclaw-initial-token
chmod 600 /etc/openclaw-initial-token
touch /etc/openclaw-first-boot

# 10. 清理
log_info "清理安装缓存..."
apt clean
apt autoremove -y
npm cache clean --force
rm -f /tmp/openclaw-install.sh

# 输出总结
echo ""
echo "============================================"
echo "  OpenClaw 安装完成！"
echo "============================================"
echo ""
echo "📦 版本信息:"
echo "   - Node.js: $(node -v)"
echo "   - npm: $(npm -v)"
echo "   - OpenClaw: $(openclaw --version)"
echo ""
echo "🔐 初始配置:"
echo "   - Dashboard: http://$(hostname -I | awk '{print $1}')"
echo "   - 初始 Token: $INITIAL_TOKEN"
echo "   - 配置文件：/home/openclaw/.openclaw/config/"
echo ""
echo "📝 服务管理:"
echo "   - 查看状态：systemctl status openclaw"
echo "   - 查看日志：journalctl -u openclaw -f"
echo "   - 重启服务：systemctl restart openclaw"
echo ""
echo "⚠️  重要提示:"
echo "   1. 首次登录 Dashboard 后请立即修改 Token"
echo "   2. 初始 Token 已保存到 /etc/openclaw-initial-token"
echo "   3. 配置文件位于 /home/openclaw/.openclaw/"
echo ""
echo "============================================"
