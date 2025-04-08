#!/bin/sh

LATEST_RELEASE_URL="https://github.com/arabezar/xkeen-tg/releases/latest/download/xkeentg.tar"

_version="0.1.1"
_cmd="$1"
_cmd_options="$2"
# _ip="$2"

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
    if [ -z "$_value_new" ]; then
        echo "Параметр не может быть пустым, установка отменена"
        exit 255
    fi

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

set_conf_param() {
    local _file="$1"
    local _param="$2"
    local _param_esc="$(escape "$_param")"
    local _value="$3"
    local _value_esc="$(escape "$_value")"
    local _str_char="$4"

    if [ -f "$_file" ]; then
        if grep -q "$_param_esc" "$_file"; then
            sed -i "s/^${_param_esc}\\s*=.*/${_param_esc} = ${_str_char}${_value_esc}${_str_char}/" "$_file"
        else
            echo "${_param} = ${_str_char}${_value}${_str_char}" >> "$_file"
        fi
    else
        echo "Файл конфигурации $_file не найден, установка отменена"
        exit 255
    fi
}

set_conf_subparam() {
    local _file="$1"
    local _param="$2"
    local _param_esc="$(escape "$_param")"
    local _subparam="$3"
    local _value="$4"
    local _search_prefix="$5"

    if [ -f "$_file" ]; then
        if grep -q "${_search_prefix}${_param_esc}" "$_file" &>/dev/null; then
            # sed -i "/${_param_esc}/,/}/ s/${_subparam}.*)/${_subparam} = ${_value}/" "$_file"
            sed -i "/${_search_prefix}${_param_esc}/,/${_search_prefix}}/d" "$_file"
        fi
        echo "${_param} {\n    ${_subparam} = ${_value}\n}" >> "$_file"
    else
        echo "Файл конфигурации $_file не найден, установка отменена"
        exit 255
    fi
}

escape() {
    echo "${2}${1}${2}" | sed "s/[]\/[]/\\\&/g"
}

case "$_cmd" in
    --cert)
        curl -sLO "$LATEST_RELEASE_URL"
        tar -xf xkeentg.tar prepare_cert.sh
        chmod +x prepare_cert.sh
        rm -f xkeentg.tar

        # заполнение файла .env
        _env=.env

        check_config_param "Имя пользователя для синхронизации сертификата" "SSH_USER" "want4cert"
        check_config_param "Пароль пользователя" "SSH_PASS" "want4cert"
        check_config_param "Домен для сертификата" "DOMAIN"
        check_config_param "Путь к сертификатам" "CERT_PATH" "/usr/local/share/acme.sh/\${DOMAIN}_ecc"
        echo "Параметры сохранены, создаём пользователя и настраиваем сертификат..."

        chmod ugo-x "$_env"

        # запуск скрипта создания пользователя и настройки для копирования сертификата
        sudo ./prepare_cert.sh
        ;;

    --router)
        # if [ -z "$_ip" ]; then
        #     echo "Не указан IP-адрес сервера сертификата, подключение не будет настроено"
        # elif [[ ! "$_ip" =~ "^((25[0-5]|(2[0-4]|1[0-9]|[1-9]|)[0-9])\.?){4}$" ]]; then
        #     echo "Некорректный IP-адрес сервера сертификата, подключение не будет настроено"
        #     _ip=""
        # elif [ ! -f ~/.ssh/id_rsa ]; then
        #     ssh-keygen -t rsa -f ~/.ssh/id_rsa -C "xkeentg" &>/dev/null
        #     cat ~/.ssh/id_rsa.pub | ssh want4cert@"$_ip" "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
        # fi

        # curl -sLO "$LATEST_RELEASE_URL"
        # tar -xf xkeentg.tar xkeentg S99tgbotd
        # chmod +x xkeentg S99tgbotd
        # rm -f xkeentg.tar

        _bin_path="/opt/sbin"
        _etc_path="/opt/etc"
        _cert_path="/opt/etc/tg"
        _initd_path="${_etc_path}/init.d"
        _xkeentg_path="${_bin_path}/.xkeentg"
        _lighttpd_path="${_etc_path}/lighttpd/conf.d"
        _env="${_xkeentg_path}/.env"

        [ -f "$_env" ] && . "$_env"

        # заполнение файла .env
        mkdir -p "$_xkeentg_path"

        echo "Сбор параметров для установки..."

        # если требуется копировать сертификат с другого компа
        # if [ -n "$_ip" ]; then
        #     check_config_param "Сервер с сертификатами" "CERT_IP" "$_ip"
        #     check_config_param "Имя пользователя для синхронизации сертификата" "SSH_USER" "want4cert"
        #     check_config_param "Путь к сертификатам" "CERT_PATH" "$_cert_path"
        # fi
        # самоподписанный сертификат

        if [[ ! -f "$CERT_PATH/host.pem" || "$_cmd_options" == "renew" ]]; then
            check_config_param "Код страны" "COUNTRY" "RU"
            check_config_param "Регион" "REGION" "Russia"
            check_config_param "Город" "CITY" "Moscow"
            check_config_param "Организация" "ORG" "Home"
            check_config_param "Подразделение" "ORG_UNIT" "IT Department"
            check_config_param "Домен для сертификата" "DOMAIN"
            # check_config_param "Информация о домене для сертификата (CSR)" "CSR_INFO" "/C=${COUNTRY}/ST=${REGION}/L=${CITY}/O=${ORG}/OU=${OU}/CN=${DOMAIN}"
            check_config_param "Путь к сертификатам" "CERT_PATH" "$_cert_path"
        fi
        check_config_param "Токен вашего бота Телеграм" "TELEGRAM_TOKEN"
        check_config_param "Список валидных пользователей (id через пробел)" "CHAT_IDS"
        check_config_param "Порт для webhook бота Телеграм " "TG_WEBHOOK_PORT" "8443"
        check_config_param "Порт для работы бота Телеграм " "TG_LOCAL_PORT" $(($TG_WEBHOOK_PORT + 1))

        chmod ugo-x "$_env"

        # обновление Entware
        echo "Обновление Entware..."
        opkg update &>/dev/null
        # opkg upgrade &>/dev/null

        # установка необходимых пакетов
        echo "Установка необходимых пакетов..."

        # создание сертификата
        opkg install openssl-util &>/dev/null
        mkdir -p "$CERT_PATH"
        if [[ ! -f "$CERT_PATH/host.pem" || "$_cmd_options" == "renew" ]]; then
            CSR_INFO="/C=${COUNTRY}/ST=${REGION}/L=${CITY}/O=${ORG}/OU=${OU}/CN=${DOMAIN}"
            echo "Выпуск сертификата (CSR: ${CSR_INFO})..."
            openssl req \
                -new \
                -x509 \
                -days 3650 \
                -nodes \
                -newkey rsa:2048 \
                -keyout "${CERT_PATH}/host.key" \
                -out "${CERT_PATH}/host.crt" \
                -subj "${CSR_INFO}" &>/dev/null
            cat "${CERT_PATH}/host.key" "${CERT_PATH}/host.crt" > "${CERT_PATH}/host.pem" &>/dev/null
            chmod 400 "${CERT_PATH}/host.key" "${CERT_PATH}/host.crt" "${CERT_PATH}/host.pem" &>/dev/null
        fi

        # установка http-сервера
        echo "Установка web-сервера lighttpd..."
        opkg install lighttpd &>/dev/null

        echo "Настройка модулей web-сервера..."
        opkg install lighttpd-mod-setenv &>/dev/null
        set_conf_param "${_lighttpd_path}/30-setenv.conf" "setenv.add-response-header" "$(escape '( "Content-Type" => "text/html; charset=UTF-8" )')"

        opkg install lighttpd-mod-openssl &>/dev/null
        set_conf_param "${_lighttpd_path}/30-openssl.conf" "server.port" "$TG_WEBHOOK_PORT"
        set_conf_param "${_lighttpd_path}/30-openssl.conf" "server.bind" "0.0.0.0" "\""
        set_conf_param "${_lighttpd_path}/30-openssl.conf" "ssl.engine" "enable" "\""
        set_conf_param "${_lighttpd_path}/30-openssl.conf" "ssl.pemfile" "$(escape "${CERT_PATH}/host.pem")" "\""

        opkg install lighttpd-mod-proxy &>/dev/null
        set_conf_subparam "${_lighttpd_path}/30-proxy.conf" "\$HTTP[\"host\"] == \"${DOMAIN}\"" "proxy.server" "( \"\" => ( ( \"host\" => \"127.0.0.1\", \"port\" => ${TG_LOCAL_PORT} ) ) )"

        # opkg install lighttpd-mod-access &>/dev/null
        # set_conf_subparam "${_lighttpd_path}/30-access.conf" "\$HTTP[\"url\"] !~ \"^/${TELEGRAM_TOKEN}\$\"" "access.deny" "(\"\")"
        opkg install lighttpd-mod-rewrite &>/dev/null
        set_conf_subparam "${_lighttpd_path}/30-rewrite.conf" "\$HTTP[\"url\"] !~ \"^/${TELEGRAM_TOKEN}\$\"" "url.rewrite" "(\".*\" => \"\/none.html\" )"

        opkg install netcat &>/dev/null

        # установка сервиса
        # mv -f xkeentg /opt/sbin
        # mv -f S99tgbotd /opt/etc/init.d
        # xkeentg --install

        /opt/etc/init.d/S80lighttpd restart
        # /opt/etc/init.d/S99tgbotd restart
        sleep 2
        /opt/etc/init.d/S80lighttpd status
        if [ $? -ne 0 ]; then
            echo "❌ Ошибка установки, проверьте конфигурацию lighttpd: ${_lighttpd_path}"
            exit 1
        fi

        echo "Регистрация webhook в Телеграме..."
        # получение IP-адреса: api.ipify.org или ifconfig.me
        _json=$(curl -s\
                -F "url=https://${DOMAIN}:${TG_WEBHOOK_PORT}/${TELEGRAM_TOKEN}" \
                -F "ip_address=$(curl -s api.ipify.org)" \
                -F "certificate=@${CERT_PATH}/host.crt" \
                   "https://api.telegram.org/bot${TELEGRAM_TOKEN}/setWebhook")

        _ok=$(echo "$_json" | jq -r '.ok')
        _descr=$(echo "$_json" | jq -r '.description')
        if [[ "$_ok" != "true" ]]; then
            echo "❌ Ошибка регистрации webhook: ${_descr}"
            exit 2
        fi

        echo "✅ Регистрация webhook прошла успешно: ${_descr}"


        echo "✅ Установка завершена, перезагрузите роутер"
        ;;

    *)
        echo "Использование: $0 [--cert|--router [<CERT.LAN.IP.ADDRESS>]]"
        exit 255
        ;;
esac
