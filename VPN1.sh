#!/bin/bash
set -e

# Конфигурация
OFFICE1_IP="10.10.0.1/24"
OFFICE2_IP="10.10.0.2/24"
OFFICE1_PUBLIC_IP="your_office1_public_ip"  # Замените на реальный IP
OFFICE2_PUBLIC_IP="your_office2_public_ip"  # Замените на реальный IP
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
docker pull linuxserver/wireguard

# Функция настройки офиса
setup_office() {
  local OFFICE_NUM=$1
  local IP=$2
  local PEER_PUBLIC_IP=$3
  local PEER_PUBLIC_KEY=$4

  echo "Настройка офиса $OFFICE_NUM ($IP)"

  # Создание директорий
  mkdir -p /etc/wireguard/office$OFFICE_NUM/config

  # Генерация ключей
  PRIVATE_KEY=$(docker run --rm linuxserver/wireguard wg genkey)
  PUBLIC_KEY=$(echo "$PRIVATE_KEY" | docker run --rm -i linuxserver/wireguard wg pubkey)

  # Конфиг сервера
  cat > /etc/wireguard/office$OFFICE