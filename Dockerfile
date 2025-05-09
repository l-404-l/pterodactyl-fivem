FROM debian:bookworm-slim

LABEL org.opencontainers.image.source https://github.com/l-404-l/pterodactyl-fivem

ENV USER=container HOME=/home/container TZ=America/Chicago

RUN apt-get update && apt upgrade -y && apt-get install -y \
    build-essential \
    curl \
    git \
    libssl-dev \
    pkg-config \
    tar \
    jq \
    procps \
    liblua5.3-0 \
    libz-dev \
    tzdata \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone && \
    dpkg-reconfigure -f noninteractive tzdata && \
    rm -rf /var/lib/apt/lists/*


RUN useradd -m -d /home/container container

USER        container
WORKDIR     /home/container

COPY        ./entrypoint.sh /entrypoint.sh
COPY        --chmod=777 ./start.sh /start.sh
CMD         [ "/bin/bash", "/entrypoint.sh" ]
