#!/bin/bash
set -e

# Конфигурация
WG_NETWORK="10.10.0.1/24"
WG_PORT="51820"
INTERFACE="ens3"
DOCKER_IMAGE="linuxserver/wireguard:latest"

# Проверка root-прав
if [ "$(id -u)" -ne 0 ]; then
  echo "Ошибка: Скрипт должен запускаться от root!"
  exit 1
fi

# Установка Docker
if ! command -v docker &>/dev/null; then
  echo "Установка Docker..."
  yum install -y yum-utils
  yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  yum install -y docker-ce docker-ce-cli containerd.io
  systemctl enable --now docker
fi

# Создание конфигурационных директорий
echo "Создание структуры каталогов..."
mkdir -p /etc/wireguard/{config,clients}
chmod 700 /etc/wireguard

# Генерация ключей
echo "Генерация ключей..."
SERVER_PRIVKEY=$(docker run --rm $DOCKER_IMAGE wg genkey)
SERVER_PUBKEY=$(echo "$SERVER_PRIVKEY" | docker run --rm -i $DOCKER_IMAGE wg pubkey)
CLIENT_PRIVKEY=$(docker run --rm $DOCKER_IMAGE wg genkey)
CLIENT_PUBKEY=$(echo "$CLIENT_PRIVKEY" | docker run --rm -i $DOCKER_IMAGE wg pubkey)

# Конфиг сервера
echo "Создание конфигурации сервера..."
cat > /etc/wireguard/config/wg0.conf <<EOF
[Interface]
Address = $WG_NETWORK
PrivateKey = $SERVER_PRIVKEY
ListenPort = $WG_PORT
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $INTERFACE -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $INTERFACE -j MASQUERADE

[Peer]
PublicKey = $CLIENT_PUBKEY
AllowedIPs = 10.10.0.2/32
EOF

# Конфиг клиента
echo "Создание клиентского конфига..."
cat > /etc/wireguard/clients/office2.conf <<EOF
[Interface]
PrivateKey = $CLIENT_PRIVKEY
Address = 10.10.0.2/32
DNS = 8.8.8.8

[Peer]
PublicKey = $SERVER_PUBKEY
AllowedIPs = 10.10.0.0/24
Endpoint = $(ip -4 addr show $INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}'):$WG_PORT
PersistentKeepalive = 25
EOF

# Настройка сети
echo "Включение IP-форвардинга..."
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# Настройка firewall
echo "Конфигурация firewall..."
firewall-cmd --add-port=$WG_PORT/udp --permanent
firewall-cmd --reload

# Запуск контейнера
echo "Запуск Docker-контейнера WireGuard..."
docker run -d \
  --name=wireguard \
  --cap-add=NET_ADMIN \
  --cap-add=SYS_MODULE \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Europe/Moscow \
  -p $WG_PORT:$WG_PORT/udp \
  -v /etc/wireguard/config:/config \
  -v /lib/modules:/lib/modules \
  --sysctl="net.ipv4.conf.all.src_valid_mark=1" \
  --restart unless-stopped \
  $DOCKER_IMAGE

echo "=============================================="
echo "Настройка завершена!"
echo "----------------------------------------------"
echo "Серверные данные:"
echo "Интерфейс: $INTERFACE"
echo "Внутренний IP: $WG_NETWORK"
echo "Публичный IP: $(curl -s ifconfig.me)"
echo "Порт: $WG_PORT/udp"
echo "Публичный ключ сервера: $SERVER_PUBKEY"
echo "----------------------------------------------"
echo "Клиентский конфиг сохранен в:"
echo "/etc/wireguard/clients/office2.conf"
echo "=============================================="

# QR-код для удобства (если установлен qrencode)
if command -v qrencode &>/dev/null; then
  echo "QR-код для клиента:"
  qrencode -t ansiutf8 < /etc/wireguard/clients/office2.conf
fi