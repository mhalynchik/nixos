# MAX Messenger — песочница в виртуальной машине

Изолированная среда для запуска мессенджера MAX с защитой от телеметрии и шпионских функций. Подходит для Linux (любой дистрибутив) и Windows.

## Зачем это нужно

MAX (бывший VK Teams) — мессенджер, навязываемый государством. Исследования [NTC-форума](https://ntc.party/) показали, что приложение:

- Определяет использование VPN через внешние IP-сервисы
- Проверяет доступность сторонних хостов (Telegram, WhatsApp, Госуслуги и др.) — событие `GET_HOST_REACHABILITY`
- Передаёт данные о VPN, IP и доступности хостов на сервер
- Может включать/отключать эти функции удалённо для отдельных аккаунтов

## Архитектура

```
┌─────────────────────────────────────────────────────────┐
│  Хост                                                    │
│  ┌──────────────┐    ┌──────────────────────────────┐   │
│  │  VPN         │    │  Firewall + Policy routing    │   │
│  │  (опционально)│   │  • ICMP из VM → DROP          │   │
│  └──────┬───────┘    │  • Spy hosts → DROP           │   │
│         │            │  • VM трафик → в обход VPN    │   │
│         │            └──────────────┬───────────────┘   │
│         │                           │                   │
│  ┌──────┴───────────────────────────┴───────────────┐   │
│  │  VM (Ubuntu/Fedora/Windows)                      │   │
│  │  • /etc/hosts или hosts — блокировка доменов     │   │
│  │  • MAX messenger                                 │   │
│  └─────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

## Что блокируем

| Категория        | Хосты                                                                                          | Цель                                                    |
|------------------|------------------------------------------------------------------------------------------------|---------------------------------------------------------|
| **IP-detection** | api.ipify.org, ifconfig.me, ipinfo.io, ident.me, wtfismyip.com, ip-api.com, l2.io, ip.sb и др. | MAX не может определить внешний IP → не детектирует VPN |
| **Reachability** | main.telegram.org, mmg.whatsapp.net, gosuslugi.ru, gstatic.com, mtalk.google.com               | Блокируем отчёт GET_HOST_REACHABILITY                   |
| **ICMP**         | Весь исходящий ping из VM                                                                      | Отключаем проверки доступности по ICMP                  |
| **Не блокируем** | api.oneme.ru, calls.okcdn.ru                                                                   | Серверы MAX — без них приложение не работает            |

---

## Linux (любой дистрибутив)

### 1. Установка KVM и virt-manager

**Debian/Ubuntu:**
```bash
sudo apt install qemu-kvm libvirt-daemon-system virt-manager
sudo usermod -aG libvirt $USER
# Перелогиньтесь
```

**Fedora:**
```bash
sudo dnf install @virtualization
sudo usermod -aG libvirt $USER
```

**Arch:**
```bash
sudo pacman -S qemu libvirt virt-manager
sudo usermod -aG libvirt $USER
```

### 2. Сеть libvirt

```bash
# Создать default-сеть, если её нет
sudo virsh net-define - << 'EOF'
<network>
  <name>default</name>
  <bridge name="virbr0"/>
  <forward mode="nat"/>
  <ip address="192.168.122.1" netmask="255.255.255.0">
    <dhcp>
      <range start="192.168.122.2" end="192.168.122.254"/>
    </dhcp>
  </ip>
</network>
EOF
sudo virsh net-start default
sudo virsh net-autostart default
```

### 3. Firewall на хосте

Добавьте правила (iptables). Подставьте свой интерфейс VM — обычно `virbr0`, подсеть `192.168.122.0/24`:

```bash
# ICMP из VM — дроп
sudo iptables -I FORWARD -s 192.168.122.0/24 -p icmp -j DROP

# Spy hosts — дроп (IP резолвятся при выполнении)
for host in api.ipify.org ifconfig.me ipinfo.io ident.me gosuslugi.ru main.telegram.org mmg.whatsapp.net mtalk.google.com; do
  for ip in $(getent ahostsv4 "$host" 2>/dev/null | awk '{print $1}' | sort -u); do
    sudo iptables -I FORWARD -s 192.168.122.0/24 -d "$ip" -j DROP
  done
done
```

Для nftables — аналогичные правила в соответствующем синтаксисе.

### 4. Трафик VM в обход VPN (опционально)

Если на хосте VPN и нужно, чтобы MAX видел реальный IP:

```bash
# Выполнить при загрузке, до старта VPN
PHYS=$(ip -4 route show default | grep -vE 'wg0|tun[0-9]+' | head -1)
sudo ip route add table 100 $PHYS
sudo ip rule add from 192.168.122.0/24 table 100 priority 100
```

### 5. Создание VM

1. Запустите `virt-manager`
2. **File → New Virtual Machine** → Local install media (ISO)
3. Образ: [Ubuntu](https://ubuntu.com/download/desktop) или [Fedora](https://fedora.org/ru/workstation/download/)
4. RAM: 2–4 ГБ, CPU: 2, диск: **30–40 ГБ**
5. Сеть: default (NAT)

### 6. /etc/hosts внутри VM (Linux)

```bash
sudo nano /etc/hosts
```

Добавьте (без api.oneme.ru и calls.okcdn.ru; gstatic.com закомментируйте, если MAX пишет «нет интернета»):

```
127.0.0.1 api.ipify.org checkip.amazonaws.com icanhazip.com ipinfo.io ifconfig.me
127.0.0.1 ident.me ip.seeip.org wtfismyip.com myexternalip.com ip-api.com l2.io ip.sb api64.ipify.org
127.0.0.1 gosuslugi.ru
# 127.0.0.1 gstatic.com
127.0.0.1 main.telegram.org mmg.whatsapp.net mtalk.google.com
```

### 7. Установка MAX в VM

```bash
# Ubuntu/Debian
sudo apt update && sudo apt install max

# Fedora
sudo dnf install max
```

---

## NixOS

В этом репозитории всё настроено через модуль `services/virt-manager.nix`:

- `features.maxSandbox = true` — libvirt, firewall, создание default-сети
- `features.maxBypassVpn = true` — трафик VM в обход VPN

```bash
sudo nixos-rebuild switch --flake .#
```

Сеть создаётся автоматически. При необходимости: `sudo libvirt-default-network`.

---

## Windows

### Гипервизор

- **Hyper-V** (встроен в Pro/Enterprise) или **VirtualBox**

### Firewall

Блокировка на хосте Windows сложнее; основной способ — **hosts в VM** (см. ниже). При необходимости можно настроить правила в Windows Firewall для подсети VM (VirtualBox: 192.168.56.0/24, Hyper-V: своя подсеть) — блокировка ICMP и TCP к известным spy-хостам.

### Трафик в обход VPN

- **Split tunneling** в клиенте VPN: исключить подсеть VM из туннеля
- Или отдельный сетевой адаптер для VM, не проходящий через VPN

### hosts в VM (Windows)

`C:\Windows\System32\drivers\etc\hosts` — те же записи, что и для Linux.

---

## Проверка

### На хосте (Linux)

```bash
virsh net-list --all
sudo iptables -L FORWARD -v -n | grep 192.168.122
# При maxBypassVpn:
ip rule show | grep 192.168.122
ip route show table 100
```

### Внутри VM

Все команды должны завершаться с «OK (blocked)»:

```bash
echo "=== IP-detection ==="
curl -s --connect-timeout 2 https://api.ipify.org && echo " FAIL" || echo "api.ipify.org: OK (blocked)"
curl -s --connect-timeout 2 https://ifconfig.me && echo " FAIL" || echo "ifconfig.me: OK (blocked)"
curl -s --connect-timeout 2 https://ipinfo.io && echo " FAIL" || echo "ipinfo.io: OK (blocked)"

echo "=== Reachability ==="
curl -s --connect-timeout 2 -o /dev/null https://main.telegram.org && echo "FAIL" || echo "main.telegram.org: OK (blocked)"
curl -s --connect-timeout 2 -o /dev/null https://gosuslugi.ru && echo "FAIL" || echo "gosuslugi: OK (blocked)"

echo "=== ICMP ==="
ping -c 1 -W 2 8.8.8.8 2>/dev/null && echo "ICMP: FAIL" || echo "ICMP: OK (blocked)"
```

---

## Частые проблемы

| Проблема | Решение |
|----------|---------|
| MAX: «Нет интернета» | Закомментируйте `gstatic.com` в hosts |
| Сеть default не создаётся | `sudo virsh net-define` + `net-start` + `net-autostart` (см. выше) |
| Мало места при установке MAX | Диск VM ≥ 30 ГБ; не используйте Live-сессию — установите ОС на диск |
| MAX видит VPN-IP | Включите обход VPN (policy routing / split tunneling) |

---

## Ограничения

- **IP соединения** MAX всё равно видит — он приходит в TCP-заголовках. Скрыть можно только через VPN/прокси.
- Блокировка снижает объём телеметрии, но не гарантирует полную анонимность перед серверами MAX.
