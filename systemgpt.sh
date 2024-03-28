#!/bin/bash

if command -v jq >/dev/null 2>&1; then
    echo "jq is already installed."
else
    if command -v apt-get >/dev/null 2>&1; then
        PM=apt-get
        INSTALL_CMD="sudo $PM update && sudo $PM install -y jq"
    elif command -v dnf >/dev/null 2>&1; then
        PM=dnf
        INSTALL_CMD="sudo $PM install -y jq"
    elif command -v yum >/dev/null 2>&1; then
        PM=yum
        INSTALL_CMD="sudo $PM install -y jq"
    elif command -v pacman >/dev/null 2>&1; then
        PM=pacman
        INSTALL_CMD="sudo $PM -Sy jq"
    elif command -v zypper >/dev/null 2>&1; then
        PM=zypper
        INSTALL_CMD="sudo $PM install -y jq"
    else
        echo "Package manager not detected. You may need to install jq manually."
        exit 1
    fi
fi
eval $INSTALL_CMD
clear
read -p "you agree that if you use systemgpt that there is an chance that your system can break and data can be lost (yes/no):" yn
if [ "$yn" == "yes" ]; then
    echo " "
    echo "agreed" > .agree
else
    echo "you didn't agree exiting now." 
    exit
fi

API_KEY_FILE="$HOME/.openai_api_key"
API_ENDPOINT="https://api.openai.com/v1/models"
ask_and_save_api_key() {
    while true; do
        echo "Please enter your OpenAI API Key:"
        read -r user_api_key
        if verify_api_key "$user_api_key"; then
            echo "$user_api_key" > "$API_KEY_FILE"
            echo "API Key is valid and has been saved to $API_KEY_FILE."
            break
        else
            echo "The API Key is invalid or there was an error. Please try again."
        fi
    done
}

verify_api_key() {
    local api_key=$1
    local response=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $api_key" "$API_ENDPOINT")

    if [ "$response" -eq 200 ]; then
        echo "The API Key is valid."
        return 0 # Success
    else
        echo "The API Key is invalid or there was an error. Response code: $response"
        return 1 # Failure
    fi
}

if [ -f "$API_KEY_FILE" ] && [ -s "$API_KEY_FILE" ]; then
    API_KEY=$(cat "$API_KEY_FILE")
    if ! verify_api_key "$API_KEY"; then
        echo "Existing API key is invalid. Please enter a new one."
        ask_and_save_api_key
    fi
else
    ask_and_save_api_key
fi
OPENAI_API_KEY=$(cat $HOME/.openai_api_key)
ASSISTANT_ID="asst_FVld48ft1p9VTqmT8neMaYKZ"
OS=$(grep '^NAME=' /etc/os-release | sed -e 's/NAME=//g' -e 's/"//g')

create_thread() {
  curl https://api.openai.com/v1/threads \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "OpenAI-Beta: assistants=v1" \
    -d ''
}

add_message_to_thread() { 
  curl https://api.openai.com/v1/threads/$THREAD_ID/messages \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "OpenAI-Beta: assistants=v1" \
    -d '{
        "role": "user",
        "content": "'"$input"'"
    }'
}

run_assistant() { 
  curl https://api.openai.com/v1/threads/$THREAD_ID/runs \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "Content-Type: application/json" \
    -H "OpenAI-Beta: assistants=v1" \
    -d '{
      "assistant_id": "'$ASSISTANT_ID'",
      "instructions": ""
    }'
}

check_run_status() { 
  curl https://api.openai.com/v1/threads/$THREAD_ID/runs/$RUN_ID \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "OpenAI-Beta: assistants=v1"
}

display_response() { 
  curl https://api.openai.com/v1/threads/$THREAD_ID/messages \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -H "OpenAI-Beta: assistants=v1"
}

while true; do
  clear
  read -p "SystemGPT: What do you want me to do?: " prompt
  if [ "$promt" == "exit" ]; then
      exit
  fi
  input="$prompt os=$OS desktop_environmen=$DESKTOP_SESSION"
  create_thread > /dev/null
  THREAD_ID=$(create_thread | jq -r '.id')
  echo "created thread: $THREAD_ID"
  add_message_to_thread > /dev/null
  echo "Added message to thread"
  RUN_ID=$(run_assistant | jq -r '.id')
  echo "Made run id: $RUN_ID"
  while true; do
      status=$(check_run_status | jq -r '.status')
      if [[ "$status" == "completed" ]]; then
          echo "Run completed"
          break
      else
          echo "Status: Loading..."
      fi
  done
  display_response | jq -r '.data[0].content[0].text.value'
  executable=$(display_response | jq -r '.data[0].content[0].text.value')
  echo $executable >> executed.txt
    read -p "Do you want to execute: $executable (y/n):" choice
    if [ "$choice" == "y" ]; then
        bash -c "$executable"
    fi
done
