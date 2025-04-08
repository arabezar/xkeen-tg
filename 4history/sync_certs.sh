#!/bin/sh

# === Загрузка конфигурации ===
. ".env"

# === Функции ===

# Функция отправки сообщений в Телеграм
send_telegram() {
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
        -d "chat_id=$1" \
        -d "text=$2"
}

# Проверка изменений сертификатов
check_cert_update() {
    echo "🔍 Проверка обновления сертификатов для $DOMAIN..."
    for file in "${CERT_FILES[@]}"; do
        LOCAL_FILE="/tmp/$file"
        REMOTE_FILE="$SYNOLOGY_CERT_PATH/$file"

        # Загружаем сертификат с Synology во временную папку
        scp "$SYNOLOGY_USER@$SYNOLOGY_IP:$REMOTE_FILE" "$LOCAL_FILE"
        if [[ $? -ne 0 ]]; then
            echo "❌ Ошибка загрузки $file"
            send_telegram "❌ Ошибка загрузки сертификата $file с Synology!"
            exit 1
        fi

        # Сравниваем с текущей версией на роутере
        ssh "$ROUTER_USER@$ROUTER_IP" "md5sum $ROUTER_CERT_PATH/$file" > /tmp/old_md5
        md5sum "$LOCAL_FILE" > /tmp/new_md5

        if diff /tmp/old_md5 /tmp/new_md5 > /dev/null; then
            echo "✅ $file не изменился."
        else
            echo "⚡ Найдено обновление $file!"
            return 0
        fi
    done
    return 1
}

# Проверка валидности сертификата
check_cert_validity() {
    echo "🔍 Проверка валидности сертификата для $DOMAIN..."
    EXPIRY_DATE=$(openssl x509 -enddate -noout -in "/tmp/fullchain.cer" | cut -d= -f2)
    EXPIRY_TIMESTAMP=$(date -d "$EXPIRY_DATE" +%s)
    CURRENT_TIMESTAMP=$(date +%s)
    DIFF_DAYS=$(( ($EXPIRY_TIMESTAMP - $CURRENT_TIMESTAMP) / 86400 ))

    if [[ $DIFF_DAYS -gt 0 ]]; then
        echo "✅ Сертификат действителен до $EXPIRY_DATE ($DIFF_DAYS дней осталось)."
        return 0
    else
        echo "❌ Сертификат истёк!"
        send_telegram "❌ ВНИМАНИЕ! Сертификат для $DOMAIN истёк!"
        return 1
    fi
}

# Копирование сертификатов на роутер
copy_certs_to_router() {
    echo "📤 Копирование обновлённых сертификатов на роутер..."
    for file in "${CERT_FILES[@]}"; do
        scp "/tmp/$file" "$ROUTER_USER@$ROUTER_IP:$ROUTER_CERT_PATH/"
        if [[ $? -eq 0 ]]; then
            echo "✅ $file успешно скопирован!"
        else
            echo "❌ Ошибка копирования $file!"
            send_telegram "❌ Ошибка копирования $file на роутер!"
            exit 1
        fi
    done
}

# Перезапуск Webhook-сервера на роутере
restart_webhook() {
    echo "🔄 Перезапуск Webhook-сервера..."
    ssh "$ROUTER_USER@$ROUTER_IP" "pkill -f xkeentg.sh; nohup bash /opt/bin/xkeentg.sh &"
    send_telegram "✅ Сертификаты для $DOMAIN обновлены, Webhook-сервер перезапущен! 🚀"
}

# === Основной процесс ===
if [[ "$SYNC_ENABLED" = true ]]; then
    check_cert_update
    if [[ $? -eq 0 ]]; then
        check_cert_validity
        if [[ $? -eq 0 ]]; then
            copy_certs_to_router
            restart_webhook
        fi
    else
        echo "⏳ Обновлений нет, завершаем работу."
    fi
else
    echo "⏸ Автообновление отключено."
fi
