#!/bin/sh

TMP_DIR="/tmp/zabbix_ipsec"
TUNNEL=$1
METRIC=$2

# Защита: разрешаем только буквы, цифры, дефис и подчеркивание в параметрах
SAFE_TUNNEL=$(echo "$TUNNEL" | sed 's/[^a-zA-Z0-9_-]//g')
SAFE_METRIC=$(echo "$METRIC" | sed 's/[^a-zA-Z0-9_-]//g')

if [ -z "$SAFE_TUNNEL" ] || [ -z "$SAFE_METRIC" ]; then
    echo "0"
    exit 1
fi

TARGET_FILE="$TMP_DIR/${SAFE_TUNNEL}.${SAFE_METRIC}"

if [ -f "$TARGET_FILE" ]; then
    cat "$TARGET_FILE"
else
    echo "0"
fi
