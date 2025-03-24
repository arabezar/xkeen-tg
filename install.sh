#!/bin/sh

LATEST_RELEASE_URL="https://github.com/arabezar/xkeen-tg/releases/latest/download/xkeentg.tar"

_env=".env"
_cmd="$1"
_ip="$2"

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

    # сохранение значения параметра
    if [[ "$_value_new" != "$_value_env" ]]; then
        if [ -n "$_value_env" ]; then
            sed -i "s/^${_param}=.*/${_param}=\"$_value_new\"/" "$_env"
        else
            echo "$_param=\"$_value_new\"" >> "$_env"
        fi
    fi
}

case "$_cmd" in
    --cert)
        curl -sLO "$LATEST_RELEASE_URL"
        tar -xf xkeentg.tar prepare_cert.sh
        rm -f xkeentg.tar

        # заполнение файла .env
        check_config_param "Имя пользователя для синхронизации сертификата" "SSH_USER" "want4cert"
        check_config_param "Пароль пользователя" "SSH_PASS" "want4cert"
        check_config_param "Домен для сертификата" "DOMAIN"
        check_config_param "Путь к сертификатам" "CERT_PATH" "/usr/local/share/acme.sh/\${DOMAIN}_ecc"
        echo "Параметры сохранены, создаём пользователя и настраиваем сертификат..."

        # назначение прав распакованным файлам
        chmod ugo-x .env
        chmod +x prepare_cert.sh

        # запуск скрипта создания пользователя и настройки для копирования сертификата
        sudo ./prepare_cert.sh
        ;;

    --router)
        if [ -z "$_ip" ]; then
            echo "Не указан IP-адрес сервера сертификата, подключение не будет настроено"
        elif [[ ! $_ip =~ ^((25[0-5]|(2[0-4]|1[0-9]|[1-9]|)[0-9])\.?){4}$ ]]; then
            echo "Некорректный IP-адрес сервера сертификата, подключение не будет настроено"
            _ip=""
        else
            ssh-keygen -t rsa
            cat ~/.ssh/id_rsa.pub | ssh want4cert@"$_ip" "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
        fi

        curl -sLO "$LATEST_RELEASE_URL"
        tar -xf xkeentg.tar xkeentg
        rm -f xkeentg.tar

        # заполнение файла .env
        if [ -n "$_ip" ]; then
            check_config_param "Сервер с сертификатами" "CERT_IP" "$_ip"
            check_config_param "Имя пользователя для синхронизации сертификата" "SSH_USER" "want4cert"
            check_config_param "Путь к сертификатам" "CERT_PATH" "/opt/etc"
        fi
        check_config_param "Токен вашего бота Телеграм" "TELEGRAM_TOKEN"
        check_config_param "Список валидных пользователей (id через пробел)" "CHAT_IDS"
        echo "Параметры сохранены, устанавливаем сервис..."
        
        # назначение прав распакованным файлам
        chmod ugo-x .env
        chmod +x xkeentg

        # установка сервиса
        ./xkeentg --install
        ;;

    *)
        echo "Использование: $0 [--cert|--router [<CERT.LAN.IP.ADDRESS>]]"
        exit 1
        ;;
esac
