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
> Задача: настроить соединение на роутере, чтобы таскать сертификат для защищённого соединения Telegram (webhook) с удалённого компа. Можно не выполнять эту настройку, если копирование сертификата не планируется
- На сервере (откуда забирать сертификат)
  - Находясь в домашней папке загрузить скрипт, подгружающий и запускающий последнюю версию скрипта установки:
    ```sh
    curl -sLO https://raw.githubusercontent.com/arabezar/xkeen-tg/main/install.sh && chmod +x install.sh && ./install.sh --cert
    ```
  - Заполнить все запрашиваемые параметры, `Enter` - подтвердить значение в квадратных скобках. Если задан пустой параметр или нажата комбинация `Ctrl-C`, скрипт выдаст ошибку и прервёт установку, однако его можно возобновить повторным запуском `./install.sh --cert`, подтвердив все уже записанные значения или изменяя необходимые
  - После ввода параметров скрипт автоматически начнёт процедуру проверки/создания указанного пользователя (`sudo` требуется для создания нового пользователя с минимальными правами для доступа по SSH и изменения прав чтения для файлов сертификата)
  - Все действия скрипта можно проделать и вручную:
    - Создать пользователя `want4cert` с минимальными правами
    - В домашней папке пользователя `want4cert` создать симлинки на файлы сертификата для последующего копирования файлов на роутер для бота Telegram
  - На Synology необходимо дополнительно в свойствах пользователя `want4cert` отключить изменение пароля, ограничить пользователю доступ только к домашней папке и всем приложениям (`Панель управления` -> `Пользователь и группа` -> `Пользователь` -> `want4cert` - кнопка `Редактировать` -> `Разрешения`: `Нет доступа` кроме `homes`; `Приложения`: `Запретить` все)
- На роутере (где будет работать Телеграм-бот, а также куда копировать сертификат)
  - Данная процедура описана ниже (при установке скрипта на роутер), однако можно её провести и вручную:
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

### Установка на роутер

  > [!NOTE]
  > Если IP-адрес сервера с сертификатом (например, адрес в локальной сети `192.168.1.234`) не указывать, то настройка соединения с сервером, где находится сертификат, не будет произведена.
  > Если же IP-адрес указать, будет произведена проверка, было ли соединение уже настроено, в этом случае настройка соединения также будет пропущена, иначе сформируется ключ соединения, и ключ будет отправлен на сервер (с запросом пароля при настройке, впоследствии пароль не понадобится)

  - Находясь в домашней папке загрузить скрипт, подгружающий и запускающий последнюю версию скрипта установки:
    ```sh
    curl -sLO https://raw.githubusercontent.com/arabezar/xkeen-tg/main/install.sh && chmod +x install.sh && ./install.sh --router 192.168.1.234
    ```
  - Заполнить все запрашиваемые параметры, `Enter` - подтвердить значение в квадратных скобках. Если задан пустой параметр или нажата комбинация `Ctrl-C`, скрипт выдаст ошибку и прервёт установку, однако его можно возобновить повторным запуском `./install.sh --router 192.168.1.234`, подтвердив все уже записанные значения или изменяя необходимые
  - После ввода параметров скрипт автоматически начнёт процедуру установки утилиты на роутер

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
