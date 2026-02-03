# ZStack API 架构概述

## API 设计理念

ZStack 采用 **全异步架构**，所有 API 操作都是异步执行的。这意味着：

1. API 调用立即返回，不会阻塞
2. 通过轮询或回调获取操作结果
3. 支持高并发和长时间运行的任务

## API 类型

ZStack API 分为以下几类：

### 1. 资源操作 API

| 操作类型 | 说明 | 示例 |
|---------|------|------|
| Create | 创建资源 | CreateVmInstance |
| Query | 查询资源 | QueryVmInstance |
| Update | 更新资源 | UpdateVmInstance |
| Delete | 删除资源 | DestroyVmInstance |
| Action | 执行动作 | StartVmInstance, StopVmInstance |

### 2. 查询 API 特点

ZStack 的查询 API 非常强大，支持：

- **条件查询**：支持多种条件操作符
- **分页**：limit, start 参数
- **排序**：sortBy, sortDirection
- **字段选择**：fields 参数
- **关联查询**：可以查询关联资源

#### 查询条件操作符

| 操作符 | 说明 | 示例 |
|--------|------|------|
| `=` | 等于 | `name=test` |
| `!=` | 不等于 | `state!=Running` |
| `>` | 大于 | `cpuNum>4` |
| `>=` | 大于等于 | `memorySize>=1073741824` |
| `<` | 小于 | `cpuNum<8` |
| `<=` | 小于等于 | `memorySize<=2147483648` |
| `?=` | 模糊匹配 | `name?=%test%` |
| `!?=` | 模糊不匹配 | `name!?=%temp%` |
| `~=` | 正则匹配 | `name~=^vm-.*` |
| `!~=` | 正则不匹配 | `name!~=^temp-.*` |
| `is null` | 为空 | `description is null` |
| `is not null` | 不为空 | `description is not null` |
| `in` | 在列表中 | `state in (Running,Stopped)` |
| `not in` | 不在列表中 | `state not in (Destroyed)` |

## API 请求格式

### HTTP 方法

- **POST**：创建资源、执行动作
- **GET**：查询资源
- **PUT**：更新资源
- **DELETE**：删除资源

### 请求头

```http
Content-Type: application/json
Authorization: OAuth <access-token>
```

### 请求体结构

```json
{
  "params": {
    "资源参数": "值"
  },
  "systemTags": ["系统标签"],
  "userTags": ["用户标签"]
}
```

## API 响应格式

### 成功响应

```json
{
  "inventory": {
    "uuid": "资源UUID",
    "name": "资源名称",
    ...
  }
}
```

### 查询响应

```json
{
  "inventories": [
    { "uuid": "...", "name": "..." },
    { "uuid": "...", "name": "..." }
  ],
  "total": 100
}
```

### 错误响应

```json
{
  "error": {
    "code": "错误代码",
    "description": "错误描述",
    "details": "详细信息"
  }
}
```

## 异步任务处理

### Job 机制

长时间运行的操作会返回一个 Job：

```json
{
  "job": {
    "uuid": "job-uuid",
    "state": "Processing"
  }
}
```

### 轮询 Job 状态

```bash
GET /v1/jobs/{job-uuid}
```

### Job 状态

| 状态 | 说明 |
|------|------|
| Processing | 处理中 |
| Done | 完成 |
| Failed | 失败 |

## API 端点

### 标准端点

```
http://<zstack-server>:8080/zstack/v1/<resource>
```

### 常用资源端点

| 资源 | 端点 |
|------|------|
| 云主机 | `/v1/vm-instances` |
| 镜像 | `/v1/images` |
| 云盘 | `/v1/volumes` |
| 网络 | `/v1/l3-networks` |
| 安全组 | `/v1/security-groups` |

## 最佳实践

1. **使用异步模式**：对于耗时操作，使用异步调用并轮询结果
2. **合理使用查询条件**：避免全量查询，使用条件过滤
3. **分页查询**：大量数据时使用分页
4. **错误处理**：始终检查响应中的 error 字段
5. **资源清理**：及时清理不需要的资源

## 参考链接

- [ZStack API 框架文档](https://www.zstack.io/help/dev_manual/dev_guide/v5/v5_api_framework/)
