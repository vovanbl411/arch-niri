# План автоматизации очистки кэша WirePlumber

## Проблема
При использовании Arch + Niri + PipeWire могут возникать проблемы с воспроизведением коротких звуков уведомлений в Discord/Vesktop из-за поврежденного состояния кэша WirePlumber или конфликтующих кастомных правил.

## Решение
Очистка кэша WirePlumber и удаление потенциально конфликтующих кастомных правил решает проблему с воспроизведением коротких звуков уведомлений.

## Требуемые действия

### 1. Создание модуля очистки кэша WirePlumber
- Файл: `scripts/modules/wireplumber-cache-cleanup.sh`
- Функции:
  - `cleanup_wireplumber_cache()` - очистка кэша WirePlumber
  - `remove_custom_rules()` - удаление кастомных правил, которые могут конфликтовать
  - `cleanup_wireplumber_and_rules()` - комбинированная функция для полной очистки

## Технические детали решения

### Текущая рабочая схема
```
+ rm -rf ~/.local/state/wireplumber ~/.cache/pipewire-*
```

### Почему это работает
1. Удаление кэша очищает повреждённое состояние WirePlumber (те assertion ошибки исчезли)
2. Удаление кастомных правил убирает конфликты между pipewire-pulse правилами и WirePlumber

## Требуемые файлы

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

## Интеграция с модулем настройки PipeWire

Модуль очистки должен быть вызван перед настройкой PipeWire, чтобы убедиться, что старые конфликты устранены:

```bash
# В функции setup_pipewire_for_short_sounds():
setup_pipewire_config_dir
cleanup_wireplumber_and_rules  # Вызов очистки перед настройкой
backup_pipewire_config
configure_pipewire_min_quantum
restart_pipewire_services