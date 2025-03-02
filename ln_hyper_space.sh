#!/bin/bash

download_node() {
  echo "Starting installation..."

  # Load private key from file (should be located in $HOME)
  if [ -f "$HOME/hype_space_private.txt" ]; then
    cat "$HOME/hype_space_private.txt" > "$HOME/my.pem"
    echo "Private key successfully loaded from hype_space_private.txt"
  else
    echo "File hype_space_private.txt not found. Exiting."
    exit 1
  fi

  session="hyperspacenode"
  cd "$HOME" || exit

  # Update system packages
  sudo DEBIAN_FRONTEND=noninteractive apt-get update -y && \
  sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

  # Install required packages
  sudo DEBIAN_FRONTEND=noninteractive apt-get install wget make tar screen nano libssl3-dev build-essential unzip lz4 gcc git jq -y

  packages="wget make tar screen nano libssl3-dev build-essential unzip lz4 gcc git jq"

  check_and_install() {
    if ! dpkg -s "$1" >/dev/null 2>&1; then
      sudo DEBIAN_FRONTEND=noninteractive apt-get install "$1" -y
    fi
  }

  for package in $packages; do
    check_and_install "$package"
  done

  # Remove previous installation if exists
  if [ -d "$HOME/.aios" ]; then
    sudo rm -rf "$HOME/.aios"
    aios-cli kill
  fi

  if screen -list | grep -q "\.${session}"; then
    screen -S hyperspacenode -X quit
  else
    echo "Session ${session} not found."
  fi

  # Install hyperspace node client
  while true; do
    curl -s https://download.hyper.space/api/install | bash | tee "$HOME/hyperspacenode_install.log"
    if ! grep -q "Failed to parse version from release data." "$HOME/hyperspacenode_install.log"; then
      echo "Client script installed successfully."
      break
    else
      echo "Installation server unavailable, retrying in 30 seconds..."
      sleep 30
    fi
  done

  rm "$HOME/hyperspacenode_install.log"

  export PATH="$PATH:$HOME/.aios"
  source "$HOME/.bashrc"
  eval "$(tail -n +10 "$HOME/.bashrc")"

  screen -dmS hyperspacenode bash -c '
    echo "Starting script in screen session"
    aios-cli start
    exec bash
  '

  # Install model
  while true; do
    aios-cli models add hf:TheBloke/phi-2-GGUF:phi-2.Q4_K_M.gguf 2>&1 | tee "$HOME/hyperspacemodel_download.log"
    if grep -q "Download complete" "$HOME/hyperspacemodel_download.log"; then
      echo "Model installed successfully."
      break
    else
      echo "Model installation server unavailable, retrying in 30 seconds..."
      sleep 30
    fi
  done

  rm "$HOME/hyperspacemodel_download.log"

  # Import keys and connect to hive
  aios-cli hive import-keys "$HOME/my.pem"
  aios-cli hive login
  aios-cli hive connect
}

start_points_monitor() {
  echo "Starting points monitoring..."

  # Create the points monitoring script
  cat > "$HOME/points_monitor_hyperspace.sh" << 'EOL'
#!/bin/bash
SCREEN_NAME="hyperspacenode"
LAST_POINTS="0"

while true; do
    CURRENT_POINTS=$(aios-cli hive points | grep "Points:" | awk '{print $2}')
    
    if [ "$CURRENT_POINTS" = "$LAST_POINTS" ] || { [ "$CURRENT_POINTS" != "NaN" ] && [ "$LAST_POINTS" != "NaN" ] && [ "$CURRENT_POINTS" -eq "$LAST_POINTS" ]; }; then
        echo "$(date): Points not updated (Current: $CURRENT_POINTS, Previous: $LAST_POINTS). Restarting service..." >> "$HOME/points_monitor_hyperspace.log"
        screen -S "$SCREEN_NAME" -X stuff $'\003'
        sleep 5
        screen -S "$SCREEN_NAME" -X stuff "aios-cli kill\n"
        sleep 5
        screen -S "$SCREEN_NAME" -X stuff "aios-cli start --connect"
    fi
    LAST_POINTS="$CURRENT_POINTS"
    sleep 10800
done
EOL

  chmod +x "$HOME/points_monitor_hyperspace.sh"
  nohup "$HOME/points_monitor_hyperspace.sh" > "$HOME/points_monitor_hyperspace.log" 2>&1 &
  echo "Points monitoring started."
}

# Run installation and points monitoring automatically
download_node
start_points_monitor
