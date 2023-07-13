#!/bin/bash

# Путь к директории ccd
CCD_DIR="/etc/openvpn/ccd"

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

# Запускаем функцию чтения системного журнала
read_syslog
