interface {{ .interface }} {
    # Enable sending router-advertisements
    AdvSendAdvert on;

    # Send router-advertisements when explicitly requested by an router solicitation as unicast
    AdvRASolicitedUnicast on;

    # The maximum interval between two unsolicited router advertisements
    MaxRtrAdvInterval {{ .max_ra_interval }};

    # The minimal interval between two unsolicited router advertisements
    MinRtrAdvInterval {{ .min_ra_interval }};

    # Enable the managed flag so the cpe sends a dhcpv6 prefix delegation request
    AdvManagedFlag on;

    # Advertise the maximum possible mtu for this access network
    # The mtu is reduced due to the use of network tunnels
    AdvLinkMTU {{ .mtu }};

    # Advertise an prefix in this router-advertisement
    prefix {{ .transfer_prefix }}/{{ .transfer_prefix_length }} {
        # Set the lifetime of the advertised prefix
        AdvValidLifetime 86400;
        AdvPreferredLifetime 14400;

        # When stopping radvd a router-advertisement with this prefix and a preferred lifetime of 0 is sent,
        # so all CPEs immediately deprecates the prefix.
        DeprecatePrefix on;

        # Enable the use of this prefix for stateless address autoconfiguration (SLAAC)
        AdvAutonomous on;
    };
};