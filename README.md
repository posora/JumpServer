<h1 id="787f6bb0">📘 JumpServer Helm 部署笔记（含 MySQL 和 Redis）</h1>
<h2 id="93c8b992">一、准备工作</h2>
<h3 id="767a0603">1. 添加 JumpServer 官方 Chart 仓库</h3>
```bash
helm repo add jumpserver https://jumpserver.github.io/helm-charts
helm repo update
```

<h3 id="3b6e5c98">2. 查看已添加的 Chart 仓库</h3>
```bash
helm repo list
```

<h2 id="be1a97c5">二、部署依赖组件（MySQL & Redis）</h2>
<h3 id="05b4c012">✳️ 建议</h3>
生产环境推荐使用外部数据库，本文为方便测试演示，使用 Helm 在集群内部部署 MySQL 和 Redis。

---

<h3 id="8283a2a4">1. 安装 MySQL（使用 Bitnami Helm Chart）</h3>
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

<h3 id="1596a465">2. 安装 Redis（使用 Bitnami Helm Chart）</h3>
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

<h2 id="90dedcb9">三、安装 JumpServer</h2>
```bash
helm pull --untar jumpserver/jumpserver
cd jumpserver
```

<h3 id="0892d76a">关键安装参数说明</h3>
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

<h2 id="568d6ac6">四、验证部署状态</h2>
```bash
kubectl get pod,svc,pvc,ingress -n jms
```

查看所有组件是否 Running，Service 是否开放 NodePort，PVC 是否绑定成功。

---

<h2 id="cbf68f40">五、常见问题及解决方案</h2>
<h3 id="53bbf025">❗1. `Invalid value: 2222: provided port is not in the valid range`</h3>
**原因：**`NodePort` 指定了小于 30000 的端口号。

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

```plain
nodePort: {{ .service.ssh.port }}
```

这就意味着 **只要你设置了 **`**service.type: NodePort**`**，就会尝试把 **`**ssh.port**`** 的值（比如 2222）直接作为 **`**nodePort**`** 用**，而不是使用合法范围的 `30000~32767`，就会报错：

`**Invalid value: 2222: provided port is not in the valid range**`

```yaml
[root@k8s-master jms]# cd jumpserver
[root@k8s-master jumpserver]# ls
Chart.yaml  configs  my-value.yaml  README.md  start.sh  templates  values.yaml
[root@k8s-master jumpserver]# cd templates/web/
[root@k8s-master web]# ls
configmap-web.yaml  deployment-web.yaml  ingress.yaml  pvc-web-logs.yaml  service-web.yaml
[root@k8s-master web]# vim service-web.yaml
    - port: {{ .service.ssh.port }}
      targetPort: ssh
      {{- if eq .service.type "NodePort" }}
      {{- if .service.ssh.nodePort }}			# 修改部分
      nodePort: {{ .service.ssh.nodePort }}
      {{- end }}													# 修改部分
      {{- end }}
      protocol: TCP
      name: ssh
[root@k8s-master templates]# cd koko/
[root@k8s-master koko]# ls
deployment-koko.yaml  pvc-koko-data.yaml  service-koko.yaml
[root@k8s-master koko]# vim service-koko.yaml
    - port: {{ .service.ssh.port }}
      targetPort: ssh
      {{- if eq .service.type "NodePort" }}
      {{- if .service.ssh.nodePort }}
      nodePort: {{ .service.ssh.nodePort }}
      {{- end }}
      {{- end }}
      protocol: TCP
      name: ssh
     # - port: {{ .service.ssh.port }}
     #   targetPort: ssh
     #   {{- if eq .service.type "NodePort" }}
     #   nodePort: {{ .service.ssh.port }}
     #   {{- end }}
     #   protocol: TCP
     #   name: ssh

```

---

<h3 id="158d3cf5">❗2. 镜像拉取缓慢 / 拉取失败</h3>
**解决方法：（没用！）**

+ 将镜像提前拉取并打包成 tar 导入：

```bash
docker pull jumpserver/jms_all:latest
docker save jumpserver/jms_all:latest -o jms_all.tar
docker load -i jms_all.tar
```

+ 修改 `values.yaml`，使用私有 Harbor 仓库或已导入的本地镜像：

```yaml
image:
  registry: your.registry.local
  repository: jumpserver/jms_all
  tag: latest
```

**最终方法：**

+ 下载 `clash for linux`开启代理
+ 配置`docker`使用代理拉取镜像

```yaml
[root@k8s-node2 docker.service.d]# pwd
/etc/systemd/system/docker.service.d
[root@k8s-node2 docker.service.d]# ls
http-proxy.conf
[root@k8s-node2 docker.service.d]# cat http-proxy.conf
[Service]
Environment="HTTP_PROXY=127.0.0.1:7890"
Environment="HTTPS_PROXY=127.0.0.1:7890"
Environment="NO_PROXY=127.0.0.1/24,*.example.com"
# 上面的ip地址 是你widows vpn代理服务器 地址
[root@k8s-node2 docker.service.d]# systemctl daemon-reload && systemctl restart docker
[root@k8s-node2 clash-for-linux]# docker info | grep Proxy
 HTTP Proxy: 127.0.0.1:7890
 HTTPS Proxy: 127.0.0.1:7890
 No Proxy: 127.0.0.1/24,*.example.com

```

---

<h3 id="ccde3aad">❗3. 不想用 debian 镜像（如只想用 mysql:5.7）</h3>
Bitnami Helm Chart 默认基于 Debian。可通过以下方法强制使用原始官方镜像：

```yaml
image:
  registry: docker.io
  repository: mysql
  tag: "5.7"
  pullPolicy: IfNotPresent
```

但需注意，Bitnami Helm Chart 对其官方镜像做了配置适配，**不兼容可能导致容器启动失败**。建议使用 Bitnami 提供的兼容镜像。  
**解决方法：**

+ 还是使用 Bitnami 官方的镜像部署

---

<h3 id="e5e9abd7">❗4. NFS provisioner 替换 rook-cephfs</h3>
若想使用自建 NFS StorageClass 替代 rook-cephfs，只需在安装命令中修改：

```bash
--set global.storageClass=jms-sc
```

---

<h2 id="ff6920a6">六、访问 JumpServer</h2>
1. 通过 Ingress 访问 Web 页面：

```plain
http://<Hosts>
```

2. 默认登录账号密码（首次进入需设置）：
    - 用户名：admin
    - 密码：ChangeMe

```plain
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

![](https://cdn.nlark.com/yuque/0/2025/png/56691720/1753320501056-8342901f-e811-41c9-bb41-9be5757b2bee.png)



