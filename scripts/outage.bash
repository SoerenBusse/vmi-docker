#!/bin/bash
function DisableOutage() {
    echo "Removing blackhole route"
    ip -6 route delete blackhole default

    echo "Retrieving tunnel interface name"
    local wireguard_tunnel_name
    wireguard_tunnel_name=$(cat /run/wireguard-tunnel-name | head -n 1)

    echo "Adding default route"
    ip -6 route add default dev "${wireguard_tunnel_name}"
}

function EnableOutage() {
    echo "Removing default route"
    ip -6 route delete default

    echo "Adding blackhole route"
    ip -6 route add blackhole default
}

# Check if the user has passed a parameter
if [[ -z "${1}" ]]; then
    echo "Missing parameter ${0} <enable/disable>"
    exit 0
fi

# Check whether the outage should be enabled or disabled
if [[ "${1}" == "enable" ]]; then
    EnableOutage
elif [[ "${1}" == "disable" ]]; then
    DisableOutage
else
    echo "Invalid option: \"${1}\". Possible options are \"enable\" and \"disable\""
fi
