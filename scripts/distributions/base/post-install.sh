#!/bin/bash

# Постустановочные действия для базового дистрибутива

# Проверяем, что config.sh загружен
if [[ ! -v PROJECT_ROOT ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
    source "$SCRIPT_DIR/modules/config.sh"
fi

# Функция создания пользователя
create_user() {
    local username="$1"
    local password="$2"
    
    if [[ -n "$username" ]]; then
        log_info "Создание пользователя $username..."
        # Здесь можно добавить создание пользователя
        # useradd -m -G wheel -s /bin/bash "$username"
        # echo "$username:$password" | chpasswd
    fi
}

# Функция настройки sudo
setup_sudo() {
    log_info "Настройка sudo..."
    # Здесь можно добавить настройку sudo для группы wheel
    # sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
}

# Функция настройки автозагрузки сервисов
setup_services() {
    log_info "Настройка автозагрузки сервисов..."
    # Здесь можно добавить включение необходимых сервисов
    # systemctl enable systemd-networkd
    # systemctl enable systemd-resolved
    # systemctl enable greetd
}

# Функция настройки безопасности
setup_security() {
    log_info "Настройка безопасности..."
    # Здесь можно добавить настройки безопасности
}

# Функция для настройки PipeWire для коротких звуков уведомлений
setup_pipewire_for_short_sounds() {
    # Проверяем, установлены ли пакеты PipeWire
    if command -v pipewire &>/dev/null && command -v wireplumber &>/dev/null; then
        log_info "Настройка PipeWire для корректной работы коротких звуков уведомлений..."
        
        # Подключаем модуль настройки PipeWire, если он доступен
        if [[ -f "$SCRIPT_DIR/modules/pipewire-config.sh" ]]; then
            source "$SCRIPT_DIR/modules/pipewire-config.sh"
            # Подключаем модуль очистки кэша WirePlumber
            if [[ -f "$SCRIPT_DIR/modules/wireplumber-cache-cleanup.sh" ]]; then
                source "$SCRIPT_DIR/modules/wireplumber-cache-cleanup.sh"
                
                # Выполняем очистку кэша перед настройкой
                cleanup_wireplumber_and_rules
                # Выполняем настройку PipeWire
                setup_pipewire_for_short_sounds
            else
                log_info "Модуль очистки кэша WirePlumber не найден, выполняем только настройку PipeWire"
                setup_pipewire_for_short_sounds
            fi
        else
            log_info "Модуль настройки PipeWire не найден, пропускаем настройку"
        fi
    else
        log_info "PipeWire не установлен, пропускаем настройку"
    fi
}

# Основная функция постустановочных действий
post_installation() {
    local username="$1"
    local password="$2"
    
    log_info "Выполнение постустановочных действий..."
    
    create_user "$username" "$password"
    setup_sudo
    setup_services
    setup_security
    setup_pipewire_for_short_sounds
    
    log_info "Постустановочные действия завершены"
}