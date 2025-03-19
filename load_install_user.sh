#!/bin/bash

TAG=arabezar/xkeen-tg

if LATEST=$(wget -q https://api.github.com/repos/${TAG}/releases?per_page=1); then
    TAG_URL=$(echo "${LATEST}" | grep "browser_download_url" | cut -d : -f 2,3 | tr -d '\" ')
    TAG_VERSION=$(echo "${LATEST}" | grep "tag_name" | cut -d : -f 2,3 | tr -d '\" ')
    echo "📦 Загрузка последней версии: ${TAG_VERSION}"
    wget -q -o prepare_user.tar ${TAG_URL} && \
    tar -xvf prepare_user.tar && \
    rm prepare_user.tar && \
    mv .env.example .env && \
    chmod +x prepare_user.sh && \
    echo "✅ Загрузка завершена, скорректируйте .env и запустите prepare_user.sh"
else
    echo "❌ Ошибка загрузки файла установки"
    exit 1
fi
