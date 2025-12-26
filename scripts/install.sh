#!/bin/bash

# Скрипт для автоматической установки пакетов из списков проекта PKGS-ARCH
# Использование: ./scripts/install.sh [категория]

set -e  # Выход при ошибке

# Определяем директорию скрипта и сохраняем корень проекта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."
cd "$PROJECT_ROOT"

# Переменная для хранения пути к лог-файлу
LOG_FILE=""

# Функция для логирования в файл, если указан
log_to_file() {
    if [ -n "$LOG_FILE" ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
    fi
}

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция для вывода сообщений
print_message() {
    echo -e "${GREEN}[INFO]${NC} $1"
    log_to_file "[INFO] $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log_to_file "[WARNING] $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log_to_file "[ERROR] $1"
}

# Проверка прав суперпользователя для установки системных пакетов
check_sudo() {
    if [ "$EUID" -ne 0 ] && [ "$1" != "aur" ]; then
        print_error "Для установки системных пакетов требуется запуск с правами суперпользователя"
        print_message "Используйте: sudo ./scripts/install.sh или запустите скрипт от root"
        exit 1
    fi
}

# Массив для хранения путей к временным файлам
TEMP_FILES=()

# Функция для добавления временного файла в список для очистки
add_temp_file() {
    TEMP_FILES+=("$1")
}

# Функция для удаления всех временных файлов
cleanup_temp_files() {
    for temp_file in "${TEMP_FILES[@]}"; do
        if [ -f "$temp_file" ]; then
            rm -f "$temp_file"
        fi
    done
}

# Функция для обработки сигналов
handle_signal() {
    print_error "Получен сигнал прерывания. Завершение работы..."
    cleanup_temp_files
    exit 1
}

# Устанавливаем обработчик для сигналов прерывания
trap handle_signal SIGINT SIGTERM

# Устанавливаем обработчик для выхода из скрипта
trap cleanup_temp_files EXIT

# Функция установки пакетов из файла
install_from_file() {
    local file_path=$1
    local package_manager=$2
    local install_only_missing=${3:-false}
    
    # Если файл не существует по относительному пути, проверяем полный путь в PROJECT_ROOT
    if [ ! -f "$file_path" ]; then
        local full_path="$PROJECT_ROOT/$file_path"
        if [ -f "$full_path" ]; then
            file_path="$full_path"
        else
            print_warning "Файл $file_path не найден, пропускаем..."
            return 0
        fi
    fi
    
    if [ ! -s "$file_path" ]; then
        print_warning "Файл $file_path пуст, пропускаем..."
        return 0
    fi
    
    print_message "Установка пакетов из $file_path"
    
    # Если нужно установить только отсутствующие пакеты, фильтруем их
    if [ "$install_only_missing" = true ]; then
        print_message "Фильтрация уже установленных пакетов..."
        local temp_file=$(mktemp)
        add_temp_file "$temp_file"
        local package_list=$(cat "$file_path")
        
        # Определяем, какие пакеты уже установлены
        case $package_manager in
            "pacman")
                # Для pacman проверяем каждый пакет
                for pkg in $package_list; do
                    if ! pacman -Q "$pkg" &>/dev/null; then
                        echo "$pkg" >> "$temp_file"
                    fi
                done
                ;;
            "yay"|"paru")
                # Для AUR helpers проверяем через pacman и yay/paru
                for pkg in $package_list; do
                    if ! pacman -Q "$pkg" &>/dev/null; then
                        # Проверяем, возможно это AUR пакет
                        if command -v $package_manager &> /dev/null; then
                            # Простая проверка - если пакет не в pacman, добавляем в список
                            # Более точная проверка потребовала бы запроса к AUR
                            echo "$pkg" >> "$temp_file"
                        fi
                    fi
                done
                ;;
        esac
        
        # Проверяем, остались ли пакеты для установки
        if [ ! -s "$temp_file" ]; then
            print_message "Все пакеты из $file_path уже установлены"
            rm "$temp_file"
            return 0
        fi
        
        print_message "Найдено $(wc -l < "$temp_file") пакетов для установки"
        case $package_manager in
            "pacman")
                if ! pacman -S --needed - < "$temp_file"; then
                    print_error "Ошибка при установке пакетов из $file_path с помощью pacman"
                    print_warning "Продолжение установки других пакетов..."
                    # Не возвращаем ошибку, чтобы установка продолжалась
                fi
                ;;
            "yay"|"paru")
                # Проверяем, установлен ли AUR helper
                if command -v $package_manager &> /dev/null; then
                    if ! $package_manager -S --needed - < "$temp_file"; then
                        print_error "Ошибка при установке пакетов из $file_path с помощью $package_manager"
                        print_warning "Продолжение установки других пакетов..."
                        # Не возвращаем ошибку, чтобы установка продолжалась
                    fi
                else
                    print_warning "$package_manager не установлен, пропускаем установку из AUR"
                fi
                ;;
        esac
        
        rm "$temp_file"
    else
        # Стандартная установка без фильтрации
        case $package_manager in
            "pacman")
                if ! pacman -S --needed - < "$file_path"; then
                    print_error "Ошибка при установке пакетов из $file_path с помощью pacman"
                    print_warning "Продолжение установки других пакетов..."
                    # Не возвращаем ошибку, чтобы установка продолжалась
                fi
                ;;
            "yay"|"paru")
                # Проверяем, установлен ли AUR helper
                if command -v $package_manager &> /dev/null; then
                    if ! $package_manager -S --needed - < "$file_path"; then
                        print_error "Ошибка при установке пакетов из $file_path с помощью $package_manager"
                        print_warning "Продолжение установки других пакетов..."
                        # Не возвращаем ошибку, чтобы установка продолжалась
                    fi
                else
                    print_warning "$package_manager не установлен, пропускаем установку из AUR"
                fi
                ;;
        esac
    fi
}

# Функция установки пакетов из содержимого файла (для временных файлов)
install_from_file_content() {
    local file_path=$1
    local package_manager=$2
    local install_only_missing=${3:-false}
    
    # Если файл не существует по относительному пути, проверяем полный путь в PROJECT_ROOT
    if [ ! -f "$file_path" ]; then
        local full_path="$PROJECT_ROOT/$file_path"
        if [ -f "$full_path" ]; then
            file_path="$full_path"
        else
            print_warning "Файл $file_path не найден, пропускаем..."
            return 0
        fi
    fi
    
    if [ ! -s "$file_path" ]; then
        print_warning "Файл $file_path пуст, пропускаем..."
        return 0
    fi
    
    print_message "Установка пакетов из содержимого файла"
    
    # Если нужно установить только отсутствующие пакеты, фильтруем их
    if [ "$install_only_missing" = true ]; then
        print_message "Фильтрация уже установленных пакетов..."
        local temp_file=$(mktemp)
        add_temp_file "$temp_file"
        local package_list=$(cat "$file_path")
        
        # Определяем, какие пакеты уже установлены
        case $package_manager in
            "pacman")
                # Для pacman проверяем каждый пакет
                for pkg in $package_list; do
                    if ! pacman -Q "$pkg" &>/dev/null; then
                        echo "$pkg" >> "$temp_file"
                    fi
                done
                ;;
            "yay"|"paru")
                # Для AUR helpers проверяем через pacman и yay/paru
                for pkg in $package_list; do
                    if ! pacman -Q "$pkg" &>/dev/null; then
                        # Проверяем, возможно это AUR пакет
                        if command -v $package_manager &> /dev/null; then
                            # Простая проверка - если пакет не в pacman, добавляем в список
                            # Более точная проверка потребовала бы запроса к AUR
                            echo "$pkg" >> "$temp_file"
                        fi
                    fi
                done
                ;;
        esac
        
        # Проверяем, остались ли пакеты для установки
        if [ ! -s "$temp_file" ]; then
            print_message "Все пакеты уже установлены"
            rm "$temp_file"
            return 0
        fi
        
        print_message "Найдено $(wc -l < "$temp_file") пакетов для установки"
        case $package_manager in
            "pacman")
                if ! pacman -S --needed - < "$temp_file"; then
                    print_error "Ошибка при установке пакетов с помощью pacman"
                    print_warning "Продолжение установки других пакетов..."
                    # Не возвращаем ошибку, чтобы установка продолжалась
                fi
                ;;
            "yay"|"paru")
                # Проверяем, установлен ли AUR helper
                if command -v $package_manager &> /dev/null; then
                    if ! $package_manager -S --needed - < "$temp_file"; then
                        print_error "Ошибка при установке пакетов с помощью $package_manager"
                        print_warning "Продолжение установки других пакетов..."
                        # Не возвращаем ошибку, чтобы установка продолжалась
                    fi
                else
                    print_warning "$package_manager не установлен, пропускаем установку из AUR"
                fi
                ;;
        esac
        
        rm "$temp_file"
    else
        # Стандартная установка без фильтрации
        case $package_manager in
            "pacman")
                if ! pacman -S --needed - < "$file_path"; then
                    print_error "Ошибка при установке пакетов с помощью pacman"
                    return 1
                fi
                ;;
            "yay"|"paru")
                # Проверяем, установлен ли AUR helper
                if command -v $package_manager &> /dev/null; then
                    if ! $package_manager -S --needed - < "$file_path"; then
                        print_error "Ошибка при установке пакетов с помощью $package_manager"
                        return 1
                    fi
                else
                    print_warning "$package_manager не установлен, пропускаем установку из AUR"
                fi
                ;;
        esac
    fi
}

# Основная функция установки
install_packages() {
    local category=$1
    local install_only_missing=${2:-false}
    local selected_desktop=${3:-""} # Передаем выбранную среду рабочего стола
    
    # Если это AUR и выбранная среда пуста, проверяем переменную окружения
    if [ "$category" = "aur" ] && [ -z "$selected_desktop" ] && [ -n "$DESKTOP_CHOICE_FILE" ] && [ -f "$DESKTOP_CHOICE_FILE" ]; then
        selected_desktop=$(cat "$DESKTOP_CHOICE_FILE")
    fi
    
    case $category in
        "core")
            print_message "Установка базовых системных пакетов..."
            install_from_file "core/system.txt" "pacman" "$install_only_missing"
            install_from_file "core/base.txt" "pacman" "$install_only_missing"
            install_from_file "core/network.txt" "pacman" "$install_only_missing"
            ;;
        "desktop")
            print_message "Установка пакетов рабочего стола..."
            install_from_file "desktop/apps.txt" "pacman" "$install_only_missing"
            install_from_file "desktop/audio-video.txt" "pacman" "$install_only_missing"
            install_from_file "desktop/greeter.txt" "pacman" "$install_only_missing"
            ;;
        "niri")
            print_message "Установка пакетов для среды Niri..."
            install_from_file "desktop/niri.txt" "pacman" "$install_only_missing"
            ;;
        "cosmic")
            print_message "Установка пакетов для среды COSMIC..."
            
            # Проверяем, запущен ли скрипт от root и если да, переключаемся на обычного пользователя для AUR
            if [ "$EUID" -eq 0 ]; then
                print_message "Обнаружен запуск от root, переключаемся на обычного пользователя для установки AUR пакетов COSMIC..."
                original_user=$(logname 2>/dev/null || whoami)
                if [ -n "$original_user" ] && [ "$original_user" != "root" ]; then
                    # Выполняем установку AUR пакетов от имени обычного пользователя
                    if command -v sudo &> /dev/null; then
                        sudo -u "$original_user" PROJECT_ROOT="$PROJECT_ROOT" "$SCRIPT_ABSOLUTE_PATH" cosmic_aur_packages "$install_only_missing"
                    else
                        exec su "$original_user" -c "PROJECT_ROOT='$PROJECT_ROOT' '$SCRIPT_ABSOLUTE_PATH' cosmic_aur_packages '$install_only_missing'"
                    fi
                    return 0
                else
                    print_error "Не удалось определить оригинального пользователя для установки AUR пакетов"
                    exit 1
                fi
            fi
            
            # Если не запущен от root, выполняем установку напрямую
            if command -v yay &> /dev/null; then
                install_from_file "aur/cosmic.txt" "yay" "$install_only_missing"
            elif command -v paru &> /dev/null; then
                install_from_file "aur/cosmic.txt" "paru" "$install_only_missing"
            else
                print_error "Ни один AUR helper (yay, paru) не установлен для установки пакетов COSMIC"
                exit 1
            fi
            ;;
        "development")
            print_message "Установка пакетов для разработки..."
            install_from_file "development/utils.txt" "pacman" "$install_only_missing"
            ;;
        "fonts-themes")
            print_message "Установка шрифтов и тем..."
            install_from_file "fonts-themes/fonts.txt" "pacman" "$install_only_missing"
            ;;
        "hardware")
            print_message "Установка драйверов..."
            install_from_file "hardware/drivers.txt" "pacman" "$install_only_missing"
            ;;
        "virtualization")
            print_message "Установка пакетов виртуализации..."
            install_from_file "virtualization/virt.txt" "pacman" "$install_only_missing"
            ;;
        "aur")
            print_message "Установка пакетов из AUR..."
            # Проверяем, запущен ли скрипт от root и если да, переключаемся на обычного пользователя для AUR
            if [ "$EUID" -eq 0 ]; then
                print_message "Обнаружен запуск от root, переключаемся на обычного пользователя для установки AUR пакетов..."
                original_user=$(logname 2>/dev/null || whoami)
                if [ -n "$original_user" ] && [ "$original_user" != "root" ]; then
                    # Создаем временный файл для передачи выбора рабочей среды
                    temp_choice_file=$(mktemp "/tmp/pkgs-arch-desktop-choice-XXXXXX")
                    add_temp_file "$temp_choice_file"
                    echo "$selected_desktop" > "$temp_choice_file"
                    export DESKTOP_CHOICE_FILE="$temp_choice_file"
                    # Выполняем установку AUR пакетов от имени обычного пользователя
                    if command -v sudo &> /dev/null; then
                        sudo -u "$original_user" env "PROJECT_ROOT=$PROJECT_ROOT" "DESKTOP_CHOICE_FILE=$temp_choice_file" "$SCRIPT_ABSOLUTE_PATH" aur_with_desktop_choice "$install_only_missing" "$selected_desktop"
                    else
                        exec su "$original_user" -c "PROJECT_ROOT='$PROJECT_ROOT' DESKTOP_CHOICE_FILE='$temp_choice_file' '$SCRIPT_ABSOLUTE_PATH' aur_with_desktop_choice '$install_only_missing' '$selected_desktop'"
                    fi
                    rm -f "$temp_choice_file"
                    return 0
                else
                    print_error "Не удалось определить оригинального пользователя для установки AUR пакетов"
                    exit 1
                fi
            fi
            
            # Если не запущен от root, выполняем установку напрямую
            if command -v yay &> /dev/null; then
                # Если выбрана среда niri, исключаем cosmic пакеты из AUR
                if [ "$selected_desktop" = "niri" ]; then
                    print_message "Исключаем пакеты COSMIC из установки AUR (выбрана среда Niri)"
                    # Создаем временный файл с фильтрованным списком
                    local temp_aur_file=$(mktemp)
                    add_temp_file "$temp_aur_file"
                    if [ -f "$PROJECT_ROOT/aur/aur.txt" ]; then
                        while IFS= read -r package; do
                            if ! grep -Fxq "$package" "$PROJECT_ROOT/aur/cosmic.txt" 2>/dev/null; then
                                echo "$package" >> "$temp_aur_file"
                            fi
                        done < "$PROJECT_ROOT/aur/aur.txt"
                        install_from_file_content "$temp_aur_file" "yay" "$install_only_missing"
                        rm "$temp_aur_file"
                    fi
                elif [ "$selected_desktop" = "cosmic" ]; then
                    print_message "Исключаем пакеты Niri из установки AUR (выбрана среда Cosmic)"
                    # Создаем временный файл с фильтрованным списком, исключая niri пакеты
                    local temp_aur_file=$(mktemp)
                    add_temp_file "$temp_aur_file"
                    if [ -f "$PROJECT_ROOT/aur/aur.txt" ]; then
                        while IFS= read -r package; do
                            if ! grep -Fxq "$package" "$PROJECT_ROOT/desktop/niri.txt" 2>/dev/null; then
                                echo "$package" >> "$temp_aur_file"
                            fi
                        done < "$PROJECT_ROOT/aur/aur.txt"
                        install_from_file_content "$temp_aur_file" "yay" "$install_only_missing"
                        rm "$temp_aur_file"
                    fi
                else
                    # Устанавливаем все AUR пакеты
                    install_from_file "aur/aur.txt" "yay" "$install_only_missing"
                fi
            elif command -v paru &> /dev/null; then
                # Та же логика для paru
                if [ "$selected_desktop" = "niri" ]; then
                    print_message "Исключаем пакеты COSMIC из установки AUR (выбрана среда Niri)"
                    local temp_aur_file=$(mktemp)
                    add_temp_file "$temp_aur_file"
                    if [ -f "$PROJECT_ROOT/aur/aur.txt" ]; then
                        while IFS= read -r package; do
                            if ! grep -Fxq "$package" "$PROJECT_ROOT/aur/cosmic.txt" 2>/dev/null; then
                                echo "$package" >> "$temp_aur_file"
                            fi
                        done < "$PROJECT_ROOT/aur/aur.txt"
                        install_from_file_content "$temp_aur_file" "paru" "$install_only_missing"
                        rm "$temp_aur_file"
                    fi
                elif [ "$selected_desktop" = "cosmic" ]; then
                    print_message "Исключаем пакеты Niri из установки AUR (выбрана среда Cosmic)"
                    # Создаем временный файл с фильтрованным списком, исключая niri пакеты
                    local temp_aur_file=$(mktemp)
                    if [ -f "$PROJECT_ROOT/aur/aur.txt" ]; then
                        while IFS= read -r package; do
                            if ! grep -Fxq "$package" "$PROJECT_ROOT/desktop/niri.txt" 2>/dev/null; then
                                echo "$package" >> "$temp_aur_file"
                            fi
                        done < "$PROJECT_ROOT/aur/aur.txt"
                        install_from_file_content "$temp_aur_file" "paru" "$install_only_missing"
                        rm "$temp_aur_file"
                    fi
                else
                    install_from_file "aur/aur.txt" "paru" "$install_only_missing"
                fi
            else
                print_error "Ни один AUR helper (yay, paru) не установлен"
                exit 1
            fi
            ;;
        "all")
            print_message "Установка всех пакетов..."
            # Устанавливаем в логическом порядке
            install_packages "core" "$install_only_missing" "$selected_desktop"
            install_packages "hardware" "$install_only_missing" "$selected_desktop"
            install_packages "virtualization" "$install_only_missing" "$selected_desktop"
            install_packages "development" "$install_only_missing" "$selected_desktop"
            install_packages "fonts-themes" "$install_only_missing" "$selected_desktop"
            install_packages "desktop" "$install_only_missing" "$selected_desktop"
            
            # Запрашиваем у пользователя, какую среду рабочего стола установить
            local desktop_choice=""
            if [ "$install_only_missing" = false ]; then
                echo "Выберите среду рабочего стола для установки:"
                echo "1) niri (установит пакеты из desktop/niri.txt, исключит cosmic пакеты из AUR)"
                echo "2) cosmic (установит пакеты из aur/cosmic.txt, исключит niri пакеты из установки)"
                echo "3) обе среды"
                echo "4) пропустить установку специфичных пакетов сред"
                read -p "Введите номер (1-4): " choice
                
                case $choice in
                    1)
                        install_packages "niri" "$install_only_missing" "niri"
                        desktop_choice="niri"
                        ;;
                    2)
                        install_packages "cosmic" "$install_only_missing" "cosmic"
                        desktop_choice="cosmic"
                        ;;
                    3)
                        install_packages "niri" "$install_only_missing" "both"
                        install_packages "cosmic" "$install_only_missing" "both"
                        desktop_choice="both"
                        ;;
                    4|*)
                        print_message "Пропускаем установку специфичных пакетов сред рабочего стола"
                        desktop_choice="none"
                        ;;
                esac
            else
                # Если устанавливаем только отсутствующие, просто уведомляем пользователя
                print_message "При установке только отсутствующих пакетов, среды рабочего стола нужно выбирать отдельно"
            fi
            
            # Установка AUR пакетов (включая cosmic, если требуется)
            install_packages "aur" "$install_only_missing" "$desktop_choice"  # Установка пакетов из AUR с учетом выбора рабочей среды
            ;;
        "aur_with_desktop_choice")
            # Специальная категория для установки AUR пакетов с выбором рабочей среды от обычного пользователя
            local install_only_missing_aur=${2:-false}
            local selected_desktop_aur=${3:-""}
            
            print_message "Установка AUR пакетов от обычного пользователя (выбрана среда: $selected_desktop_aur)..."
            
            if command -v yay &> /dev/null; then
                # Если выбрана среда niri, исключаем cosmic пакеты из AUR
                if [ "$selected_desktop_aur" = "niri" ]; then
                    print_message "Исключаем пакеты COSMIC из установки AUR (выбрана среда Niri)"
                    # Создаем временный файл с фильтрованным списком
                    local temp_aur_file=$(mktemp)
                    add_temp_file "$temp_aur_file"
                    if [ -f "$PROJECT_ROOT/aur/aur.txt" ]; then
                        while IFS= read -r package; do
                            if ! grep -Fxq "$package" "$PROJECT_ROOT/aur/cosmic.txt" 2>/dev/null; then
                                echo "$package" >> "$temp_aur_file"
                            fi
                        done < "$PROJECT_ROOT/aur/aur.txt"
                        install_from_file_content "$temp_aur_file" "yay" "$install_only_missing_aur"
                        rm "$temp_aur_file"
                    fi
                elif [ "$selected_desktop_aur" = "cosmic" ]; then
                    print_message "Исключаем пакеты Niri из установки AUR (выбрана среда Cosmic)"
                    # Создаем временный файл с фильтрованным списком, исключая niri пакеты
                    local temp_aur_file=$(mktemp)
                    add_temp_file "$temp_aur_file"
                    if [ -f "$PROJECT_ROOT/aur/aur.txt" ]; then
                        while IFS= read -r package; do
                            if ! grep -Fxq "$package" "$PROJECT_ROOT/desktop/niri.txt" 2>/dev/null; then
                                echo "$package" >> "$temp_aur_file"
                            fi
                        done < "$PROJECT_ROOT/aur/aur.txt"
                        install_from_file_content "$temp_aur_file" "yay" "$install_only_missing_aur"
                        rm "$temp_aur_file"
                    fi
                else
                    # Устанавливаем все AUR пакеты
                    install_from_file "aur/aur.txt" "yay" "$install_only_missing_aur"
                fi
            elif command -v paru &> /dev/null; then
                # Та же логика для paru
                if [ "$selected_desktop_aur" = "niri" ]; then
                    print_message "Исключаем пакеты COSMIC из установки AUR (выбрана среда Niri)"
                    local temp_aur_file=$(mktemp)
                    add_temp_file "$temp_aur_file"
                    if [ -f "$PROJECT_ROOT/aur/aur.txt" ]; then
                        while IFS= read -r package; do
                            if ! grep -Fxq "$package" "$PROJECT_ROOT/aur/cosmic.txt" 2>/dev/null; then
                                echo "$package" >> "$temp_aur_file"
                            fi
                        done < "$PROJECT_ROOT/aur/aur.txt"
                        install_from_file_content "$temp_aur_file" "paru" "$install_only_missing_aur"
                        rm "$temp_aur_file"
                    fi
                elif [ "$selected_desktop_aur" = "cosmic" ]; then
                    print_message "Исключаем пакеты Niri из установки AUR (выбрана среда Cosmic)"
                    # Создаем временный файл с фильтрованным списком, исключая niri пакеты
                    local temp_aur_file=$(mktemp)
                    add_temp_file "$temp_aur_file"
                    if [ -f "$PROJECT_ROOT/aur/aur.txt" ]; then
                        while IFS= read -r package; do
                            if ! grep -Fxq "$package" "$PROJECT_ROOT/desktop/niri.txt" 2>/dev/null; then
                                echo "$package" >> "$temp_aur_file"
                            fi
                        done < "$PROJECT_ROOT/aur/aur.txt"
                        install_from_file_content "$temp_aur_file" "paru" "$install_only_missing_aur"
                        rm "$temp_aur_file"
                    fi
                else
                    install_from_file "aur/aur.txt" "paru" "$install_only_missing_aur"
                fi
            else
                print_error "Ни один AUR helper (yay, paru) не установлен"
                exit 1
            fi
            ;;
        "cosmic_aur_packages")
            print_message "Установка AUR пакетов для среды COSMIC от обычного пользователя..."
            if command -v yay &> /dev/null; then
                install_from_file "aur/cosmic.txt" "yay" "$install_only_missing"
            elif command -v paru &> /dev/null; then
                install_from_file "aur/cosmic.txt" "paru" "$install_only_missing"
            else
                print_error "Ни один AUR helper (yay, paru) не установлен для установки пакетов COSMIC"
                exit 1
            fi
            ;;
        "all_with_aur")
            print_error "Категория all_with_aur должна обрабатываться до вызова install_packages"
            exit 1
            ;;
        *)
            print_error "Неизвестная категория: $category"
            print_message "Доступные категории: core, desktop, niri, cosmic (пакеты из AUR), development, fonts-themes, hardware, virtualization, aur, all, all_with_aur, aur_with_desktop_choice, cosmic_aur_packages"
            exit 1
            ;;
    esac
}

# Проверка аргументов командной строки
if [ $# -eq 0 ]; then
    print_message "Использование: $0 <категория> [опции]"
    print_message "Доступные категории: core, desktop, niri, cosmic (пакеты из AUR), development, fonts-themes, hardware, virtualization, aur, all, all_with_aur"
    print_message "Доступные опции:"
    print_message "  --missing-only: Установить только отсутствующие пакеты"
    print_message "  --log-file <путь>: Записывать лог в указанный файл"
    print_message "Для установки системных пакетов запустите с sudo: sudo $0 <категория> [опции]"
    print_message "Для установки AUR пакетов запустите без sudo: $0 aur [опции]"
    print_message "Для установки всех пакетов с AUR: sudo $0 all_with_aur [опции]"
    exit 0
fi

# Получаем категорию из аргумента
CATEGORY=$1
MISSING_ONLY=false
LOG_FILE=""

# Проверяем дополнительные опции
i=1
while [ $i -le $# ]; do
    arg="${!i}"
    if [ $i -lt $# ]; then
        next_index=$((i+1))
        next_arg="${!next_index}"
    else
        next_arg=""
    fi
    if [ "$arg" = "--missing-only" ]; then
        MISSING_ONLY=true
    elif [ "$arg" = "--log-file" ] && [ -n "$next_arg" ] && [[ "$next_arg" != -* ]]; then
        LOG_FILE="$next_arg"
        i=$((i+1))  # Пропускаем следующий аргумент, так как он используется как путь к лог-файлу
    fi
    i=$((i+1))
done

# Проверяем, нужно ли запрашивать sudo для установки
# Исключаем специальные категории, которые должны запускаться от обычного пользователя
if [ "$CATEGORY" != "aur" ] && [ "$CATEGORY" != "all_with_aur" ] && [ "$CATEGORY" != "aur_with_desktop_choice" ] && [ "$CATEGORY" != "cosmic_aur_packages" ]; then
    check_sudo
fi

# Если запрошена установка all с AUR пакетами, меняем категорию на all и устанавливаем флаг
INSTALL_AUR_WITH_ALL=false
desktop_choice=""
if [ "$CATEGORY" = "all_with_aur" ]; then
    ORIGINAL_CATEGORY="$CATEGORY"
    CATEGORY="all"
    INSTALL_AUR_WITH_ALL=true
    
    # Для all_with_aur также запрашиваем выбор среды рабочего стола
    if [ "$MISSING_ONLY" = false ]; then
        echo "Выберите среду рабочего стола для установки:"
        echo "1) niri (установит пакеты из desktop/niri.txt, исключит cosmic пакеты из AUR)"
        echo "2) cosmic (установит пакеты из aur/cosmic.txt, исключит niri пакеты из установки)"
        echo "3) обе среды"
        echo "4) пропустить установку специфичных пакетов сред"
        read -p "Введите номер (1-4): " choice
        
        case $choice in
            1)
                desktop_choice="niri"
                ;;
            2)
                desktop_choice="cosmic"
                ;;
            3)
                desktop_choice="both"
                ;;
            4|*)
                desktop_choice="none"
                ;;
        esac
    fi
fi

# Если PROJECT_ROOT не установлен (например, при первом запуске), определяем его как родительский каталог скрипта
if [ -z "$PROJECT_ROOT" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$SCRIPT_DIR/.."
fi

# Переходим в корень проекта
cd "$PROJECT_ROOT"

# Определяем абсолютный путь к скрипту до его использования
SCRIPT_ABSOLUTE_PATH="$PROJECT_ROOT/scripts/install.sh"

# Выполняем установку
install_packages "$CATEGORY" "$MISSING_ONLY" "$desktop_choice"

# Если была запрошена установка AUR пакетов вместе с all, устанавливаем их отдельно
if [ "$INSTALL_AUR_WITH_ALL" = true ]; then
    print_message "Установка AUR пакетов..."
    # Для AUR нужен отдельный вызов без sudo
    if command -v sudo &> /dev/null && [ "$EUID" -eq 0 ]; then
        # Если мы в sudo, временно сбрасываем привилегии для установки AUR
        original_user=$(logname 2>/dev/null || whoami)
        if [ -n "$original_user" ]; then
            # Создаем временный файл для передачи выбора рабочей среды
            temp_choice_file=$(mktemp "/tmp/pkgs-arch-desktop-choice-XXXXXX")
            add_temp_file "$temp_choice_file"
            echo "$desktop_choice" > "$temp_choice_file"
            export DESKTOP_CHOICE_FILE="$temp_choice_file"
            exec su "$original_user" -c "PROJECT_ROOT='$PROJECT_ROOT' DESKTOP_CHOICE_FILE='$temp_choice_file' '$SCRIPT_ABSOLUTE_PATH' aur $([ "$MISSING_ONLY" = true ] && echo '--missing-only' || echo '') $([ -n "$LOG_FILE" ] && echo "--log-file $LOG_FILE" || echo '')"
        else
            print_error "Не удалось определить оригинального пользователя для установки AUR пакетов"
            print_message "Запустите установку AUR пакетов отдельно: ./scripts/install.sh aur"
        fi
    else
        install_packages "aur" "$MISSING_ONLY" "$desktop_choice"
    fi
fi

# Убедимся, что последнее сообщение также попадает в лог
print_message "Установка завершена!"
log_to_file "Установка завершена успешно"

# Удаляем временный файл с выбором рабочей среды, если он был создан
if [ -n "$DESKTOP_CHOICE_FILE" ] && [ -f "$DESKTOP_CHOICE_FILE" ]; then
    rm -f "$DESKTOP_CHOICE_FILE"
fi