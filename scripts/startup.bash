#!/bin/bash
# See: https://stackoverflow.com/questions/35800082/how-to-trap-err-when-using-set-e-in-bash
set -eE

# Load all files from the scripts directory into the bash-interpreter-session
for file in /opt/vmi/scripts/include/*.bash; do
    source "${file}"
done

LogInfo "Validate environment variables"
ValidateEnvironmentVariables \
    WIREGUARD_INTERFACE_SUFFIX \
    WIREGUARD_PRIVATE_KEY \
    WIREGUARD_PEER \
    WIREGUARD_ADDRESS \
    WIREGUARD_ENDPOINT \
    WIREGUARD_MTU \
    WIREGUARD_ASSIGNED_SUBNET \
    ROUTER_ADVERTISEMENT_MAX_INTERVAL \
    ROUTER_ADVERTISEMENT_MIN_INTERVAL \
    TRANSFER_PREFIX \
    TRANSFER_PREFIX_LENGTH \
    TRANSFER_INTERFACE \
    DHCPV6_PD_PREFIX \
    DHCPV6_PD_PREFIX_LENGTH \
    DHCPV6_PD_DELEGATION_LENGTH \
    DHCPV6_PD_DELEGATION_LENGTH

# Optional parameters with default value
if [[ -n "${DEBUG}" ]]; then
    DEBUG="true"
    LogInfo "Enabling debug"
else
    DEBUG="false"
fi

EnableIPv6
EnableForwarding
ValidateHostNamespace
MountOwnNamespace
SetupWireguard
SaveWireguardInterfaceName
SetupTransferInterface
AddRoutes

SetupRouterAdvertisementConfiguration
SetupKeaDHCPv6Configuration

LogInfo "VMI startup completed"

# Forward process handling to supervisor
# exec replaces the current bash session with the supervisor daemon
exec supervisord --configuration /opt/vmi/conf/supervisor.conf
