# Минимальная загрузочная флешка с Windows (запуск с флешки, не установка)

Цель: флешка, с которой **загружается и работает** минимальная Windows (среда восстановления/рабочий стол), а не установщик Windows на ПК.

---

## Только для установки DeepCool DEEPCREATIVE (минимальная Windows)

Если нужна Windows **исключительно чтобы один раз запустить установщик** DeepCool DEEPCREATIVE (настройка/прошивка устройства):

1. **Wine/Bottles не подходит для запуска DeepCreative:** приложение (Electron + node-usb) вызывает Windows API регистрации USB-уведомлений (`RegisterNotification`). В Wine это даёт ошибку *«RegisterNotification failed»* при старте — нужна реальная Windows. Установка через Bottles может пройти, но запуск падает с этой ошибкой.

2. **Минимальная Windows с флешки** (рабочий вариант):
   - Сделайте флешку по **Варианту 1** ниже (Ventoy + Windows PE).
   - Подойдёт любой **компактный Windows PE** с рабочим столом (например **Hiren's BootCD PE** — один ISO, ~2–3 ГБ).
   - Загрузитесь с флешки → в PE откройте проводник, скопируйте установщик DeepCreative на флешку заранее или скачайте в PE → запустите `DeepCreative_*.exe`.
   - После установки/настройки можно снова загружаться в NixOS; для постоянной работы с MYSTIQUE у вас уже есть `deepcool-digital-linux` в конфиге (включите `features.deepcool = true` в `vars.nix`).

Полноценная Windows на ПК не нужна — достаточно загрузки с PE один раз для установки.

---

## Вариант 1: Ventoy + Windows PE (рекомендуется, минимум действий)

**Windows PE** — это облегчённая Windows (рабочий стол, проводник, браузер, утилиты). Идеально для «запустить Windows с флешки».

### Шаг 1: Узнать устройство флешки

```bash
lsblk -o NAME,SIZE,MODEL,TRAN
```

Найдите флешку по размеру и метке (например `sdb`). **Убедитесь, что это именно флешка**, иначе можно стереть диск системы.

### Шаг 2: Установить Ventoy на флешку

**Способ A — Web-интерфейс (если команда есть в системе):**

```bash
sudo ventoy-web
```

Откройте в браузере: **http://127.0.0.1:24680** → выберите флешку → **Install**. Все данные на флешке будут удалены.

**Способ B — если `ventoy-web` не найден (или пакет не ставит его в PATH):**

Скачайте Ventoy для Linux с официального сайта и установите вручную:

```bash
cd ~/Downloads
wget https://github.com/ventoy/Ventoy/releases/download/v1.0.96/ventoy-1.0.96-linux.tar.gz
tar -xzf ventoy-*-linux.tar.gz
cd ventoy-*-linux
# Узнайте устройство флешки (например /dev/sdb) через lsblk!
sudo ./Ventoy2Disk.sh -i /dev/sdX
```

Подставьте актуальную версию и букву диска (например `v1.0.96` → смотрите [Releases](https://github.com/ventoy/Ventoy/releases), `/dev/sdX` → ваша флешка по `lsblk`). Подтвердите запись — данные на флешке будут стёрты.

### Шаг 3: Скачать образ Windows PE

Нужен **ISO с Windows PE** (минимальная загрузочная Windows), а не обычный установочный ISO Windows.

**Скачать из терминала (прямые ссылки):**

Hiren's BootCD PE — архив, стабильные ссылки:

```bash
mkdir -p ~/Downloads && cd ~/Downloads

# Вариант 1: версия 1.0.2 (~2.9 ГБ)
wget -c https://archive.hirensbootcd.org/pe-versions/HBCD_PE_x64_v102.iso -O HBCD_PE_x64.iso

# Вариант 2: версия 1.0.1 (~1.3 ГБ, меньше по размеру)
# wget -c https://archive.hirensbootcd.org/pe-versions/HBCD_PE_x64_v101.iso -O HBCD_PE_x64.iso
```

Флаг `-c` продолжает прерванное скачивание. После загрузки файл будет в `~/Downloads/HBCD_PE_x64.iso`.

Другие варианты (если нужны): Sergei Strelec WinPE (поиск по названию), официальный Windows PE (ADK).

### Шаг 4: Скопировать ISO на флешку

После установки Ventoy флешка при подключении показывается как обычный диск с одним разделом (exFAT/FAT32). Если она не появилась в `/run/media/$USER/`, смонтируйте вручную:

```bash
# Узнать устройство флешки: lsblk (например /dev/sda → раздел /dev/sda1)
sudo mkdir -p /mnt/ventoy
sudo mount /dev/sda1 /mnt/ventoy
cp ~/Downloads/HBCD_PE_x64.iso /mnt/ventoy/
sudo umount /mnt/ventoy
```

Если флешка уже смонтирована (видна в файловом менеджере или в `ls /run/media/$USER/`), достаточно:  
`cp ~/Downloads/HBCD_PE_x64.iso /run/media/$USER/Ventoy/`

### Шаг 5: Загрузка с флешки

1. Перезагрузка.
2. Выбор загрузки с USB (F12/F8/ESC в зависимости от материнской платы).
3. Ventoy покажет список ISO — выберите ваш Windows PE.
4. Загрузится минимальная Windows с флешки (без установки на ПК).

---

## Вариант 2: Полная Windows на флешке (Windows в VHD через Ventoy)

Если нужна **полноценная Windows** (как с диска), а не только PE:

1. Установите Ventoy на флешку (как в варианте 1).
2. В корне флешки создайте папку `ventoy` и положите туда образ плагина:
   - Скачайте `ventoy_vhdboot.img` с https://github.com/ventoy/vhdiso/releases
   - Положите в `/ventoy/` на флешке.
3. Подготовьте **VHD с установленной Windows**:
   - В Windows (или в виртуальной машине с Windows) создайте VHD и установите в него Windows.
   - Или используйте готовые «portable Windows» образы (осторожно с лицензией и источниками).
4. Скопируйте файл `.vhd` (или `.vhdx`) на флешку (в корень или в любую папку).
5. При загрузке с флешки Ventoy предложит загрузить этот VHD — будет полноценная Windows с флешки.

Создать VHD с нуля удобнее на машине с Windows (Hyper-V, Disk Management, или VirtualBox + конвертация в VHD).

---

## Краткая шпаргалка (только Ventoy + PE)

```bash
# 1. Узнать флешку
lsblk -o NAME,SIZE,MODEL,TRAN

# 2. Установить Ventoy: sudo ventoy-web (если есть) или скачать с
#    https://github.com/ventoy/Ventoy/releases и запустить ./Ventoy2Disk.sh -i /dev/sdX

# 3. Скачать Windows PE ISO (например Hiren's) и скопировать на флешку
cp ~/Downloads/Hirens.BootCD.PE.*.iso /run/media/$USER/Ventoy/

# 4. Перезагрузка → загрузка с USB → выбор ISO в меню Ventoy
```

После этого у вас будет минимальная загрузочная флешка с Windows для **запуска с неё**, а не для установки на ПК.
