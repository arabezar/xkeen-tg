#!/bin/sh

_bin_path="/opt/sbin"
_etc_path="/opt/etc"
_www_path="/opt/share/www"
_log_path="/opt/var/log/tgbotd"
_initd_path="${_etc_path}/init.d"
_lighttpd_path="${_etc_path}/lighttpd/conf.d"
_cert_path="${_etc_path}/tg"
_xkeentg_path="${_bin_path}/.xkeentg"
_env="${_xkeentg_path}/.env"

. "$_env"

ask_user() { read -p "$1 " -n 1 -r && echo; [[ $REPLY =~ $2 ]]; }

if ! ask_user "❓ Удалить xkeen-tg? y(N)" "^[YyДд]$"; then
    echo "❌ Удаление xkeen-tg отменено"
    exit 0
fi

echo "Остановка сервисов бота и вэб-сервера..."
${_initd_path}/S99tgbotd stop
${_initd_path}/S80lighttpd stop
sleep 2
${_initd_path}/S99tgbotd status
${_initd_path}/S80lighttpd status

echo "Удаление конфигурационных файлов..."
# настройки вэб-сервера lighttpd
find "$_lighttpd_path" -regex "^${_lighttpd_path}/[0-9]+-tg.conf$" -exec rm -f {} \;
# страницы вэб-сервера lighttpd
rm -f "$_www_path/index.html"
rm -f "$_www_path/none.html"
rm -f "$_www_path/style.css"

# настройки бота
if ask_user "❓ Удалить настройки бота (для возможности переустановки xkeen-tg)? y(N)" "^[YyДд]$"; then
    rm -f "$_env"
    rmdir "$_xkeentg_path"
fi

echo "Удаление регистрации бота в Телеграм..."
json=$(curl -s "https://api.telegram.org/bot${TG_TOKEN}/deleteWebhook" &>/dev/null)
_ok=$(echo "$_json" | jq -r '.ok')
_descr=$(echo "$_json" | jq -r '.description')
if [ "$_ok" != "true" ]; then
    echo "❌ Ошибка удаления регистрации бота в Телеграм: ${_descr}"
else
    echo "✅ Регистрация бота удалена: ${_descr}"
fi

echo "Удаление бота..."
rm -f "${_initd_path}/S99tgbotd"
rm -f "${_bin_path}/tgbotd"
rm -f "${_bin_path}/xkeentg"
rm -rf "${_log_path}"

# сертификаты
_csr_info="/C=${CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_CITY}/O=${CERT_ORG}/OU=${CERT_OU}/CN=${DOMAIN}"
if ask_user "❓ Удалить выпущенный сертификат (${_csr_info})? y(N)" "^[YyДд]$"; then
    rm -rf "${_cert_path}"
fi

if ask_user "❓ Удалить инструмент netcat? y(N)" "^[YyДд]$"; then
    opkg remove netcat;
fi

if ask_user "❓ Удалить вэб-сервер lighttpd со всеми установленными модулями? y(N)" "^[YyДд]$"; then
    opkg remove lighttpd-mod-rewrite
    opkg remove lighttpd-mod-setenv
    opkg remove lighttpd-mod-openssl
    opkg remove lighttpd-mod-proxy
    opkg remove lighttpd
fi

if ask_user "❓ Удалить инструменты для работы с сертификатами? y(N)" "^[YyДд]$"; then
    opkg remove openssl-util
fi

echo "✅ Удаление xkeen-tg завершено"
