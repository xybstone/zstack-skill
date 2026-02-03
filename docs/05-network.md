# ZStack 网络资源管理

本文档涵盖网络（L3 Network）、安全组（Security Group）和弹性 IP（EIP）的管理。

## 1. 网络架构概述

ZStack 采用分层网络架构：

```
Zone (区域)
└── Cluster (集群)
    └── L2 Network (二层网络)
        └── L3 Network (三层网络)
            ├── IP Range (IP 地址段)
            ├── DNS
            └── DHCP
```

### 网络类型

| 类型 | 说明 |
|------|------|
| L2NoVlanNetwork | 无 VLAN 的二层网络 |
| L2VlanNetwork | VLAN 二层网络 |
| VxlanNetwork | VxLAN 网络 |

### L3 网络类型

| 类型 | 说明 |
|------|------|
| L3BasicNetwork | 基础网络 |
| L3VpcNetwork | VPC 网络 |

## 2. L3 网络管理

### 查询网络

```bash
# 查询所有 L3 网络
GET /v1/l3-networks

# 按条件查询
GET /v1/l3-networks?q=type=L3BasicNetwork&q=state=Enabled

# 查询单个网络
GET /v1/l3-networks/<l3-uuid>

# 查询网络的 IP 使用情况
GET /v1/l3-networks/<l3-uuid>/ip-statistics
```

### 创建 L3 网络

```bash
POST /v1/l3-networks

{
  "params": {
    "name": "guest-network",
    "description": "Guest VM network",
    "type": "L3BasicNetwork",
    "l2NetworkUuid": "<l2-network-uuid>",
    "category": "Private",
    "system": false
  }
}
```

### 网络类别

| 类别 | 说明 |
|------|------|
| Private | 私有网络 |
| Public | 公有网络（用于 EIP） |
| System | 系统网络 |

### 添加 IP 地址段

```bash
POST /v1/l3-networks/<l3-uuid>/ip-ranges

{
  "params": {
    "name": "ip-range-1",
    "startIp": "192.168.1.100",
    "endIp": "192.168.1.200",
    "netmask": "255.255.255.0",
    "gateway": "192.168.1.1"
  }
}

# 添加 CIDR 格式的 IP 段
POST /v1/l3-networks/<l3-uuid>/ip-ranges/by-cidr

{
  "params": {
    "name": "ip-range-cidr",
    "networkCidr": "192.168.2.0/24",
    "gateway": "192.168.2.1"
  }
}
```

### 添加 DNS

```bash
POST /v1/l3-networks/<l3-uuid>/dns

{
  "params": {
    "dns": "8.8.8.8"
  }
}

# 删除 DNS
DELETE /v1/l3-networks/<l3-uuid>/dns/<dns-address>
```

### 网络服务

```bash
# 查询可用的网络服务
GET /v1/network-services/providers

# 为网络附加服务
POST /v1/l3-networks/<l3-uuid>/network-services

{
  "params": {
    "networkServices": {
      "<provider-uuid>": ["DHCP", "DNS", "SNAT", "PortForwarding", "EIP"]
    }
  }
}
```

### 常用网络服务

| 服务 | 说明 |
|------|------|
| DHCP | 动态 IP 分配 |
| DNS | DNS 解析 |
| SNAT | 源地址转换（访问外网） |
| PortForwarding | 端口转发 |
| EIP | 弹性 IP |
| SecurityGroup | 安全组 |
| LoadBalancer | 负载均衡 |

### 更新网络

```bash
PUT /v1/l3-networks/<l3-uuid>

{
  "updateL3Network": {
    "name": "new-name",
    "description": "new description"
  }
}
```

### 删除网络

```bash
DELETE /v1/l3-networks/<l3-uuid>
```

## 3. 安全组管理

安全组是虚拟防火墙，控制云主机的入站和出站流量。

### 创建安全组

```bash
POST /v1/security-groups

{
  "params": {
    "name": "web-sg",
    "description": "Security group for web servers"
  }
}
```

### 查询安全组

```bash
# 查询所有安全组
GET /v1/security-groups

# 查询单个安全组
GET /v1/security-groups/<sg-uuid>

# 查询安全组规则
GET /v1/security-groups/<sg-uuid>/rules
```

### 添加安全组规则

```bash
POST /v1/security-groups/<sg-uuid>/rules

{
  "params": {
    "rules": [
      {
        "type": "Ingress",
        "protocol": "TCP",
        "startPort": 22,
        "endPort": 22,
        "allowedCidr": "0.0.0.0/0"
      },
      {
        "type": "Ingress",
        "protocol": "TCP",
        "startPort": 80,
        "endPort": 80,
        "allowedCidr": "0.0.0.0/0"
      },
      {
        "type": "Ingress",
        "protocol": "TCP",
        "startPort": 443,
        "endPort": 443,
        "allowedCidr": "0.0.0.0/0"
      }
    ]
  }
}
```

### 规则参数

| 参数 | 说明 | 可选值 |
|------|------|--------|
| type | 规则类型 | Ingress（入站）, Egress（出站） |
| protocol | 协议 | TCP, UDP, ICMP, ALL |
| startPort | 起始端口 | 1-65535 |
| endPort | 结束端口 | 1-65535 |
| allowedCidr | 允许的 CIDR | 如 0.0.0.0/0 |
| remoteSecurityGroupUuid | 允许的安全组 | 安全组 UUID |

### 常用安全组规则模板

```bash
# SSH 访问
{
  "type": "Ingress",
  "protocol": "TCP",
  "startPort": 22,
  "endPort": 22,
  "allowedCidr": "10.0.0.0/8"
}

# HTTP/HTTPS
{
  "type": "Ingress",
  "protocol": "TCP",
  "startPort": 80,
  "endPort": 80,
  "allowedCidr": "0.0.0.0/0"
}

# MySQL
{
  "type": "Ingress",
  "protocol": "TCP",
  "startPort": 3306,
  "endPort": 3306,
  "remoteSecurityGroupUuid": "<app-sg-uuid>"
}

# 允许 Ping
{
  "type": "Ingress",
  "protocol": "ICMP",
  "startPort": -1,
  "endPort": -1,
  "allowedCidr": "0.0.0.0/0"
}

# 允许所有出站
{
  "type": "Egress",
  "protocol": "ALL",
  "startPort": -1,
  "endPort": -1,
  "allowedCidr": "0.0.0.0/0"
}
```

### 删除安全组规则

```bash
DELETE /v1/security-groups/rules?ruleUuids=<rule-uuid1>,<rule-uuid2>
```

### 将安全组绑定到网卡

```bash
# 绑定
POST /v1/security-groups/<sg-uuid>/vm-nics

{
  "params": {
    "vmNicUuids": ["<nic-uuid1>", "<nic-uuid2>"]
  }
}

# 解绑
DELETE /v1/security-groups/<sg-uuid>/vm-nics?vmNicUuids=<nic-uuid>
```

### 将安全组绑定到 L3 网络

```bash
# 绑定（该网络上的所有网卡自动应用此安全组）
POST /v1/security-groups/<sg-uuid>/l3-networks/<l3-uuid>

# 解绑
DELETE /v1/security-groups/<sg-uuid>/l3-networks/<l3-uuid>
```

### 删除安全组

```bash
DELETE /v1/security-groups/<sg-uuid>
```

## 4. 弹性 IP (EIP) 管理

EIP 提供公网访问能力，可以动态绑定到云主机。

### 创建 EIP

```bash
POST /v1/eips

{
  "params": {
    "name": "web-eip",
    "description": "EIP for web server",
    "vipUuid": "<vip-uuid>"
  }
}
```

### 创建 VIP（虚拟 IP）

EIP 需要先创建 VIP：

```bash
POST /v1/vips

{
  "params": {
    "name": "public-vip",
    "l3NetworkUuid": "<public-l3-uuid>",
    "requiredIp": "203.0.113.10"  # 可选，指定 IP
  }
}
```

### 查询 EIP

```bash
# 查询所有 EIP
GET /v1/eips

# 查询可用的 EIP
GET /v1/eips?q=vmNicUuid=null

# 查询单个 EIP
GET /v1/eips/<eip-uuid>
```

### 绑定 EIP 到云主机

```bash
PUT /v1/eips/<eip-uuid>/actions

{
  "attachEip": {
    "vmNicUuid": "<vm-nic-uuid>"
  }
}
```

### 解绑 EIP

```bash
PUT /v1/eips/<eip-uuid>/actions

{
  "detachEip": {}
}
```

### 更新 EIP

```bash
PUT /v1/eips/<eip-uuid>

{
  "updateEip": {
    "name": "new-name",
    "description": "new description"
  }
}
```

### 删除 EIP

```bash
DELETE /v1/eips/<eip-uuid>
```

## 5. 端口转发

端口转发允许将公网端口映射到内网云主机。

### 创建端口转发规则

```bash
POST /v1/port-forwarding

{
  "params": {
    "name": "ssh-forward",
    "vipUuid": "<vip-uuid>",
    "vipPortStart": 2222,
    "vipPortEnd": 2222,
    "privatePortStart": 22,
    "privatePortEnd": 22,
    "protocolType": "TCP",
    "vmNicUuid": "<vm-nic-uuid>"
  }
}
```

### 查询端口转发规则

```bash
GET /v1/port-forwarding
```

### 删除端口转发规则

```bash
DELETE /v1/port-forwarding/<rule-uuid>
```

## 6. VPC 网络

VPC 提供隔离的网络环境。

### 创建 VPC 路由器

```bash
POST /v1/vpc/virtual-routers

{
  "params": {
    "name": "vpc-router-1",
    "virtualRouterOfferingUuid": "<vr-offering-uuid>"
  }
}
```

### 创建 VPC 网络

```bash
POST /v1/l3-networks

{
  "params": {
    "name": "vpc-subnet-1",
    "type": "L3VpcNetwork",
    "l2NetworkUuid": "<l2-uuid>",
    "category": "Private"
  },
  "systemTags": [
    "virtualRouterUuid::<vr-uuid>"
  ]
}
```

## 7. 常用操作示例

### 创建完整的网络环境

```bash
#!/bin/bash

# 1. 创建安全组
SG_UUID=$(curl -s -X POST "$ZSTACK_API/security-groups" \
  -H "Authorization: OAuth $SESSION" \
  -H "Content-Type: application/json" \
  -d '{"params":{"name":"default-sg"}}' | jq -r '.inventory.uuid')

# 2. 添加基本规则
curl -X POST "$ZSTACK_API/security-groups/$SG_UUID/rules" \
  -H "Authorization: OAuth $SESSION" \
  -H "Content-Type: application/json" \
  -d '{
    "params": {
      "rules": [
        {"type":"Ingress","protocol":"TCP","startPort":22,"endPort":22,"allowedCidr":"0.0.0.0/0"},
        {"type":"Ingress","protocol":"ICMP","startPort":-1,"endPort":-1,"allowedCidr":"0.0.0.0/0"},
        {"type":"Egress","protocol":"ALL","startPort":-1,"endPort":-1,"allowedCidr":"0.0.0.0/0"}
      ]
    }
  }'

# 3. 绑定安全组到网络
curl -X POST "$ZSTACK_API/security-groups/$SG_UUID/l3-networks/$L3_UUID" \
  -H "Authorization: OAuth $SESSION"
```

### 为云主机配置公网访问

```bash
#!/bin/bash

# 1. 创建 VIP
VIP_UUID=$(curl -s -X POST "$ZSTACK_API/vips" \
  -H "Authorization: OAuth $SESSION" \
  -H "Content-Type: application/json" \
  -d '{"params":{"name":"web-vip","l3NetworkUuid":"'$PUBLIC_L3_UUID'"}}' \
  | jq -r '.inventory.uuid')

# 2. 创建 EIP
EIP_UUID=$(curl -s -X POST "$ZSTACK_API/eips" \
  -H "Authorization: OAuth $SESSION" \
  -H "Content-Type: application/json" \
  -d '{"params":{"name":"web-eip","vipUuid":"'$VIP_UUID'"}}' \
  | jq -r '.inventory.uuid')

# 3. 绑定到云主机网卡
curl -X PUT "$ZSTACK_API/eips/$EIP_UUID/actions" \
  -H "Authorization: OAuth $SESSION" \
  -H "Content-Type: application/json" \
  -d '{"attachEip":{"vmNicUuid":"'$VM_NIC_UUID'"}}'
```

## 8. 最佳实践

### 网络规划

1. **CIDR 规划**：提前规划好 IP 地址段，避免冲突
2. **网络隔离**：不同业务使用不同网络
3. **预留地址**：为网关、DNS 等预留 IP

### 安全组策略

1. **最小权限**：只开放必要的端口
2. **分层设计**：Web、App、DB 使用不同安全组
3. **使用安全组引用**：内部通信使用安全组而非 CIDR
4. **定期审计**：检查并清理不需要的规则

### EIP 管理

1. **按需分配**：不使用时及时释放
2. **绑定记录**：记录 EIP 与云主机的对应关系
3. **监控流量**：关注 EIP 的流量使用

## 参考链接

- [L3 网络 API](https://www.zstack.io/help/dev_manual/dev_guide/v5/v5_l3_network/)
- [安全组 API](https://www.zstack.io/help/dev_manual/dev_guide/v5/v5_security_group/)
- [EIP API](https://www.zstack.io/help/dev_manual/dev_guide/v5/v5_eip/)
