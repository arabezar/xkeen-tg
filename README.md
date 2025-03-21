# xkeen-tg

![Github last commit](https://img.shields.io/github/last-commit/arabezar/xkeen-tg)
[![GitHub Release](https://img.shields.io/github/release/arabezar/xkeen-tg?style=flat&color=green)](https://github.com/arabezar/xkeen-tg/releases)
[![GitHub Stars](https://img.shields.io/github/stars/arabezar/xkeen-tg?style=flat)](https://github.com/arabezar/xkeen-tg/stargazers)
[![License](https://img.shields.io/github/license/arabezar/xkeen-tg?style=flat&color=orange)](LICENSE)
[![YooMoney](https://img.shields.io/badge/donate-YooMoney-8037fd.svg?style=flat)](https://yoomoney.ru/to/410013875426872)
[![CloudTips](https://img.shields.io/badge/donate-CloudTips-598bd7.svg?style=flat)](https://pay.cloudtips.ru/p/6352cb45)

Скрипты для установки `xkeen-tg` на маршрутизаторы с XKeen.

Предназначены для роутеров Keenetic/Netcraze с [установленным](https://help.keenetic.com/hc/ru/articles/360021214160-Установка-системы-пакетов-репозитория-Entware-на-USB-накопитель) [Entware](https://github.com/Entware/Entware) и [XKeen](https://github.com/Skrill0/XKeen).

> [!IMPORTANT]
> Данный материал подготовлен в научно-технических целях.
> Использование предоставленных материалов в целях отличных от ознакомления может являться нарушением действующего законодательства.
> Автор не несет ответственности за неправомерное использование данного материала.

> [!WARNING]
> **Вы пользуетесь этой инструкцией на свой страх и риск!**
> 
> Автор не несёт ответственности за порчу оборудования и программного обеспечения.

## Что это?

`xkeen-tg` - инструмент (ограниченного) управления конфигурацией утилиты [XKeen](https://github.com/Skrill0/XKeen) для роутеров через Telegram бота.

## Установка

### Предварительные требования

- Белый IP для Telegram Webhook
- Зарегистрированный бот Telegram с возможностью настройки webhook
- Роутер Keenetic с установленным XKeen (требуется root доступ)

### Настройка соединения для копирования сертификата

> [!NOTE]
> Задача: настроить соединение на роутере, чтобы таскать сертификат для защищённого соединения Telegram (webhook) с удалённого компа командой `scp`. Можно не выполнять эту настройку, если копирование сертификата не планируется
- На сервере (откуда забирать сертификат). Например, адрес в локальной сети `192.168.1.234`
  - Находясь в домашней папке загрузить скрипт, подгружающий и запускающий последнюю версию скрипта установки:
    ```sh
    curl -s -L https://github.com/arabezar/xkeen-tg/releases/latest/download/prepare_user.tar --output prepare_user.tar && tar -xf prepare_user.tar && rm prepare_user.tar && if [ -f .env ]; then rm .env.sample.user; else mv .env.sample.user .env; fi && chmod ugo-x .env LICENSE
    ```
  - Заполнить параметры скрипта в `.env` (например, `vi .env` или `nano .ext`)
  - Запустить скрипт командой `sudo prepare_on_server.sh` (`sudo` требуется для создания нового пользователя с минимальными правами для доступа по SSH и изменения прав чтения для файлов сертификата). Все вышеперечисленные действия можно проделать вручную:
    - Создать пользователя `want4cert` с минимальными правами
    - В домашней папке пользователя `want4cert` создать симлинки на файлы сертификата для последующего копирования файлов на роутер для бота Telegram
    - Ограничить пользователя `want4cert` на вход и работу только в домашней папке
- На роутере
  - Создать ключ:
    ```sh
    ssh-keygen -t rsa
    ```
  - Отправить его на сервер:
    ```sh
    ssh-copy-id -i ~/.ssh/id_rsa.pub want4cert@192.168.1.234
    ```
    Если команда `ssh-copy-id` не поддерживается роутером (скорее всего так), то
    ```sh
    cat ~/.ssh/id_rsa.pub | ssh want4cert@192.168.1.234 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
    ```
  - Проверить соединение
    ```sh
    ssh want4cert@192.168.1.234
    ```
  - Если не получается, добавить на сервере `PubkeyAuthentication yes` в `/etc/ssh/sshd_config`

### Установка на роутер

  - Загрузить скрипт, находясь в домашней папке
    ```sh
    curl -o install.sh https://raw.githubusercontent.com/arabezar/xkeen-tg/main/install.sh
    ```
  - Заполнить параметры скрипта в `.env`, так же как и на предыдущем шаге (по файлу шаблона `.env.sample`, можно просто изменить имеющийся файл, а потом переименовать в `.env`)
  - Запустить скрипт командой `install.sh`


## Использование

* Все команды исполняются из Телеграма.
  Краткую помощь по списку подкоманд можно получить непосредственно в Телеграме через меню.
* Команды разрешено выполнять только зарегистрированных пользователям, прописанным в настройках скрипта `.env`
* Полный список команд управления службой XKeen роутера с кратким описанием:
  ```sh
    <none-of-below> - список команд роутера
    check <domain>  - проверить статус домена в конфигурационных файлах
    add <domain>    - добавить домен в конфигурацию (+ перезагрузка)
    del <domain>    - закомментировать домен в конфигурации (+ перезагрузка)
    status          - проверить статус службы (статус, текущая и последняя версии xkeen, текущая и последняя версии xray, версии баз данных, внешние IP-адреса роутера)
    key <url>       - обновить параметры соединения в конфигурации (+ перезагрузка), в ответе - заменённый URL с датой к комменте
    restart         - перезагрузить службу
    можно использовать алиасы субкоманд:
    . <domain>      - проверить статус домена в конфигурационных файлах
    + <domain>      - добавить домен в конфигурацию (+ перезагрузка)
    - <domain>      - закомментировать домен в конфигурации (+ перезагрузка)
    ?               - проверить статус службы (статус, текущая и последняя версии xkeen, текущая и последняя версии xray, версии баз данных, внешние IP-адреса роутера)
    !               - перезагрузить службу
  ```

## Вклад

Все идеи, пожелания и замечания категорически приветствуются в разделах [Issues](https://github.com/arabezar/xkeen-tg/issues) и [Discussions](https://github.com/arabezar/xkeen-tg/discussions).

---

Нравится проект? Поддержи автора, купи ему :beers: или :coffee: ([тынц](https://yoomoney.ru/to/410013875426872) или [тынц](https://pay.cloudtips.ru/p/6352cb45))
