#!/bin/bash
cd 
location=$(pwd)
OPENAI_API_KEY=$(cat /usr/local/bin/OPENAI_API_KEY) #assistant write api key needed
ASSISTANT_ID="asst_FVld48ft1p9VTqmT8neMaYKZ"
OS=$(grep '^NAME=' /etc/os-release | sed -e 's/NAME=//g' -e 's/"//g')
API_KEY_FILE="/usr/local/bin/OPENAI_API_KEY"

if [ ! -s "$API_KEY_FILE" ]; then
    echo "The OpenAI API Key file is empty or does not exist."
    read -p "Please enter your assistant write API key: " api_key
    if [ -z "$api_key" ]; then
        echo "No input provided. Exiting."
        exit 1
    else
        sudo echo "$api_key" | sudo tee "$API_KEY_FILE" > /dev/null
        sudo chmod 600 "$API_KEY_FILE"
        
        echo "API Key has been saved to $API_KEY_FILE."
    fi
else
    echo "OpenAI API Key file already exists and is not empty."
fi

cd $location

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
  input="$prompt os=$OS"
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
  clear
  read -p "Do you want to execute: $executable (y/n):" choice 
  if [ $choice == y ]
  then
    echo $executable >> executed.txt
    bash -c "$executable"
  elif [ $choice == n ]
  then
    echo "did not execute!"
  fi
done