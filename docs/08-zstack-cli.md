# ZStack CLI 工具使用指南

`zstack-cli` 是 ZStack 云平台的命令行管理工具，是 ZStack REST API 的封装，比直接调用 API 更方便。

## 1. 关键规则

1. **必须使用 JSON 格式输出**：始终添加 `-j` 参数
2. **非交互模式**：直接以单行命令执行，不要进入交互式 shell
3. **参数格式**：参数名区分大小写（驼峰命名，如 `imageUuid`）

## 2. 基础语法

```bash
zstack-cli -j [API名称] [参数1=值1] [参数2=值2] ...
```

| 组件 | 说明 |
|------|------|
| `-j` | 强制返回 JSON 格式结果（必须项） |
| API名称 | ZStack 的 API 动作，如 `QueryVmInstance`, `StartVmInstance` |
| 参数 | 键值对，列表类型用逗号分隔，如 `uuids=uuid1,uuid2` |

## 3. 核心工作流

### 3.1 认证 (Authentication)

在执行任何操作前，必须先登录获取 Session。

```bash
# 登录
zstack-cli -j LogInByAccount accountName=admin password=password
```

> **注意**：CLI 会自动将 SessionID 保存到本地文件，后续命令无需再次输入用户名密码。

### 3.2 资源查询 (Query)

ZStack 拥有强大的 Query API（以 `Query` 开头）。

#### Conditions 语法

| 操作符 | 说明 | 示例 |
|--------|------|------|
| `=` | 等于 | `state=Running` |
| `!=` | 不等于 | `state!=Stopped` |
| `~=` | LIKE 模糊匹配 | `name~=web-server` |
| `>` | 大于 | `cpuNum>2` |
| `<` | 小于 | `memorySize<4294967296` |
| `in` | 包含 | `state in Stopped,Running` |

多个条件用 `;` 分隔。

#### 查询示例

```bash
# 查找所有运行中的虚拟机
zstack-cli -j QueryVmInstance conditions="state=Running"

# 查找名字包含 "test" 且 CPU 大于 2 核的云主机
zstack-cli -j QueryVmInstance conditions="name~=test;cpuNum>2"

# 查询所有镜像
zstack-cli -j QueryImage

# 查询计算规格
zstack-cli -j QueryInstanceOffering

# 查询网络
zstack-cli -j QueryL3Network

# 查询云盘
zstack-cli -j QueryVolume
```

### 3.3 资源操作 (Actions)

执行具体动作，如创建、启动、停止、删除。

```bash
# 启动云主机
zstack-cli -j StartVmInstance vmInstanceUuid=6177d853765147368532457813134629

# 停止云主机
zstack-cli -j StopVmInstance vmInstanceUuid=6177d853765147368532457813134629

# 重启云主机
zstack-cli -j RebootVmInstance vmInstanceUuid=6177d853765147368532457813134629

# 删除云主机
zstack-cli -j DestroyVmInstance vmInstanceUuid=6177d853765147368532457813134629

# 创建数据云盘
zstack-cli -j CreateDataVolume name=data-vol-1 diskOfferingUuid=[UUID] primaryStorageUuid=[UUID]

# 创建快照
zstack-cli -j CreateVolumeSnapshot volumeUuid=[UUID] name=snapshot-1
```

## 4. 结果解析

### 成功响应

```json
{
  "status": "success",
  "success": true,
  "inventory": { ... }    // 单个资源
  // 或
  "inventories": [ ... ]  // 资源列表
}
```

### 失败响应

```json
{
  "status": "failure",
  "success": false,
  "error": {
    "code": "SYS.1006",
    "description": "...",
    "details": "..."
  }
}
```

## 5. 常用 API 列表

### 云主机

| API | 说明 |
|-----|------|
| `QueryVmInstance` | 查询云主机 |
| `CreateVmInstance` | 创建云主机 |
| `StartVmInstance` | 启动云主机 |
| `StopVmInstance` | 停止云主机 |
| `RebootVmInstance` | 重启云主机 |
| `DestroyVmInstance` | 删除云主机 |
| `RecoverVmInstance` | 恢复云主机 |
| `MigrateVm` | 迁移云主机 |

### 云盘

| API | 说明 |
|-----|------|
| `QueryVolume` | 查询云盘 |
| `CreateDataVolume` | 创建数据盘 |
| `AttachDataVolumeToVm` | 挂载云盘 |
| `DetachDataVolumeFromVm` | 卸载云盘 |
| `DeleteDataVolume` | 删除云盘 |
| `ResizeDataVolume` | 扩容云盘 |

### 快照

| API | 说明 |
|-----|------|
| `QueryVolumeSnapshot` | 查询快照 |
| `CreateVolumeSnapshot` | 创建快照 |
| `DeleteVolumeSnapshot` | 删除快照 |
| `RevertVolumeFromSnapshot` | 回滚快照 |

### 镜像

| API | 说明 |
|-----|------|
| `QueryImage` | 查询镜像 |
| `AddImage` | 添加镜像 |
| `DeleteImage` | 删除镜像 |
| `ExpungeImage` | 彻底删除镜像 |

### 网络

| API | 说明 |
|-----|------|
| `QueryL3Network` | 查询 L3 网络 |
| `QuerySecurityGroup` | 查询安全组 |
| `CreateSecurityGroup` | 创建安全组 |
| `AddSecurityGroupRule` | 添加安全组规则 |
| `QueryEip` | 查询 EIP |
| `CreateEip` | 创建 EIP |
| `AttachEip` | 绑定 EIP |
| `DetachEip` | 解绑 EIP |

### 规格

| API | 说明 |
|-----|------|
| `QueryInstanceOffering` | 查询计算规格 |
| `QueryDiskOffering` | 查询云盘规格 |

## 6. 实战示例

### 创建云主机完整流程

```bash
# 1. 查询计算规格（找 2核4G）
zstack-cli -j QueryInstanceOffering conditions="cpuNum=2;memorySize=4294967296"

# 2. 查询镜像（找 CentOS 7）
zstack-cli -j QueryImage conditions="name~=CentOS"

# 3. 查询网络
zstack-cli -j QueryL3Network

# 4. 创建云主机
zstack-cli -j CreateVmInstance \
  name=my-vm \
  instanceOfferingUuid=[规格UUID] \
  imageUuid=[镜像UUID] \
  l3NetworkUuids=[网络UUID]
```

### 批量操作

```bash
# 批量启动云主机
zstack-cli -j StartVmInstance vmInstanceUuid=uuid1
zstack-cli -j StartVmInstance vmInstanceUuid=uuid2

# 查询并操作
for uuid in $(zstack-cli -j QueryVmInstance conditions="state=Stopped" | jq -r '.inventories[].uuid'); do
  zstack-cli -j StartVmInstance vmInstanceUuid=$uuid
done
```

## 7. 错误处理

| 错误码 | 说明 | 处理方式 |
|--------|------|---------|
| `ID.1001` | Session 过期 | 重新执行 `LogInByAccount` |
| `SYS.1006` | 参数错误 | 检查参数名和值 |
| `SYS.1007` | API 不存在 | 检查 API 名称拼写 |

## 8. 环境配置

CLI 默认连接本地 ZStack，如需连接远程：

```bash
# 设置 API 端点
export ZSTACK_BUILT_IN_HTTP_SERVER_IP=172.26.100.11
export ZSTACK_BUILT_IN_HTTP_SERVER_PORT=8080

# 或在命令中指定
zstack-cli -j -H 172.26.100.11:8080 LogInByAccount accountName=admin password=password
```

## 参考

- CLI 是 API 的封装，所有 API 文档同样适用
- API 名称通常是 `动词+名词`，如 `Create` + `VmInstance`
