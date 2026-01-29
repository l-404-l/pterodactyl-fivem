#!/bin/bash
# FiveM Startup Script for Pterodactyl
# This script handles txAdmin environment setup, auto-updates, and server launch

set -e

echo "=================================================="
echo "   FiveM Server Startup"
echo "=================================================="
echo ""

# Set timezone
if [ -n "${TIMEZONE}" ]; then
    export TZ="${TIMEZONE}"
    echo "* Timezone: ${TZ}"
fi

# txAdmin Environment Variables (new TXHOST format)
export TXHOST_DATA_PATH="/home/container"
export TXHOST_PORT="${TXADMIN_PORT:-40120}"
export TXHOST_INTERFACE="${TXADMIN_INTERFACE:-0.0.0.0}"
export TXHOST_FXSERVER_PORT="${SERVER_PORT:-30120}"
export TXHOST_PUBLIC_URL="http://${SERVER_IP}:${TXADMIN_PORT:-40120}"
export TXHOST_PROVIDER_NAME="${TXADMIN_PROVIDER_NAME:-Pterodactyl}"
export TXHOST_PROVIDER_LOGO_URL="${TXADMIN_PROVIDER_LOGO}"
export TXHOST_SERVER_GAME="fivem"

echo "* txAdmin Port: ${TXHOST_PORT}"
echo "* Game Port: ${TXHOST_FXSERVER_PORT}"

# Auto-Update Artifacts
if [ "${AUTO_UPDATE_ARTIFACTS}" == "1" ]; then
    echo ""
    echo "[UPDATE] Checking for artifact updates..."
    
    if [ -f "alpine/opt/cfx-server/version" ]; then
        CURRENT_VERSION=$(cat alpine/opt/cfx-server/version 2>/dev/null || echo "unknown")
    else
        CURRENT_VERSION="unknown"
    fi
    
    echo "[UPDATE] Current version: ${CURRENT_VERSION}"
    
    CHANGELOGS_API="https://changelogs-live.fivem.net/api/changelog/versions/linux/server"
    
    case "${FIVEM_VERSION}" in
        recommended|"")
            TARGET_VERSION=$(curl -sSL ${CHANGELOGS_API} | jq -r '.recommended')
            DOWNLOAD_LINK=$(curl -sSL ${CHANGELOGS_API} | jq -r '.recommended_download')
            ;;
        optional)
            TARGET_VERSION=$(curl -sSL ${CHANGELOGS_API} | jq -r '.optional')
            DOWNLOAD_LINK=$(curl -sSL ${CHANGELOGS_API} | jq -r '.optional_download')
            ;;
        latest)
            TARGET_VERSION=$(curl -sSL ${CHANGELOGS_API} | jq -r '.latest')
            DOWNLOAD_LINK=$(curl -sSL ${CHANGELOGS_API} | jq -r '.latest_download')
            ;;
        *)
            echo "[UPDATE] Specific version pinned: ${FIVEM_VERSION} - skipping auto-update"
            TARGET_VERSION="${FIVEM_VERSION}"
            DOWNLOAD_LINK=""
            ;;
    esac
    
    if [ "${CURRENT_VERSION}" != "${TARGET_VERSION}" ] && [ -n "${DOWNLOAD_LINK}" ]; then
        echo "[UPDATE] Update available: ${CURRENT_VERSION} -> ${TARGET_VERSION}"
        echo "[UPDATE] Creating backup..."
        mkdir -p backups
        BACKUP_DIR="backups/artifacts_${CURRENT_VERSION}_$(date +%Y%m%d_%H%M%S)"
        cp -r alpine "${BACKUP_DIR}" 2>/dev/null || true
        echo "[UPDATE] Downloading new artifact..."
        curl -sSL "${DOWNLOAD_LINK}" -o artifact.tar.xz --progress-bar
        echo "[UPDATE] Extracting..."
        tar xf artifact.tar.xz && rm -f artifact.tar.xz
        echo "[UPDATE] ✓ Updated to ${TARGET_VERSION}"
    else
        echo "[UPDATE] ✓ Already on target version"
    fi
fi

echo ""
echo "* Starting FXServer..."
echo "=================================================="
echo ""

# Build startup command
STARTUP_CMD="$(pwd)/alpine/opt/cfx-server/ld-musl-x86_64.so.1"
STARTUP_CMD="${STARTUP_CMD} --library-path \"$(pwd)/alpine/usr/lib/v8/:$(pwd)/alpine/lib/:$(pwd)/alpine/usr/lib/\""
STARTUP_CMD="${STARTUP_CMD} -- $(pwd)/alpine/opt/cfx-server/FXServer"
STARTUP_CMD="${STARTUP_CMD} +set citizen_dir $(pwd)/alpine/opt/cfx-server/citizen/"
STARTUP_CMD="${STARTUP_CMD} +set sv_licenseKey \"${CFX_LICENSE_KEY}\""
STARTUP_CMD="${STARTUP_CMD} +set steam_webApiKey \"${STEAM_API_KEY}\""
STARTUP_CMD="${STARTUP_CMD} +set sv_maxplayers ${MAX_PLAYERS}"
STARTUP_CMD="${STARTUP_CMD} +set sv_hostname \"${SERVER_HOSTNAME}\""
STARTUP_CMD="${STARTUP_CMD} +set serverProfile \"${TXADMIN_PROFILE}\""
STARTUP_CMD="${STARTUP_CMD} +set onesync ${ONESYNC_ENABLED}"
STARTUP_CMD="${STARTUP_CMD} +set sv_enforceGameBuild ${GAME_BUILD}"

# Add +exec server.cfg only if txAdmin is disabled
if [ "${TXADMIN_ENABLED}" != "1" ]; then
    STARTUP_CMD="${STARTUP_CMD} +exec server.cfg"
fi

# Execute the server
eval ${STARTUP_CMD}
