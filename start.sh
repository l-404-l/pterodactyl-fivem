#!/bin/bash
# Enhanced FiveM Startup Script with Artifact Switching
# Timezone support via TZ environment variable

## Color definitions for console output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

Text="${GREEN}[STARTUP]${NC}"
Info="${BLUE}[INFO]${NC}"
Warn="${YELLOW}[WARN]${NC}"
Error="${RED}[ERROR]${NC}"

echo -e "${Text} ${CYAN}========================================${NC}"
echo -e "${Text} ${CYAN}FiveM Server Startup${NC}"
echo -e "${Text} ${CYAN}========================================${NC}"

# Display current artifact information if available
if [ -f "/home/container/.artifact_version" ]; then
    CURRENT_INFO=$(cat /home/container/.artifact_version)
    echo -e "${Info} ${BLUE}Current installation:${NC}"
    echo -e "${Info} ${BLUE}${CURRENT_INFO}${NC}"
else
    echo -e "${Warn} ${YELLOW}No artifact version info found${NC}"
fi

# Display configuration
echo -e "${Info} ${BLUE}Configuration:${NC}"
echo -e "${Info} ${BLUE}- Artifact Type: ${ARTIFACT_TYPE:-recommended}${NC}"
echo -e "${Info} ${BLUE}- Auto Update: ${AUTO_UPDATE}${NC}"
echo -e "${Info} ${BLUE}- Timezone: ${TZ}${NC}"
echo -e "${Text} ${CYAN}========================================${NC}"

# Function to get download link based on artifact type
get_artifact_link() {
    local artifact_type=$1
    local changelogs=$2
    
    case "$artifact_type" in
        "recommended")
            echo $(echo $changelogs | jq -r '.recommended_download')
            ;;
        "optional")
            echo $(echo $changelogs | jq -r '.optional_download')
            ;;
        "latest")
            echo $(echo $changelogs | jq -r '.latest_download')
            ;;
        "critical")
            echo $(echo $changelogs | jq -r '.critical_download')
            ;;
        "specific")
            if [[ -n "${FIVEM_VERSION}" ]]; then
                RELEASE_PAGE=$(curl -sSL https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/)
                VERSION_LINK=$(echo -e "${RELEASE_PAGE}" | grep -Eo '"[^"]*\/[^"]*\.tar\.xz"' | grep -Eo '"[^"]*"' | sed 's/"//g' | sed 's/^\.\///' | grep "${FIVEM_VERSION}")
                if [[ -n "${VERSION_LINK}" ]]; then
                    echo "https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/${VERSION_LINK}"
                else
                    echo $(echo $changelogs | jq -r '.recommended_download')
                fi
            else
                echo $(echo $changelogs | jq -r '.recommended_download')
            fi
            ;;
        *)
            echo $(echo $changelogs | jq -r '.recommended_download')
            ;;
    esac
}

# Function to extract version from download link
get_artifact_version() {
    local download_link=$1
    echo $(basename $(dirname $download_link))
}

# Handle auto-update
if [[ "${AUTO_UPDATE}" == "1" ]]; then
    echo -e "${Text} ${BLUE}Auto-update enabled, checking for updates...${NC}"
    
    # Fetch latest artifact information
    CHANGELOGS_PAGE=$(curl -sSL https://changelogs-live.fivem.net/api/changelog/versions/linux/server 2>&1)
    
    if [ $? -ne 0 ]; then
        echo -e "${Error} ${RED}Failed to fetch artifact information, continuing with current version${NC}"
    else
        ARTIFACT_TYPE_USED=${ARTIFACT_TYPE:-recommended}
        DOWNLOAD_LINK=$(get_artifact_link "$ARTIFACT_TYPE_USED" "$CHANGELOGS_PAGE")
        NEW_VERSION=$(get_artifact_version "$DOWNLOAD_LINK")
        
        # Get current version
        CURRENT_VERSION=""
        if [ -f "/home/container/.artifact_version" ]; then
            CURRENT_VERSION=$(head -n 1 /home/container/.artifact_version)
        fi
        
        echo -e "${Info} ${BLUE}Artifact channel: ${ARTIFACT_TYPE_USED}${NC}"
        echo -e "${Info} ${BLUE}Current version: ${CURRENT_VERSION:-not set}${NC}"
        echo -e "${Info} ${BLUE}Latest version: ${NEW_VERSION}${NC}"
        
        # Compare versions and update if needed
        if [[ "$CURRENT_VERSION" != "$NEW_VERSION" ]] || [[ -z "$CURRENT_VERSION" ]]; then
            echo -e "${Text} ${YELLOW}Update available, downloading artifact ${NEW_VERSION}...${NC}"
            
            # Remove old installation
            if [ -d "/home/container/alpine" ]; then
                echo -e "${Info} ${BLUE}Removing old installation...${NC}"
                rm -rf /home/container/alpine
            fi
            
            # Download new artifact
            cd /home/container
            DOWNLOAD_FILE="${DOWNLOAD_LINK##*/}"
            
            echo -e "${Text} ${BLUE}Downloading from: ${DOWNLOAD_LINK}${NC}"
            curl -sSL "${DOWNLOAD_LINK}" -o "${DOWNLOAD_FILE}"
            
            if [ $? -eq 0 ]; then
                echo -e "${Text} ${BLUE}Extracting artifact...${NC}"
                tar -xf "${DOWNLOAD_FILE}" 2>&1
                
                if [ $? -eq 0 ]; then
                    rm -f "${DOWNLOAD_FILE}" run.sh
                    echo "${NEW_VERSION}" > /home/container/.artifact_version
                    echo "Artifact type: ${ARTIFACT_TYPE_USED}" >> /home/container/.artifact_version
                    echo -e "${Text} ${GREEN}Successfully updated to ${NEW_VERSION}!${NC}"
                else
                    echo -e "${Error} ${RED}Failed to extract artifact${NC}"
                    rm -f "${DOWNLOAD_FILE}"
                fi
            else
                echo -e "${Error} ${RED}Failed to download artifact${NC}"
            fi
        else
            echo -e "${Text} ${GREEN}Already running latest ${ARTIFACT_TYPE_USED} version${NC}"
        fi
    fi
else 
    echo -e "${Text} ${BLUE}Auto-update is disabled${NC}"
fi

# Display current artifact channel info
if command -v jq &> /dev/null; then
    CHANGELOGS_PAGE=$(curl -sSL https://changelogs-live.fivem.net/api/changelog/versions/linux/server 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo -e "${Text} ${CYAN}========================================${NC}"
        echo -e "${Text} ${CYAN}Available Artifact Channels:${NC}"
        RECOMMENDED=$(echo $CHANGELOGS_PAGE | jq -r '.recommended' 2>/dev/null)
        OPTIONAL=$(echo $CHANGELOGS_PAGE | jq -r '.optional' 2>/dev/null)
        LATEST=$(echo $CHANGELOGS_PAGE | jq -r '.latest' 2>/dev/null)
        CRITICAL=$(echo $CHANGELOGS_PAGE | jq -r '.critical' 2>/dev/null)
        
        [[ -n "$RECOMMENDED" ]] && echo -e "${Info} ${GREEN}Recommended: ${RECOMMENDED}${NC}"
        [[ -n "$OPTIONAL" ]] && echo -e "${Info} ${YELLOW}Optional: ${OPTIONAL}${NC}"
        [[ -n "$LATEST" ]] && echo -e "${Info} ${RED}Latest: ${LATEST}${NC}"
        [[ -n "$CRITICAL" ]] && echo -e "${Info} ${CYAN}Critical: ${CRITICAL}${NC}"
        echo -e "${Text} ${CYAN}========================================${NC}"
    fi
fi

echo -e "${Text} ${BLUE}Starting FiveM Server...${NC}"

# Export environment variables for txAdmin and FiveM server
export TXHOST_DATA_PATH=/home/container/txData
export TXHOST_MAX_SLOTS=${MAX_PLAYERS}
export TXHOST_TXA_PORT=${TXADMIN_PORT}
export TXHOST_FXS_PORT=${SERVER_PORT}
export TXHOST_DEFAULT_CFXKEY=${FIVEM_LICENSE}
export TXHOST_PROVIDER_NAME=${PROVIDER_NAME}
export TXHOST_PROVIDER_LOGO=${PROVIDER_LOGO}
export TXHOST_TXA_URL=${TXADMIN_URL}
export TXHOST_INTERFACE=${TXHOST_IP}

# Set the path to the FiveM server binary
SERVER_BIN_PATH="/home/container/alpine/opt/cfx-server/FXServer"

# Verify binary exists
if [ ! -f "$SERVER_BIN_PATH" ]; then
    echo -e "${Error} ${RED}========================================${NC}"
    echo -e "${Error} ${RED}FiveM server binary not found!${NC}"
    echo -e "${Error} ${RED}Expected location: ${SERVER_BIN_PATH}${NC}"
    echo -e "${Error} ${RED}========================================${NC}"
    echo -e "${Error} ${RED}Possible solutions:${NC}"
    echo -e "${Error} ${RED}1. Reinstall the server${NC}"
    echo -e "${Error} ${RED}2. Check artifact installation${NC}"
    echo -e "${Error} ${RED}3. Verify disk space${NC}"
    echo -e "${Error} ${RED}========================================${NC}"
    exit 1
fi

# Display final startup info
echo -e "${Text} ${GREEN}========================================${NC}"
echo -e "${Text} ${GREEN}Starting FiveM Server${NC}"
echo -e "${Info} ${BLUE}txAdmin: ${TXADMIN_ENABLE}${NC}"
echo -e "${Info} ${BLUE}Max Players: ${MAX_PLAYERS}${NC}"
echo -e "${Info} ${BLUE}Server Port: ${SERVER_PORT}${NC}"
echo -e "${Info} ${BLUE}txAdmin Port: ${TXADMIN_PORT}${NC}"
echo -e "${Text} ${GREEN}========================================${NC}"

# Execute the FiveM server
cd /home/container
exec $(pwd)/alpine/opt/cfx-server/ld-musl-x86_64.so.1 \
    --library-path "$(pwd)/alpine/usr/lib/v8/:$(pwd)/alpine/lib/:$(pwd)/alpine/usr/lib/" \
    -- $(pwd)/alpine/opt/cfx-server/FXServer \
    +set citizen_dir $(pwd)/alpine/opt/cfx-server/citizen/ \
    $( [ "$TXADMIN_ENABLE" == "1" ] || printf %s '+exec server.cfg' )
