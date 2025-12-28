#!/bin/bash

# Модуль для настройки PipeWire с правильными параметрами для коротких звуков уведомлений

# Проверяем, что другие модули загружены
if ! declare -f log_info >/dev/null 2>&1; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    source "$SCRIPT_DIR/modules/logging.sh" || {
        source "$SCRIPT_DIR/modules/config.sh"
    }
fi

# Функция для создания директории конфигурации PipeWire, если она не существует
setup_pipewire_config_dir() {
    local config_dir="$HOME/.config/pipewire"
    
    if [[ ! -d "$config_dir" ]]; then
        log_info "Создание директории конфигурации PipeWire: $config_dir"
        mkdir -p "$config_dir"
    fi
}

# Функция для резервного копирования существующего файла конфигурации
backup_pipewire_config() {
    local config_file="$HOME/.config/pipewire/pipewire.conf"
    
    if [[ -f "$config_file" ]]; then
        local backup_file="${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "Создание резервной копии: $config_file -> $backup_file"
        cp "$config_file" "$backup_file"
        log_info "Резервная копия создана: $backup_file"
    fi
}

# Функция для настройки PipeWire с правильным значением min-quantum
configure_pipewire_min_quantum() {
    local config_file="$HOME/.config/pipewire/pipewire.conf"
    local temp_config

    # Создаем временный файл
    temp_config=$(mktemp)

    # Если файл конфигурации уже существует, копируем его содержимое
    if [[ -f "$config_file" ]]; then
        # Копируем существующий файл во временный, заменяя или добавляя параметр min-quantum
        if grep -q "default.clock.min-quantum" "$config_file"; then
            # Если параметр уже существует, заменяем его
            sed "s/default\.clock\.min-quantum.*/default.clock.min-quantum = 1024/" "$config_file" > "$temp_config"
        else
            # Если параметра нет, добавляем его в секцию context.properties
            awk '
            /^context\.properties/ { 
                print $0
                in_context_props = 1
                printed_min_quantum = 0
                print "    default.clock.min-quantum = 1024  # Установлено для корректной работы коротких звуков уведомлений"
                next
            }
            in_context_props && /^[[:space:]]*[}]/ && !printed_min_quantum {
                print $0
                in_context_props = 0
                printed_min_quantum = 1
                next
            }
            { print $0 }
            ' "$config_file" > "$temp_config"
        fi
    else
        # Создаем новый файл с минимальной конфигурацией
        cat > "$temp_config" << 'EOF'
{
    # PipeWire конфигурация для корректной работы коротких звуков уведомлений
    context.properties = {
        # Установка минимального кванта времени для корректной работы коротких звуков
        default.clock.min-quantum = 1024
        
        # Остальные параметры по умолчанию
        default.clock.quantum = 1024
        default.clock.rate = 48000
    }
}
EOF
    fi

    # Копируем временный файл в конечное место
    cp "$temp_config" "$config_file"
    rm "$temp_config"

    log_info "Конфигурация PipeWire обновлена: $config_file"
    log_info "Установлено значение default.clock.min-quantum = 1024"
}

# Функция для перезапуска сервисов PipeWire
restart_pipewire_services() {
    log_info "Перезапуск сервисов PipeWire..."

    # Перезапускаем пользовательские сервисы
    systemctl --user restart pipewire pipewire-pulse wireplumber

    # Ждем немного, чтобы сервисы стартовали
    sleep 2

    # Проверяем статус сервисов
    if systemctl --user is-active --quiet pipewire && 
       systemctl --user is-active --quiet pipewire-pulse && 
       systemctl --user is-active --quiet wireplumber; then
        log_info "Сервисы PipeWire успешно перезапущены"
    else
        log_error "Некоторые сервисы PipeWire не запустились корректно"
        log_info "Проверьте статус сервисов: systemctl --user status pipewire pipewire-pulse wireplumber"
    fi
}

# Основная функция настройки PipeWire
setup_pipewire_for_short_sounds() {
    log_info "Настройка PipeWire для корректной работы коротких звуков уведомлений..."

    setup_pipewire_config_dir
    backup_pipewire_config
    configure_pipewire_min_quantum
    restart_pipewire_services

    log_info "Настройка PipeWire завершена"
}

# Функция для отображения текущей конфигурации
show_current_pipewire_config() {
    local config_file="$HOME/.config/pipewire/pipewire.conf"

    if [[ -f "$config_file" ]]; then
        log_info "Текущая конфигурация PipeWire ($config_file):"
        grep -n "min-quantum\|context\.properties" "$config_file" || echo "Параметры min-quantum не найдены"
    else
        log_info "Файл конфигурации PipeWire не найден: $config_file"
    fi
}
