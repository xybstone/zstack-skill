# ZStack API 快速参考

## 认证

```bash
# 登录
POST /v1/accounts/login
{"logInByAccount":{"accountName":"admin","password":"xxx"}}

# 使用 Session
Authorization: OAuth <session-uuid>
```

## 云主机

| 操作 | 方法 | 端点 |
|------|------|------|
| 列表 | GET | `/v1/vm-instances` |
| 详情 | GET | `/v1/vm-instances/{uuid}` |
| 创建 | POST | `/v1/vm-instances` |
| 启动 | PUT | `/v1/vm-instances/{uuid}/actions` `{"startVmInstance":{}}` |
| 停止 | PUT | `/v1/vm-instances/{uuid}/actions` `{"stopVmInstance":{}}` |
| 重启 | PUT | `/v1/vm-instances/{uuid}/actions` `{"rebootVmInstance":{}}` |
| 删除 | DELETE | `/v1/vm-instances/{uuid}` |
| 彻底删除 | DELETE | `/v1/vm-instances/{uuid}?deleteMode=Enforcing` |

## 云盘

| 操作 | 方法 | 端点 |
|------|------|------|
| 列表 | GET | `/v1/volumes` |
| 创建数据盘 | POST | `/v1/volumes/data` |
| 挂载 | POST | `/v1/volumes/{uuid}/vm-instances/{vm-uuid}` |
| 卸载 | DELETE | `/v1/volumes/{uuid}/vm-instances` |
| 扩容 | PUT | `/v1/volumes/{uuid}/actions` `{"resizeDataVolume":{"size":xxx}}` |
| 删除 | DELETE | `/v1/volumes/{uuid}` |

## 快照

| 操作 | 方法 | 端点 |
|------|------|------|
| 列表 | GET | `/v1/volume-snapshots` |
| 创建 | POST | `/v1/volumes/{uuid}/volume-snapshots` |
| 回滚 | PUT | `/v1/volume-snapshots/{uuid}/actions` `{"revertVolumeFromSnapshot":{}}` |
| 删除 | DELETE | `/v1/volume-snapshots/{uuid}` |

## 镜像

| 操作 | 方法 | 端点 |
|------|------|------|
| 列表 | GET | `/v1/images` |
| 添加 | POST | `/v1/images` |
| 从云盘创建 | POST | `/v1/images/root-volume-templates/from/volumes/{uuid}` |
| 删除 | DELETE | `/v1/images/{uuid}` |

## 网络

| 操作 | 方法 | 端点 |
|------|------|------|
| L3 网络列表 | GET | `/v1/l3-networks` |
| 安全组列表 | GET | `/v1/security-groups` |
| 创建安全组 | POST | `/v1/security-groups` |
| 添加规则 | POST | `/v1/security-groups/{uuid}/rules` |
| EIP 列表 | GET | `/v1/eips` |
| 创建 EIP | POST | `/v1/eips` |
| 绑定 EIP | PUT | `/v1/eips/{uuid}/actions` `{"attachEip":{"vmNicUuid":"xxx"}}` |

## 查询条件

| 操作符 | 示例 |
|--------|------|
| 等于 | `?q=state=Running` |
| 不等于 | `?q=state!=Stopped` |
| 大于 | `?q=cpuNum>4` |
| 小于 | `?q=cpuNum<8` |
| 模糊 | `?q=name?=%test%` |
| 正则 | `?q=name~=^vm-.*` |
| 包含 | `?q=state=in(Running,Stopped)` |
| 为空 | `?q=description=null` |

## 分页

```
?limit=10&start=0&sortBy=createDate&sortDirection=desc
```

## 常用资源端点

| 资源 | 端点 |
|------|------|
| 云主机 | `/v1/vm-instances` |
| 云盘 | `/v1/volumes` |
| 快照 | `/v1/volume-snapshots` |
| 镜像 | `/v1/images` |
| L3 网络 | `/v1/l3-networks` |
| 安全组 | `/v1/security-groups` |
| EIP | `/v1/eips` |
| 计算规格 | `/v1/instance-offerings` |
| 云盘规格 | `/v1/disk-offerings` |
| 物理机 | `/v1/hosts` |
| 集群 | `/v1/clusters` |
| 区域 | `/v1/zones` |
| 主存储 | `/v1/primary-storage` |
| 备份存储 | `/v1/backup-storage` |
| 定时任务 | `/v1/schedulers` |
| 告警 | `/v1/zwatch/alarms` |
| 监控数据 | `/v1/zwatch/metrics` |
