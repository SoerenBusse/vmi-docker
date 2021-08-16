#!/bin/bash
function ValidateHostNamespace() {
    # Check whether the bind mount for the host network namespace exists with the expected name
    [[ -f /var/run/netns/host ]]
}

function MountOwnNamespace() {
    mkdir -p /var/run/netns
    touch /var/run/netns/self
    mount --bind /proc/1/ns/net /var/run/netns/self
}

function EnableIPv6() {
    # We need to enable IPv6 manually inside the container
    # When creating a container with network=none ipv6 is disabled by default
    # See: https://github.com/moby/moby/issues/42748
    LogInfo "Enable IPv6"
    echo 0 >/proc/sys/net/ipv6/conf/all/disable_ipv6
}

function EnableForwarding() {
    # Enable forwarding for ipv4 and ipv6
    # The ipv4 settings are inherited from the main namespace, however not the ipv6 one
    LogInfo "Enable packet forwarding for IPv4 and IPv6"
    echo 1 >/proc/sys/net/ipv4/ip_forward
    echo 1 >/proc/sys/net/ipv6/conf/all/forwarding
}

function AddRoutes() {
    local interface_name
    interface_name="wg-${WIREGUARD_INTERFACE_SUFFIX}"

    # Add a default route to send all traffic inside the container through the wireguard tunnel
    LogInfo "Set default route to ${interface_name}"
    ip -6 route add default dev "${interface_name}"

    LogInfo "Set unreachable route to prevent route loop"
    ip -6 route add unreachable "${WIREGUARD_ASSIGNED_SUBNET}"
}

function SetupWireguard() {
    local interface_name
    interface_name="wg-${WIREGUARD_INTERFACE_SUFFIX}"

    LogInfo "Setup Wireguard tunnel" "${interface_name}"

    # Add interface to the birth-place network namespace
    # This is the place where the outer encrypted packets of the tunnel leaves the system towards the internet
    # The interface will then be moved inside the container, so that the inner packets leaves the tunnel inside the container
    LogInfo "Create wireguard interface in the host network namespace" "${interface_name}"
    ip netns exec host ip link add dev "${interface_name}" type wireguard

    LogInfo "Move the wireguard interface to the container's network namespace" "${interface_name}"
    ip netns exec host ip link set "${interface_name}" netns self

    LogInfo "Set MTU to ${WIREGUARD_MTU}" "${interface_name}"
    ip link set dev "${interface_name}" mtu "${WIREGUARD_MTU}"

    LogInfo "Assign IP ${WIREGUARD_ADDRESS}" "${interface_name}"
    ip address add dev "${interface_name}" "${WIREGUARD_ADDRESS}"

    LogInfo "Set wireguard configuration" "${interface_name}"
    LogInfo "Endpoint: ${WIREGUARD_ENDPOINT}" "${interface_name}"
    LogInfo "Peer: ${WIREGUARD_PEER}" "${interface_name}"

    # TODO: Support DNS for endpoint

    wg set "${interface_name}" \
        private-key <(GetSecretFromEnvironment WIREGUARD_PRIVATE_KEY) \
        peer "${WIREGUARD_PEER}" \
        endpoint "${WIREGUARD_ENDPOINT}" \
        persistent-keepalive 25 \
        allowed-ips ::/0

    LogInfo "Activate interface" "${interface_name}"
    ip link set dev "${interface_name}" up
}

function SetupTransferInterface() {
    local interface_name
    local transfer_interface_address

    interface_name="${TRANSFER_INTERFACE}"
    transfer_interface_address="${TRANSFER_PREFIX}1/${TRANSFER_PREFIX_LENGTH}"

    LogInfo "Setup transfer interface" "${interface_name}"

    # Check whether the real network interface exists on the host
    if ! ip netns exec host ip link show dev "${interface_name}" >/dev/null 2>&1; then
        LogError "Cannot find interface ${interface_name} on host network namespace" true
    fi

    # Move the real network interface into the docker namespace
    LogInfo "Move interface to docker namespace" "${interface_name}"
    ip netns exec host ip link set "${interface_name}" netns self

    LogInfo "Set address to ${transfer_interface_address}" "${interface_name}"
    ip address add dev "${interface_name}" "${transfer_interface_address}"

    LogInfo "Activate interface" "${interface_name}"
    ip link set dev "${interface_name}" up

    # We need to wait until the duplicate address detection has finished. This can be detected by checking if the interface
    # status changes from "tentative" to "forever". Without waiting binding sockets to the interface might fail.
    # Inspired by: https://salsa.debian.org/debian/ifupdown/-/blob/master/settle-dad.sh#L9
    LogInfo "Waiting for DAD to finish"
    while ip -o -6 address list dev "${interface_name}" | grep -q "tentative"; do
        sleep 0.5
    done
}

function SetupRouterAdvertisementConfiguration() {
    LogInfo "Generate radvd.conf using template"
    mkdir -p /opt/vmi/conf

    gucci \
        -s interface="${TRANSFER_INTERFACE}" \
        -s min_ra_interval="${ROUTER_ADVERTISEMENT_MIN_INTERVAL}" \
        -s max_ra_interval="${ROUTER_ADVERTISEMENT_MAX_INTERVAL}" \
        -s mtu="${WIREGUARD_MTU}" \
        -s transfer_prefix="${TRANSFER_PREFIX}" \
        -s transfer_prefix_length="${TRANSFER_PREFIX_LENGTH}" \
        -s debug="${DEBUG}" \
        /opt/vmi/templates/radvd.conf.tpl >/opt/vmi/conf/radvd.conf
}

function SetupKeaDHCPv6Configuration() {
    LogInfo "Generate kea-dhcp6.conf using template"
    mkdir -p /opt/vmi/conf

    gucci \
        -s interface="${TRANSFER_INTERFACE}" \
        -s prefix="${DHCPV6_PD_PREFIX}" \
        -s prefix_length="${DHCPV6_PD_PREFIX_LENGTH}" \
        -s delegation_length="${DHCPV6_PD_DELEGATION_LENGTH}" \
        -s nameserver="${DHCPV6_PD_NAMESERVER}" \
        -s debug="${DEBUG}" \
        /opt/vmi/templates/kea-dhcp6.conf.tpl >/opt/vmi/conf/kea-dhcp6.conf
}
