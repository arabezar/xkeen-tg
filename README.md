# xkeen-tg

![Github last commit](https://img.shields.io/github/last-commit/arabezar/xkeen-tg)
[![GitHub Release](https://img.shields.io/github/release/arabezar/xkeen-tg?style=flat&color=green)](https://github.com/arabezar/xkeen-tg/releases)
[![GitHub Stars](https://img.shields.io/github/stars/arabezar/xkeen-tg?style=flat)](https://github.com/arabezar/xkeen-tg/stargazers)
[![License](https://img.shields.io/github/license/arabezar/xkeen-tg?style=flat&color=orange)](LICENSE)
[![YooMoney](https://img.shields.io/badge/donate-YooMoney-8037fd.svg?style=flat)](https://yoomoney.ru/to/410013875426872)
[![CloudTips](https://img.shields.io/badge/donate-CloudTips-598bd7.svg?style=flat)](https://pay.cloudtips.ru/p/6352cb45)
[![visitors](https://visitor-badge.laobi.icu/badge?page_id=arabezar.xkeen-tg&left_color=green&right_color=blue)](https://github.com/arabezar/xkeen-tg)

Инструмент (ограниченного) управления маршрутизатором и конфигурацией утилиты `XKeen` для роутеров через Telegram бота. Написан исключительно на `shell` (`bash`), но, разумеется, использует пакеты `Entware`. Весь код полностью открыт и доступен для изучения

Предназначен для роутеров Keenetic/Netcraze с [установленным](https://help.keenetic.com/hc/ru/articles/360021214160-Установка-системы-пакетов-репозитория-Entware-на-USB-накопитель) [Entware](https://github.com/Entware/Entware) и [XKeen](https://github.com/Skrill0/XKeen).
> [!TIP]
> Теоретически инструмент может работать на любой связке `Entware` и `xray`, если будут предложения и необходимость, можно попробовать реализовать, обсуждения можно вести в [Discussions](https://github.com/arabezar/xkeen-tg/discussions)

> [!IMPORTANT]
> Данный материал подготовлен в научно-технических целях.
> Использование предоставленных материалов в целях отличных от ознакомления может являться нарушением действующего законодательства.
> Автор не несет ответственности за неправомерное использование данного материала.

> [!WARNING]
> **Вы пользуетесь этой инструкцией на свой страх и риск!**
> 
> Автор не несёт ответственности за порчу оборудования и программного обеспечения.

## Предварительные требования

- Белый IP для Telegram Webhook
- Зарегистрированный бот Telegram с возможностью настройки webhook
- Роутер Keenetic с установленным XKeen (требуется root доступ)
> [!IMPORTANT]
> Установщик определяет ваш внешний IP-адрес (сначала средствами роутера, если не получается - обращаясь к https://ifconfig.me) для дальнейшего определения страны, региона и города для CSR при выпуске самоподписанного сертификата, а также регистрации бота в Телеграм.

> [!TIP]
> Для определение страны, региона и города для CSR установщик использует внешние ресурсы, используя функции, выделенные в отдельный модуль `ip2geo.sh`. Если роутер подключён через VPN, то полученная от внешних ресурсов информация будет неверной, однако установщик позволяет переопределить страну, регион и город в момент установки. Также сервисы из `ip2geo.sh` могут ошибаться при определении региона и города даже по валидному ip-адресу. Если вы столкнулись с подобным поведением, у вас есть возможность сразу поправить параметры вводом корректных значений или, если у вас есть время, и вы чувствуете зуд перфекциониста 😊, можно прервать установку по `Ctrl+C` в момент сбора информации (как раз на ошибочно определённых регионе и городе), и запустить тестирование сервисов командой `./ip2geo_test.sh`, выбрать наиболее подходящий, скорректировать его в функции `get_geo_info` (в самом низу модуля) `ip2geo.sh`, после чего вновь запустить установщик командой `./install_xktg.sh --renew` (`--renew` используется только для обновления сертификата и всего, что с ним связано, остальная функциональность установщика не меняется) и продолжить установку `xkeen-tg`

  <details>
  <summary>Пример тестирования доступности сервисов</summary>
  
  ```sh
  root@router:~$ ./ip2geo_test.sh
  Время доступа для ipwho.is: 10 мс
      Страна: RU, Регион: Moscow Oblast, Город: Zagornovo
  Время доступа для api.sypexgeo.net: 10 мс
      Страна: RU, Регион: Moskva, Город: Moscow
  Время доступа для ipinfo.io: 20 мс
      Страна: RU, Регион: Moscow, Город: Moscow
  Время доступа для ipapi.co: 2 мс
      Страна: RU, Регион: Moscow Oblast, Город: Imeni Tsyurupy
  Время доступа для ipapi.is: 43 мс
      Страна: RU, Регион: Москва, Город: Moscow
  ```
  </details>

## Установка на роутер

- Открыть на роутере внешний порт `8843` на прослушивание
> [!IMPORTANT]
> Телеграм для webhook умеет слать на `80`, `88`, `443` и `8443` порты, другие не пробовал. На роутере необходимо открыть порт вручную, но в будущих версиях установщик сможет это делать сам. Необходимо в разделе `Безопасность (Security) → Фаервол (Firewall)`, у меня на `Keenetic Ultra II` это - `Сетевые правила → Межсетевой экран' → Wired (интерфейс от провайдера)`, добавить и включить правило `Telegram Bot` (`Действие`=`Разрешить`, `IP-адрес источника`=`Любой`, `IP-адрес назначения`=`127.0.0.1`, `Номер порта источника`=`Любой`, `Протокол`=`TCP`, `Номер порта назначения`=`8443` (один из указанных выше))

- Находясь в домашней папке (или создав в ней подпапку `xkeentg` и перейдя в неё, чтоб не мусорить) загрузить скрипт, подгружающий и запускающий последнюю версию скрипта установки:
  ```sh
  curl -sLO https://raw.githubusercontent.com/arabezar/xkeen-tg/main/install_xktg.sh && chmod +x install_xktg.sh && ./install_xktg.sh
  ```
- Заполнить все запрашиваемые параметры, `Enter` - подтвердить значение в квадратных скобках.
> [!TIP]
> Если параметр, являющийся обязательным для заполнения, не задан, например, в результате нажатия на `Enter`, то скрипт попросит ещё раз заполнить параметр, и так будет продолжаться до ввода параметра.

> [!TIP]
> Если нажата комбинация `Ctrl-C`, скрипт прервёт установку, однако её можно возобновить повторным запуском `./install_xktg.sh`, подтвердив все уже записанные значения или изменяя необходимые

- После ввода и сохранения параметров скрипт автоматически начнёт процедуру установки утилиты `xkeen-tg` на роутер, дождитесь завершения установки и перезагрузите роутер (не обязательно)

### Действия и описание параметров установки

При установке скрипт последовательно выполняет следующие действия:
- Проверяет наличие `Entware` и `XKeen`, а также совместимость с версией последней для установки `xkeen-tg`
- Скачивает и распаковывает в текущую папку файлы последнего релиза `xkeen-tg`
- Запрашивает параметры установки у пользователя и сохраняет их в конфигурационном файле `/opt/sbin/.xkeentg/.env`, в том числе:
  - Информация (CSR) для выпускаемого самоподписываемого сертификата для регистрации webhook бота Телеграм: `Код страны`, `Регион или область`, `Город`, `Организация`, `Подразделение`
    > Можно оставить эти параметры по умолчанию, они ни на что не влияют, параметры будут видны в самом сертификате при открытии, если это вообще когда-либо случится 😊. В начале данной страницы описано, как получаются параметры и как улучшить их определяемость по ip-адресу. Если кто хочет подискутировать на эту тему и не только, милости прошу в [Discussions](https://github.com/arabezar/xkeen-tg/discussions) и/или [Issues](https://github.com/arabezar/xkeen-tg/issues)

  - `Домен для сертификата`
    > Этот параметр должен строго соответствовать домену, на который будет регистрироваться webhook бота Телеграм, впоследствии бот будет общаться с роутером через этот домен. _Пример:_ `tg.example.com`. Динамические домены не пробовал, пробуйте сами, делитесь опытом в [Discussions](https://github.com/arabezar/xkeen-tg/discussions)

  - `Путь к сертификатам` - это путь по которому в роутере будет храниться вновь выпущенный сертификат с приватным ключём, можно оставить по умолчанию.
    > Выпущенный роутером сертификат будет использоваться как ботом Телеграм, так и вэб-сервером для безопасного соединения обоих между собой, поэтому удалять их из папки не рекомендуется

  - `Токен вашего бота Телеграм`, выдаётся ботом Телеграма `@BotFather` при регистрации вашего бота. Описывать регистрацию бота здесь смысла не имеет, описаний полно в интернетах
    > Данный токен используется не только для регистрации webhook бота на роутере, но и для ответа вашего бота Телеграмму, а также как виртуальная папка вэб-сервера на роутере, на которую Телеграм шлёт команды для обработки, таким образом увеличивая защиту вашего роутера,... ведь даже если злоумышленникам известен домен бота роутера, не зная токена они не смогут получить контроль над ботом, т.к. любые попытки отправки команд боту на известный домен роутера будут пресечены вэб-сервером и не достигнут бота

  - `Список валидных пользователей (id через пробел)` - идентификаторы (`chat_id`) пользователей, которые имеют доступ к управлению вашим роутером. Любой из пользователей имеет одинаковые права. _Пример_: `123456789 987654321 135790864`. Как узнать идентификатор пользователя ищите в интернетах, описаний полно

  - `Порт для webhook бота Телеграм` - входящий порт для прослушивания на роутере, куда приходят сообщения от пользователей Телеграма, можно оставить по умолчанию, если не занят на роутере
    > Телеграм для webhook умеет слать на `80`, `88`, `443` и `8443` порты, другие не пробовал. На роутере необходимо открыть порт вручную (см. самый первый пункт), но в будущих версиях установщик сможет это делать сам

  - `Порт для работы бота Телеграм` - прокси-порт для бота на роутере, который будет обрабатывать команды. Может быть любым незанятым портом на роутере, используется вэб-сервером роутера для проксирования запросов от Телеграма на бот обработчика команд

  - `Внешний ip-адрес роутера` - адрес, используемый для регистрации бота в Телеграм

  - `Внутренний ip-адрес роутера` - адрес, используемый для отображения страницы вэб-сервера в локальной сети

- Обновляет список состава и версий `Entware`, это действие позволяет загрузить стабильные пакеты последних версий
- Обновляет уже установленные пакеты `Entware` новыми версиями
  > Сложно сказать, необходимо ли обновлять уже установленные версии пакетов `Entware` или нет, но я у себя обновил, проблем не заметил. На всякий случай я закомментировал команду обновления уже установленных пакетов `Entware` в установщике, но могу в следующей версии либо включить эту возможность безусловно, либо по дополнительному запросу установщика. Предложения прошу писа́ть в [Discussions](https://github.com/arabezar/xkeen-tg/discussions)

- Устанавливает необходимые для `xkeen-tg` пакеты:
  - `openssl-util` - для выпуска самоподписываемого сертификата
  - `lighttpd` - очень лёгкий вэб-сервер с дополнительными модулями `mod-setenv, mod-openssl, mod-proxy, mod-rewrite` для защищённого обмена роутера и Телеграм
  - `netcat` - инструмент для обмена данными бота и Телеграма, работающий как ещё более лёгкий и быстрый незащищённый вэб-сервер через защищённый проксирующий вэб-сервер `lighttpd`

- Выпускает самоподписанный сертификат (если необходимо) сроком на 10 лет
  > Установщик проверяет, был ли ранее выпущен сертификат, и была ли введена команда на перевыпуск (`./install_xktg.sh --renew`). Если сертификат найден в указанной пользователем папке и команда на перевыпуск не подавалась, выпуск сертификата пропускается

- Конфигурирует веб-сервер в соответствии с указанными пользователем параметрами и сохраняет конфигурацию веб-сервера в папке `/opt/etc/lighttpd/conf.d`

- Копирует вспомогательные файлы вэб-сервера (статичные вэб-страницы - главная и ошибок) в корневую папку вэб-сервера `/opt/share/www`

- Копирует исполняемые файлы инструмента `xkeen-tg` (`tgbotd`, `xkeentg`) в системную папку `/opt/sbin`

- Регистрирует инструмент в автозагрузке (`S99xkeentg`)

- Запускает вэб-сервер и бот Телеграм

- Регистрирует webhook на роутер в Телеграм
    </details>
    <details>
      <summary>Лог</summary>
      
      ```sh
      ```
    </details>

## Удаление

- Находясь в домашней папке (или создав в ней подпапку `xkeentg` и перейдя в неё, чтоб не мусорить) загрузить скрипт, подгружающий и запускающий последнюю версию скрипта установки:
  ```sh
  curl -sLO https://raw.githubusercontent.com/arabezar/xkeen-tg/main/remove_xktg.sh && chmod +x remove_xktg.sh && ./remove_xktg.sh
  ```
- На все вопросы отвечать одной клавишей - Y|N или на киррилице Д|Н, `Enter` = N|Н
> [!NOTE]
> Если отрицательно ответить на первый же вопрос, скрипт просто не успеет ничего сделать и прекратит исполнение. Далее идут остановка сервисов с отображением статусов, удаление конфигурационных файлов, удаление регистрации бота в Телеграм, удаление выпущенных сертификатов, инструментов `netcat`, вэб-сервера `lighttpd`, инструментов для выпуска сертификата. От удаления настроек бота, выпущенного сертификата можно отказаться, если планируется в дальнейшем повторно устанавливать `xkeen-tg`, тогде при переустановке параметры и сертификат будут подхвачены установщиком. Также можно отказаться от удаления инструментов `netcat`, `openssl-util` и вэб-сервера `lighttpd`, если планируется использование их в других проектах

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
