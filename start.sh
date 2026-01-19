#!/bin/bash

## Make Colorful text for the console
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

Text="${GREEN}[STARTUP]${NC}"
Info="${BLUE}[INFO]${NC}"
Warn="${YELLOW}[WARN]${NC}"
Error="${RED}[ERROR]${NC}"

# Set timezone
if [ -n "$TZ" ]; then
    echo -e "${Text} ${CYAN}Setting timezone to: ${TZ}${NC}"
    export TZ=$TZ
    # Create symlink for timezone if it exists
    if [ -f "/usr/share/zoneinfo/$TZ" ]; then
        ln -snf "/usr/share/zoneinfo/$TZ" /etc/localtime
        echo "$TZ" > /etc/timezone
        echo -e "${Text} ${GREEN}Timezone set successfully!${NC}"
    else
        echo -e "${Warn} ${YELLOW}Timezone file not found, using system default${NC}"
    fi
fi

echo -e "${Text} ${CYAN}========================================${NC}"
echo -e "${Text} ${CYAN}FiveM Server Startup${NC}"
echo -e "${Text} ${CYAN}Artifact Type: ${ARTIFACT_TYPE:-recommended}${NC}"
echo -e "${Text} ${CYAN}Auto Update: ${AUTO_UPDATE}${NC}"
echo -e "${Text} ${CYAN}Timezone: ${TZ}${NC}"
echo -e "${Text} ${CYAN}========================================${NC}"

# Fetch changelogs for artifact information
CHANGELOGS_PAGE=$(curl -sSL https://changelogs-live.fivem.net/api/changelog/versions/linux/server)

# Function to get download link based on artifact type
get_artifact_link() {
    local artifact_type=$1
    case "$artifact_type" in
        "recommended")
            echo $(echo $CHANGELOGS_PAGE | jq -r '.recommended_download')
            ;;
        "optional")
            echo $(echo $CHANGELOGS_PAGE | jq -r '.optional_download')
            ;;
        "latest")
            echo $(echo $CHANGELOGS_PAGE | jq -r '.latest_download')
            ;;
        "critical")
            echo $(echo $CHANGELOGS_PAGE | jq -r '.critical_download')
            ;;
        "specific")
            if [[ -n "${FIVEM_VERSION}" ]]; then
                RELEASE_PAGE=$(curl -sSL https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/)
                VERSION_LINK=$(echo -e "${RELEASE_PAGE}" | grep -Eo '".*/*.tar.xz"' | grep -Eo '".*"' | sed 's/"//g' | sed 's/\.\///1' | grep ${FIVEM_VERSION})
                if [[ -n "${VERSION_LINK}" ]]; then
                    echo "https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/${VERSION_LINK}"
                else
                    echo $(echo $CHANGELOGS_PAGE | jq -r '.recommended_download')
                fi
            else
                echo $(echo $CHANGELOGS_PAGE | jq -r '.recommended_download')
            fi
            ;;
        *)
            echo $(echo $CHANGELOGS_PAGE | jq -r '.recommended_download')
            ;;
    esac
}

# Function to get artifact version from download link
get_artifact_version() {
    local download_link=$1
    echo $(basename $(dirname $download_link))
}

# Check current installed version
CURRENT_VERSION=""
if [ -f "/home/container/.artifact_version" ]; then
    CURRENT_VERSION=$(cat /home/container/.artifact_version)
    echo -e "${Info} ${BLUE}Currently installed artifact: ${CURRENT_VERSION}${NC}"
fi

# Handle auto-update
if [[ "${AUTO_UPDATE}" == "1" ]]; then
    echo -e "${Text} ${BLUE}Auto-update enabled, checking for updates...${NC}"
    
    # Determine which artifact to download
    ARTIFACT_TYPE_USED=${ARTIFACT_TYPE:-recommended}
    DOWNLOAD_LINK=$(get_artifact_link "$ARTIFACT_TYPE_USED")
    NEW_VERSION=$(get_artifact_version "$DOWNLOAD_LINK")
    
    echo -e "${Info} ${BLUE}Target artifact type: ${ARTIFACT_TYPE_USED}${NC}"
    echo -e "${Info} ${BLUE}Latest ${ARTIFACT_TYPE_USED} version: ${NEW_VERSION}${NC}"
    
    # Compare versions
    if [[ "$CURRENT_VERSION" != "$NEW_VERSION" ]]; then
        echo -e "${Text} ${YELLOW}Update available: ${CURRENT_VERSION} -> ${NEW_VERSION}${NC}"
        echo -e "${Text} ${BLUE}Downloading and installing update...${NC}"
        
        # Backup current alpine folder if it exists
        if [ -d "/home/container/alpine" ]; then
            echo -e "${Info} ${BLUE}Backing up current installation...${NC}"
            rm -rf /home/container/alpine.backup > /dev/null 2>&1
            mv /home/container/alpine /home/container/alpine.backup > /dev/null 2>&1
        fi
        
        # Download new artifact
        cd /home/container
        curl -sSL ${DOWNLOAD_LINK} -o ${DOWNLOAD_LINK##*/} > /dev/null 2>&1
        
        if [ $? -eq 0 ]; then
            echo -e "${Text} ${BLUE}Extracting artifact...${NC}"
            tar -xf ${DOWNLOAD_LINK##*/} > /dev/null 2>&1
            
            if [ $? -eq 0 ]; then
                rm -rf ${DOWNLOAD_LINK##*/} run.sh > /dev/null 2>&1
                echo "$NEW_VERSION" > /home/container/.artifact_version
                echo -e "${Text} ${GREEN}Successfully updated to artifact ${NEW_VERSION}!${NC}"
                
                # Remove backup on successful update
                rm -rf /home/container/alpine.backup > /dev/null 2>&1
            else
                echo -e "${Error} ${RED}Failed to extract artifact, restoring backup...${NC}"
                rm -rf /home/container/alpine > /dev/null 2>&1
                mv /home/container/alpine.backup /home/container/alpine > /dev/null 2>&1
            fi
        else
            echo -e "${Error} ${RED}Failed to download artifact, keeping current version${NC}"
            if [ -d "/home/container/alpine.backup" ]; then
                mv /home/container/alpine.backup /home/container/alpine > /dev/null 2>&1
            fi
        fi
    else
        echo -e "${Text} ${GREEN}Already running latest ${ARTIFACT_TYPE_USED} artifact (${CURRENT_VERSION})${NC}"
    fi
else 
    echo -e "${Text} ${BLUE}Auto-update is disabled${NC}"
    if [ -n "$CURRENT_VERSION" ]; then
        echo -e "${Info} ${BLUE}Running artifact version: ${CURRENT_VERSION}${NC}"
    fi
fi

# Display artifact information
echo -e "${Text} ${CYAN}========================================${NC}"
echo -e "${Text} ${CYAN}Artifact Information:${NC}"
case "${ARTIFACT_TYPE:-recommended}" in
    "recommended")
        CURRENT_REC=$(echo $CHANGELOGS_PAGE | jq -r '.recommended')
        echo -e "${Info} ${GREEN}Recommended: ${CURRENT_REC} (Stable, Production-Ready)${NC}"
        ;;
    "optional")
        CURRENT_OPT=$(echo $CHANGELOGS_PAGE | jq -r '.optional')
        echo -e "${Info} ${YELLOW}Optional: ${CURRENT_OPT} (Newer Features, May Have Minor Issues)${NC}"
        ;;
    "latest")
        CURRENT_LATEST=$(echo $CHANGELOGS_PAGE | jq -r '.latest')
        echo -e "${Info} ${RED}Latest: ${CURRENT_LATEST} (Bleeding-Edge, Use With Caution!)${NC}"
        ;;
    "critical")
        CURRENT_CRITICAL=$(echo $CHANGELOGS_PAGE | jq -r '.critical')
        echo -e "${Info} ${CYAN}Critical: ${CURRENT_CRITICAL}${NC}"
        ;;
    "specific")
        echo -e "${Info} ${CYAN}Specific Version: ${FIVEM_VERSION}${NC}"
        ;;
esac
echo -e "${Text} ${CYAN}========================================${NC}"

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

# Set the path to the correct binary location for the FiveM server
SERVER_BIN_PATH="/home/container/alpine/opt/cfx-server/FXServer"

# If the binary does not exist, print an error message
if [ ! -f "$SERVER_BIN_PATH" ]; then
    echo -e "${Error} ${RED}FiveM server binary not found at ${SERVER_BIN_PATH}${NC}"
    echo -e "${Error} ${RED}Please reinstall the server or check your artifact installation${NC}"
    exit 1
fi

# Execute the server with txAdmin enabled
echo -e "${Text} ${GREEN}Running the FiveM server...${NC}"
echo -e "${Text} ${CYAN}========================================${NC}"

$(pwd)/alpine/opt/cfx-server/ld-musl-x86_64.so.1 --library-path "$(pwd)/alpine/usr/lib/v8/:$(pwd)/alpine/lib/:$(pwd)/alpine/usr/lib/" -- $(pwd)/alpine/opt/cfx-server/FXServer +set citizen_dir $(pwd)/alpine/opt/cfx-server/citizen/ $( [ "$TXADMIN_ENABLE" == "1" ] || printf %s '+exec server.cfg' )
