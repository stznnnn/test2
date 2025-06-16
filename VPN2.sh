#!/bin/bash
set -e

# Конфигурация
OFFICE_NUMBER="1"  # 1 или 2 в зависимости от офиса
OFFICE_IP="10.10.0.${OFFICE_NUMBER}/24"
PEER_PUBLIC_IP="IP_ДРУГОГО_ОФИСА"  # Замените на реальный IP
PEER_PUBLIC_KEY="PUBLIC_KEY_ДРУГОГО_ОФИСА"  # Получить командой: sudo docker exec -it wireguard wg show wg0 public-key
WG_PORT="51820"

# Проверка root-прав
if [ "$(id -u)" -ne 0 ]; then
  echo "Скрипт должен запускаться от root!"
  exit 1
fi

# Установка Docker (если нет)
if ! command -v docker &> /dev/null; then
  echo "Установка Docker..."
  yum install -y yum-utils
  yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  yum install -y docker-ce docker-ce-cli containerd.io
  systemctl enable --now docker
fi

# Установка WireGuard образа
echo "Загрузка образа WireGuard..."
docker pull linuxserver/wireguard

# Создание директорий
mkdir -p /etc/wireguard/config

# Генерация ключей
echo "Генерация ключей..."
PRIVATE_KEY=$(docker run --rm linuxserver/wireguard wg genkey)
PUBLIC_KEY=$(echo "$PRIVATE_KEY" | docker run --rm -i linuxserver/wireguard wg pubkey)

# Конфиг сервера
echo "Создание конфигурации..."
cat > /etc/wireguard/config/wg0.conf <<EOF
[Interface]
Address = $OFFICE_IP
PrivateKey = $PRIVATE_KEY
ListenPort = $WG_PORT
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

[Peer]
PublicKey = $PEER_PUBLIC_KEY
AllowedIPs = 10.10.0.0/24
Endpoint = $PEER_PUBLIC_IP:$WG_PORT
PersistentKeepalive = 25
EOF

# Запуск контейнера
echo "Запуск контейнера WireGuard..."
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
  linuxserver/wireguard

# Включение маршрутизации
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p

echo "============================================"
echo "Настройка завершена!"
echo "Ваш публичный ключ: $PUBLIC_KEY"
echo "IP-адрес офиса: $OFFICE_IP"
echo "Порт: $WG_PORT/udp"
echo "============================================"