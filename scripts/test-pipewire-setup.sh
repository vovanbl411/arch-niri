#!/bin/bash

# Тестовый скрипт для проверки работы автоматизированной настройки PipeWire

# Определяем директорию скрипта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Подключаем необходимые модули
source "$SCRIPT_DIR/modules/config.sh"
source "$SCRIPT_DIR/modules/logging.sh"

# Подключаем модули настройки
if [[ -f "$SCRIPT_DIR/modules/pipewire-config.sh" ]]; then
    source "$SCRIPT_DIR/modules/pipewire-config.sh"
else
    log_error "Модуль настройки PipeWire не найден: $SCRIPT_DIR/modules/pipewire-config.sh"
    exit 1
fi

if [[ -f "$SCRIPT_DIR/modules/wireplumber-cache-cleanup.sh" ]]; then
    source "$SCRIPT_DIR/modules/wireplumber-cache-cleanup.sh"
else
    log_error "Модуль очистки кэша WirePlumber не найден: $SCRIPT_DIR/modules/wireplumber-cache-cleanup.sh"
    exit 1
fi

# Функция для тестирования настройки PipeWire
test_pipewire_setup() {
    log_info "=== Тестирование автоматизированной настройки PipeWire ==="
    
    # Показываем текущую конфигурацию до настройки
    log_info "Текущая конфигурация до настройки:"
    show_current_pipewire_config
    
    # Выполняем очистку кэша
    log_info "Выполняем очистку кэша WirePlumber..."
    cleanup_wireplumber_and_rules
    
    # Выполняем настройку PipeWire
    log_info "Выполняем настройку PipeWire..."
    setup_pipewire_for_short_sounds
    
    # Показываем конфигурацию после настройки
    log_info "Конфигурация после настройки:"
    show_current_pipewire_config
    
    log_info "=== Тестирование завершено ==="
}

# Функция для проверки правильности настройки
verify_pipewire_config() {
    local config_file="$HOME/.config/pipewire/pipewire.conf"
    
    log_info "Проверка правильности настройки PipeWire..."
    
    if [[ -f "$config_file" ]]; then
        if grep -q "default\.clock\.min-quantum = 1024" "$config_file"; then
            log_info "✓ Параметр default.clock.min-quantum = 1024 установлен корректно"
        else
            log_error "✗ Параметр default.clock.min-quantum не найден или установлен неправильно"
        fi
        
        # Проверяем статус сервисов
        if systemctl --user is-active --quiet pipewire; then
            log_info "✓ Сервис pipewire активен"
        else
            log_error "✗ Сервис pipewire неактивен"
        fi
        
        if systemctl --user is-active --quiet pipewire-pulse; then
            log_info "✓ Сервис pipewire-pulse активен"
        else
            log_error "✗ Сервис pipewire-pulse неактивен"
        fi
        
        if systemctl --user is-active --quiet wireplumber; then
            log_info "✓ Сервис wireplumber активен"
        else
            log_error "✗ Сервис wireplumber неактивен"
        fi
    else
        log_error "Файл конфигурации PipeWire не найден: $config_file"
    fi
}

# Основная функция тестирования
main() {
    log_info "Запуск тестирования автоматизированной настройки PipeWire для коротких звуков уведомлений"
    
    test_pipewire_setup
    verify_pipewire_config
    
    log_info "Тестирование завершено. Если все проверки показали ✓, то настройка выполнена успешно."
    log_info "Теперь короткие звуки уведомлений в Discord/Vesktop должны работать корректно."
}

# Запускаем основную функцию, если скрипт запущен напрямую
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi