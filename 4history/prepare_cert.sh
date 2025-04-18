#!/bin/bash

# Определение папки скрипта
SCRIPT_PATH=$(cd `dirname $0` && pwd)

# Параметры скрипта
. $SCRIPT_PATH/.env

# функции-запросы
is_synology() { uname -a | grep "synology" &>/dev/null; }
ask_user() { read -p "$1 : " -n 1 -r && echo; [[ $REPLY =~ $2 ]]; }
user_get_info() { user_info=`grep -E "^${SSH_USER}" /etc/passwd`
                  user_dir=`echo "${user_info}" | cut -d ':' -f 6`
                  user_shell=`echo "${user_info}" | cut -d ':' -f 7`; }
user_not_exists() { user_get_info; [ -z "${user_info}" ]; }
user_inactive() { echo "${user_shell}" | grep -E "/nologin|/false" &>/dev/null; }
replace_slash() { echo "$1" | sed 's/\//\\\//g'; }
get_shell() { if is_synology; then echo "/bin/sh"; else echo "/bin/bash"; fi; }
user_shell_ok() { echo "${user_shell}" | grep $(get_shell) &>/dev/null; }

# функции, изменяющие реальные данные в системе
user_create_syno() { synouser --add "$SSH_USER" "$SSH_PASS" "User wants Let's Encrypt certificate" 0 "" 0 &>/dev/null; }
user_create_linux() { useradd -m -p "$SSH_PASS" -c "User wants Let's Encrypt certificate" "$SSH_USER" &>/dev/null; }
user_create() { if is_synology; then user_create_syno; else user_create_linux; fi; }
replace_shell() { sed -i "/^${SSH_USER}/s/$(replace_slash ${user_shell})/$(replace_slash $1)/" /etc/passwd &>/dev/null; }
activate_user() { replace_shell $(get_shell); }
create_link() { if [[ -L "${user_dir}/$1" ]]; then
                    show_info_cert_link_exists "$2"
                elif  [[ -f "$2" ]]; then
                    if ln -s "$2" "${user_dir}/$1" &>/dev/null; then
                        chmod o+r "${user_dir}/$1" &>/dev/null
                        show_info_cert_linked "$2"
                    else show_error_cant_create_link "$2"; fi
                else show_error_no_cert "$2"; fi; }

# функции вывода ошибок с выходом из скрипта
show_error() { echo "❌ $1" >&2; exit $2; }
show_error_nouser() { show_error "Пользователь ${SSH_USER} не найден" 1; }
show_error_user_created() { show_error "Ошибка создания пользователя ${SSH_USER}" 2; }
show_error_inactive() { show_error "Пользователь ${SSH_USER} деактивирован" 3; }
show_error_cannot_change_shell() { show_error "Ошибка изменения оболочки пользователя ${SSH_USER}" 4; }
show_error_cannot_limit() { show_error "Ошибка ограничения прав пользователя ${SSH_USER}" 5; }
show_error_no_cert_dir() { show_error "Директория с сертификатами '${CERT_PATH}' не найдена" 6; }
show_error_no_cert() { show_error "Файл сертификата '$1' не найден" 7; }
show_error_cant_create_link() { show_error "Ссылка на сертификат '$1' не создана" 8; }

# функции вывода информации
show_info_user_checking() { echo "🔍 Проверка существования пользователя ${SSH_USER}..."; }
show_info_user_exists() { echo "✅ Пользователь ${SSH_USER} найден"; }
show_info_user_deactivated() { echo "👤 Пользователь ${SSH_USER} деактивирован"; }
show_info_user_activated() { echo "✅ Пользователь ${SSH_USER} активирован"; }
show_info_user_shell_changed() { echo "✅ Оболочка пользователя ${SSH_USER} изменена"; }
show_info_user_creating() { echo "👤 Создание пользователя ${SSH_USER}..."; }
show_info_user_created() { echo "✅ Пользователь ${SSH_USER} создан"; }
show_info_cert_linked() { echo "🔗 Ссылка на сертификат '$1' создана"; }
show_info_cert_link_exists() { echo "🔗 Ссылка на сертификат '$1' уже существует"; }

# ================================================
# Проверка наличия переменных окружения
if [[ -z "${SSH_USER}" || -z "${SSH_PASS}" || -z "${DOMAIN}" || -z "${CERT_PATH}" ]]; then
    show_error "Не все переменные окружения установлены" 255
fi

# ================================================
# Проверка существования пользователя
show_info_user_checking
if user_not_exists; then
    if ask_user "❓ Создать пользователя ${SSH_USER}?" "^[YyДд]$"; then
        if user_create; then
            show_info_user_created
            user_not_exists # перечитать параметры пользователя
        else
            show_error_user_created
        fi
    else
        show_error_nouser
    fi
else
    show_info_user_exists
fi

# Включить пользователя, если он деактивирован
if user_inactive; then
    show_info_user_deactivated
    if ask_user "❓ Активировать пользователя ${SSH_USER}?" "^[YyДд]+"; then
        if activate_user; then
            show_info_user_activated
        else
            show_error_cannot_activate
        fi
    else
        show_error_inactive
    fi
# И проверить оболочку
elif ! user_shell_ok && ask_user "❓ Поменять оболочку пользователя ${SSH_USER} '${user_shell}' на '$(get_shell)'?" "^[YyДд]+"; then
    if activate_user; then
        show_info_user_shell_changed
    else
        show_error_cannot_change_shell
    fi
fi

# Создание ссылок на сертификат в домашней папке
if [[ -d "${CERT_PATH}" ]]; then
    create_link "cert.cer" "${CERT_PATH}/${DOMAIN}.cer"
    create_link "cert.key" "${CERT_PATH}/${DOMAIN}.key"
    create_link "fullchain.cer" "${CERT_PATH}/fullchain.cer"
else
    show_error_no_cert_dir
fi
