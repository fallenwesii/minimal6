#!/bin/bash

# Navigate to the script's directory
cd "$(dirname "$0")" || exit 1

echo "Pulling latest changes..."
git pull

echo "Re-running setup.sh..."
bash ./setup.sh
