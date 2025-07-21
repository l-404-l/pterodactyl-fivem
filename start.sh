#!/bin/bash

# ========== Color Setup ==========
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'
BLUE='\033[0;34m'
Text="${GREEN}[STARTUP]${NC}"

# ========== Install Required Packages ==========
echo -e "${Text} ${BLUE}Installing dependencies...${NC}"
apt update -y && apt install -y tar xz-utils curl git file jq unzip

# ========== Setup Directory ==========
mkdir -p /mnt/server
cd /mnt/server

# ========== Fetch Artifact Page ==========
RELEASE_PAGE=$(curl -sSL "https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/?$RANDOM")
CHANGELOGS_PAGE=$(curl -sSL https://changelogs-live.fivem.net/api/changelog/versions/linux/server)

# ========== Installation / Update Logic ==========
if [ ! -d "./alpine/" ] && [ ! -d "./resources/" ]; then
    echo -e "${Text} ${BLUE}Beginning installation of new FiveM server...${NC}"

    if [ "${FIVEM_VERSION}" == "latest" ] || [ -z ${FIVEM_VERSION} ]; then
        LATEST_ARTIFACT=$(echo -e "${RELEASE_PAGE}" | grep "LATEST OPTIONAL" -B1 | grep -Eo 'href=".*/*.tar.xz"' | grep -Eo '".*"' | sed 's/\"//g' | sed 's/\.\///1')
        DOWNLOAD_LINK="https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/${LATEST_ARTIFACT}"
    else
        VERSION_LINK=$(echo -e "${RELEASE_PAGE}" | grep -Eo 'href=".*/*.tar.xz"' | grep -Eo '".*"' | sed 's/\"//g' | sed 's/\.\///1' | grep ${FIVEM_VERSION})
        DOWNLOAD_LINK="https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/${FIVEM_VERSION}/fx.tar.xz"
    fi

    echo -e "${Text} ${BLUE}Downloading artifact...${NC}"
    curl -sSL ${DOWNLOAD_LINK} -o ${DOWNLOAD_LINK##*/}
    FILETYPE=$(file -F ',' ${DOWNLOAD_LINK##*/} | cut -d',' -f2 | cut -d' ' -f2)

    if [ "$FILETYPE" == "gzip" ]; then
        tar xzvf ${DOWNLOAD_LINK##*/}
    elif [ "$FILETYPE" == "Zip" ]; then
        unzip ${DOWNLOAD_LINK##*/}
    elif [ "$FILETYPE" == "XZ" ]; then
        tar xvf ${DOWNLOAD_LINK##*/}
    else
        echo -e "${RED}Unknown filetype. Exiting.${NC}"
        exit 2
    fi

    rm -rf ${DOWNLOAD_LINK##*/} run.sh

    if [ ! -e server.cfg ]; then
        echo -e "${Text} ${BLUE}Downloading default server.cfg...${NC}"
        curl -sSL https://raw.githubusercontent.com/darksaid98/pterodactyl-fivem-egg/master/server.cfg -o server.cfg
    fi

    if [ "${GIT_ENABLED}" == "1" ] && [ ! -d "./resources" ]; then
        if [[ ${GIT_REPOURL} != *.git ]]; then GIT_REPOURL=${GIT_REPOURL}.git; fi
        [ -n "${GIT_USERNAME}" ] && [ -n "${GIT_TOKEN}" ] && GIT_REPOURL="https://${GIT_USERNAME}:${GIT_TOKEN}@$(echo -e ${GIT_REPOURL} | cut -d/ -f3-)"

        echo -e "${Text} ${BLUE}Cloning resources from Git...${NC}"
        [ -z ${GIT_BRANCH} ] && git clone ${GIT_REPOURL} ./resources || git clone --single-branch --branch ${GIT_BRANCH} ${GIT_REPOURL} ./resources
    else
        echo -e "${Text} ${BLUE}Cloning default FiveM resources...${NC}"
        git clone https://github.com/citizenfx/cfx-server-data.git /tmp && cp -Rf /tmp/resources/* ./resources/
    fi

    mkdir -p logs/
    echo -e "${Text} ${BLUE}Installation complete.${NC}"
else
    echo -e "${Text} ${BLUE}Beginning update of existing FiveM server artifact...${NC}"
    rm -rf ./alpine/
    sleep 2

    if [ "${FIVEM_VERSION}" == "latest" ] || [ -z ${FIVEM_VERSION} ]; then
        LATEST_ARTIFACT=$(echo -e "${RELEASE_PAGE}" | grep "LATEST OPTIONAL" -B1 | grep -Eo 'href=".*/*.tar.xz"' | grep -Eo '".*"' | sed 's/\"//g' | sed 's/\.\///1')
        DOWNLOAD_LINK="https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/${LATEST_ARTIFACT}"
    else
        VERSION_LINK=$(echo -e "${RELEASE_PAGE}" | grep -Eo 'href=".*/*.tar.xz"' | grep -Eo '".*"' | sed 's/\"//g' | sed 's/\.\///1' | grep ${FIVEM_VERSION})
        DOWNLOAD_LINK="https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/${FIVEM_VERSION}/fx.tar.xz"
    fi

    curl -sSL ${DOWNLOAD_LINK} -o ${DOWNLOAD_LINK##*/}
    FILETYPE=$(file -F ',' ${DOWNLOAD_LINK##*/} | cut -d',' -f2 | cut -d' ' -f2)

    if [ "$FILETYPE" == "gzip" ]; then
        tar xzvf ${DOWNLOAD_LINK##*/}
    elif [ "$FILETYPE" == "Zip" ]; then
        unzip ${DOWNLOAD_LINK##*/}
    elif [ "$FILETYPE" == "XZ" ]; then
        tar xvf ${DOWNLOAD_LINK##*/}
    else
        echo -e "${RED}Unknown filetype. Exiting.${NC}"
        exit 2
    fi

    rm -rf ${DOWNLOAD_LINK##*/} run.sh
    echo -e "${Text} ${BLUE}Update complete.${NC}"
fi

# ========== Optional Auto Update ==========
if [[ "${AUTO_UPDATE}" == "1" ]]; then
    echo -e "${Text} ${BLUE}Auto update enabled. Fetching latest download link...${NC}"
    DOWNLOAD_LINK=$(echo $CHANGELOGS_PAGE | jq -r '.latest_download')

    rm -rf ./alpine
    curl -sSL ${DOWNLOAD_LINK} -o ${DOWNLOAD_LINK##*/}
    tar -xvf ${DOWNLOAD_LINK##*/}
    rm -rf ${DOWNLOAD_LINK##*/} run.sh

    echo -e "${Text} ${BLUE}CitizenFX resources updated successfully!${NC}"
else
    echo -e "${Text} ${BLUE}Auto update is disabled.${NC}"
fi

# ========== Launch Server ==========
echo -e "${Text} ${BLUE}Starting FiveM Server...${NC}"
export TXHOST_DATA_PATH=/mnt/server/txData
export TXHOST_MAX_SLOTS=${MAX_PLAYERS}
export TXHOST_TXA_PORT=${TXADMIN_PORT}
export TXHOST_FXS_PORT=${SERVER_PORT}
export TXHOST_DEFAULT_CFXKEY=${FIVEM_LICENSE}
export TXHOST_PROVIDER_NAME=${PROVIDER_NAME}
export TXHOST_PROVIDER_LOGO=${PROVIDER_LOGO}
export TXHOST_TXA_URL=${TXADMIN_URL}
export TXHOST_INTERFACE=${TXHOST_IP}

SERVER_BIN_PATH="/mnt/server/alpine/opt/cfx-server/FXServer"

if [ ! -f "$SERVER_BIN_PATH" ]; then
    echo -e "${RED}[ERROR] FiveM server binary not found at ${SERVER_BIN_PATH}${NC}"
    exit 1
fi

echo -e "${Text} ${BLUE}Running the FiveM server with txAdmin...${NC}"
$(pwd)/alpine/opt/cfx-server/ld-musl-x86_64.so.1 --library-path "$(pwd)/alpine/usr/lib/v8/:$(pwd)/alpine/lib/:$(pwd)/alpine/usr/lib/" -- $(pwd)/alpine/opt/cfx-server/FXServer +set citizen_dir $(pwd)/alpine/opt/cfx-server/citizen/ $( [ "$TXADMIN_ENABLE" == "1" ] || printf %s '+exec server.cfg' )
