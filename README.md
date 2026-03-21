# ZStack Cloud Skill

ZStack Cloud API 操作技能 - 用于 OpenClaw 的云平台管理技能包。

## 概述

ZStack 是一个开源的云计算 IaaS 软件，提供完整的云平台管理能力。本技能包整理了 ZStack API 的核心操作，方便通过 OpenClaw 进行云资源管理。

## 快速开始

### 推荐：使用 MCP 协议（AI 集成）

MCP 方式更适合 AI 自动化调用，自动处理认证、错误和响应限制。

```bash
# 查看 MCP 文档
cat mcp/SKILL.md

# 快速配置
bash mcp/scripts/configure.sh
bash mcp/scripts/register-mcp.sh
```

### 传统：直接 API 调用

直接使用 curl 调用 ZStack REST API，适合脚本和手动操作。

## 文档结构

```
zstack-skill/
├── README.md                    # 本文件
├── SKILL.md                     # OpenClaw Skill 定义
├── mcp/                         # MCP 协议集成（新增）
│   ├── SKILL.md                 # MCP Skill 文档
│   ├── scripts/
│   │   ├── configure.sh         # MCP 认证配置
│   │   ├── register-mcp.sh      # 注册到 mcporter
│   │   └── test-connection.sh   # 连接测试
│   └── config/
│       └── zstack.env           # MCP 配置文件
├── docs/
│   ├── 01-api-architecture.md   # API 架构概述
│   ├── 02-authentication.md     # 认证机制
│   ├── 03-compute.md            # 计算资源管理
│   ├── 04-storage.md            # 存储资源管理
│   ├── 05-network.md            # 网络资源管理
│   └── ...
├── scripts/
│   └── examples/                # 示例脚本
└── references/
    └── api-quick-ref.md         # API 快速参考
```

## 快速开始

### 1. 环境准备

```bash
# ZStack API 端点
export ZSTACK_API="http://<your-zstack-server>:8080/zstack/v1"

# 认证信息
export ZSTACK_ACCESS_KEY="your-access-key"
export ZSTACK_SECRET_KEY="your-secret-key"
```

### 2. 基本 API 调用

```bash
# 使用 curl 调用 API
curl -X POST "$ZSTACK_API/vm-instances" \
  -H "Content-Type: application/json" \
  -H "Authorization: OAuth $ACCESS_TOKEN" \
  -d '{...}'
```

## 学习进度

- [x] API 架构概述
- [x] 认证机制
- [x] 计算资源管理（云主机、镜像、计算规格）
- [x] 存储资源管理（云盘、快照、云盘规格）
- [x] 网络资源管理（L3网络、安全组、EIP）
- [x] 监控与告警
- [x] 高级功能（定时任务、标签、批量操作）

## 参考资料

- [ZStack 官方文档](https://www.zstack.io/help/dev_manual/dev_guide/v5/)
- [ZStack GitHub](https://github.com/zstackio/zstack)

## License

MIT
