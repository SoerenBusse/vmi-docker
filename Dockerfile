# Use the newest debian-sid as base-image, because the sid already includes wireguard-tools in their repository
FROM ubuntu:focal-20210713

# Install needed tools
# iproute2 - provides all ip-related commands to manage interfaces and network namespaces
# iputils-ping - provides the ping command for debugging purposes
# radvd - server for sending router-advertisements
# supervisor - process management tool
# mtr-tiny, net-tools, tcpdump - some network debugging tools
# wireguard-tools - provides the wg-command to interact with the wireguard kernel module, installed without
# receommended-dependencies to prevent kernel installation in docker-container
RUN apt-get update && \
    apt-get install -y iproute2 iputils-ping radvd supervisor mtr-tiny net-tools tcpdump && \
    apt-get install -y --no-install-recommends wireguard-tools && \
    rm -rf /var/lib/apt/lists/*

# Install kea-dhcp-server from third-party repository
RUN apt-get update && \
    apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl && \
    curl -1sLf "https://dl.cloudsmith.io/public/isc/kea-1-9/gpg.5DC67B0A74E30739.key" | apt-key add - && \
    curl -1sLf "https://dl.cloudsmith.io/public/isc/kea-1-9/config.deb.txt?distro=ubuntu&codename=focal" > /etc/apt/sources.list.d/isc-kea-1-9.list && \
    apt-get update && \
    apt-get install -y isc-kea-dhcp6-server

# Copy supervisor configuration
COPY config /opt/vmi/conf

# Install template engine gucci
RUN curl -L https://github.com/noqcks/gucci/releases/download/1.4.0/gucci-v1.3.0-linux-amd64 -o /usr/local/bin/gucci && \
    chmod +x /usr/local/bin/gucci

# Copy all templates into the image
COPY templates /opt/vmi/templates

# Copy all scripts into the image
COPY scripts /opt/vmi/scripts

# Make all scripts in top-level-directory executable
RUN chmod +x /opt/vmi/scripts/*.bash

# Set the startup-script as entrypoint
ENTRYPOINT ["/opt/vmi/scripts/startup.bash"]



