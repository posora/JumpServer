#!/bin/bash
set -e

NAMESPACE="jms"
RELEASE="jms-mysql"
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
