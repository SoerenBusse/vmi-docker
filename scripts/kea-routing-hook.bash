#!/bin/bash
# Siehe: https://kea.readthedocs.io/en/latest/arm/hooks.html#run-script-support
# Dieses Skript verarbeitet DHCPv6-PD Hooks von Kea und trägt die entsprechenden
# Routing-Informationen in die Routing-Tabelle ein
# Die Hooks werden in drei Kategorien eingeteilt
# 1. Hinzufügen einer Route in die Routing Tabelle
# - lease6_renew
# - lease6_rebind
# - leases6_committed
# 2. Entfernen einer Route aus der Routing Tabelle
# - lease6_expire
# - lease6_release
# - lease6_decline
# 3. Nichts tun, da irrelevant für die Routen
# - lease6_recover, da fehlen die Infos von welcher Source die kommen

function AddCommittedLeaseRoute() {
    # Check whether it's a DHCPv6-Solicication or a DHCPv6-Request and the Lease-Type ist IA_PD
    # else cancel the hook-script
    printenv

    if [[ $QUERY6_TYPE != "REQUEST" && $QUERY6_TYPE != "SOLICIT" ]]; then
      return
    fi

    if [[ $LEASES6_AT0_TYPE != "IA_PD" ]]; then
      return
    fi

    echo "Install committed lease route"

    ip route add "${LEASES6_AT0_ADDRESS}/${LEASES6_AT0_PREFIX_LEN}" via "${QUERY6_REMOTE_ADDR}" dev "${QUERY6_IFACE_NAME}" >/dev/null 2>&1
}

function AddLeaseRoute() {
    echo "Add lease route"

    ip route add "${LEASE6_ADDRESS}/${LEASE6_PREFIX_LEN}" via "${QUERY6_REMOTE_ADDR}" dev "${QUERY6_IFACE_NAME}" >/dev/null 2>&1
}

function DeleteRoute() {
    echo "Delete lease route"
    ip route del "${LEASE6_ADDRESS}/${LEASE6_PREFIX_LEN}" >/dev/null 2>&1
}

echo "Kea-Routing-Hook: Got request: ${1}"

case "$1" in
"lease6_renew" | "lease6_rebind")
    AddLeaseRoute
    ;;
"leases6_committed")
    AddCommittedLeaseRoute
    ;;
"lease6_expire" | "lease6_release")
    DeleteRoute
    ;;
esac
