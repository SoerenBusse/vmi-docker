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
    # Prüfen wie viele Leases committet wurden
    local size=$LEASES6_SIZE

    # Wenn keine Leases vorhanden direkt beenden
    if [[ $size -eq 0 ]]; then
        return
    fi

    echo "Install committed lease route"

    # Ansonsten durch alle Leases iterieren und Routen hinzufügen
    # In der Regel sollte dies nur eine sein, da Keas nur ein Prefix pro Lease vergibt
    for ((i = 0; i < size; i++)); do
        # Variabelnamen erstellen
        local var_prefix_len="LEASES6_AT${i}_PREFIX_LEN"
        local var_address="LEASES6_AT${i}_ADDRESS"

        # Auf dynamische Variabeln per Indirection zugreifen
        ip route add "${!var_address}/${!var_prefix_len}" via "${QUERY6_REMOTE_ADDR}" dev "${QUERY6_IFACE_NAME}" >/dev/null 2>&1 || true
    done
}

function AddLeaseRoute() {
    echo "Add lease route"

    ip route add "${LEASE6_ADDRESS}/${LEASE6_PREFIX_LEN}" via "${QUERY6_REMOTE_ADDR}" dev "${QUERY6_IFACE_NAME}" >/dev/null 2>&1 || true
}

function DeleteRoute() {
    echo "Delete lease route"
    ip route del "${LEASE6_ADDRESS}/${LEASE6_PREFIX_LEN}" >/dev/null 2>&1 || true
}

echo "Kea-Routing-Hook: Got request: ${1}"

case "$1" in
"lease6_renew" | "lease6_rebind")
    AddLeaseRoute
    ;;
"leases6_committed")
    AddCommittedLeaseRoute
    ;;
"lease6_expire" | "lease6_release" | "lease6_decline")
    DeleteRoute
    ;;
esac
