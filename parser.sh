#!/bin/sh

add_ip() {
  ip route add table 1000 "$1" dev "$IFACE" 2>/dev/null
}

check_ip() {
  # https://stackoverflow.com/a/36760050
  if echo "$1" | grep -qP \
  '^((25[0-5]|(2[0-4]|1[0-9]|[1-9]|)[0-9])(\.(?!$)|(\/(3[0-2]|[12][0-9]|[0-9]))?$)){4}$'; then
    return 0
  else
    return 1
  fi
}

cut_special() {
  grep -vE -e '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)' \
           -e '^(0\.|127\.|100\.(6[4-9]|[7-9][0-9]|1[01][0-9]|12[0-7])\.|255\.255\.255\.255)'
}

logger_msg() {
  logger -s -t parser "$1"
}

logger_failure() {
  logger_msg "Error: ${1}"
  exit 1
}

CONFIG="/opt/etc/unblock/config"
if [ -f "$CONFIG" ]; then
  . "$CONFIG"
else
  logger_failure "Не удалось обнаружить файл \"config\"."
fi

for _tool in dig grep ip rm seq sleep; do
  command -v "$_tool" >/dev/null 2>&1 || \
  logger_failure "Для работы скрипта требуется \"${_tool}\"."
done

PIDFILE="${PIDFILE:-/tmp/parser.sh.pid}"
[ -e "$PIDFILE" ] && logger_failure "Обнаружен файл \"${PIDFILE}\"."
( echo $$ > "$PIDFILE" ) 2>/dev/null || logger_failure "Не удалось создать файл \"${PIDFILE}\"."
trap 'rm -f "$PIDFILE"' EXIT
trap 'exit 2' INT TERM QUIT HUP

[ -f "$FILE" ] || logger_failure "Отсутствует файл \"${FILE}\"."

if ! ip address show dev "$IFACE" >/dev/null 2>&1; then
  logger_failure "Не удалось обнаружить интерфейс \"${IFACE}\"."
elif [ -z "$(ip link show "${IFACE}" up 2>/dev/null)" ]; then
  logger_failure "Интерфейс \"${IFACE}\" отключен."
fi

for _attempt in $(seq 0 10); do
  if dig +short +tries=1 ripe.net @localhost 2>/dev/null | grep -qvE '^$|^;'; then
    break
  elif [ "$_attempt" -eq 10 ]; then
    logger_failure "Не удалось разрешить проверочное доменное имя."
  fi
  sleep 1
done

if ip route flush table 1000; then
  logger_msg "Таблица маршрутизации #1000 очищена."
else
  logger_failure "Не удалось очистить таблицу маршрутизации #1000."
fi

logger_msg "Парсинг $(grep -c "" "$FILE") строк(-и) в файле \"${FILE}\"..."

while read -r line || [ -n "$line" ]; do
  [ -z "$line" ] && continue
  [ "${line:0:1}" = "#" ] && continue

  if check_ip "$line"; then
    add_ip "$line"
  else
    dig_host=$(dig +short "$line" @localhost 2>&1 | grep -vE '[a-z]+' | cut_special)
    if [ -n "$dig_host" ]; then
      for i in $dig_host; do check_ip "$i" && add_ip "$i"; done
    else
      logger_msg "Не удалось разрешить доменное имя: строка \"${line}\" проигнорирована."
    fi
  fi
done < "$FILE"

logger_msg "Парсинг завершен. #1000: $(ip route list table 1000 | wc -l)."

exit 0
