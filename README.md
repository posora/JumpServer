---

# 📘 JumpServer Helm 部署笔记（含 MySQL 和 Redis）

## 一、准备工作

### 1. 添加 JumpServer 官方 Chart 仓库

```bash
helm repo add jumpserver https://jumpserver.github.io/helm-charts
helm repo update
```

### 2. 查看已添加的 Chart 仓库

```bash
helm repo list
```

---

## 二、部署依赖组件（MySQL & Redis）

### ✳️ 建议

生产环境推荐使用外部数据库，本文为方便测试演示，使用 Helm 在集群内部部署 MySQL 和 Redis。

---

### 1. 安装 MySQL（使用 Bitnami Helm Chart）

```bash
helm pull --untar bitnami/mysql
kubectl create ns jms
cd mysql
helm install jms-mysql . -n jms \
  --set global.storageClass=jms-sc \
  --set auth.rootPassword=jumpserver \
  --set auth.database=jumpserver \
  --set auth.username=jumpserver \
  --set auth.password=jumpserver
```

✅ 也可将上述配置写入 `values.yaml` 文件，使用以下命令安装：

```bash
helm install jms-mysql . -n jms
```

---

### 2. 安装 Redis（使用 Bitnami Helm Chart）

```bash
helm pull --untar bitnami/redis
cd redis
helm install jms-redis . -n jms \
  --set global.storageClass=jms-sc \
  --set auth.enabled=true \
  --set auth.password=jumpserver
```

✅ 同样支持通过编辑 `values.yaml` 文件后安装：

```bash
helm install jms-redis . -n jms
```

---

## 三、安装 JumpServer

```bash
helm pull --untar jumpserver/jumpserver
cd jumpserver
```

### 关键安装参数说明

```bash
# 生成 secretKey 和 bootstrapToken
openssl rand -base64 32
openssl rand -hex 16
```

```bash
helm install jumpserver . -n jms \
  --set core.config.secretKey=<yourSecretKey> \
  --set core.config.bootstrapToken=<yourBootstrapToken> \
  --set global.storageClass=jms-sc \
  --set externalDatabase.engine=mysql \
  --set externalDatabase.host=jms-mysql \
  --set externalDatabase.port=3306 \
  --set externalDatabase.user=jumpserver \
  --set externalDatabase.password=jumpserver \
  --set externalDatabase.database=jumpserver \
  --set externalRedis.host=jms-redis-master \
  --set externalRedis.port=6379 \
  --set externalRedis.password=jumpserver \
  --set koko.service.type=NodePort \
  --set web.service.type=NodePort
```

📌 如果使用 `values.yaml` 管理参数，也可通过以下命令部署：

```bash
helm install jumpserver . -n jms -f my-value.yaml
```

---

## 四、验证部署状态

```bash
kubectl get pod,svc,pvc,ingress -n jms
```

查看所有组件是否 Running，Service 是否开放 NodePort，PVC 是否绑定成功。

---

## 五、常见问题及解决方案

### ❗1. `Invalid value: 2222: provided port is not in the valid range`

**原因：** `NodePort` 指定了小于 30000 的端口号。

**解决1：** 修改 `values.yaml` 或模板中 koko 的配置：**（没用！）**

```yaml
koko:
  service:
    type: NodePort
    ssh:
      port: 32222  # 合法端口范围：30000-32767
```

**解决2：**

这个 `Helm` 模板的写法是典型的将 `NodePort` 写成了**固定值**，也就是：

```yaml
nodePort: {{ .service.ssh.port }}
```

这就意味着 **只要你设置了 `service.type: NodePort`，就会尝试把 `ssh.port` 的值（比如 2222）直接作为 `nodePort` 用**，而不是使用合法范围的 `30000~32767`，就会报错：

`Invalid value: 2222: provided port is not in the valid range`

**解决方案是修改模板逻辑：**

```yaml
- port: {{ .service.ssh.port }}
  targetPort: ssh
  {{- if eq .service.type "NodePort" }}
  {{- if .service.ssh.nodePort }}
  nodePort: {{ .service.ssh.nodePort }}
  {{- end }}
  {{- end }}
  protocol: TCP
  name: ssh
```

---

### ❗2. 镜像拉取缓慢 / 拉取失败

**失败方法：**（没用）

```bash
docker pull jumpserver/jms_all:latest
docker save jumpserver/jms_all:latest -o jms_all.tar
docker load -i jms_all.tar
```

**最终有效方法：使用代理拉取镜像**

安装 `clash for linux` 代理工具，配置 Docker 使用代理：

```ini
# /etc/systemd/system/docker.service.d/http-proxy.conf
[Service]
Environment="HTTP_PROXY=127.0.0.1:7890"
Environment="HTTPS_PROXY=127.0.0.1:7890"
Environment="NO_PROXY=127.0.0.1/24,*.example.com"
```

重启 Docker 并验证：

```bash
systemctl daemon-reload && systemctl restart docker
docker info | grep Proxy
```

输出：

```bash
HTTP Proxy: 127.0.0.1:7890
HTTPS Proxy: 127.0.0.1:7890
No Proxy: 127.0.0.1/24,*.example.com
```

---

### ❗3. 不想用 debian 镜像（如只想用 mysql:5.7）

Bitnami Helm Chart 默认基于 Debian。

```yaml
image:
  registry: docker.io
  repository: mysql
  tag: "5.7"
  pullPolicy: IfNotPresent
```

但因适配差异，容易出现启动失败。**推荐使用 Bitnami 官方镜像**。

---

### ❗4. NFS provisioner 替换 rook-cephfs

若想使用自建 NFS StorageClass 替代 rook-cephfs，只需将安装命令中的参数改为：

```bash
--set global.storageClass=jms-sc
```

---

## 六、访问 JumpServer

1. 通过 Ingress 访问 Web 页面：

```
http://<Hosts>
```

2. 默认登录账号密码（首次进入需设置）：

* 用户名：admin
* 密码：ChangeMe

```bash
[root@k8s-master jumpserver]# helm install jumpserver . -n jms -f my-value.yaml
W0723 17:18:36.492974   31555 warnings.go:70] annotation "kubernetes.io/ingress.class" is deprecated, please use 'spec.ingressClassName' instead
NAME: jumpserver
LAST DEPLOYED: Wed Jul 23 17:18:22 2025
NAMESPACE: jms
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
The Installation is Complete.
    --------------------------------------------------
    | Documentation:    https://docs.jumpserver.org/ |
    | Official Website: https://www.jumpserver.org/  |
    --------------------------------------------------

       ██╗██╗   ██╗███╗   ███╗██████╗ ███████╗███████╗██████╗ ██╗   ██╗███████╗██████╗
       ██║██║   ██║████╗ ████║██╔══██╗██╔════╝██╔════╝██╔══██╗██║   ██║██╔════╝██╔══██╗
       ██║██║   ██║██╔████╔██║██████╔╝███████╗█████╗  ██████╔╝██║   ██║█████╗  ██████╔╝
  ██   ██║██║   ██║██║╚██╔╝██║██╔═══╝ ╚════██║██╔══╝  ██╔══██╗╚██╗ ██╔╝██╔══╝  ██╔══██╗
  ╚█████╔╝╚██████╔╝██║ ╚═╝ ██║██║     ███████║███████╗██║  ██║ ╚████╔╝ ███████╗██║  ██║
   ╚════╝  ╚═════╝ ╚═╝     ╚═╝╚═╝     ╚══════╝╚══════╝╚═╝  ╚═╝  ╚═══╝  ╚══════╝╚═╝  ╚═╝

                                                                   Version: v4.10.4

1. Web access:
  http://test.jumpserver.org
  username: admin  password: ChangeMe
```

![JumpServer 登录页面]
https://i.mji.rip/2025/07/24/e152bfd28cc304c2db1a30d2c79a259e.png
