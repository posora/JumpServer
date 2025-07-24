#!/bin/bash
set -e

NAMESPACE="jms"
RELEASE="jumpserver"
VALUES="my-value.yaml"

if [[ -z $1 ]]; then
    echo "请输入参数：(start|stop)"
    exit 1
fi

case "$1" in
    start)
        echo "开始启动 ${RELEASE}"
        if helm status "$RELEASE" -n "$NAMESPACE" &>/dev/null; then
            echo "${RELEASE} 已经启动，无需重复安装"
        else
            helm install "$RELEASE" . -n "$NAMESPACE" -f "$VALUES"
        fi
        ;;
    stop)
        echo "开始关闭 ${RELEASE}"
        if helm status "$RELEASE" -n "$NAMESPACE" &>/dev/null; then
            helm uninstall "$RELEASE" -n "$NAMESPACE"
        else
            echo "${RELEASE} 未运行，无需卸载"
        fi
        ;;
    *)
        echo "请检查输入：(start|stop)"
        exit 1
        ;;
esac




#-----------------------------------------------------------------
# helm install jumpserver . -n jms \
# --set core.config.secretKey=GxrLH7rewfsRN8B9Zl6MEGD50Uou4LF6UV \
# --set core.config.bootstrapToken=ilR8RvAbK7lgRTxs \
# --set global.storageClass=jms-sc \
# --set externalDatabase.engine=mysql \
# --set externalDatabase.host=jms-mysql \
# --set externalDatabase.port=3306 \
# --set externalDatabase.user=jumpserver \
# --set externalDatabase.password=jumpserver \
# --set externalDatabase.database=jumpserver \
# --set externalRedis.host=jms-redis-master \
# --set externalRedis.port=6379 \
# --set externalRedis.password=jumpserver \
# --set koko.service.type=NodePort \
# --set koko.service.nodePort=32222 \
# --set web.service.type=NodePort \
# --set web.service.nodePort=31111

