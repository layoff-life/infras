-- Create a custom admin user with full access
CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED BY 'r9HuHsNQnT2C5Eb3U7Zg';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%' WITH GRANT OPTION;

-- Ensure the standard user has access (redundant if MYSQL_USER is set, but good for safety)
CREATE USER IF NOT EXISTS 'my_user'@'%' IDENTIFIED BY 'NC130g2gbbXKdEdTsyxF';
GRANT ALL PRIVILEGES ON `my_database`.* TO 'my_user'@'%';

FLUSH PRIVILEGES;
