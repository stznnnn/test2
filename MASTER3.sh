#!/bin/bash

# ===== 1. Настройка Keepalived (MASTER) =====
echo "Устанавливаем и настраиваем Keepalived..."
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

# ===== 2. Установка системы мониторинга =====
echo "Настраиваем систему мониторинга Prometheus+Grafana..."

# Добавляем репозитории
sudo tee /etc/yum.repos.d/prometheus.repo <<EOF
[prometheus]
name=Prometheus
baseurl=https://repo.red-soft.ru/redos/8/prometheus
enabled=1
gpgcheck=0
EOF

sudo tee /etc/yum.repos.d/grafana.repo <<EOF
[grafana]
name=Grafana
baseurl=https://repo.red-soft.ru/redos/8/grafana
enabled=1
gpgcheck=0
EOF

# Устанавливаем компоненты
sudo yum install -y prometheus2 grafana prometheus-node_exporter

# Настраиваем Prometheus
sudo systemctl enable --now prometheus
sudo systemctl enable --now prometheus-node_exporter

# Настраиваем Grafana
sudo systemctl enable --now grafana-server

# Конфигурация Grafana
sudo tee /etc/grafana/provisioning/datasources/prometheus.yml <<EOF
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
EOF

sudo systemctl restart grafana-server

# Открываем порты в firewall
sudo firewall-cmd --add-port=9090/tcp --permanent  # Prometheus
sudo firewall-cmd --add-port=3000/tcp --permanent  # Grafana
sudo firewall-cmd --add-port=9100/tcp --permanent  # Node Exporter
sudo firewall-cmd --reload

# ===== 3. Настройка MariaDB =====
echo "Настраиваем MariaDB с корректной кодировкой..."
sudo yum install -y mariadb-server
sudo systemctl enable --now mariadb

# Создаем БД с utf8mb4
sudo mysql -e "CREATE DATABASE mopc_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -e "CREATE USER 'mopc_user'@'localhost' IDENTIFIED BY 'password';"
sudo mysql -e "GRANT ALL PRIVILEGES ON mopc_db.* TO 'mopc_user'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Создаем таблицу и добавляем данные (латинскими символами)
sudo mysql mopc_db -e "CREATE TABLE company_info (
    id INT AUTO_INCREMENT PRIMARY KEY,
    creator_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20) NOT NULL,
    email VARCHAR(100) NOT NULL
);"

sudo mysql mopc_db -e "INSERT INTO company_info (creator_name, phone, email) VALUES 
    ('Derezin Stepan Yurievich', '89999999999', 'admin@mopc.ru');"

# ===== 4. Настройка веб-сайта =====
echo "Развертываем веб-сайт..."
sudo yum install -y httpd php php-mysqlnd
sudo systemctl enable --now httpd

# HTML-страница
sudo tee /var/www/html/index.php <<EOF
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <title>MOPC Company</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; margin-top: 50px; }
        button { padding: 10px 20px; font-size: 16px; cursor: pointer; }
        #result { margin-top: 20px; padding: 20px; border: 1px solid #ccc; max-width: 500px; margin-left: auto; margin-right: auto; }
    </style>
</head>
<body>
    <h1>Welcome to MOPC!</h1>
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
2. Prometheus: http://10.0.0.99:9090
3. Grafana: http://10.0.0.99:3000 (admin/admin)
4. Node Exporter: http://10.0.0.99:9100
5. Website: http://mopc.com
6. MySQL данные: Derezin Stepan Yurievich
"