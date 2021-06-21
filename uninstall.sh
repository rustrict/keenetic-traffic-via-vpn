#!/bin/sh

msg() {
  printf "%s\n" "$1"
}

error_msg() {
  printf "[!] %s\n" "$1"
}

delete_file() {
  if rm -f "$1" 2>/dev/null; then
    msg "${2:-"Файл"} \"${1##*/}\" удален или отсутствует."
  else
    error_msg "Не удалось удалить ${3:-"файл"} \"${1##*/}\"."
fi
}

PRJ_DIR="/opt/etc/unblock"

for _tool in ip rm; do
  command -v "$_tool" >/dev/null 2>&1 || {
    error_msg "Для работы скрипта требуется \"${_tool}\"."
    exit 1
  }
done

# https://stackoverflow.com/a/226724
read -p "Приступить к удалению? [y/n] " yn
case "$yn" in
  [Yy]*) ;;
      *) msg "Удаление отменено."; exit 1;;
esac

if ip route flush table 1000; then
  msg "Таблица маршрутизации #1000 очищена."
fi

if ip rule del priority 1995 2>/dev/null; then
  msg "Правило маршрутизации удалено."
fi

delete_file "/opt/etc/cron.daily/routing_table_update" "Симлинк" "симлинк"
delete_file "/opt/etc/ndm/ifstatechanged.d/ip_rule_switch" "Симлинк" "симлинк"

for _file in \
  config parser.sh start-stop.sh uninstall.sh unblock-list.txt; do
  delete_file "${PRJ_DIR}/${_file}"
done

# https://unix.stackexchange.com/a/615900
if [ -d "${PRJ_DIR}" ] && \
   [ "$(echo "${PRJ_DIR}/"*)" = "${PRJ_DIR}/*" ]; then
  if rm -r "${PRJ_DIR}" 2>/dev/null; then
    msg "Каталог \"${PRJ_DIR}\" удален."
  else
    error_msg "Не удалось удалить каталог \"${PRJ_DIR}\"."
  fi
fi

printf "%s\n" "---" "Удаление завершено."

exit 0
