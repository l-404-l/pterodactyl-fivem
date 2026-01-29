#!/bin/bash

# FiveM Pterodactyl Entrypoint Script
# This script processes Pterodactyl startup command variables and executes the server

cd /home/container || exit 1

# Set timezone if provided
if [ -n "${TZ}" ]; then
    export TZ="${TZ}"
    echo "* Timezone set to: ${TZ}"
fi

# Output current user
echo "* Running as user: $(whoami)"
echo "* Current directory: $(pwd)"

# Make internal Docker IP address available to startup command
INTERNAL_IP=$(ip route get 1 2>/dev/null | awk '{print $(NF-2);exit}')
export INTERNAL_IP

echo "* Internal IP: ${INTERNAL_IP:-not detected}"

# Replace Pterodactyl startup command variables
# Pterodactyl passes the startup command via STARTUP environment variable
# Variables are in the format {{VARIABLE_NAME}}
MODIFIED_STARTUP=$(echo "${STARTUP}" | sed -e 's/{{/${/g' -e 's/}}/}/g')

echo "* Starting FiveM Server..."
echo "-------------------------------------------"

# Execute the modified startup command
# shellcheck disable=SC2086
exec env ${MODIFIED_STARTUP}
