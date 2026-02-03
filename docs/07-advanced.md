# ZStack 高级功能

本文档涵盖定时任务、资源编排、标签管理等高级功能。

## 1. 定时任务 (Scheduler)

定时任务允许自动执行云主机操作，如定时开关机、定时快照等。

### 创建定时任务

```bash
POST /v1/schedulers

{
  "params": {
    "name": "daily-shutdown",
    "description": "每天晚上10点关机",
    "schedulerType": "cron",
    "cronScheduler": "0 0 22 * * ?",  # 每天22:00
    "targetResourceUuid": "<vm-uuid>",
    "jobClassName": "org.zstack.header.vm.StopVmInstanceJob",
    "jobData": "{}"
  }
}
```

### 定时任务类型

| 类型 | 说明 |
|------|------|
| simple | 简单定时（间隔执行） |
| cron | Cron 表达式 |

### Simple 类型示例

```bash
{
  "params": {
    "name": "hourly-snapshot",
    "schedulerType": "simple",
    "schedulerInterval": 3600,    # 间隔秒数
    "repeatCount": -1,            # -1 表示无限重复
    "startTime": 1704067200000,   # 开始时间戳（毫秒）
    "targetResourceUuid": "<volume-uuid>",
    "jobClassName": "org.zstack.header.volume.CreateVolumeSnapshotJob",
    "jobData": "{\"name\":\"auto-snapshot\"}"
  }
}
```

### Cron 表达式格式

```
秒 分 时 日 月 周 [年]
```

| 字段 | 允许值 | 特殊字符 |
|------|--------|---------|
| 秒 | 0-59 | , - * / |
| 分 | 0-59 | , - * / |
| 时 | 0-23 | , - * / |
| 日 | 1-31 | , - * ? / L W |
| 月 | 1-12 | , - * / |
| 周 | 1-7 (1=周日) | , - * ? / L # |

### 常用 Cron 示例

| 表达式 | 说明 |
|--------|------|
| `0 0 8 * * ?` | 每天早上8点 |
| `0 0 22 * * ?` | 每天晚上10点 |
| `0 0 2 * * ?` | 每天凌晨2点 |
| `0 0 0 ? * MON` | 每周一凌晨 |
| `0 0 0 1 * ?` | 每月1号凌晨 |
| `0 */30 * * * ?` | 每30分钟 |

### 支持的任务类型

| Job 类名 | 说明 |
|---------|------|
| StartVmInstanceJob | 启动云主机 |
| StopVmInstanceJob | 停止云主机 |
| RebootVmInstanceJob | 重启云主机 |
| CreateVolumeSnapshotJob | 创建云盘快照 |
| CreateVmSnapshotJob | 创建云主机快照 |

### 查询定时任务

```bash
# 查询所有定时任务
GET /v1/schedulers

# 查询单个定时任务
GET /v1/schedulers/<scheduler-uuid>

# 查询任务执行历史
GET /v1/scheduler-job-histories?q=schedulerUuid=<scheduler-uuid>
```

### 更新定时任务

```bash
PUT /v1/schedulers/<scheduler-uuid>

{
  "updateScheduler": {
    "name": "new-name",
    "cronScheduler": "0 0 23 * * ?"
  }
}
```

### 启用/禁用定时任务

```bash
PUT /v1/schedulers/<scheduler-uuid>/actions

{
  "changeSchedulerState": {
    "stateEvent": "enable"  # enable 或 disable
  }
}
```

### 删除定时任务

```bash
DELETE /v1/schedulers/<scheduler-uuid>
```

## 2. 标签管理

ZStack 支持系统标签和用户标签，用于资源分类和配置。

### 标签类型

| 类型 | 说明 |
|------|------|
| 系统标签 (systemTags) | 影响系统行为的标签 |
| 用户标签 (userTags) | 用户自定义分类标签 |

### 创建用户标签

```bash
POST /v1/user-tags

{
  "params": {
    "resourceUuid": "<resource-uuid>",
    "resourceType": "VmInstanceVO",
    "tag": "env::production"
  }
}
```

### 资源类型

| 资源类型 | 说明 |
|---------|------|
| VmInstanceVO | 云主机 |
| VolumeVO | 云盘 |
| ImageVO | 镜像 |
| L3NetworkVO | L3 网络 |
| SecurityGroupVO | 安全组 |
| HostVO | 物理机 |

### 查询标签

```bash
# 查询资源的标签
GET /v1/user-tags?q=resourceUuid=<resource-uuid>

# 按标签查询资源
GET /v1/vm-instances?q=__userTag__=env::production
```

### 删除标签

```bash
DELETE /v1/user-tags/<tag-uuid>
```

### 常用系统标签

#### 云主机相关

| 标签 | 说明 |
|------|------|
| `hostname::{name}` | 设置主机名 |
| `sshkey::{key}` | 注入 SSH 公钥 |
| `consolePassword::{pwd}` | 控制台密码 |
| `staticIp::{l3Uuid}::{ip}` | 指定静态 IP |
| `bootOrder::{order}` | 启动顺序 |
| `cpuPinning::{config}` | CPU 绑定 |

#### 镜像相关

| 标签 | 说明 |
|------|------|
| `qemuga` | 启用 QEMU GA |
| `bootMode::UEFI` | UEFI 启动 |
| `virtio::true` | 使用 virtio |

## 3. 资源绑定

### 亲和组 (Affinity Group)

控制云主机的部署策略。

```bash
# 创建亲和组
POST /v1/affinity-groups

{
  "params": {
    "name": "web-servers",
    "policy": "antiSoft",  # 尽量分散部署
    "type": "host"
  }
}
```

### 亲和策略

| 策略 | 说明 |
|------|------|
| antiHard | 强制分散（不同物理机） |
| antiSoft | 尽量分散 |
| hard | 强制集中（同一物理机） |
| soft | 尽量集中 |

### 将云主机加入亲和组

```bash
POST /v1/affinity-groups/<ag-uuid>/vm-instances/<vm-uuid>
```

## 4. 资源池

### 创建资源池

```bash
POST /v1/resource-pools

{
  "params": {
    "name": "production-pool",
    "description": "Production resources"
  }
}
```

### 将资源加入资源池

```bash
POST /v1/resource-pools/<pool-uuid>/resources

{
  "params": {
    "resourceUuid": "<resource-uuid>",
    "resourceType": "VmInstanceVO"
  }
}
```

## 5. 批量操作

### 批量启动云主机

```bash
PUT /v1/vm-instances/actions

{
  "startVmInstance": {
    "vmInstanceUuids": ["<uuid1>", "<uuid2>", "<uuid3>"]
  }
}
```

### 批量停止云主机

```bash
PUT /v1/vm-instances/actions

{
  "stopVmInstance": {
    "vmInstanceUuids": ["<uuid1>", "<uuid2>", "<uuid3>"],
    "type": "grace"
  }
}
```

### 批量删除

```bash
DELETE /v1/vm-instances?uuids=<uuid1>,<uuid2>,<uuid3>
```

## 6. 审计日志

### 查询操作日志

```bash
GET /v1/management-nodes/actions/audit-logs

{
  "params": {
    "startTime": 1704067200000,
    "endTime": 1704153600000,
    "resourceType": "VmInstanceVO",
    "operatorAccountUuid": "<account-uuid>"
  }
}
```

### 日志字段

| 字段 | 说明 |
|------|------|
| apiName | API 名称 |
| resourceUuid | 资源 UUID |
| resourceType | 资源类型 |
| operatorAccountUuid | 操作者账户 |
| operatorUserUuid | 操作者用户 |
| clientIp | 客户端 IP |
| createDate | 操作时间 |
| success | 是否成功 |

## 7. 系统配置

### 查询全局配置

```bash
GET /v1/global-configurations
```

### 更新全局配置

```bash
PUT /v1/global-configurations/<category>/<name>

{
  "updateGlobalConfig": {
    "value": "new-value"
  }
}
```

### 常用配置项

| 类别 | 配置名 | 说明 |
|------|--------|------|
| vm | vm.expungeInterval | 云主机彻底删除间隔 |
| vm | vm.deletionPolicy | 删除策略 |
| volume | volume.expungeInterval | 云盘彻底删除间隔 |
| identity | session.timeout | Session 超时时间 |
| quota | quota.check | 是否检查配额 |

## 8. 实用脚本示例

### 定时备份脚本

```bash
#!/bin/bash
# 为所有生产环境云主机创建定时快照任务

ZSTACK_API="http://zstack:8080/zstack/v1"
SESSION="your-session"

# 获取所有生产环境云主机
VMS=$(curl -s -H "Authorization: OAuth $SESSION" \
  "$ZSTACK_API/vm-instances?q=__userTag__=env::production" \
  | jq -r '.inventories[].uuid')

for VM_UUID in $VMS; do
  # 创建每日快照任务
  curl -X POST "$ZSTACK_API/schedulers" \
    -H "Authorization: OAuth $SESSION" \
    -H "Content-Type: application/json" \
    -d '{
      "params": {
        "name": "daily-snapshot-'$VM_UUID'",
        "schedulerType": "cron",
        "cronScheduler": "0 0 2 * * ?",
        "targetResourceUuid": "'$VM_UUID'",
        "jobClassName": "org.zstack.header.vm.CreateVmSnapshotJob",
        "jobData": "{\"name\":\"auto-daily\"}"
      }
    }'
done
```

### 资源清理脚本

```bash
#!/bin/bash
# 清理已停止超过7天的云主机

ZSTACK_API="http://zstack:8080/zstack/v1"
SESSION="your-session"
SEVEN_DAYS_AGO=$(($(date +%s) - 604800))000

# 查询已停止的云主机
STOPPED_VMS=$(curl -s -H "Authorization: OAuth $SESSION" \
  "$ZSTACK_API/vm-instances?q=state=Stopped" \
  | jq -r '.inventories[] | select(.lastOpDate < '$SEVEN_DAYS_AGO') | .uuid')

for VM_UUID in $STOPPED_VMS; do
  echo "Deleting VM: $VM_UUID"
  curl -X DELETE "$ZSTACK_API/vm-instances/$VM_UUID" \
    -H "Authorization: OAuth $SESSION"
done
```

## 9. 最佳实践

### 定时任务

1. **错峰执行**：避免多个任务同时执行
2. **监控执行**：定期检查任务执行状态
3. **失败处理**：设置失败通知
4. **资源清理**：定期清理过期快照

### 标签管理

1. **命名规范**：使用统一的标签格式
2. **分类清晰**：按环境、项目、团队分类
3. **定期审计**：清理无用标签

### 批量操作

1. **分批执行**：大量操作分批进行
2. **确认检查**：执行前确认目标资源
3. **回滚准备**：准备回滚方案

## 参考链接

- [定时任务 API](https://www.zstack.io/help/dev_manual/dev_guide/v5/v5_scheduler/)
- [标签管理 API](https://www.zstack.io/help/dev_manual/dev_guide/v5/v5_tag/)
- [审计日志 API](https://www.zstack.io/help/dev_manual/dev_guide/v5/v5_audit/)
