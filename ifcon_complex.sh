#!/bin/bash

# Путь к директории ccd
CCD_DIR="/etc/openvpn/ccd"
# Путь к файлу результатов
RESULT_FILE="/root/ccd_parsed.txt"
# Токен Telegram бота
TELEGRAM_BOT_TOKEN="1234567890"
# ID чата, куда отправлять уведомления
CHAT_ID="1234567890"

# Очистка файла результатов перед каждым запуском скрипта
> "$RESULT_FILE"

# Функция для чтения системного журнала в реальном времени
read_syslog() {
    tail -f /var/log/syslog | while read -r line; do
        # Извлекаем имя клиента из строки, если она содержит "VERIFY OK"
        if echo "$line" | grep -q "VERIFY OK"; then
            CLIENT_NAME=$(echo "$line" | awk -F'CN=' '{print $2}' | awk '{print $1}')
        fi

        # Извлекаем IP-адрес клиента из строки, если она содержит "MULTI_sva: pool returned"
        if echo "$line" | grep -q "MULTI_sva: pool returned"; then
            IP_ADDRESS=$(echo "$line" | awk -F'IPv4=' '{print $2}' | awk -F',' '{print $1}')

            # Проверяем, пустой ли клиентский файл и содержит ли он уже необходимую строку
            if [ ! -s "$CCD_DIR/$CLIENT_NAME" ] && ! grep -q "ifconfig-push $IP_ADDRESS" "$CCD_DIR/$CLIENT_NAME"; then
                # Записываем IP-адрес в клиентский файл
                echo "ifconfig-push $IP_ADDRESS 255.255.0.0" > "$CCD_DIR/$CLIENT_NAME"
                echo "Записан IP-адрес $IP_ADDRESS в клиентский файл $CCD_DIR/$CLIENT_NAME"
            fi
        fi
    done
}

# Функция для сканирования файлов в директории ccd и отправки результатов в Telegram
scan_ccd_directory() {
    for file in "$CCD_DIR"/*; do
        if [ -f "$file" ]; then
            # Извлечение имени клиента из имени файла
            client_name=$(basename "$file")
            # Извлечение локального IP-адреса из содержимого файла
            ip_address=$(grep -oP 'ifconfig-push \K(\S+)' "$file")

            # Проверка наличия актуального локального IP-адреса
            if [ -n "$ip_address" ]; then
                # Запись актуальных данных в файл результатов
                echo "$client_name - $ip_address" >> "$RESULT_FILE"
            else
                # Удаление файла, если локальный IP-адрес отсутствует
                rm "$file"
            fi
        fi
    done

    # Отправка уведомления в Telegram
    message="Данные в файле $RESULT_FILE обновлены"
    curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
         -d "chat_id=$CHAT_ID" \
         -d "text=$message" >/dev/null

    # Отправка файла результатов в Telegram
    curl -s -F "chat_id=$CHAT_ID" -F "document=@$RESULT_FILE" "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendDocument" >/dev/null
}

# Проверяем переданный аргумент и вызываем соответствующую функцию
if [ "$1" = "read_syslog" ]; then
    read_syslog
elif [ "$1" = "scan_ccd_directory" ]; then
    scan_ccd_directory
else
    echo "Неправильный аргумент. Используйте 'read_syslog' или 'scan_ccd_directory'."
fi
