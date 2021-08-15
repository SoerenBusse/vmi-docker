{
  "Dhcp6": {
    // Interface where the dhcpv6 server should receive packets
    "interfaces-config": {
      "interfaces": [
        "{{ .interface }}"
      ]
    },
    // Use an in-memory database with persistence to disk for dhcpv6-leases.
    // The server removes old entries that are no longer valid every "lfc-interval" seconds from the lease-file
    "lease-database": {
      "type": "memfile",
      "persist": true,
      "name": "/var/lib/kea/dhcp6.leases",
      "lfc-interval": 1800
    },
    "expired-leases-processing": {
      // The assigned address/prefix is reserved for "hold-reclaimed-time" seconds, in which the client must do another
      // request to get the same prefix/address again. When a client is shutdown and turned on again later and the
      // time difference is in "hold-reclaimed-time" it will get the same prefix, otherwise it will get another one
      // Because this is a test environment we set a high value, so if the CPEs still get their old prefix, altough
      // they might be shutdown for some days
      "hold-reclaimed-time": 432000
    },
    // Time until the client should send a DHCPv6 renew
    // When the docker-container is restarted all installed routed using the hooks are discarded, so the devices behind the CPEs
    // using the delegated prefix cannot reach the internet anymore. Because of this we're using a short renew-interval
    // so the CPE sends a renew and the route will be installed without much downtime
    "renew-timer": 600,
    // Time interval when the client should send a rebind-request, when it doesn't get an answer to the renew-request
    // The rebind request will be send to all dhcpv6-servers on the network
    "rebind-timer": 2700,
    // The preferred lifetime of the DHCPv6 lease
    // It must be longer than the renew/rebind timer
    "preferred-lifetime": 3600,
    // The valid lifetime of the DHCPv6 lease
    // When expired all delegated prefixes and assigned addresses are marked as deprecated and aren't used anymore
    "valid-lifetime": 4500,

    "subnet6": [
      {
        // The prefix from which all shorter prefixes are delegated
        "subnet": "{{ .prefix }}/{{ .prefix_length }}",

        // Assign this subnet6 configuration an interface
        // If the server is listening on the link-local-address and receives a dhcpv6 message it cannot determine
        // which GUA subnet from the configuration to select. When setting an interface here, the server knows that this
        // GUA subnet is meant when receiving dhcpv6 messages on this interface.
        "interface": "{{ .interface }}",
        "pd-pools": [
          {
            "prefix": "{{ .prefix }}",
            "prefix-len": {{ .prefix_length }},
            "delegated-len": {{ .delegation_length }}
          }
        ],
        // Add additional options to the DHCPv6-server
        "option-data": [
          {
            "name": "dns-servers",
            "data": "{{ .nameserver }}"
          }
        ]
      }
    ],
    // Hooks hinzufügen
    "hooks-libraries": [
        // Run a hook-script when receiving dhcpv6-messages to install routes for the delegated prefix
        {
            "library": "/usr/lib/x86_64-linux-gnu/kea/hooks/libdhcp_run_script.so",
            "parameters": {
                "name": "/opt/vmi/scripts/kea-routing-hook.bash",
                "sync": true
            }
        }
    ],
    "loggers": [
      {
        // Print the log to stdout so supervisorctl shows it in the docker-console
        "name": "kea-dhcp6",
        "output_options": [
          {
            "output": "stdout",
            "pattern": "%-5p %m\n"
          }
        ],

        {{ if eq .debug "true" }}
        // Set log level to debug if requested by user
        "severity": "DEBUG",
        "debuglevel": 10
        {{ else }}
        "severity": "INFO"
        {{ end }}
      }
    ]
  }
}