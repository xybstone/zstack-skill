---
name: zstack
description: "Manage ZStack Cloud resources via REST API or MCP protocol. Supports both direct API calls and MCP-based AI integration."
metadata:
  openclaw:
    emoji: "☁️"
    requires:
      bins: ["curl", "jq"]
    optional:
      bins: ["mcporter", "zstack-mcp-server"]
---

# ZStack Cloud Skill

Manage ZStack Cloud infrastructure via REST API or MCP protocol.

## 两种方式

### 方式一：MCP 协议（推荐用于 AI 集成）

通过 MCP Server 调用 ZStack API，自动处理认证、错误和响应限制。

```bash
# 安装 MCP Server
pipx install zstack-mcp-server

# 配置认证
bash mcp/scripts/configure.sh

# 注册到 mcporter
bash mcp/scripts/register-mcp.sh

# 使用示例
mcporter call zstack-mcp.search_api --args '{"keywords":["Query","Vm"]}'
mcporter call zstack-mcp.execute_api --args '{"api_name":"QueryVmInstance","parameters":{"conditions":[]}}'
```

详细文档：[mcp/SKILL.md](mcp/SKILL.md)

---

### 方式二：直接 API 调用（传统方式）

直接使用 curl 调用 ZStack REST API。

## Environment Setup

```bash
# Required environment variables
export ZSTACK_API="http://<zstack-server>:8080/zstack/v1"
export ZSTACK_ACCESS_KEY_ID="AK_xxxxxxxx"
export ZSTACK_ACCESS_KEY_SECRET="SK_xxxxxxxx"

# Or use session-based auth
export ZSTACK_SESSION="<session-uuid>"
```

## Quick Reference

### Authentication

> ⚠️ **重要**：API 登录时密码需要使用 **SHA-512 哈希**，不是明文！

```bash
# 生成密码哈希
PASSWORD_HASH=$(echo -n "password" | sha512sum | awk '{print $1}')

# Login and get session (使用 PUT 方法)
curl -X PUT "$ZSTACK_API/accounts/login" \
  -H "Content-Type: application/json" \
  -d '{"logInByAccount":{"accountName":"admin","password":"'$PASSWORD_HASH'"}}'

# Use session in subsequent requests
curl -H "Authorization: OAuth $ZSTACK_SESSION" "$ZSTACK_API/vm-instances"
```

### 使用 zstack-cli (推荐)

zstack-cli 会自动处理密码哈希和 Session 管理，更方便：

```bash
# 登录
zstack-cli LogInByAccount accountName=admin password=password

# 查询云主机
zstack-cli QueryVmInstance

# 带条件查询
zstack-cli QueryVmInstance conditions="state=Running"
```

### VM Operations

```bash
# List VMs
curl -H "Authorization: OAuth $ZSTACK_SESSION" \
  "$ZSTACK_API/vm-instances"

# Query with conditions
curl -H "Authorization: OAuth $ZSTACK_SESSION" \
  "$ZSTACK_API/vm-instances?q=state=Running"

# Create VM
curl -X POST "$ZSTACK_API/vm-instances" \
  -H "Authorization: OAuth $ZSTACK_SESSION" \
  -H "Content-Type: application/json" \
  -d '{
    "params": {
      "name": "test-vm",
      "instanceOfferingUuid": "<offering-uuid>",
      "imageUuid": "<image-uuid>",
      "l3NetworkUuids": ["<network-uuid>"]
    }
  }'

# Start VM
curl -X PUT "$ZSTACK_API/vm-instances/<vm-uuid>/actions" \
  -H "Authorization: OAuth $ZSTACK_SESSION" \
  -H "Content-Type: application/json" \
  -d '{"startVmInstance":{}}'

# Stop VM
curl -X PUT "$ZSTACK_API/vm-instances/<vm-uuid>/actions" \
  -H "Authorization: OAuth $ZSTACK_SESSION" \
  -H "Content-Type: application/json" \
  -d '{"stopVmInstance":{}}'

# Delete VM
curl -X DELETE "$ZSTACK_API/vm-instances/<vm-uuid>" \
  -H "Authorization: OAuth $ZSTACK_SESSION"
```

### Volume Operations

```bash
# List volumes
curl -H "Authorization: OAuth $ZSTACK_SESSION" \
  "$ZSTACK_API/volumes"

# Create data volume
curl -X POST "$ZSTACK_API/volumes/data" \
  -H "Authorization: OAuth $ZSTACK_SESSION" \
  -H "Content-Type: application/json" \
  -d '{
    "params": {
      "name": "data-disk",
      "diskOfferingUuid": "<offering-uuid>",
      "primaryStorageUuid": "<storage-uuid>"
    }
  }'

# Attach volume to VM
curl -X POST "$ZSTACK_API/volumes/<volume-uuid>/vm-instances/<vm-uuid>" \
  -H "Authorization: OAuth $ZSTACK_SESSION"

# Detach volume
curl -X DELETE "$ZSTACK_API/volumes/<volume-uuid>/vm-instances" \
  -H "Authorization: OAuth $ZSTACK_SESSION"
```

### Network Operations

```bash
# List L3 networks
curl -H "Authorization: OAuth $ZSTACK_SESSION" \
  "$ZSTACK_API/l3-networks"

# List security groups
curl -H "Authorization: OAuth $ZSTACK_SESSION" \
  "$ZSTACK_API/security-groups"

# Create security group rule
curl -X POST "$ZSTACK_API/security-groups/<sg-uuid>/rules" \
  -H "Authorization: OAuth $ZSTACK_SESSION" \
  -H "Content-Type: application/json" \
  -d '{
    "params": {
      "rules": [{
        "type": "Ingress",
        "protocol": "TCP",
        "startPort": 22,
        "endPort": 22,
        "allowedCidr": "0.0.0.0/0"
      }]
    }
  }'
```

### Image Operations

```bash
# List images
curl -H "Authorization: OAuth $ZSTACK_SESSION" \
  "$ZSTACK_API/images"

# Add image from URL
curl -X POST "$ZSTACK_API/images" \
  -H "Authorization: OAuth $ZSTACK_SESSION" \
  -H "Content-Type: application/json" \
  -d '{
    "params": {
      "name": "ubuntu-22.04",
      "url": "http://example.com/ubuntu.qcow2",
      "format": "qcow2",
      "mediaType": "RootVolumeTemplate",
      "platform": "Linux",
      "backupStorageUuids": ["<backup-storage-uuid>"]
    }
  }'
```

## Query Operators

| Operator | Example | Description |
|----------|---------|-------------|
| `=` | `state=Running` | Equals |
| `!=` | `state!=Stopped` | Not equals |
| `>` | `cpuNum>4` | Greater than |
| `<` | `cpuNum<8` | Less than |
| `?=` | `name?=%test%` | Like (wildcard) |
| `~=` | `name~=^vm-.*` | Regex match |
| `in` | `state=in(Running,Stopped)` | In list |

## Common Resources

| Resource | Endpoint |
|----------|----------|
| VMs | `/vm-instances` |
| Images | `/images` |
| Volumes | `/volumes` |
| L3 Networks | `/l3-networks` |
| Security Groups | `/security-groups` |
| EIPs | `/eips` |
| Snapshots | `/volume-snapshots` |
| Instance Offerings | `/instance-offerings` |
| Disk Offerings | `/disk-offerings` |

## Error Handling

Check for errors in response:

```json
{
  "error": {
    "code": "SYS.1001",
    "description": "Resource not found",
    "details": "VM instance xxx not found"
  }
}
```

## Tips

1. Always use `jq` to parse JSON responses
2. Use query conditions to filter results
3. Check job status for async operations
4. Set appropriate timeouts for long operations
