#!/bin/sh

SWANCTL="/usr/local/sbin/swanctl"
TUNNEL=$1
METRIC=$2

if [ -z "$TUNNEL" ] || [ -z "$METRIC" ]; then
    echo "0"
    exit 1
fi

if [ ! -x "$SWANCTL" ]; then
    echo "0"
    exit 1
fi

if [ "$METRIC" = "status" ]; then
    # Получаем статус напрямую без промежуточных переменных
    # Проверяем ESTABLISHED и INSTALLED одной строкой awk
    $SWANCTL --list-sas --ike "$TUNNEL" | awk '
        /ESTABLISHED/ {ike=1}
        /INSTALLED/ {child=1}
        END {
            if (ike && child) print 1;
            else if (ike) print 2;
            else print 0;
        }
    '
    exit 0
fi

if [ "$METRIC" = "bytes_in" ]; then
    # Ищем строки с отступом, начинающиеся на 'in ', берем 3-й столбец (байты) и суммируем
    BYTES_IN=$($SWANCTL --list-sas --ike "$TUNNEL" | awk '/^[[:space:]]+in[[:space:]]+/ {s+=$3} END {print s}')
    echo "${BYTES_IN:-0}"
    exit 0
fi

if [ "$METRIC" = "bytes_out" ]; then
    # Ищем строки с отступом, начинающиеся на 'out ', берем 3-й столбец (байты) и суммируем
    BYTES_OUT=$($SWANCTL --list-sas --ike "$TUNNEL" | awk '/^[[:space:]]+out[[:space:]]+/ {s+=$3} END {print s}')
    echo "${BYTES_OUT:-0}"
    exit 0
fi

# Если передан неизвестный параметр
echo "0"
