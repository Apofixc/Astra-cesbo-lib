#!/bin/bash

BOT_TOKEN=""
CHAT_ID="-1002003869984"
PARSE_MODE="HTML"

# Требуется: jq

json=$(cat)

for i in $(echo "$json" | jq -r '.metrics | keys[]'); do
  
  ready_changed=$(echo "$json" | jq -r ".metrics[$i].tags.ready_changed")
  
  # Только если ready_changed == "true", отправляем сообщение
  if [[ "$ready_changed" == "true" ]]; then
    
    # Извлечение данных с обработкой пустого канала
    channel=$(echo "$json" | jq -r ".metrics[$i].tags.channel | if . == null or . == \"\" then \"Channel Unknown\" else . end")
    ready_bool=$(echo "$json" | jq -r ".metrics[$i].fields.ready")
    
    # Базовое сообщение с логикой остановка/восстановление
    if [[ "$ready_bool" == "true" ]]; then
      status="восстановлена"
    else
      status="остановлена"
    fi
    
    message="🌐 Трансляция канала $channel была $status"
    
    # Отправляем в Telegram
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
      -d chat_id=${CHAT_ID} -d text="$message" >/dev/null
    
  fi
done
