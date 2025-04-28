#!/bin/sh

VERSION="1.0.6" # Версия скрипта
DAEMON_NAME="tgbotd"
DAEMON_START_NAME="S99${DAEMON_NAME}"

BIN_PATH="/opt/sbin"
ETC_PATH="/opt/etc"
WWW_PATH="/opt/share/www"
LOG_PATH="/opt/var/log/${DAEMON_NAME}"
INITD_PATH="${ETC_PATH}/init.d"
LIGHTTPD_PATH="${ETC_PATH}/lighttpd/conf.d"
XKEENTG_PATH="${BIN_PATH}/.xkeentg"
ENV_FILE="${XKEENTG_PATH}/.env"

. "$ENV_FILE"

ask_user() { read -p "$1 " -n 1 -r && echo; [[ $REPLY =~ $2 ]]; }

if ! ask_user "❓ Удалить xkeen-tg? y(N)" "^[YyДд]$"; then
    echo "❌ Удаление xkeen-tg отменено"
    exit 0
fi

echo "Остановка сервисов бота и вэб-сервера..."
${INITD_PATH}/${DAEMON_START_NAME} stop
${INITD_PATH}/S80lighttpd stop
sleep 2
${INITD_PATH}/${DAEMON_START_NAME} status
${INITD_PATH}/S80lighttpd status

echo "Удаление конфигурационных файлов..."
# настройки вэб-сервера lighttpd
find "$LIGHTTPD_PATH" -regex "^${LIGHTTPD_PATH}/[0-9]+-tg.conf$" -exec rm -f {} \;
# страницы вэб-сервера lighttpd
rm -f "$WWW_PATH/index.html"
rm -f "$WWW_PATH/none.html"
rm -f "$WWW_PATH/style.css"
rm -f "$WWW_PATH/favicon.ico"

# настройки бота
if ask_user "❓ Удалить настройки бота (переменные и команды)? y(N)" "^[YyДд]$"; then
    rm -f "$ENV_FILE"
    rm -f "$XKEENTG_PATH/tg_null_cmd"
    for _filepath in $XKEENTG_PATH/*.tg; do
        _filename=${_filepath##*/}
        ask_user "❓ Удалить команду бота /${_filename%.tg} ? y(N)" "^[YyДд]$" && rm -f "$_filepath"
    done
    rmdir "$XKEENTG_PATH"
fi

echo "Удаление регистрации бота в Телеграм..."
_json=$(curl -s "https://api.telegram.org/bot${TG_TOKEN}/deleteWebhook" &>/dev/null)
_ok=$(echo "$_json" | jq -r '.ok')
_descr=$(echo "$_json" | jq -r '.description')
if [ "$_ok" != "true" ]; then
    echo "❌ Ошибка удаления регистрации бота в Телеграм: ${_descr}"
else
    echo "✅ Регистрация бота удалена: ${_descr}"
fi

echo "Удаление бота..."
rm -f "${INITD_PATH}/S99tgbotd"
rm -f "${BIN_PATH}/tgbotd"
rm -f "${BIN_PATH}/xkeentg"
rm -rf "${LOG_PATH}"

# сертификаты
_csr_info="/C=${CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_CITY}/O=${CERT_ORG}/OU=${CERT_ORG_UNIT}/CN=${DOMAIN}"
if ask_user "❓ Удалить выпущенный сертификат (${_csr_info})? y(N)" "^[YyДд]$"; then
    rm -rf "${CERT_PATH}"
fi

if ask_user "❓ Удалить инструмент netcat? y(N)" "^[YyДд]$"; then
    opkg remove netcat;
fi

if ask_user "❓ Удалить вэб-сервер lighttpd со всеми установленными модулями? y(N)" "^[YyДд]$"; then
    opkg remove lighttpd-mod-accesslog
    opkg remove lighttpd-mod-rewrite
    opkg remove lighttpd-mod-setenv
    opkg remove lighttpd-mod-openssl
    opkg remove lighttpd-mod-proxy
    opkg remove lighttpd
fi

if ask_user "❓ Удалить инструменты для работы с сертификатами? y(N)" "^[YyДд]$"; then
    opkg remove openssl-util
fi

logger -p notice -t "xkeen-tg" "Удалена версия ${VERSION}"
echo "✅ Удаление xkeen-tg завершено"
