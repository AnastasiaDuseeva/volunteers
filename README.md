# volunteers
# База данных
# Создать базу данных

1. В левой панели "Создать базу данных"
2. В поле имени: volunteer_db
3. Rодировкf: utf8mb4_unicode_ci
4. "Создать"
5. В верхней панели есть вкладка "Импорт". Выбрать schema.sql

# Настройка подключения к БД
В папке проекта файл config/config.example.php. Его надо скопировать рядом под именем config/config.php.
Открыть config/config.php и заполнить так:
<?php
return [
    'host'     => '127.0.0.1',
    'dbname'   => 'volunteer_db',
    'user'     => 'root',
    'password' => '',
    'charset'  => 'utf8mb4',
    'port'     => 3306
]; php?>
