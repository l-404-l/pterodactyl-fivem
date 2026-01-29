FROM debian:bookworm-slim

LABEL author="Four" maintainer="https://github.com/l-404-l"
LABEL org.opencontainers.image.source="https://github.com/l-404-l/pterodactyl-fivem"
LABEL org.opencontainers.image.description="FiveM Pterodactyl Egg Docker Image with txAdmin Support"

# Environment
ENV DEBIAN_FRONTEND=noninteractive

# Install all dependencies for FiveM
RUN apt-get update && apt-get install -y --no-install-recommends \
    tar \
    xz-utils \
    curl \
    jq \
    git \
    file \
    tzdata \
    ca-certificates \
    locales \
    iproute2 \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Configure locale for proper character encoding
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

# Create Pterodactyl container user
RUN useradd -m -d /home/container -s /bin/bash container

# Set up the container user environment
USER container
ENV HOME=/home/container USER=container
WORKDIR /home/container

# Copy entrypoint script
COPY --chown=container:container entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/bin/bash", "/entrypoint.sh"]
