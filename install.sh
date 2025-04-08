#!/bin/sh

VERSION="0.1.3" # Версия скрипта
VERSIONS_XKEEN_SUPPORTED="1.1.3 1.1.3.1 1.1.3.2" # Поддерживаемые версии xkeen (через пробел)
LATEST_RELEASE_URL="https://github.com/arabezar/xkeen-tg/releases/latest/download/xkeentg.tar"

_cmd="$1"
_cmd_renew="--renew"

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
chmod +x tgbotd S99tgbotd ip2geo.sh ip2geo_test.sh
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
    local _value_env=$(sed -nE "s/^${_param}=(\\\"?)(.*)\1.*/\2/p" "$_env" 2>/dev/null)
    if [ -n "$_value_env" ]; then
        _value_ask="$_value_env"
    fi

    do
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
    until [ -n "$_value_new" ]
    done

    export $_param="$_value_new"

    # сохранение значения параметра
    if [[ "$_value_new" != "$_value_env" ]]; then
        if [ -n "$_value_env" ]; then
            sed -i "s/^$_param=.*/$_param=\"$_value_new\"/" "$_env"
        else
            echo "$_param=\"$_value_new\"" >> "$_env"
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

_bin_path="/opt/sbin"
_etc_path="/opt/etc"
_www_path="/opt/share/www"
_cert_path="${_etc_path}/tg"
_initd_path="${_etc_path}/init.d"
_lighttpd_path="${_etc_path}/lighttpd/conf.d"
_xkeentg_path="${_bin_path}/.xkeentg"
_env="${_xkeentg_path}/.env"

[ -f "$_env" ] && . "$_env"

# заполнение файла .env
echo "Сбор параметров для установки..."
mkdir -p "$_xkeentg_path"

if [[ ! -f "$CERT_PATH/host.pem" || "$_cmd" == "$_cmd_renew" ]]; then
    . "./ip2geo.sh"
    get_geo_info
    if [[ "$_cmd" == "$_cmd_renew" ]]; then
        CERT_COUNTRY=""
        CERT_STATE=""
        CERT_CITY=""
    fi
    check_config_param "Код страны" "CERT_COUNTRY" "${_country}"
    check_config_param "Регион или область" "CERT_STATE" "${_state}"
    check_config_param "Город" "CERT_CITY" "${_city}"
    check_config_param "Организация" "CERT_ORG" "Home"
    check_config_param "Подразделение" "CERT_ORG_UNIT" "IT"
    check_config_param "Домен для сертификата" "DOMAIN"
    check_config_param "Путь к сертификатам" "CERT_PATH" "$_cert_path"
fi
check_config_param "Токен вашего бота Телеграм" "TG_TOKEN"
check_config_param "Список валидных пользователей (id через пробел)" "TG_CHAT_IDS"
check_config_param "Порт для webhook бота Телеграм" "TG_WEBHOOK_PORT" "8443"
check_config_param "Порт для работы бота Телеграм" "TG_LOCAL_PORT" $(($TG_WEBHOOK_PORT + 1))
check_config_param "Внешний ip-адрес роутера" "ROUTER_IP_EXTERNAL" "$(get_external_ip)"
check_config_param "Внутренний ip-адрес роутера" "ROUTER_IP_INTERNAL" "$(get_internal_ip)"

chmod ugo-x "$_env"

# обновление Entware
echo "Обновление Entware..."
opkg update &>/dev/null
# opkg upgrade &>/dev/null

# установка необходимых пакетов
echo "Установка необходимых пакетов (openssl-util, lighttpd, netcat)..."

# создание сертификата
opkg install openssl-util &>/dev/null
mkdir -p "$CERT_PATH"
if [[ ! -f "$CERT_PATH/host.pem" || "$_cmd" == "$_cmd_renew" ]]; then
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
    cat "${CERT_PATH}/host.key" "${CERT_PATH}/host.crt" > "${CERT_PATH}/host.pem" &>/dev/null
    chmod 400 "${CERT_PATH}/host.key" "${CERT_PATH}/host.crt" "${CERT_PATH}/host.pem" &>/dev/null
fi

# установка web-сервера
echo "Установка web-сервера lighttpd..."
opkg install lighttpd &>/dev/null
opkg install lighttpd-mod-setenv &>/dev/null
opkg install lighttpd-mod-openssl &>/dev/null
opkg install lighttpd-mod-proxy &>/dev/null
opkg install lighttpd-mod-rewrite &>/dev/null
opkg install netcat &>/dev/null

echo "Настройка модулей web-сервера..."
find "$_lighttpd_path" -regex "^${_lighttpd_path}/[0-9]+-tg.conf$" -exec rm -f {} \;
_num_max=$(find ${_lighttpd_path} -type f -name "*.conf" -exec basename {} \; | grep -o "^[0-9]\+" | sort -nr | head -n 1)
if [ -n "$_num_max" ]; then
    _num_max=$(($_num_max + 5))
else
    _num_max=99
fi
_file_conf="${_lighttpd_path}/${_num_max}-tg.conf"

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
    }
    else {
        url.rewrite = ( ".*" => "/none.html" )
    }
}

\$HTTP["host"] == "${ROUTER_IP_INTERNAL}" {
    index-file.names = ( "index.html" )

    \$HTTP["url"] !~ "^/style\.css$" {
        url.rewrite-if-not-file = ( ".*" => "/none.html" )
    }
}
EOF

# установка сервиса
mv -f www/* "$_www_path"
mv -f tgbotd "$_bin_path"
mv -f S99tgbotd "$_initd_path"
# mv -f xkeentg "$_bin_path"
# xkeentg --install

/opt/etc/init.d/S80lighttpd restart
/opt/etc/init.d/S99tgbotd restart
sleep 2
/opt/etc/init.d/S80lighttpd status
if [ $? -ne 0 ]; then
    echo "❌ Ошибка установки, проверьте конфигурацию lighttpd: ${_lighttpd_path}"
    exit 1
fi
/opt/etc/init.d/S99tgbotd status
if [ $? -ne 0 ]; then
    echo "❌ Ошибка установки, проверьте конфигурацию xkeen-tg: ${_xkeentg_path}"
    exit 2
fi

_json=$(curl -s "https://api.telegram.org/bot${TG_TOKEN}/getWebhookInfo")
_ok=$(echo "$_json" | jq -r '.ok')
if [[ "$_ok" != "true" || "$_cmd" == "$_cmd_renew" ]]; then
    echo "Регистрация webhook в Телеграме..."
    # получение IP-адреса: api.ipify.org или ifconfig.me
    _json=$(curl -s \
                 -F "url=https://${DOMAIN}:${TG_WEBHOOK_PORT}/${TG_TOKEN}" \
                 -F "ip_address=${ROUTER_IP_EXTERNAL}" \
                 -F "certificate=@${CERT_PATH}/host.crt" \
                    "https://api.telegram.org/bot${TG_TOKEN}/setWebhook")

    _ok=$(echo "$_json" | jq -r '.ok')
    _descr=$(echo "$_json" | jq -r '.description')
    if [[ "$_ok" != "true" ]]; then
        echo "❌ Ошибка регистрации webhook: ${_descr}"
        exit 3
    fi
    echo "✅ Регистрация webhook прошла успешно: ${_descr}"
fi
echo "✅ Установка завершена, перезагрузите роутер"
