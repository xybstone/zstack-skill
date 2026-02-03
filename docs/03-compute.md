# ZStack 计算资源管理

本文档涵盖云主机（VM）、镜像（Image）和计算规格（Instance Offering）的管理。

## 1. 云主机管理

### 云主机状态

| 状态 | 说明 |
|------|------|
| Creating | 创建中 |
| Starting | 启动中 |
| Running | 运行中 |
| Stopping | 停止中 |
| Stopped | 已停止 |
| Migrating | 迁移中 |
| Rebooting | 重启中 |
| Destroyed | 已销毁 |
| Expunging | 彻底删除中 |
| Error | 错误 |
| Unknown | 未知 |

### 创建云主机

```bash
POST /v1/vm-instances

{
  "params": {
    "name": "my-vm",
    "description": "Test VM",
    "instanceOfferingUuid": "<instance-offering-uuid>",
    "imageUuid": "<image-uuid>",
    "l3NetworkUuids": ["<l3-network-uuid>"],
    "dataDiskOfferingUuids": ["<disk-offering-uuid>"],  # 可选，创建时附加数据盘
    "rootDiskOfferingUuid": "<disk-offering-uuid>",     # 可选，指定根盘规格
    "zoneUuid": "<zone-uuid>",                          # 可选，指定区域
    "clusterUuid": "<cluster-uuid>",                    # 可选，指定集群
    "hostUuid": "<host-uuid>",                          # 可选，指定物理机
    "defaultL3NetworkUuid": "<l3-network-uuid>",        # 可选，默认网络
    "strategy": "InstantStart"                          # 创建后立即启动
  },
  "systemTags": [
    "hostname::my-hostname",                            # 设置主机名
    "sshkey::ssh-rsa AAAA...",                         # 注入 SSH 公钥
    "consolePassword::password123"                      # 设置控制台密码
  ]
}
```

### 创建策略

| 策略 | 说明 |
|------|------|
| InstantStart | 创建后立即启动（默认） |
| CreateStopped | 创建后保持停止状态 |
| JustCreate | 仅创建，不分配资源 |

### 查询云主机

```bash
# 查询所有云主机
GET /v1/vm-instances

# 带条件查询
GET /v1/vm-instances?q=state=Running&q=name?=%test%

# 查询单个云主机
GET /v1/vm-instances/<vm-uuid>

# 查询云主机的网卡
GET /v1/vm-instances/<vm-uuid>/vm-nics

# 查询云主机的云盘
GET /v1/vm-instances/<vm-uuid>/volumes
```

### 云主机生命周期操作

```bash
# 启动云主机
PUT /v1/vm-instances/<vm-uuid>/actions
{
  "startVmInstance": {}
}

# 停止云主机
PUT /v1/vm-instances/<vm-uuid>/actions
{
  "stopVmInstance": {
    "type": "grace"  # grace(优雅停止) 或 cold(强制停止)
  }
}

# 重启云主机
PUT /v1/vm-instances/<vm-uuid>/actions
{
  "rebootVmInstance": {}
}

# 暂停云主机
PUT /v1/vm-instances/<vm-uuid>/actions
{
  "pauseVmInstance": {}
}

# 恢复暂停的云主机
PUT /v1/vm-instances/<vm-uuid>/actions
{
  "resumeVmInstance": {}
}

# 删除云主机（进入回收站）
DELETE /v1/vm-instances/<vm-uuid>

# 恢复已删除的云主机
PUT /v1/vm-instances/<vm-uuid>/actions
{
  "recoverVmInstance": {}
}

# 彻底删除云主机
DELETE /v1/vm-instances/<vm-uuid>?deleteMode=Enforcing
```

### 更新云主机

```bash
PUT /v1/vm-instances/<vm-uuid>

{
  "updateVmInstance": {
    "name": "new-name",
    "description": "new description",
    "state": "Stopped",           # 可以通过更新状态来启停
    "cpuNum": 4,                  # 在线调整 CPU（需要支持）
    "memorySize": 8589934592      # 在线调整内存（需要支持）
  }
}
```

### 云主机迁移

```bash
# 迁移到指定物理机
PUT /v1/vm-instances/<vm-uuid>/actions
{
  "migrateVm": {
    "hostUuid": "<target-host-uuid>"
  }
}

# 获取可迁移的目标物理机列表
GET /v1/vm-instances/<vm-uuid>/migration-targets
```

### 云主机控制台

```bash
# 获取 VNC 控制台地址
GET /v1/vm-instances/<vm-uuid>/console-addresses

# 设置控制台密码
PUT /v1/vm-instances/<vm-uuid>/actions
{
  "setVmConsolePassword": {
    "consolePassword": "newpassword"
  }
}
```

### 云主机快照

```bash
# 创建云主机快照（包含所有云盘）
POST /v1/vm-instances/<vm-uuid>/volume-snapshots

{
  "params": {
    "name": "vm-snapshot-1",
    "description": "Full VM snapshot"
  }
}
```

## 2. 镜像管理

### 镜像类型

| 类型 | 说明 |
|------|------|
| RootVolumeTemplate | 根盘镜像，用于创建云主机 |
| DataVolumeTemplate | 数据盘镜像 |
| ISO | ISO 镜像，用于安装系统 |

### 镜像格式

| 格式 | 说明 |
|------|------|
| qcow2 | QEMU Copy-On-Write 格式（推荐） |
| raw | 原始格式 |
| vmdk | VMware 格式 |
| iso | ISO 光盘格式 |

### 添加镜像

```bash
# 从 URL 添加镜像
POST /v1/images

{
  "params": {
    "name": "ubuntu-22.04",
    "description": "Ubuntu 22.04 LTS",
    "url": "http://example.com/ubuntu-22.04.qcow2",
    "format": "qcow2",
    "mediaType": "RootVolumeTemplate",
    "platform": "Linux",
    "architecture": "x86_64",
    "guestOsType": "Ubuntu",
    "backupStorageUuids": ["<backup-storage-uuid>"]
  },
  "systemTags": [
    "qemuga",                    # 启用 QEMU Guest Agent
    "bootMode::UEFI"             # 启动模式：Legacy 或 UEFI
  ]
}

# 从云盘创建镜像
POST /v1/images/root-volume-templates/from/volumes/<volume-uuid>

{
  "params": {
    "name": "image-from-volume",
    "backupStorageUuids": ["<backup-storage-uuid>"]
  }
}
```

### 查询镜像

```bash
# 查询所有镜像
GET /v1/images

# 按条件查询
GET /v1/images?q=platform=Linux&q=state=Enabled

# 查询镜像详情
GET /v1/images/<image-uuid>
```

### 镜像操作

```bash
# 更新镜像信息
PUT /v1/images/<image-uuid>
{
  "updateImage": {
    "name": "new-name",
    "description": "new description",
    "guestOsType": "CentOS"
  }
}

# 启用/禁用镜像
PUT /v1/images/<image-uuid>/actions
{
  "changeImageState": {
    "stateEvent": "enable"  # enable 或 disable
  }
}

# 删除镜像
DELETE /v1/images/<image-uuid>

# 彻底删除镜像
DELETE /v1/images/<image-uuid>?deleteMode=Enforcing

# 导出镜像
GET /v1/images/<image-uuid>/actions
{
  "exportImage": {
    "backupStorageUuid": "<backup-storage-uuid>"
  }
}
```

### 镜像同步

```bash
# 同步镜像到其他备份存储
POST /v1/images/<image-uuid>/backup-storage/<backup-storage-uuid>

# 从备份存储删除镜像
DELETE /v1/images/<image-uuid>/backup-storage/<backup-storage-uuid>
```

## 3. 计算规格管理

计算规格（Instance Offering）定义了云主机的 CPU、内存等配置。

### 创建计算规格

```bash
POST /v1/instance-offerings

{
  "params": {
    "name": "2C4G",
    "description": "2 vCPU, 4GB RAM",
    "cpuNum": 2,
    "memorySize": 4294967296,      # 4GB in bytes
    "type": "UserVm",
    "allocatorStrategy": "DefaultHostAllocatorStrategy"
  },
  "systemTags": [
    "userdata::true"               # 允许使用 userdata
  ]
}
```

### 计算规格类型

| 类型 | 说明 |
|------|------|
| UserVm | 用户云主机（默认） |
| VirtualRouter | 虚拟路由器 |

### 查询计算规格

```bash
# 查询所有计算规格
GET /v1/instance-offerings

# 查询可用的计算规格
GET /v1/instance-offerings?q=state=Enabled

# 查询单个计算规格
GET /v1/instance-offerings/<offering-uuid>
```

### 更新计算规格

```bash
PUT /v1/instance-offerings/<offering-uuid>

{
  "updateInstanceOffering": {
    "name": "new-name",
    "cpuNum": 4,
    "memorySize": 8589934592
  }
}
```

### 启用/禁用计算规格

```bash
PUT /v1/instance-offerings/<offering-uuid>/actions

{
  "changeInstanceOfferingState": {
    "stateEvent": "enable"  # enable 或 disable
  }
}
```

### 删除计算规格

```bash
DELETE /v1/instance-offerings/<offering-uuid>
```

## 4. 常用系统标签

### 云主机相关

| 标签 | 说明 | 示例 |
|------|------|------|
| hostname | 设置主机名 | `hostname::my-host` |
| sshkey | 注入 SSH 公钥 | `sshkey::ssh-rsa AAAA...` |
| consolePassword | 控制台密码 | `consolePassword::pass123` |
| usbRedirect | USB 重定向 | `usbRedirect::true` |
| vmPriority | 云主机优先级 | `vmPriority::high` |
| cleanTraffic | 清理流量 | `cleanTraffic::true` |

### 镜像相关

| 标签 | 说明 | 示例 |
|------|------|------|
| qemuga | 启用 QEMU GA | `qemuga` |
| bootMode | 启动模式 | `bootMode::UEFI` |
| virtio | 使用 virtio 驱动 | `virtio::true` |

## 5. 最佳实践

### 云主机创建建议

1. **选择合适的计算规格**：根据业务需求选择 CPU 和内存
2. **使用 SSH 密钥**：比密码更安全
3. **设置主机名**：便于管理和识别
4. **选择正确的网络**：确保网络连通性

### 镜像管理建议

1. **使用 qcow2 格式**：支持快照和稀疏分配
2. **启用 QEMU GA**：支持更多管理功能
3. **定期清理**：删除不再使用的镜像
4. **多备份存储**：重要镜像同步到多个存储

### 计算规格建议

1. **标准化命名**：如 2C4G、4C8G
2. **预定义常用规格**：减少创建时的选择
3. **禁用而非删除**：保留历史记录

## 参考链接

- [云主机 API](https://www.zstack.io/help/dev_manual/dev_guide/v5/v5_vm/)
- [镜像 API](https://www.zstack.io/help/dev_manual/dev_guide/v5/v5_image/)
- [计算规格 API](https://www.zstack.io/help/dev_manual/dev_guide/v5/v5_instance_offering/)
