# ZStack 监控与告警

本文档涵盖监控数据查询和告警管理。

## 1. 监控数据查询

ZStack 提供丰富的监控指标，支持查询云主机、物理机、存储等资源的性能数据。

### 监控指标类型

| 资源类型 | 监控指标 |
|---------|---------|
| 云主机 | CPU、内存、磁盘IO、网络IO |
| 物理机 | CPU、内存、磁盘、网络、温度 |
| 存储 | 容量、IOPS、吞吐量 |
| 网络 | 带宽、包数、错误数 |

### 查询云主机监控数据

```bash
# 查询 CPU 使用率
GET /v1/zwatch/metrics

{
  "params": {
    "namespace": "ZStack/VM",
    "metricName": "CPUUsedUtilization",
    "offsetAheadOfCurrentTime": 3600,  # 查询最近1小时
    "period": 60,                       # 采样周期60秒
    "labels": [
      {
        "key": "VMUuid",
        "op": "=",
        "value": "<vm-uuid>"
      }
    ]
  }
}

# 查询内存使用率
{
  "params": {
    "namespace": "ZStack/VM",
    "metricName": "MemoryUsedInPercent",
    "offsetAheadOfCurrentTime": 3600,
    "period": 60,
    "labels": [
      {
        "key": "VMUuid",
        "op": "=",
        "value": "<vm-uuid>"
      }
    ]
  }
}
```

### 常用监控指标

#### 云主机指标 (ZStack/VM)

| 指标名 | 说明 | 单位 |
|--------|------|------|
| CPUUsedUtilization | CPU 使用率 | % |
| MemoryUsedInPercent | 内存使用率 | % |
| MemoryFreeInPercent | 内存空闲率 | % |
| DiskReadBytes | 磁盘读取字节数 | Bytes/s |
| DiskWriteBytes | 磁盘写入字节数 | Bytes/s |
| DiskReadOps | 磁盘读取IOPS | 次/s |
| DiskWriteOps | 磁盘写入IOPS | 次/s |
| NetworkInBytes | 网络入流量 | Bytes/s |
| NetworkOutBytes | 网络出流量 | Bytes/s |
| NetworkInPackets | 网络入包数 | 个/s |
| NetworkOutPackets | 网络出包数 | 个/s |

#### 物理机指标 (ZStack/Host)

| 指标名 | 说明 | 单位 |
|--------|------|------|
| CPUUsedUtilization | CPU 使用率 | % |
| CPUAverageLoad | CPU 平均负载 | - |
| MemoryUsedInPercent | 内存使用率 | % |
| DiskUsedCapacityInPercent | 磁盘使用率 | % |
| NetworkInBytes | 网络入流量 | Bytes/s |
| NetworkOutBytes | 网络出流量 | Bytes/s |

#### 存储指标 (ZStack/PrimaryStorage)

| 指标名 | 说明 | 单位 |
|--------|------|------|
| UsedCapacityInPercent | 使用率 | % |
| AvailableCapacity | 可用容量 | Bytes |
| TotalCapacity | 总容量 | Bytes |

### 查询参数说明

| 参数 | 说明 |
|------|------|
| namespace | 指标命名空间 |
| metricName | 指标名称 |
| offsetAheadOfCurrentTime | 查询时间范围（秒） |
| period | 采样周期（秒） |
| startTime | 开始时间（时间戳） |
| endTime | 结束时间（时间戳） |
| labels | 过滤标签 |

### 批量查询

```bash
POST /v1/zwatch/metrics/batch

{
  "params": {
    "queries": [
      {
        "namespace": "ZStack/VM",
        "metricName": "CPUUsedUtilization",
        "labels": [{"key": "VMUuid", "op": "=", "value": "<vm-uuid>"}]
      },
      {
        "namespace": "ZStack/VM",
        "metricName": "MemoryUsedInPercent",
        "labels": [{"key": "VMUuid", "op": "=", "value": "<vm-uuid>"}]
      }
    ],
    "offsetAheadOfCurrentTime": 3600,
    "period": 60
  }
}
```

## 2. 告警管理

### 告警架构

```
告警规则 (Alarm) 
    ↓ 触发
告警消息 (AlarmHistory)
    ↓ 通知
告警动作 (AlarmAction)
    ├── 邮件通知
    ├── 短信通知
    ├── Webhook
    └── 自动伸缩
```

### 创建告警规则

```bash
POST /v1/zwatch/alarms

{
  "params": {
    "name": "high-cpu-alarm",
    "description": "CPU usage > 80%",
    "namespace": "ZStack/VM",
    "metricName": "CPUUsedUtilization",
    "comparisonOperator": "GreaterThanOrEqualTo",
    "threshold": 80,
    "period": 300,           # 检测周期（秒）
    "repeatInterval": 1800,  # 重复告警间隔（秒）
    "repeatCount": 3,        # 连续触发次数
    "enableRecovery": true,  # 启用恢复通知
    "labels": [
      {
        "key": "VMUuid",
        "op": "=",
        "value": "<vm-uuid>"
      }
    ],
    "actions": [
      {
        "actionType": "sns",
        "actionUuid": "<sns-topic-uuid>"
      }
    ]
  }
}
```

### 比较操作符

| 操作符 | 说明 |
|--------|------|
| GreaterThanOrEqualTo | 大于等于 |
| GreaterThan | 大于 |
| LessThanOrEqualTo | 小于等于 |
| LessThan | 小于 |

### 查询告警规则

```bash
# 查询所有告警规则
GET /v1/zwatch/alarms

# 查询单个告警规则
GET /v1/zwatch/alarms/<alarm-uuid>

# 查询告警历史
GET /v1/zwatch/alarm-histories
```

### 更新告警规则

```bash
PUT /v1/zwatch/alarms/<alarm-uuid>

{
  "updateAlarm": {
    "name": "new-name",
    "threshold": 90,
    "period": 600
  }
}
```

### 启用/禁用告警

```bash
PUT /v1/zwatch/alarms/<alarm-uuid>/actions

{
  "changeAlarmState": {
    "stateEvent": "enable"  # enable 或 disable
  }
}
```

### 删除告警规则

```bash
DELETE /v1/zwatch/alarms/<alarm-uuid>
```

## 3. 通知服务 (SNS)

### 创建 SNS 主题

```bash
POST /v1/sns/topics

{
  "params": {
    "name": "ops-alerts",
    "description": "Operations team alerts"
  }
}
```

### 创建邮件接收端点

```bash
POST /v1/sns/application-endpoints

{
  "params": {
    "name": "ops-email",
    "platformUuid": "<email-platform-uuid>",
    "topicUuid": "<topic-uuid>"
  }
}

# 配置邮件地址
PUT /v1/sns/application-endpoints/<endpoint-uuid>

{
  "updateSNSApplicationEndpoint": {
    "email": "ops@example.com"
  }
}
```

### 创建 Webhook 端点

```bash
POST /v1/sns/application-endpoints

{
  "params": {
    "name": "webhook-endpoint",
    "platformUuid": "<http-platform-uuid>",
    "topicUuid": "<topic-uuid>"
  }
}

PUT /v1/sns/application-endpoints/<endpoint-uuid>

{
  "updateSNSApplicationEndpoint": {
    "url": "https://your-webhook.example.com/alerts"
  }
}
```

### 订阅主题

```bash
POST /v1/sns/topics/<topic-uuid>/subscriptions

{
  "params": {
    "endpointUuid": "<endpoint-uuid>"
  }
}
```

## 4. 事件订阅

除了指标告警，还可以订阅系统事件。

### 创建事件订阅

```bash
POST /v1/zwatch/event-subscriptions

{
  "params": {
    "name": "vm-state-change",
    "namespace": "ZStack/VM",
    "eventName": "VmStateChangedEvent",
    "actions": [
      {
        "actionType": "sns",
        "actionUuid": "<sns-topic-uuid>"
      }
    ]
  }
}
```

### 常用事件

| 命名空间 | 事件名 | 说明 |
|---------|--------|------|
| ZStack/VM | VmStateChangedEvent | 云主机状态变化 |
| ZStack/VM | VmDestroyedEvent | 云主机销毁 |
| ZStack/Host | HostStateChangedEvent | 物理机状态变化 |
| ZStack/Host | HostDisconnectedEvent | 物理机断连 |
| ZStack/Volume | VolumeStateChangedEvent | 云盘状态变化 |

## 5. 常用告警模板

### CPU 高负载告警

```bash
{
  "params": {
    "name": "cpu-high-load",
    "namespace": "ZStack/VM",
    "metricName": "CPUUsedUtilization",
    "comparisonOperator": "GreaterThanOrEqualTo",
    "threshold": 80,
    "period": 300,
    "repeatCount": 3,
    "enableRecovery": true
  }
}
```

### 内存不足告警

```bash
{
  "params": {
    "name": "memory-low",
    "namespace": "ZStack/VM",
    "metricName": "MemoryFreeInPercent",
    "comparisonOperator": "LessThanOrEqualTo",
    "threshold": 10,
    "period": 300,
    "repeatCount": 2,
    "enableRecovery": true
  }
}
```

### 磁盘空间告警

```bash
{
  "params": {
    "name": "disk-space-low",
    "namespace": "ZStack/Host",
    "metricName": "DiskUsedCapacityInPercent",
    "comparisonOperator": "GreaterThanOrEqualTo",
    "threshold": 90,
    "period": 600,
    "repeatCount": 1,
    "enableRecovery": true
  }
}
```

### 网络流量异常告警

```bash
{
  "params": {
    "name": "network-traffic-high",
    "namespace": "ZStack/VM",
    "metricName": "NetworkOutBytes",
    "comparisonOperator": "GreaterThanOrEqualTo",
    "threshold": 104857600,  # 100MB/s
    "period": 300,
    "repeatCount": 3,
    "enableRecovery": true
  }
}
```

## 6. 最佳实践

### 监控策略

1. **分层监控**：基础设施、平台、应用分层
2. **关键指标**：优先监控影响业务的指标
3. **合理周期**：根据指标特性设置采样周期
4. **数据保留**：设置合理的数据保留策略

### 告警策略

1. **避免告警风暴**：设置合理的重复间隔
2. **分级告警**：不同级别使用不同通知方式
3. **告警收敛**：相关告警合并通知
4. **定期审查**：清理无效告警规则

### 通知策略

1. **多渠道通知**：重要告警使用多种通知方式
2. **值班轮换**：配置值班人员轮换
3. **升级机制**：未处理告警自动升级
4. **告警确认**：要求确认重要告警

## 参考链接

- [监控 API](https://www.zstack.io/help/dev_manual/dev_guide/v5/v5_monitor/)
- [告警 API](https://www.zstack.io/help/dev_manual/dev_guide/v5/v5_alarm/)
