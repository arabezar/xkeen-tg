# Функции получения страны, региона и города по IP-адресу

# get_geo_info # Получение информации о стране, регионе и городе по ip-адресу для выбранного сервиса
# get_geo_test # Тестирование сервисов для выбора наиболее подходящего для вашего ip-адреса

# Ресурсы, использовавшиеся для выбора сервиса, предложенные поиском:
# - ChatGPT:
#   - https://ipwhois.io/
# - Яндекс:
#   - https://habr.com/ru/companies/hflabs/articles/340466/
#   - https://www.iplocation.net/ip-lookup
# Минимальные требования для выбора: бесплатный доступ и отсутствие авторизации (токен)
# Какой конкретно вам подойдёт - решать только вам
# В данном модуле присутствует функция тестирования доступности сервисов
# После тестирования необходимо включить только выбранный сервис в функции get_geo_info (в конце модуля)

# Значения по умолчанию, предназначены для заполнения информации, если реальная информация не может быть получена
get_geo_defalts() {
    echo "Ошибка получения города и страны по IP-адресу, заполните вручную"
    _geo_country="RU"
    _geo_state="Moscow"
    _geo_city="Moscow"
}

get_geo_info_ipwho_is() {
    local _geo_ip_site="ipwho.is"
    local _geo_info="$(curl -s "$_geo_ip_site")"
    if [ $? -eq 0 ]; then
        _geo_country="$(echo "$_geo_info" | jq -r '.country_code')"
        _geo_state="$(echo "$_geo_info" | jq -r '.region')"
        _geo_city="$(echo "$_geo_info" | jq -r '.city')"
    fi
}

get_geo_info_sypexgeo_net() {
    local _geo_ip_site="https://api.sypexgeo.net/json"
    local _user_agent="Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:109.0) Gecko/20100101 Firefox/113.0"
    local _geo_info="$(curl -s -A "User-Agent: ${_user_agent}" "$_geo_ip_site")"
    if [ $? -eq 0 -a -n "$_geo_info" ]; then
        _geo_country="$(echo "$_geo_info" | jq -r '.country.iso')"
        _geo_state="$(echo "$_geo_info" | jq -r '.region.name_en')"
        _geo_city="$(echo "$_geo_info" | jq -r '.city.name_en')"
    fi
}

get_geo_info_ipinfo_io() {
    local _geo_ip_site="ipinfo.io/json"
    local _geo_info="$(curl -s "$_geo_ip_site")"
    if [ $? -eq 0 ]; then
        _geo_country="$(echo "$_geo_info" | jq -r '.country')"
        _geo_state="$(echo "$_geo_info" | jq -r '.region')"
        _geo_city="$(echo "$_geo_info" | jq -r '.city')"
    fi
}

get_geo_info_ipapi_co() {
    local _geo_ip_site="https://ipapi.co/json"
    local _geo_info="$(curl -s "$_geo_ip_site")"
    if [ $? -eq 0 ]; then
        _geo_country="$(echo "$_geo_info" | jq -r '.country')"
        _geo_state="$(echo "$_geo_info" | jq -r '.region')"
        _geo_city="$(echo "$_geo_info" | jq -r '.city')"
    fi
}

get_geo_info_ipapi_is() {
    local _geo_ip_site="https://api.ipapi.is"
    local _geo_info="$(curl -s "$_geo_ip_site")"
    if [ $? -eq 0 ]; then
        _geo_country="$(echo "$_geo_info" | jq -r '.location.country_code')"
        _geo_state="$(echo "$_geo_info" | jq -r '.location.state')"
        _geo_city="$(echo "$_geo_info" | jq -r '.location.city')"
    fi
}

# Тестирование сервисов с откликом
get_ping_test() {
    local _geo_ip_site="$1"
    local _ping_result="$(ping -4 -c 1 -W 1 "$_geo_ip_site" 2>/dev/null)"
    local _time_ms="$(echo "$_ping_result" | grep -oE 'time=[[:digit:]]+' | cut -d'=' -f2)"
    local _bad_address="$(echo "$_ping_result" | grep "not knows")"
    if [ -n "$_time_ms" ]; then
        echo "Время доступа для ${_geo_ip_site}: ${_time_ms} мс"
        return 0
    elif [ -z "${_ping_result}" ]; then
        echo "Неверный адрес ${_geo_ip_site}"
        return 1
    else
        echo "Сервер ${_geo_ip_site} недоступен"
        return 2
    fi
}

show_geo_info() {
    echo -e "\tСтрана: $_geo_country, Регион: $_geo_state, Город: $_geo_city"
}

get_geo_test() {
    get_ping_test "ipwho.is"
    if [ $? -eq 0 ]; then
        get_geo_info_ipwho_is
        show_geo_info
    fi

    get_ping_test "api.sypexgeo.net"
    if [ $? -eq 0 ]; then
        get_geo_info_sypexgeo_net
        show_geo_info
    fi

    get_ping_test "ipinfo.io"
    if [ $? -eq 0 ]; then
        get_geo_info_ipinfo_io
        show_geo_info
    fi

    get_ping_test "ipapi.co"
    if [ $? -eq 0 ]; then
        get_geo_info_ipapi_co
        show_geo_info
    fi

    get_ping_test "ipapi.is"
    if [ $? -eq 0 ]; then
        get_geo_info_ipapi_is
        show_geo_info
    fi
}

# Основная функция, в которой надо прописать предпочтительную из функций выше
get_geo_info() {
    # раскомментируйте только один сервис
    # get_geo_info_ipwho_is
    # get_geo_info_sypexgeo_net
    get_geo_info_ipinfo_io
    # get_geo_info_ipapi_co
    # get_geo_info_ipapi_is

    if [ -z "$_geo_country" ]; then
        get_geo_defalts
    fi
}
