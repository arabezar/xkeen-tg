# Функция определения номера строки для regex-шаблона в блоке конфигурации
_find_xray_config_mask() {
    local _json="$1"
    local _mask="$2"
    local _from="$3"
    local _i _ret
    for _i in $_mask; do
        [ -n "$_ret" ] && _from=$_ret
        if [ -n "$_from" ]; then
            _ret=$(echo "$_json" | tail -n "+$_from" | grep -iE "$_i" -m 1 | xargs | cut -d' ' -f1)
        else
            _ret=$(echo "$_json" | grep -iE "$_i" -m 1 | xargs | cut -d' ' -f1)
        fi
        [ -z "$_ret" ] && break
    done
    echo "$_ret"
}

# Функция чтения блока конфигурации
_find_xray_config_block_multilevel() {
    local _json="$1"
    local _from="$2"
    local _to="$3"
    local _from_line="$4"

    local _list=$(echo "$_json" | grep -E "{|}" | grep -vE "^[[:space:]]*\/\/" | sed -e "s/[^\{\?\}0-9]/ /g" | xargs)
    local _line_start=0
    local _val _line_end _level _found

    for _val in $_list; do
        [[ "$_val" =~ [[:digit:]]+ ]] && _line_n=$_val
        (( $_line_n < $_from_line )) && continue
        [[ "$_val" =~ ${_from} ]] && _level=$(( $_level + 1 ))
        [[ "$_val" =~ ${_to} ]] && _level=$(( $_level - 1 ))
        [[ $_level == 1 ]] && [[ $_line_start == 0 ]] && _line_start=$_line_n
        [[ $_level == 0 ]] && [[ $_line_start != 0 ]] && _line_end=$_line_n && echo "$_line_start $_line_end" && break
    done
}

# Функция поиска конфигурационного файла с определённым именем блока, поиска подблока с определённым именем, запуск callback-функции для блока
_find_xray_config() {
    local _block_name="$1"
    local _tag_name="$2"
    local _tag_value="$3"
    local _function="$4"

    local _filename _json _line_n _block_n _start _end _block
    if [ -d "${XRAY_CONFIG_PATH}" ]; then
        for _filename in ${XRAY_CONFIG_PATH}/*.json; do
            _json="$(awk '{print NR, $0}' "$_filename")"
            # _json="$(cat -n "$_filename")"
            _line_n=$(_find_xray_config_mask "$_json" "${_block_name}")
            while [ -n "$_line_n" ]; do
                # found block line num
                _block_n="$(_find_xray_config_block_multilevel "$_json" "\{" "\}" "$_line_n")"
                if [ -n "${_block_n}" ]; then
                    # get the section (dictionary)
                    _start="${_block_n%% *}"
                    _end="${_block_n#* }"
                    _line_n=$(($_end + 1))
                    _block="$(echo "$_json" | sed -n "${_start},${_end}p")"
                    if [ -n "$(_find_xray_config_mask "$_block" "\"${_tag_name}\"\s*:.*\"${_tag_value}\"")" ]; then
                        # call the function for block
                        [ -n "$_function" ] && $_function "$_block"
                        return 0
                    fi
                else
                    echo "$_end $_filename"
                    # _line_n=""
                    return 1
                fi
            done
        done
    fi
    return 255
}

# Функция получения значения ключа из блока по строке из файла
_get_config_value() {
    local _key="$1"
    local _filename="$2"
    local _line_n="$3"
    sed -n -r "${_line_n}s/^[[:space:]]*\"${_key}\"[[:space:]]*:[[:space:]]*\"?([^\",]*)\"?,?/\1/p" "${_filename}"
}

# Функция получения значения ключа из блока с номерами строк
_get_block_value() {
    local _key="$1"
    local _block="$2"
    echo "${_block}" | grep -i "\"${_key}\"" | sed -n -r "s/^[[:space:]]*[[:digit:]]*[[:space:]]*\"${_key}\"[[:space:]]*:[[:space:]]*\"?([^\",]*)\"?,?/\1/p"
}

# Функция callback получения порта прокси
get_proxy_port() {
    local _param="$1"
    local _block="$2"
    _get_block_value "${_param}" "${_block}"
}

# пример поиска порта прокси:
# _find_xray_config "inbounds" "protocol" "socks" "get_proxy_port port"
