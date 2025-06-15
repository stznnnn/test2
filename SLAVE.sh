#!/bin/bash

# ===== 1. Настройка Keepalived (BACKUP) =====
echo "Устанавливаем и настраиваем Keepalived..."
sudo yum install -y keepalived

sudo tee /etc/keepalived/keepalived.conf <<EOF
! Configuration File for keepalived

global_defs {
    router_id LVS_BACKUP
}

vrrp_instance VI_1 {
    state BACKUP
    interface ens3
    virtual_router_id 51
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass derezin
    }
    virtual_ipaddress {
        10.0.0.99/8
    }
}
EOF

sudo systemctl enable --now keepalived
sudo systemctl restart keepalived

# ===== 2. Установка базовых компонентов =====
echo "Устанавливаем Apache и PHP..."
sudo yum install -y httpd php php-mysqlnd
sudo systemctl enable --now httpd

# Копируем файлы сайта с MASTER (нужно выполнить вручную после настройки MASTER)
echo "Для синхронизации сайта выполните на MASTER:"
echo "rsync -avz /var/www/html/ 10.0.0.18:/var/www/html/"

# ===== 3. Настройка репликации MariaDB =====
echo "Устанавливаем MariaDB для репликации..."
sudo yum install -y mariadb-server
sudo systemctl enable --now mariadb

echo "Настройте репликацию вручную, выполнив на MASTER:"
echo "1. CREATE USER 'replica'@'10.0.0.18' IDENTIFIED BY 'password';"
echo "2. GRANT REPLICATION SLAVE ON *.* TO 'replica'@'10.0.0.18';"
echo "3. FLUSH PRIVILEGES;"
echo "4. SHOW MASTER STATUS; (запомните File и Position)"
echo ""
echo "Затем на этом сервере (SLAVE) выполните:"
echo "CHANGE MASTER TO MASTER_HOST='10.0.0.17',"
echo "MASTER_USER='replica', MASTER_PASSWORD='password',"
echo "MASTER_LOG_FILE='[значение из File]', MASTER_LOG_POS=[значение из Position];"
echo "START SLAVE;"

# ===== Финал =====
echo "
=== Настройка SLAVE завершена! ===
1. Keepalived работает в режиме BACKUP
2. Apache установлен (синхронизируйте файлы сайта с MASTER)
3. MariaDB установлен (настройте репликацию вручную)
4. VIP 10.0.0.99 будет автоматически перехвачен при падении MASTER
"