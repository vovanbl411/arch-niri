# План автоматизации настройки PipeWire для коротких звуков уведомлений

## Проблема
При использовании Arch + Niri + PipeWire возникает проблема с воспроизведением коротких звуков уведомлений в Discord/Vesktop. Звуки обрезаются или не воспроизводятся вообще.

## Решение
Настройка параметра `default.clock.min-quantum = 1024` в конфигурации PipeWire решает проблему с короткими звуками уведомлений.

## Требуемые действия

### 1. Создание модуля настройки PipeWire
- Файл: `scripts/modules/pipewire-config.sh`
- Функции:
  - `setup_pipewire_config_dir()` - создание директории конфигурации
  - `backup_pipewire_config()` - резервное копирование существующей конфигурации
  - `configure_pipewire_min_quantum()` - настройка параметра min-quantum
  - `restart_pipewire_services()` - перезапуск сервисов PipeWire
  - `setup_pipewire_for_short_sounds()` - основная функция настройки
  - `show_current_pipewire_config()` - отображение текущей конфигурации

### 2. Создание модуля очистки кэша WirePlumber
- Файл: `scripts/modules/wireplumber-cache-cleanup.sh`
- Функции:
  - `cleanup_wireplumber_cache()` - очистка кэша WirePlumber
  - `remove_custom_rules()` - удаление кастомных правил, которые могут конфликтовать

### 3. Интеграция в установочные скрипты
- Модификация `scripts/distributions/base/post-install.sh` для вызова новых функций
- Добавление опционального вызова в `scripts/modules/installer.sh`

### 4. Документация
- Обновление `docs/installation-guide.md` с описанием проблемы и решения
- Создание отдельного файла с объяснением проблемы и решения

## Технические детали решения

### Текущая рабочая схема
```
~/.config/pipewire/pipewire.conf:
context.properties = {
    ...
    default.clock.min-quantum = 1024  # КЛЮЧЕВОЕ изменение!
}

+ systemctl --user restart pipewire pipewire-pulse wireplumber
+ rm -rf ~/.local/state/wireplumber ~/.cache/pipewire-*
```

### Почему это работает
1. Глобальный `min-quantum = 1024` применён ко всем приложениям сразу, а не только к Discord через правила
2. Удаление кэша очистило повреждённое состояние WirePlumber (те assertion ошибки исчезли)
3. Удаление кастомных правил убрало конфликты между pipewire-pulse правилами и WirePlumber

### Итог
Это самое простое и надёжное решение для Arch + Niri + PipeWire. Больше никаких lua-правил или pulse.rules не нужно — глобальная настройка работает для всех приложений с короткими звуками (Discord, Telegram, Steam и т.д.).

## Требуемые файлы

### Основной модуль настройки PipeWire
```bash
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
```

### Модуль очистки кэша WirePlumber
```bash
#!/bin/bash

# Модуль для очистки кэша WirePlumber и удаления конфликтующих правил

# Проверяем, что другие модули загружены
if ! declare -f log_info >/dev/null 2>&1; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    source "$SCRIPT_DIR/modules/logging.sh" || {
        source "$SCRIPT_DIR/modules/config.sh"
    }
fi

# Функция для очистки кэша WirePlumber
cleanup_wireplumber_cache() {
    local cache_dirs=("$HOME/.local/state/wireplumber" "$HOME/.cache/pipewire-*")
    
    log_info "Очистка кэша WirePlumber и PipeWire..."
    
    # Удаляем директории кэша
    for cache_dir in "${cache_dirs[@]}"; do
        if [[ "$cache_dir" == "$HOME/.cache/pipewire-*" ]]; then
            # Обработка шаблона
            for dir in "$HOME/.cache/pipewire-"*; do
                if [[ -d "$dir" ]]; then
                    log_info "Удаление: $dir"
                    rm -rf "$dir"
                fi
            done
        else
            if [[ -d "$cache_dir" ]]; then
                log_info "Удаление: $cache_dir"
                rm -rf "$cache_dir"
            fi
        fi
    done
    
    log_info "Очистка кэша завершена"
}

# Функция для удаления кастомных lua-правил, которые могут конфликтовать
remove_custom_rules() {
    local custom_rule_paths=("$HOME/.config/wireplumber/main.lua.d" "$HOME/.config/pipewire/pipewire-pulse.conf.d")
    
    log_info "Удаление потенциально конфликтующих кастомных правил..."
    
    for rule_path in "${custom_rule_paths[@]}"; do
        if [[ -d "$rule_path" ]]; then
            log_info "Проверка: $rule_path"
            
            # Проверяем, есть ли в директории какие-либо файлы
            if ls "$rule_path"/* &>/dev/null; then
                log_info "Найдены кастомные правила в $rule_path, предлагаю удалить:"
                ls -la "$rule_path"
                
                log_info "Удаление кастомных правил из $rule_path"
                rm -rf "$rule_path"
            else
                log_info "В $rule_path нет файлов для удаления"
            fi
        fi
    done
    
    log_info "Удаление кастомных правил завершено"
}

# Комбинированная функция для полной очистки
cleanup_wireplumber_and_rules() {
    log_info "Полная очистка WirePlumber и кастомных правил..."
    
    cleanup_wireplumber_cache
    remove_custom_rules
    
    log_info "Полная очистка завершена"
}
```

## Интеграция в существующие скрипты

### Модификация post-install.sh
В файл `scripts/distributions/base/post-install.sh` нужно добавить вызов функций настройки PipeWire после настройки сервисов.

### Добавление в installer.sh
В файл `scripts/modules/installer.sh` можно добавить опциональный вызов настройки PipeWire при установке аудио-видео пакетов.