# Руководство по установке

Это руководство описывает, как использовать списки пакетов из проекта PKGS-ARCH для установки на новую систему Arch Linux.

## Подготовка

Перед установкой пакетов убедитесь, что:

1. У вас установлена базовая система Arch Linux
2. Установлены необходимые инструменты (git, pacman)
3. У вас есть подключение к интернету
4. Для установки AUR пакетов установите соответствующий helper (yay или paru)

## Установка через скрипт

Самый простой способ установки - использование предоставленного скрипта:

```bash
# Установка всех пакетов
sudo ./scripts/install.sh all

# Установка всех пакетов с AUR
sudo ./scripts/install.sh all_with_aur

# Установка пакетов определенной категории
sudo ./scripts/install.sh core
sudo ./scripts/install.sh desktop
sudo ./scripts/install.sh niri
sudo ./scripts/install.sh cosmic
sudo ./scripts/install.sh development
sudo ./scripts/install.sh fonts-themes
sudo ./scripts/install.sh hardware
sudo ./scripts/install.sh virtualization
sudo ./scripts/install.sh aur

# Дополнительные опции:
# --missing-only: Установить только отсутствующие пакеты
sudo ./scripts/install.sh core --missing-only

# --log-file: Записывать лог в указанный файл
sudo ./scripts/install.sh all --log-file /path/to/logfile.log
```

Для установки AUR пакетов запускайте скрипт без sudo:

```bash
./scripts/install.sh aur
```

## Ручная установка

Вы также можете устанавливать пакеты вручную:

```bash
# Установка через pacman
sudo pacman -S - < core/system.txt

# Установка через AUR helper
yay -S - < aur/aur.txt
```

## Установка по категориям

### 1. Core (Ядро системы)
Начните с установки базовых системных пакетов:

```bash
sudo pacman -S - < core/system.txt
sudo pacman -S - < core/base.txt
sudo pacman -S - < core/network.txt
```

### 2. Hardware (Оборудование)
Затем установите драйверы:

```bash
sudo pacman -S - < hardware/drivers.txt
```

### 3. Virtualization (Виртуализация)
Если планируете использовать виртуализацию:

```bash
sudo pacman -S - < virtualization/virt.txt
```

### 4. Desktop (Рабочий стол)
Установите пакеты рабочего стола:

```bash
sudo pacman -S - < desktop/apps.txt
sudo pacman -S - < desktop/audio-video.txt
sudo pacman -S - < desktop/greeter.txt
```

> Примечание: Если вы используете среду рабочего стола Niri или COSMIC, установите соответствующие пакеты:
>
> ```bash
> # Для Niri
> sudo pacman -S - < desktop/niri.txt
>
> # Для COSMIC (пакеты из AUR)
> yay -S - < aur/cosmic.txt
> ```

### 5. Development (Разработка)
Для разработчиков:

```bash
sudo pacman -S - < development/utils.txt
```

> Примечание: В этой категории теперь находятся утилиты командной строки и инструменты разработки, включая kitty.
### 6. Fonts-Themes (Шрифты и темы)
Для настройки внешнего вида:

```bash
sudo pacman -S - < fonts-themes/fonts.txt
```

### 7. AUR (AUR пакеты)
Наконец, установите пакеты из AUR:

```bash
yay -S - < aur/aur.txt
```

## Установка AUR Helper

Если у вас не установлен AUR helper, вы можете установить его следующим образом:

```bash
# Установка yay
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si

# Или установка paru
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si
```

## Проверка установки

После установки пакетов рекомендуется:

1. Перезагрузить систему
2. Проверить, что все необходимые сервисы запущены
3. Убедиться, что все приложения запускаются корректно

## Устранение проблем

Если возникли проблемы с установкой:

1. Проверьте, что все имена пакетов указаны правильно
2. Убедитесь, что репозитории обновлены: `sudo pacman -Sy`
3. Если пакет не найден в AUR, возможно, он был переименован или удален