#!/bin/sh

SWANCTL="/usr/local/sbin/swanctl"
CONFIG_XML="/conf/config.xml"
TMP_DIR="/tmp/zabbix_ipsec"

mkdir -p "$TMP_DIR"

# 1. Если IPsec выключен, создаем пустой JSON обнаружения и выходим
if [ ! -x "$SWANCTL" ]; then
    echo '{"data":[]}' > "$TMP_DIR/discovery.json"
    exit 0
fi

# 2. Собираем сырые данные один раз, чтобы не дергать систему трижды
$SWANCTL --list-conns > "$TMP_DIR/list_conns.raw"
$SWANCTL --list-sas > "$TMP_DIR/list_sas.raw"

# 3. Генерируем JSON автообнаружения туннелей
CONNS=$(awk -F':' '/^[a-zA-Z0-9_-]+:/ {print $1}' "$TMP_DIR/list_conns.raw" | grep -v 'bypass')

echo '{"data":[' > "$TMP_DIR/discovery.json.tmp"
FIRST=1

for conn in $CONNS; do
    [ -z "$conn" ] && continue
    
    TUN_NUM=$(echo "$conn" | sed 's/[^0-9]//g')
    DESC=""
    if [ -f "$CONFIG_XML" ] && [ ! -z "$TUN_NUM" ]; then
        DESC=$(xmllint --xpath "string(//phase1[ikeid='$TUN_NUM']/descr)" "$CONFIG_XML" 2>/dev/null)
    fi
    [ -z "$DESC" ] && DESC="$conn"

    if [ $FIRST -ne 1 ]; then
        printf ",\n" >> "$TMP_DIR/discovery.json.tmp"
    fi
    FIRST=0
    
    printf '    { "{#TUNNEL_NAME}": "%s", "{#TUNNEL_DESC}": "%s" }' "$conn" "$DESC" >> "$TMP_DIR/discovery.json.tmp"
done
printf "\n]}\n" >> "$TMP_DIR/discovery.json.tmp"
mv "$TMP_DIR/discovery.json.tmp" "$TMP_DIR/discovery.json"

# 4. Собираем метрики для каждого обнаруженного туннеля
for conn in $CONNS; do
    [ -z "$conn" ] && continue

    # Защищаем имя файла от спецсимволов
    SAFE_NAME=$(echo "$conn" | sed 's/[^a-zA-Z0-9_-]/_/g')

    # Статус туннеля
    # Вырезаем блок конкретного туннеля из общего вывода list-sas
    sed -n "/^$conn:/,/^[a-zA-Z0-9_-]\+:/p" "$TMP_DIR/list_sas.raw" > "$TMP_DIR/${SAFE_NAME}.sas"
    
    # Считаем статус
    ike=$(grep -c "ESTABLISHED" "$TMP_DIR/${SAFE_NAME}.sas")
    child=$(grep -c "INSTALLED" "$TMP_DIR/${SAFE_NAME}.sas")
    
    if [ "$ike" -gt 0 ] && [ "$child" -gt 0 ]; then
        echo "1" > "$TMP_DIR/${SAFE_NAME}.status"
    elif [ "$ike" -gt 0 ]; then
        echo "2" > "$TMP_DIR/${SAFE_NAME}.status"
    else
        echo "0" > "$TMP_DIR/${SAFE_NAME}.status"
    fi

    # Считаем входящие/исходящие байты
    awk '/^[[:space:]]+in[[:space:]]+/ {s+=$3} END {print s+0}' "$TMP_DIR/${SAFE_NAME}.sas" > "$TMP_DIR/${SAFE_NAME}.bytes_in"
    awk '/^[[:space:]]+out[[:space:]]+/ {s+=$3} END {print s+0}' "$TMP_DIR/${SAFE_NAME}.sas" > "$TMP_DIR/${SAFE_NAME}.bytes_out"
    
    # Очищаем временный файл туннеля
    rm -f "$TMP_DIR/${SAFE_NAME}.sas"
done

# Делаем файлы доступными для чтения пользователю zabbix
chmod -R 644 "$TMP_DIR"/*
