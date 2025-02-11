#!/bin/bash
# Stop any running aios-cli process
echo "[INFO] Stopping any running aios-cli processes..."
aios-cli kill
sleep 1

# Delete any existing screen sessions with name "hyperspace"
echo "[INFO] Searching for existing 'hyperspace' screen sessions..."
existing_screens=$(screen -ls | grep "\.hyperspace" | awk -F. '{print $1}')
if [ -n "$existing_screens" ]; then
    for scr in $existing_screens; do
        echo "[INFO] Deleting existing screen session with ID: $scr"
        screen -S "$scr.hyperspace" -X quit
    done
else
    echo "[INFO] No existing 'hyperspace' screen sessions found."
fi
sleep 1

# Download model by default
echo "[INFO] Downloading model..."
url="https://huggingface.com/afrideva/Tiny-Vicuna-1B-GGUF/resolve/main/tiny-vicuna-1b.q8_0.gguf"
model_folder="/root/.cache/hyperspace/models/hf__afrideva___Tiny-Vicuna-1B-GGUF__tiny-vicuna-1b.q8_0.gguf"
model_path="$model_folder/tiny-vicuna-1b.q8_0.gguf"
if [ ! -d "$model_folder" ]; then
    echo "[INFO] Model folder not found. Creating folder: $model_folder"
    mkdir -p "$model_folder"
fi

if [ ! -f "$model_path" ]; then
    echo "[INFO] Downloading model from $url..."
    wget -q --show-progress "$url" -O "$model_path"
    if [ -f "$model_path" ]; then
        echo "[SUCCESS] Model downloaded successfully to $model_path."
    else
        echo "[ERROR] Failed to download the model."
    fi
else
    echo "[INFO] Model already exists at $model_path. Skipping download."
fi
sleep 1

# Import private key from hyperspace_private_key.txt
if [ -f "hyperspace_private_key.txt" ]; then
    echo "[INFO] Importing private key from hyperspace_private_key.txt..."
    cat hyperspace_private_key.txt > .pem
    aios-cli hive import-keys ./.pem
else
    echo "[WARNING] hyperspace_private_key.txt not found. Skipping private key import."
fi
sleep 1

# Create a new screen session named "hyperspace" with logging enabled
# Create a temporary screen configuration file to log to hyperspace.log
cat <<EOF > /tmp/hyperspace_screenrc
logfile hyperspace.log
log on
EOF

echo "[INFO] Creating new screen session 'hyperspace' with logging enabled..."
screen -dmS hyperspace -c /tmp/hyperspace_screenrc
sleep 1

# Start aios-cli in the "hyperspace" screen session
echo "[INFO] Starting aios-cli in screen session 'hyperspace'..."
screen -S hyperspace -X stuff "aios-cli start\n"
sleep 1

# Run Hive commands
echo "[INFO] Logging in to Hive..."
aios-cli hive login
sleep 1

echo "[INFO] Selecting Tier 5..."
aios-cli hive select-tier 5
sleep 1

echo "[INFO] Connecting to Hive..."
aios-cli hive connect
sleep 1

# Set inference prompt with LazyNode branding
infer_prompt="What is LazyNode? Describe the node community."

# Run inference using aios-cli
echo "[INFO] Running inference with aios-cli..."
if aios-cli infer --model hf:afrideva/Tiny-Vicuna-1B-GGUF:tiny-vicuna-1b.q8_0.gguf --prompt "$infer_prompt"; then
    echo "[SUCCESS] aios-cli inference completed successfully."
else
    echo "[ERROR] aios-cli inference failed."
fi
sleep 1

# Run Hive inference
echo "[INFO] Running Hive inference..."
if aios-cli hive infer --model hf:afrideva/Tiny-Vicuna-1B-GGUF:tiny-vicuna-1b.q8_0.gguf --prompt "$infer_prompt"; then
    echo "[SUCCESS] Hive inference completed successfully."
else
    echo "[ERROR] Hive inference failed."
fi
sleep 1

# Reconnect aios-cli in the screen session (with the connect flag)
echo "[INFO] Restarting aios-cli with connect flag in screen session 'hyperspace'..."
screen -S hyperspace -X stuff "aios-cli start --connect\n"
sleep 1

echo "[INFO] Process completed."
echo "DONE. Check the logs in 'hyperspace.log' or attach to the screen session with: screen -r hyperspace"
