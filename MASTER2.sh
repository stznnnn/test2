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

# ===== 2. Установка Prometheus + Grafana =====
echo "Устанавливаем Prometheus и Grafana..."
sudo yum install -y prometheus grafana

sudo systemctl enable --now prometheus
sudo systemctl enable --now grafana-server

sudo tee /etc/grafana/provisioning/datasources/prometheus.yml <<EOF
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
EOF

sudo systemctl restart grafana-server

# ===== 3. Создание базы данных MariaDB =====
echo "Устанавливаем MariaDB и создаем базу данных..."
sudo yum install -y mariadb-server
sudo systemctl enable --now mariadb

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
    ('Дерезин Степан Юрьевич', '89999999999', 'admin@mopc.ru');"

# ===== 4. Настройка веб-сайта (Apache + PHP) =====
echo "Устанавливаем Apache и PHP..."
sudo yum install -y httpd php php-mysqlnd
sudo systemctl enable --now httpd

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
    <h1>Добро пожаловать в MOPC!</h1>
    <button onclick="loadData()">Показать информацию о компании</button>
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

sudo tee /var/www/html/get_data.php <<EOF
<?php
\$conn = new mysqli('localhost', 'mopc_user', 'password', 'mopc_db');
if (\$conn->connect_error) {
    die("Ошибка подключения: " . \$conn->connect_error);
}

\$sql = "SELECT * FROM company_info";
\$result = \$conn->query(\$sql);

if (\$result->num_rows > 0) {
    \$row = \$result->fetch_assoc();
    echo "<strong>Создатель компании:</strong> " . \$row['creator_name'] . "<br>";
    echo "<strong>Телефон:</strong> " . \$row['phone'] . "<br>";
    echo "<strong>Email:</strong> " . \$row['email'];
} else {
    echo "Данные не найдены!";
}
\$conn->close();
?>
EOF

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

echo "10.0.0.99 mopc.com" | sudo tee -a /etc/hosts
sudo systemctl restart httpd

echo "
=== Настройка завершена! ===
1. Keepalived работает как MASTER с VIP 10.0.0.99
2. Prometheus: http://10.0.0.99:9090
3. Grafana: http://10.0.0.99:3000 (логин: admin, пароль: admin)
4. Сайт доступен: http://mopc.com
5. Данные компании хранятся в MariaDB (mopc_db.company_info)
"