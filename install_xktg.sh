#!/bin/sh

VERSION="1.0.1" # Версия скрипта
VERSIONS_XKEEN_SUPPORTED="1.1.3 1.1.3.1 1.1.3.2" # Поддерживаемые версии xkeen (через пробел)
LATEST_RELEASE_URL="https://github.com/arabezar/xkeen-tg/releases/latest/download/xkeentg.tar"
DAEMON_NAME="tgbotd"
DAEMON_START_NAME="S99${DAEMON_NAME}"

ACTION="$1"
ACTION_RENEW="--renew"

BIN_PATH="/opt/sbin"
ETC_PATH="/opt/etc"
WWW_PATH="/opt/share/www"
CERT_PATH="${ETC_PATH}/tg"
INITD_PATH="${ETC_PATH}/init.d"
LIGHTTPD_PATH="${ETC_PATH}/lighttpd/conf.d"
XKEENTG_PATH="${BIN_PATH}/.xkeentg"
ENV_FILE="${XKEENTG_PATH}/.env"

[ -f "$ENV_FILE" ] && . "$ENV_FILE"

# Функция получения подстроки по regexp
get_match() {
    local _str="$1"
    local _regexp="$2"
    echo "$_str" | grep -oE "$_regexp"
}

# Функция проверки Entware
check_entware() {
    local _entware_path="$(which opkg)"
    if [ -z "$_entware_path" ]; then
        echo "❌ Entware не установлен"
        exit 255
    fi
}

# Функция проверки версии xkeen
check_xkeen_version() {
    local _xkeen_path="$(which xkeen)"
    if [ -z "$_xkeen_path" ]; then
        echo "❌ xkeen не установлен"
        exit 254
    fi
    local _answer="$($_xkeen_path -v)"
    local _version="$(get_match "$_answer" "[0-9\.]+")"
    if [[ "$VERSIONS_XKEEN_SUPPORTED" != *"$_version"* ]]; then
        echo "❌ Версия xkeen ${_version} не поддерживается (поддерживаются: ${VERSIONS_XKEEN_SUPPORTED}), свяжитесь с разработчиком xkeen-tg"
        exit 253
    fi
}

# Проверка наличия необходимых утилит
echo "Установка xkeen-tg ${VERSION}..."
check_entware
check_xkeen_version

# скачивание и распаковка релиза
echo "Загрузка и распаковка xkeen-tg..."
curl -sLO "$LATEST_RELEASE_URL"
tar -xf xkeentg.tar
chmod +x services/* tools/* commands/*
chmod -x www/* LICENSE README.md
rm -f xkeentg.tar

# Функция проверки наличия и установки значения параметров конфигурации
check_config_param() {
    # параметры функции
    local _question="$1"
    local _param="$2"
    local _value_def="$3"

    # локальные переменные
    local _value_ask="$_value_def"
    local _value_env=$(sed -nE "s/^${_param}=(\\\"?)(.*)\1.*/\2/p" "$ENV_FILE" 2>/dev/null)
    if [ -n "$_value_env" ]; then
        _value_ask="$_value_env"
    fi

    local _value_new=""
    while [ -z "$_value_new" ]; do
        # запрос параметра у пользователя
        if [ -n "$_value_ask" ]; then
            read -p "$_question [$_value_ask] (Enter - подтвердить): " _value_new
        else
            read -p "$_question: " _value_new
        fi

        # обработка ввода пользователя
        if [ -z "$_value_new" ]; then
            _value_new="$_value_ask"
        fi
    done

    export $_param="$_value_new"

    # сохранение значения параметра
    if [[ "$_value_new" != "$_value_env" ]]; then
        if [ -n "$_value_env" ]; then
            sed -i "s/^$_param=.*/$_param=\"$_value_new\"/" "$ENV_FILE"
        else
            echo "$_param=\"$_value_new\"" >> "$ENV_FILE"
        fi
    fi
}

# Функция экранирования строк заданным символом
escape() {
    echo "${2}${1}${2}" | sed "s/[]\/[]/\\\&/g"
}

# Функция получения внешнего IP-адреса
get_external_ip() {
    if [ -z "$_ip_external" ]; then
        _ip_external="$(ip r g 1.1.1.1 | xargs | rev | cut -d' ' -f1 | rev)"
        if [ -z "$_ip_external" ]; then
            # получение IP-адреса: ifconfig.me или api.ipify.org
            _ip_external="$(curl -s ifconfig.me)"
            if [ $? -ne 0 -o -z "$_ip_external" ]; then
                echo "❌ Ошибка получения внешнего IP-адреса"
                exit 4
            fi
        fi
    fi
    echo "$_ip_external"
}

# Функция получения внутреннего IP-адреса
get_internal_ip() {
    if [ -z "$_ip_internal" ]; then
        _ip_internal="$(echo "$SSH_CONNECTION" | cut -d' ' -f3)"
        if [ -z "$_ip_internal" ]; then
            for i in $(seq 0 9); do
                _ip_internal="$(ip r | grep br$i | xargs | rev | cut -d' ' -f1 | rev)"
                if [ -n "$_ip_internal" ]; then
                    break
                fi
            done
        fi
    fi
    echo "$_ip_internal"
}

# заполнение файла .env
echo "Сбор параметров для установки..."
mkdir -p "$XKEENTG_PATH"

if [[ ! -f "$CERT_PATH/host.pem" || "$ACTION" == "$ACTION_RENEW" ]]; then
    . "./tools/ip2geo.sh"
    get_geo_info
    if [[ "$ACTION" == "$ACTION_RENEW" ]]; then
        CERT_COUNTRY=""
        CERT_STATE=""
        CERT_CITY=""
    fi
    check_config_param "Код страны" "CERT_COUNTRY" "${_geo_country}"
    check_config_param "Регион или область" "CERT_STATE" "${_geo_state}"
    check_config_param "Город" "CERT_CITY" "${_geo_city}"
    check_config_param "Организация" "CERT_ORG" "Home"
    check_config_param "Подразделение" "CERT_ORG_UNIT" "IT"
    check_config_param "Домен для сертификата" "DOMAIN"
    check_config_param "Путь к сертификатам" "CERT_PATH" "$CERT_PATH"
fi
check_config_param "Токен вашего бота Телеграм" "TG_TOKEN"
check_config_param "Список валидных пользователей (id через пробел)" "TG_CHAT_IDS"
check_config_param "Порт для webhook бота Телеграм" "TG_WEBHOOK_PORT" "8443"
check_config_param "Порт для работы бота Телеграм" "TG_LOCAL_PORT" $(($TG_WEBHOOK_PORT + 1))
check_config_param "Внешний ip-адрес роутера" "ROUTER_IP_EXTERNAL" "$(get_external_ip)"
check_config_param "Внутренний ip-адрес роутера" "ROUTER_IP_INTERNAL" "$(get_internal_ip)"

chmod ugo-x "$ENV_FILE"

# обновление Entware
echo "Обновление Entware..."
opkg update &>/dev/null
# opkg upgrade &>/dev/null

# установка необходимых пакетов
echo "Установка необходимых пакетов (openssl-util, lighttpd, netcat)..."

# создание сертификата
opkg install openssl-util &>/dev/null
mkdir -p "$CERT_PATH"
if [[ ! -f "$CERT_PATH/host.pem" || "$ACTION" == "$ACTION_RENEW" ]]; then
    _csr_info="/C=${CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_CITY}/O=${CERT_ORG}/OU=${CERT_OU}/CN=${DOMAIN}"
    echo "Выпуск сертификата (CSR: ${_csr_info})..."
    openssl req \
        -new \
        -x509 \
        -days 3650 \
        -nodes \
        -newkey rsa:2048 \
        -keyout "${CERT_PATH}/host.key" \
        -out "${CERT_PATH}/host.crt" \
        -subj "${_csr_info}" &>/dev/null
    cat "${CERT_PATH}/host.key" "${CERT_PATH}/host.crt" > "${CERT_PATH}/host.pem"
    chmod 400 "${CERT_PATH}/host.key" "${CERT_PATH}/host.crt" "${CERT_PATH}/host.pem" &>/dev/null
fi

# установка web-сервера
echo "Установка web-сервера lighttpd..."
opkg install lighttpd &>/dev/null
opkg install lighttpd-mod-setenv &>/dev/null
opkg install lighttpd-mod-openssl &>/dev/null
opkg install lighttpd-mod-proxy &>/dev/null
opkg install lighttpd-mod-rewrite &>/dev/null
opkg install lighttpd-mod-accesslog &>/dev/null
opkg install netcat &>/dev/null

echo "Настройка модулей web-сервера..."
find "$LIGHTTPD_PATH" -regex "^${LIGHTTPD_PATH}/[0-9]+-tg.conf$" -exec rm -f {} \;
_num_max=$(find ${LIGHTTPD_PATH} -type f -name "*.conf" -exec basename {} \; | grep -o "^[0-9]\+" | sort -nr | head -n 1)
if [ -n "$_num_max" ]; then
    _num_max=$(($_num_max + 5))
else
    _num_max=99
fi
_file_conf="${LIGHTTPD_PATH}/${_num_max}-tg.conf"

cat > "$_file_conf" <<EOF
# WARINNG: this file is auto-generated by xkeen-tg install.sh
# please do not edit it, it will be recreated on next xkeen-tg update/(re)installation

# mod-setenv
setenv.add-response-header = ( "Content-Type" => "text/html; charset=UTF-8" )

# mod-openssl
server.port = $TG_WEBHOOK_PORT
server.bind = "0.0.0.0"
ssl.engine = "enable"
ssl.pemfile = "${CERT_PATH}/host.pem"

# mod-proxy, mod-rewrite
\$HTTP["host"] == "${DOMAIN}" {
    \$HTTP["url"] =~ "^/${TG_TOKEN}$" {
        proxy.server = ( "" => ( ( "host" => "127.0.0.1", "port" => ${TG_LOCAL_PORT} ) ) )
    } else {
        \$HTTP["url"] !~ "^/(style\.css|favicon\.ico)$" {
            url.rewrite-once = ( ".*" => "/none.html" )
        }
    }
}

\$HTTP["host"] == "${ROUTER_IP_INTERNAL}" {
    \$HTTP["url"] == "/" {
        url.rewrite-if-not-file = ( ".*" => "/index.html" )
    } else \$HTTP["url"] !~ "^/(style\.css|favicon\.ico)$" {
        url.rewrite-if-not-file = ( ".*" => "/none.html" )
    }
}

# mod-accesslog
accesslog.filename = "/opt/var/log/lighttpd/access.log"
accesslog.format = "%h %V %t \"%r\" %>s %b \"%{User-Agent}i\""
EOF

# https://redmine.lighttpd.net/projects/lighttpd/wiki/Mod_accesslog

# установка сервиса
mv -f www/* "$WWW_PATH"
mv -f services/${DAEMON_NAME} "$BIN_PATH"
mv -f services/${DAEMON_START_NAME} "$INITD_PATH"
mv -f services/xkeentg "$BIN_PATH"
mv -f commands/* "$XKEENTG_PATH"

${INITD_PATH}/S80lighttpd restart
${INITD_PATH}/${DAEMON_START_NAME} restart
sleep 2
${INITD_PATH}/S80lighttpd status
if [ $? -ne 0 ]; then
    echo "❌ Ошибка установки, проверьте конфигурацию lighttpd: ${LIGHTTPD_PATH}"
    exit 1
fi
${INITD_PATH}/${DAEMON_START_NAME} status
if [ $? -ne 0 ]; then
    echo "❌ Ошибка установки, проверьте конфигурацию xkeen-tg: ${XKEENTG_PATH}"
    exit 2
fi

_json=$(curl -s "https://api.telegram.org/bot${TG_TOKEN}/getWebhookInfo")
_ok=$(echo "$_json" | jq -r '.ok')
if [[ "$_ok" != "true" ]]; then
    _descr=$(echo "$_json" | jq -r '.description')
    echo "❌ Ошибка получения информации о webhook в Телеграме: ${_descr}"
    exit 3
else
    echo "Регистрация webhook в Телеграме..."
    _url=$(echo "$_json" | jq -r '.result.url')
    if [[ "$ACTION" == "$ACTION_RENEW" || -z "$_url" ]]; then
        _tg_reg="true"
    elif [[ "$_url" != "" && "$_url" != "https://${DOMAIN}:${TG_WEBHOOK_PORT}/${TG_TOKEN}" ]]; then
        read -p "Webhook в Телеграме уже установлен (${_url}), перерегистрировать? (y/N): " _answer
        [[ "$_answer" =~ ^[YyДд] ]] && _tg_reg="true"
    fi
    if [[ "$_tg_reg" == "true" ]]; then
        _json=$(curl -s \
                     -F "url=https://${DOMAIN}:${TG_WEBHOOK_PORT}/${TG_TOKEN}" \
                     -F "ip_address=${ROUTER_IP_EXTERNAL}" \
                     -F "certificate=@${CERT_PATH}/host.crt" \
                        "https://api.telegram.org/bot${TG_TOKEN}/setWebhook")

        _ok=$(echo "$_json" | jq -r '.ok')
        _descr=$(echo "$_json" | jq -r '.description')
        if [[ "$_ok" != "true" ]]; then
            echo "❌ Ошибка регистрации webhook: ${_descr}"
            exit 4
        fi
        echo "✅ Регистрация webhook прошла успешно: ${_descr}"
    fi
fi

xkeentg --renew-telegram-commands
logger -p notice -t "xkeen-tg" "Установлена версия ${VERSION}"
echo "✅ Установка завершена"
