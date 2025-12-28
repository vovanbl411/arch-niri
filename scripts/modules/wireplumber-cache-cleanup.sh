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
    local cache_dirs=("$HOME/.local/state/wireplumber" "$HOME/.cache/pipewire-"*)
    
    log_info "Очистка кэша WirePlumber и PipeWire..."
    
    # Удаляем директории кэша
    for cache_dir in "${cache_dirs[@]}"; do
        if [[ "$cache_dir" == "$HOME/.cache/pipewire-"* ]]; then
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