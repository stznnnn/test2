#!/bin/bash

# ===== 1. Настройка Keepalived (MASTER) =====
echo "Настраиваем Keepalived..."
sudo yum install -y keepalived

sudo tee /etc/keepalived/keepalived.conf <<EOF
! Configuration File for keepalived

global_defs {
    router_id LVS_MASTER
}

vrrp_instance VI_1 {
    state MASTER
    interface ens3
    virtual_router_id 51
    priority 101
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

# ===== 2. Настройка DNS (BIND9) =====
echo "Настраиваем DNS сервер..."
sudo yum install -y bind bind-utils

# Конфигурация named.conf
sudo tee /etc/named.conf <<EOF
options {
    listen-on port 53 { any; };
    directory       "/var/named";
    dump-file       "/var/named/data/cache_dump.db";
    statistics-file "/var/named/data/named_stats.txt";
    memstatistics-file "/var/named/data/named_mem_stats.txt";
    allow-query     { any; };
    recursion yes;
};

zone "mopc.com" {
    type master;
    file "/var/named/mopc.com.zone";
};

zone "0.0.10.in-addr.arpa" {
    type master;
    file "/var/named/0.0.10.rev";
};
EOF

# Прямая зона
sudo tee /var/named/mopc.com.zone <<EOF
\$TTL 86400
@   IN  SOA     ns1.mopc.com. admin.mopc.com. (
        2024061501  ; Serial
        3600        ; Refresh
        1800        ; Retry
        604800      ; Expire
        86400       ; Minimum TTL
)
@       IN  NS  ns1.mopc.com.
@       IN  A   10.0.0.99
ns1     IN  A   10.0.0.17
www     IN  A   10.0.0.99
EOF

# Обратная зона
sudo tee /var/named/0.0.10.rev <<EOF
\$TTL 86400
@   IN  SOA     ns1.mopc.com. admin.mopc.com. (
        2024061501  ; Serial
        3600        ; Refresh
        1800        ; Retry
        604800      ; Expire
        86400       ; Minimum TTL
)
@       IN  NS  ns1.mopc.com.
17      IN  PTR ns1.mopc.com.
99      IN  PTR mopc.com.
EOF

# Права на файлы зон
sudo chown named:named /var/named/mopc.com.zone
sudo chown named:named /var/named/0.0.10.rev

# Запуск BIND
sudo systemctl enable --now named
sudo firewall-cmd --add-service=dns --permanent
sudo firewall-cmd --reload

# ===== 3. Настройка MariaDB =====
echo "Настраиваем MariaDB..."
sudo yum install -y mariadb-server
sudo systemctl enable --now mariadb

# Создаем БД (без спец. кодировки)
sudo mysql -e "CREATE DATABASE mopc_db;"
sudo mysql -e "CREATE USER 'mopc_user'@'localhost' IDENTIFIED BY 'password';"
sudo mysql -e "GRANT ALL PRIVILEGES ON mopc_db.* TO 'mopc_user'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

sudo mysql mopc_db -e "CREATE TABLE company_info (
    id INT AUTO_INCREMENT PRIMARY KEY,
    creator_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    email VARCHAR(100) NOT NULL
);"

sudo mysql mopc_db -e "INSERT INTO company_info (creator_name, phone, email) VALUES 
    ('Derezin Stepan Yurievich', '89999999999', 'admin@mopc.ru');"

# ===== 4. Настройка веб-сайта =====
echo "Настраиваем веб-сервер..."
sudo yum install -y httpd php php-mysqlnd
sudo systemctl enable --now httpd

# Контент сайта
sudo tee /var/www/html/index.php <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>MOPC Company</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; }
        button { padding: 10px 20px; font-size: 16px; cursor: pointer; }
        #result { margin-top: 20px; padding: 20px; border: 1px solid #ccc; max-width: 500px; margin-left: auto; margin-right: auto; }
    </style>
</head>
<body>
    <h1>Welcome to MOPC</h1>
    <button onclick="loadData()">Show Company Info</button>
    <div id="result"></div>

    <script>
        function loadData() {
            fetch('/get_data.php')
                .then(response => response.text())
                .then(data => {
                    document.getElementById('result').innerHTML = data;
                });
        }
    </script>
</body>
</html>
EOF

# PHP-скрипт
sudo tee /var/www/html/get_data.php <<EOF
<?php
\$conn = new mysqli('localhost', 'mopc_user', 'password', 'mopc_db');
if (\$conn->connect_error) {
    die("Connection error: " . \$conn->connect_error);
}

\$sql = "SELECT * FROM company_info";
\$result = \$conn->query(\$sql);

if (\$result->num_rows > 0) {
    \$row = \$result->fetch_assoc();
    echo "<strong>Company creator:</strong> " . \$row['creator_name'] . "<br>";
    echo "<strong>Phone:</strong> " . \$row['phone'] . "<br>";
    echo "<strong>Email:</strong> " . \$row['email'];
} else {
    echo "Data not found!";
}
\$conn->close();
?>
EOF

# Виртуальный хост
sudo tee /etc/httpd/conf.d/mopc.conf <<EOF
<VirtualHost *:80>
    ServerName mopc.com
    DocumentRoot /var/www/html
    <Directory /var/www/html>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF

# Добавляем запись в hosts
echo "10.0.0.99 mopc.com" | sudo tee -a /etc/hosts
sudo systemctl restart httpd

# ===== Завершение =====
echo "
=== Настройка завершена! ===
1. Keepalived: MASTER с VIP 10.0.0.99
2. DNS сервер:
   - Прямая зона: /var/named/mopc.com.zone
   - Обратная зона: /var/named/0.0.10.rev
3. MariaDB: данные доступны для пользователя mopc_user
4. Веб-сайт: http://mopc.com
"