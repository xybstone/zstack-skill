# ZStack 存储资源管理

本文档涵盖云盘（Volume）、快照（Snapshot）和云盘规格（Disk Offering）的管理。

## 1. 云盘管理

### 云盘类型

| 类型 | 说明 |
|------|------|
| Root | 根盘，随云主机创建 |
| Data | 数据盘，可独立创建和挂载 |

### 云盘状态

| 状态 | 说明 |
|------|------|
| Creating | 创建中 |
| Ready | 就绪，可使用 |
| NotInstantiated | 未实例化 |
| Deleted | 已删除（在回收站） |
| Expunged | 已彻底删除 |

### 创建数据盘

```bash
# 从云盘规格创建
POST /v1/volumes/data

{
  "params": {
    "name": "data-disk-1",
    "description": "Data disk for database",
    "diskOfferingUuid": "<disk-offering-uuid>",
    "primaryStorageUuid": "<primary-storage-uuid>"  # 可选，指定存储
  }
}

# 从快照创建
POST /v1/volumes/data/from/volume-snapshots/<snapshot-uuid>

{
  "params": {
    "name": "disk-from-snapshot",
    "primaryStorageUuid": "<primary-storage-uuid>"
  }
}

# 从镜像创建
POST /v1/volumes/data/from/images/<image-uuid>

{
  "params": {
    "name": "disk-from-image",
    "primaryStorageUuid": "<primary-storage-uuid>"
  }
}
```

### 查询云盘

```bash
# 查询所有云盘
GET /v1/volumes

# 按类型查询
GET /v1/volumes?q=type=Data

# 查询已挂载的云盘
GET /v1/volumes?q=vmInstanceUuid!=null

# 查询未挂载的云盘
GET /v1/volumes?q=vmInstanceUuid=null&q=type=Data

# 查询单个云盘
GET /v1/volumes/<volume-uuid>
```

### 云盘挂载与卸载

```bash
# 挂载云盘到云主机
POST /v1/volumes/<volume-uuid>/vm-instances/<vm-uuid>

# 卸载云盘
DELETE /v1/volumes/<volume-uuid>/vm-instances

# 强制卸载（云主机运行中）
DELETE /v1/volumes/<volume-uuid>/vm-instances?detachMode=force
```

### 云盘扩容

```bash
PUT /v1/volumes/<volume-uuid>/actions

{
  "resizeDataVolume": {
    "size": 107374182400  # 新大小，单位 bytes (100GB)
  }
}

# 扩容根盘
PUT /v1/volumes/<volume-uuid>/actions

{
  "resizeRootVolume": {
    "size": 53687091200  # 50GB
  }
}
```

> ⚠️ **注意**：云盘只能扩容，不能缩容。扩容后需要在操作系统内扩展文件系统。

### 更新云盘

```bash
PUT /v1/volumes/<volume-uuid>

{
  "updateVolume": {
    "name": "new-name",
    "description": "new description"
  }
}
```

### 删除云盘

```bash
# 删除云盘（进入回收站）
DELETE /v1/volumes/<volume-uuid>

# 彻底删除
DELETE /v1/volumes/<volume-uuid>?deleteMode=Enforcing

# 恢复已删除的云盘
PUT /v1/volumes/<volume-uuid>/actions
{
  "recoverDataVolume": {}
}
```

### 云盘迁移

```bash
# 迁移到其他主存储
PUT /v1/volumes/<volume-uuid>/actions

{
  "localStorageMigrateVolume": {
    "destHostUuid": "<target-host-uuid>"
  }
}
```

## 2. 快照管理

### 快照类型

| 类型 | 说明 |
|------|------|
| 云盘快照 | 单个云盘的快照 |
| 云主机快照 | 包含所有云盘的快照组 |

### 创建快照

```bash
# 创建云盘快照
POST /v1/volumes/<volume-uuid>/volume-snapshots

{
  "params": {
    "name": "snapshot-1",
    "description": "Daily backup"
  }
}

# 创建云主机快照（快照组）
POST /v1/vm-instances/<vm-uuid>/volume-snapshots

{
  "params": {
    "name": "vm-snapshot-1",
    "description": "Full VM snapshot"
  }
}
```

### 查询快照

```bash
# 查询所有快照
GET /v1/volume-snapshots

# 查询某个云盘的快照
GET /v1/volume-snapshots?q=volumeUuid=<volume-uuid>

# 查询快照树
GET /v1/volume-snapshots/<snapshot-uuid>/trees

# 查询快照详情
GET /v1/volume-snapshots/<snapshot-uuid>
```

### 快照操作

```bash
# 回滚快照（恢复云盘到快照状态）
PUT /v1/volume-snapshots/<snapshot-uuid>/actions

{
  "revertVolumeFromSnapshot": {}
}

# 从快照创建云盘
POST /v1/volumes/data/from/volume-snapshots/<snapshot-uuid>

{
  "params": {
    "name": "volume-from-snapshot",
    "primaryStorageUuid": "<primary-storage-uuid>"
  }
}

# 从快照创建镜像
POST /v1/images/root-volume-templates/from/volume-snapshots/<snapshot-uuid>

{
  "params": {
    "name": "image-from-snapshot",
    "backupStorageUuids": ["<backup-storage-uuid>"]
  }
}
```

### 删除快照

```bash
# 删除单个快照
DELETE /v1/volume-snapshots/<snapshot-uuid>

# 删除快照及其所有子快照
DELETE /v1/volume-snapshots/<snapshot-uuid>?deleteMode=Enforcing
```

### 快照策略（自动快照）

```bash
# 创建快照策略
POST /v1/volume-snapshot-schedulers

{
  "params": {
    "volumeUuid": "<volume-uuid>",
    "schedulerName": "daily-backup",
    "schedulerType": "simple",
    "schedulerInterval": 86400,        # 间隔秒数（24小时）
    "repeatCount": -1,                  # -1 表示无限重复
    "snapshotMaxNum": 7                 # 保留最近 7 个快照
  }
}

# 使用 cron 表达式
POST /v1/volume-snapshot-schedulers

{
  "params": {
    "volumeUuid": "<volume-uuid>",
    "schedulerName": "weekly-backup",
    "schedulerType": "cron",
    "cronScheduler": "0 0 2 ? * SUN",  # 每周日凌晨 2 点
    "snapshotMaxNum": 4
  }
}

# 查询快照策略
GET /v1/volume-snapshot-schedulers

# 删除快照策略
DELETE /v1/volume-snapshot-schedulers/<scheduler-uuid>
```

## 3. 云盘规格管理

云盘规格（Disk Offering）定义了数据盘的大小和类型。

### 创建云盘规格

```bash
POST /v1/disk-offerings

{
  "params": {
    "name": "100G-SSD",
    "description": "100GB SSD disk",
    "diskSize": 107374182400,          # 100GB in bytes
    "type": "DefaultDiskOfferingType",
    "allocatorStrategy": "DefaultPrimaryStorageAllocationStrategy"
  }
}
```

### 查询云盘规格

```bash
# 查询所有云盘规格
GET /v1/disk-offerings

# 查询可用的云盘规格
GET /v1/disk-offerings?q=state=Enabled

# 查询单个云盘规格
GET /v1/disk-offerings/<offering-uuid>
```

### 更新云盘规格

```bash
PUT /v1/disk-offerings/<offering-uuid>

{
  "updateDiskOffering": {
    "name": "new-name",
    "description": "new description"
  }
}
```

### 启用/禁用云盘规格

```bash
PUT /v1/disk-offerings/<offering-uuid>/actions

{
  "changeDiskOfferingState": {
    "stateEvent": "enable"  # enable 或 disable
  }
}
```

### 删除云盘规格

```bash
DELETE /v1/disk-offerings/<offering-uuid>
```

## 4. 存储相关概念

### 主存储（Primary Storage）

主存储是云盘实际存放的位置，支持多种类型：

| 类型 | 说明 |
|------|------|
| LocalStorage | 本地存储 |
| NFS | NFS 共享存储 |
| SharedMountPoint | 共享挂载点 |
| Ceph | Ceph 分布式存储 |
| SharedBlock | 共享块存储 |

```bash
# 查询主存储
GET /v1/primary-storage

# 查询主存储容量
GET /v1/primary-storage/<ps-uuid>/capacities
```

### 备份存储（Backup Storage）

备份存储用于存放镜像和备份：

| 类型 | 说明 |
|------|------|
| ImageStoreBackupStorage | 镜像仓库 |
| SftpBackupStorage | SFTP 备份存储 |
| CephBackupStorage | Ceph 备份存储 |

```bash
# 查询备份存储
GET /v1/backup-storage
```

## 5. 常用操作示例

### 创建并挂载数据盘

```bash
# 1. 创建数据盘
curl -X POST "$ZSTACK_API/volumes/data" \
  -H "Authorization: OAuth $SESSION" \
  -H "Content-Type: application/json" \
  -d '{
    "params": {
      "name": "app-data",
      "diskOfferingUuid": "'$DISK_OFFERING_UUID'"
    }
  }'

# 2. 挂载到云主机
curl -X POST "$ZSTACK_API/volumes/$VOLUME_UUID/vm-instances/$VM_UUID" \
  -H "Authorization: OAuth $SESSION"
```

### 备份云盘

```bash
# 1. 创建快照
curl -X POST "$ZSTACK_API/volumes/$VOLUME_UUID/volume-snapshots" \
  -H "Authorization: OAuth $SESSION" \
  -H "Content-Type: application/json" \
  -d '{
    "params": {
      "name": "backup-'$(date +%Y%m%d)'"
    }
  }'

# 2. 从快照创建镜像（可选，用于跨区域备份）
curl -X POST "$ZSTACK_API/images/root-volume-templates/from/volume-snapshots/$SNAPSHOT_UUID" \
  -H "Authorization: OAuth $SESSION" \
  -H "Content-Type: application/json" \
  -d '{
    "params": {
      "name": "backup-image",
      "backupStorageUuids": ["'$BACKUP_STORAGE_UUID'"]
    }
  }'
```

### 扩容数据盘

```bash
# 1. 扩容云盘
curl -X PUT "$ZSTACK_API/volumes/$VOLUME_UUID/actions" \
  -H "Authorization: OAuth $SESSION" \
  -H "Content-Type: application/json" \
  -d '{
    "resizeDataVolume": {
      "size": 214748364800
    }
  }'

# 2. 在云主机内扩展文件系统
# Linux: resize2fs /dev/vdb (ext4) 或 xfs_growfs /dev/vdb (xfs)
# Windows: 磁盘管理 -> 扩展卷
```

## 6. 最佳实践

### 云盘管理

1. **命名规范**：使用有意义的名称，如 `app-data-prod`
2. **定期备份**：设置自动快照策略
3. **监控容量**：及时扩容避免空间不足
4. **分离数据**：系统盘和数据盘分离

### 快照管理

1. **定期清理**：删除不需要的快照
2. **快照前准备**：数据库等应用先刷新缓存
3. **测试恢复**：定期测试快照恢复流程
4. **保留策略**：设置合理的快照保留数量

### 存储规划

1. **容量规划**：预留足够的存储空间
2. **性能考虑**：高 IO 应用使用 SSD
3. **高可用**：重要数据使用分布式存储
4. **备份策略**：跨存储备份重要数据

## 参考链接

- [云盘 API](https://www.zstack.io/help/dev_manual/dev_guide/v5/v5_volume/)
- [快照 API](https://www.zstack.io/help/dev_manual/dev_guide/v5/v5_volume_snapshot/)
- [云盘规格 API](https://www.zstack.io/help/dev_manual/dev_guide/v5/v5_disk_offering/)
