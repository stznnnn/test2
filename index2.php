<?php
$host = 'localhost';
$dbname = 'base';
$user = 'admin';
$pass = 'P@ssword';

try {
    $pdo = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8", $user, $pass);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    $stmt = $pdo->query("SELECT * FROM key_value_store");
    $data = $stmt->fetchAll(PDO::FETCH_ASSOC);
} catch (PDOException $e) {
    die("Ошибка подключения: " . $e->getMessage());
}
?>

<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Список пользователей</title>
    <style>
        table { border-collapse: collapse; width: 50%; margin: 20px auto; }
        th, td { border: 1px solid black; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        body {
            background-color: #000;
            display: flex;
            justify-content: center;
            align-items: center;
            height: 100vh;
            margin: 0;
            overflow: hidden;
            font-family: monospace;
        }
        
        .ascii-art {
            color: #0ff;
            font-size: 10px;
            line-height: 10px;
            text-shadow: 0 0 10px #0ff, 0 0 20px #0ff;
            white-space: pre;
            animation: glow 1.5s ease-in-out infinite alternate;
        }
        
        @keyframes glow {
            from {
                text-shadow: 0 0 5px #0ff, 0 0 10px #0ff;
            }
            to {
                text-shadow: 0 0 15px #0ff, 0 0 30px #0ff, 0 0 40px #0ff;
            }
        }
    </style>
</head>
<body>
    <div class="ascii-art">
        ___     _,.---._        _ __      _,.----.   
  .-._ .'=.'\  ,-.' , -  `.   .-`.' ,`.  .' .' -   \  
 /==/ \|==|  |/==/_,  ,  - \ /==/, -   \/==/  ,  ,-'  
 |==|,|  / - |==|   .=.     |==| _ .=. ||==|-   |  .  
 |==|  \/  , |==|_ : ;=:  - |==| , '=',||==|_   `-' \ 
 |==|- ,   _ |==| , '='     |==|-  '..' |==|   _  , | 
 |==| _ /\   |\==\ -    ,_ /|==|,  |    \==\.       / 
 /==/  / / , / '.='. -   .' /==/ - |     `-.`.___.-'  
 `--`./  `--`    `--`--''   `--`---'                     
    </div>

    <script>
        // Анимация изменения размера
        let fontSize = 10;
        let growing = true;
        
        function animate() {
            const art = document.querySelector('.ascii-art');
            
            if (growing) {
                fontSize += 0.2;
                if (fontSize >= 15) growing = false;
            } else {
                fontSize -= 0.2;
                if (fontSize <= 10) growing = true;
            }
            
            art.style.fontSize = `${fontSize}px`;
            art.style.lineHeight = `${fontSize}px`;
            
            requestAnimationFrame(animate);
        }
        
        animate();
    </script>


    <table>
        <tr>
            <th>ID</th>
            <th>ФИО</th>
        </tr>
        <?php foreach ($data as $row): ?>
            <tr>
                <td><?php echo htmlspecialchars($row['key']); ?></td>
                <td><?php echo htmlspecialchars($row['value']); ?></td>
            </tr>
        <?php endforeach; ?>
    </table>
</body>
</html>
