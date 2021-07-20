#!/bin/sh

check_command() {
  command -v "$1" >/dev/null 2>&1
}

msg() {
  printf "%s\n" "$1"
}

error_msg() {
  printf "[!] %s\n" "$1"
}

failure() {
  error_msg "$1"
  exit 1
}

pkg_install() {
  msg "Установка пакета \"${1}\"..."
  if opkg install "$1" >/dev/null 2>&1; then
    msg "Пакет \"${1}\" установлен."
  else
    failure "Ошибка при установке пакета \"${1}\"."
  fi
}

download() {
  check_command curl || failure "Для загрузки файлов требуется curl."
  if curl -sfL --connect-timeout 7 "$1" -o "$2"; then
    msg "Файл \"${2##*/}\" скачан."
  else
    failure "Не удалось скачать файл \"${2##*/}\"."
  fi
}

mk_file_exec() {
  check_command chmod || failure "Для изменения прав на файлы требуется chmod."
  if chmod +x "$1" 2>/dev/null; then
    msg "Установлены права на исполнение для файла \"${1}\"."
  else
    failure "Не удалось установить права на исполнение для файла \"${1}\"."
  fi
}

crt_symlink() {
  check_command ln || failure "Для создания симлинков требуется ln."
  if ln -sf "$1" "$2" 2>/dev/null; then
    msg "В каталоге \"${2%/*}\" создан симлинк \"${2##*/}\"."
  else
    failure "Не удалось создать симлинк \"${2##*/}\"."
fi
}

msg "Выполняется установка keenetic-traffic-via-vpn..."

INSTALL_DIR="/opt/etc/unblock"
REPO_URL="https://raw.githubusercontent.com/rustrict/keenetic-traffic-via-vpn/main"

check_command opkg || failure "Для установки пакетов требуется opkg."
opkg update >/dev/null 2>&1 || failure "Не удалось обновить список пакетов Entware."

for pkg in bind-dig cron grep; do
  [ -n "$(opkg status ${pkg})" ] && continue

  pkg_install "$pkg"
  sleep 1

  if [ "$pkg" = "cron" ]; then
    sed -i 's/^ARGS="-s"$/ARGS=""/' /opt/etc/init.d/S10cron && \
    msg "Отключен флуд cron в логе роутера."
    /opt/etc/init.d/S10cron restart >/dev/null
  fi
done

if [ ! -d "$INSTALL_DIR" ]; then
  if mkdir -p "$INSTALL_DIR"; then
    msg "Каталог \"${INSTALL_DIR}\" создан."
  else
    failure "Не удалось создать каталог \"${INSTALL_DIR}\"."
  fi
fi

[ ! -f "${INSTALL_DIR}/config" ] && download "${REPO_URL}/config" "${INSTALL_DIR}/config"

for _file in parser.sh start-stop.sh uninstall.sh; do
  download "${REPO_URL}/${_file}" "${INSTALL_DIR}/${_file}"
  mk_file_exec "${INSTALL_DIR}/${_file}"
done

crt_symlink "${INSTALL_DIR}/parser.sh" "/opt/etc/cron.daily/routing_table_update"
crt_symlink "${INSTALL_DIR}/start-stop.sh" "/opt/etc/ndm/ifstatechanged.d/ip_rule_switch"

if [ ! -f "${INSTALL_DIR}/unblock-list.txt" ]; then
  if touch "${INSTALL_DIR}/unblock-list.txt" 2>/dev/null; then
    msg "Файл \"${INSTALL_DIR}/unblock-list.txt\" создан."
  else
    error_msg "Не удалось создать файл \"${INSTALL_DIR}/unblock-list.txt\"."
  fi
fi

printf "%s\n" "---" "Установка завершена."
msg "Не забудьте вписать название интерфейса VPN в файл config, а также заполнить файл unblock-list.txt."

exit 0
