# ZStack 认证机制

ZStack 提供多种认证方式，支持不同的使用场景。

## 认证方式概览

| 认证方式 | 适用场景 | 安全级别 |
|---------|---------|---------|
| Session 认证 | 交互式操作、Web UI | 中 |
| AccessKey 认证 | API 调用、自动化脚本 | 高 |
| OAuth2 认证 | 第三方集成 | 高 |

## 1. Session 认证

### 登录获取 Session

```bash
POST /v1/accounts/login

{
  "logInByAccount": {
    "accountName": "admin",
    "password": "password"
  }
}
```

### 响应

```json
{
  "inventory": {
    "uuid": "session-uuid",
    "accountUuid": "account-uuid",
    "userUuid": "user-uuid",
    "expiredDate": "2026-02-04T11:00:00.000+08:00"
  }
}
```

### 使用 Session

```bash
# 在请求头中携带 Session
Authorization: OAuth <session-uuid>
```

### 登出

```bash
DELETE /v1/accounts/sessions/<session-uuid>
```

### Session 特点

- 有过期时间（默认 24 小时）
- 可以手动续期
- 适合短期交互操作

## 2. AccessKey 认证

AccessKey 是更安全的认证方式，适合长期运行的自动化脚本。

### 创建 AccessKey

```bash
POST /v1/accounts/access-keys

{
  "params": {
    "userUuid": "user-uuid",
    "description": "API automation key"
  }
}
```

### 响应

```json
{
  "inventory": {
    "uuid": "accesskey-uuid",
    "accessKeyId": "AK_xxxxxxxxxxxxxxxx",
    "accessKeySecret": "SK_xxxxxxxxxxxxxxxxxxxxxxxx",
    "userUuid": "user-uuid",
    "state": "Enabled"
  }
}
```

> ⚠️ **重要**：AccessKeySecret 只在创建时返回一次，请妥善保存！

### 使用 AccessKey 签名请求

AccessKey 认证需要对请求进行签名：

```python
import hmac
import hashlib
import base64
import time

def sign_request(access_key_id, access_key_secret, method, path, params=None):
    """生成 ZStack API 签名"""
    timestamp = str(int(time.time() * 1000))
    
    # 构建签名字符串
    string_to_sign = f"{method}\n{path}\n{timestamp}"
    if params:
        sorted_params = sorted(params.items())
        param_str = "&".join([f"{k}={v}" for k, v in sorted_params])
        string_to_sign += f"\n{param_str}"
    
    # HMAC-SHA256 签名
    signature = hmac.new(
        access_key_secret.encode('utf-8'),
        string_to_sign.encode('utf-8'),
        hashlib.sha256
    ).digest()
    
    return base64.b64encode(signature).decode('utf-8'), timestamp
```

### 请求头格式

```http
Authorization: ZStack <access-key-id>:<signature>
Date: <timestamp>
```

### 管理 AccessKey

```bash
# 查询 AccessKey
GET /v1/accounts/access-keys?q=userUuid=<user-uuid>

# 禁用 AccessKey
PUT /v1/accounts/access-keys/<accesskey-uuid>/actions
{
  "changeAccessKeyState": {
    "stateEvent": "disable"
  }
}

# 删除 AccessKey
DELETE /v1/accounts/access-keys/<accesskey-uuid>
```

## 3. 账户与用户管理

### 账户层级

```
Account (账户)
├── User (用户)
│   ├── AccessKey
│   └── Session
└── User (用户)
    ├── AccessKey
    └── Session
```

### 创建账户

```bash
POST /v1/accounts

{
  "params": {
    "name": "tenant1",
    "password": "password123",
    "type": "Normal"
  }
}
```

### 账户类型

| 类型 | 说明 |
|------|------|
| SystemAdmin | 系统管理员，拥有所有权限 |
| Normal | 普通账户，权限受限 |

### 创建用户

```bash
POST /v1/accounts/users

{
  "params": {
    "name": "operator",
    "password": "password123",
    "accountUuid": "account-uuid"
  }
}
```

## 4. 权限控制

### 策略 (Policy)

策略定义了用户可以执行的操作：

```bash
POST /v1/accounts/policies

{
  "params": {
    "name": "vm-operator",
    "accountUuid": "account-uuid",
    "statements": [
      {
        "effect": "Allow",
        "actions": [
          "instance:APIQueryVmInstance",
          "instance:APIStartVmInstance",
          "instance:APIStopVmInstance"
        ]
      }
    ]
  }
}
```

### 将策略绑定到用户

```bash
POST /v1/accounts/users/<user-uuid>/policies

{
  "params": {
    "policyUuid": "policy-uuid"
  }
}
```

### 策略效果

| Effect | 说明 |
|--------|------|
| Allow | 允许执行 |
| Deny | 拒绝执行（优先级高于 Allow） |

## 5. 配额管理

限制账户可使用的资源量：

```bash
POST /v1/accounts/quotas

{
  "params": {
    "identityUuid": "account-uuid",
    "name": "vm.num",
    "value": 100
  }
}
```

### 常用配额项

| 配额名 | 说明 |
|--------|------|
| vm.num | 云主机数量 |
| vm.cpuNum | CPU 核数总量 |
| vm.memorySize | 内存总量 (bytes) |
| volume.data.num | 数据盘数量 |
| volume.data.size | 数据盘总容量 |
| eip.num | 弹性 IP 数量 |

## 6. 最佳实践

### 安全建议

1. **生产环境使用 AccessKey**：避免使用账户密码
2. **定期轮换密钥**：定期更换 AccessKey
3. **最小权限原则**：只授予必要的权限
4. **审计日志**：开启操作审计

### 自动化脚本模板

```bash
#!/bin/bash

# ZStack API 配置
ZSTACK_API="http://zstack-server:8080/zstack/v1"
ACCESS_KEY_ID="AK_xxxxxxxx"
ACCESS_KEY_SECRET="SK_xxxxxxxx"

# 生成签名并调用 API
call_api() {
    local method=$1
    local path=$2
    local data=$3
    
    # 签名逻辑...
    
    curl -X "$method" \
        -H "Authorization: ZStack $ACCESS_KEY_ID:$signature" \
        -H "Date: $timestamp" \
        -H "Content-Type: application/json" \
        -d "$data" \
        "$ZSTACK_API$path"
}

# 示例：查询云主机
call_api GET "/vm-instances" ""
```

## 参考链接

- [ZStack 认证文档](https://www.zstack.io/help/dev_manual/dev_guide/v5/v5_api_framework/4.html)
- [AccessKey 管理](https://www.zstack.io/help/dev_manual/dev_guide/v5/v5_api_framework/5.html)
