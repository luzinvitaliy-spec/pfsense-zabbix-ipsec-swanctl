#!/bin/sh

SWANCTL_CONF="/var/etc/ipsec/swanctl.conf"
CONFIG_XML="/conf/config.xml"

# Если IPsec выключен или конфигурационный файл пуст, отдаем Zabbix пустой валидный массив
if [ ! -f "$SWANCTL_CONF" ] || [ ! -s "$SWANCTL_CONF" ]; then
    echo '{"data":[]}'
    exit 0
fi

# Извлекаем технические имена туннелей (con1, con4, con9...) прямо из конфигурации swanctl
CONNS=$(awk -F' {' '/^[[:space:]]*con[0-9]+/ {print $1}' "$SWANCTL_CONF" | tr -d ' ' | sort -u | grep -v 'bypass')

echo '{"data":['
FIRST=1

for conn in $CONNS; do
    [ -z "$conn" ] && continue
    
    # Получаем числовой ID туннеля (из con9 извлекаем 9)
    TUN_NUM=$(echo "$conn" | sed 's/[^0-9]//g')
    
    # Достаем человеческое описание из XML-конфига pfSense
    DESC=""
    if [ -f "$CONFIG_XML" ] && [ ! -z "$TUN_NUM" ]; then
        DESC=$(xmllint --xpath "string(//phase1[ikeid='$TUN_NUM']/descr)" "$CONFIG_XML" 2>/dev/null)
    fi
    
    # Если описания в GUI нет, оставляем техническое имя conX
    if [ -z "$DESC" ]; then
        DESC="$conn"
    fi

    if [ $FIRST -ne 1 ]; then
        printf ",\n"
    fi
    FIRST=0
    
    # Отдаем Zabbix техническое имя для скрипта сбора и описание для визуализации
    printf '    { "{#TUNNEL_NAME}": "%s", "{#TUNNEL_DESC}": "%s" }' "$conn" "$DESC"
done

printf "\n]}\n"
