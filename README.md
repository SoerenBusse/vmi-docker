# Virtual Multihoming Infrastructure - Docker
This docker container emulates an IPv6-only access-network (BNG) of an internet provider for evaluation purposes.
The access-network connects to the internet using a wireguard tunnel.
It runs a DHCPv6-PD and a router-advertisement server to provide prefixes and addresses to CPEs which are connected to the physical interface.

If you start multiple instances of this docker-image with different wireguard tunnel endpoints you get multiple virtual internet connections to evaluate multihoming solutions.  

## Kernel requirements
Your kernel needs to support Wireguard. It's recommended to use kernel >= 5.6 to don't fiddle about dkms.

## Configure Docker Daemon
You've to enable ipv6-support in the docker daemon. 
Otherwise the sysctl `disable_ipv6` is enabled, which will prevent any IPv6 setup inside the container.
This image doesn't use the default network bridge provided by docker, however the option `fixed-cidr-v6` is required so use whatever you like.

Edit `/etc/docker/daemon.json`
```json
{
    "ipv6": true,
    "fixed-cidr-v6": "fd00:ffff::/64"
}
```
Reload docker to activate the changes: `systemctl reload docker`

## Magic you better don't tell anybody
This docker container does something strange using network namespaces.
Wireguard supports to create a tunnel inside a birth-namespace (usually your docker-host) using the host's internet connection and move the wireguard interface, where the unencrypted packets leaving the tunnel inside the container. 
So the container doesn't need an internet connection using the docker linux bridge, because it gets an internet access through the tunnel.
https://www.wireguard.com/netns/#ordinary-containerization

However this must normally be done outside the container:
- Create the docker container
- Create the wireguard tunnel on the docker-host
- Move the wireguard interface to the network namespace of the docker-container

This isn't very comfortable for the user. Instead this container accesses the init-Namespace of the docker-host through a bind-volume, creates an wireguard tunnel there, and moves the interface afterwards from the init-namespace to it's own namespace.
This is the reason the container needs to run as privileged and need this strange bind mount. 

## Volumes
Mount the init-Namespace from the docker-host inside the docker-container where the `ip netns` expects it.

`/proc/1/ns/net:/var/run/netns/host`

## Environment-Variables
| Variable                          | Example value               | Description                                                                                             |
|-----------------------------------|-----------------------------|---------------------------------------------------------------------------------------------------------|
| WIREGUARD_INTERFACE_SUFFIX        | provider1                   | A suffix which should be attached to the wireguard interface name inside the container                  |
| WIREGUARD_PRIVATE_KEY             | <Base64 encoded key>        | Your own private key for the wireguard tunnel                                                           |
| WIREGUARD_PEER                    | <Base64 public encoded key> | A public key of the wireguard tunnel peer                                                               |
| WIREGUARD_ADDRESS                 | 2001:db8:0:0::2/64          | The ipv6 address inside the tunnel on your site (might be a transfer net)                               |
| WIREGUARD_ENDPOINT                | 192.0.2.42:51820            | The endpoint of your wireguard tunnel with port. Might be IPv4 or IPv6                                  |
| WIREGUARD_MTU                     | 1280                        | The mtu inside your wireguard-tunnel                                                                    |
| WIREGUARD_ASSIGNED_SUBNET         | 2001:db8:ffff:0::/48        | The ipv6 subnet which is routed over the wireguard tunnel. The dhcpv6-pd server delegates /56 from this |
| TRANSFER_PREFIX                   | 2001:db8:ffff:0::           | Prefix used for the transfer network between BNG and CPE                                                |
| TRANSFER_PREFIX_LENGTH            | 64                          | Prefix length for the transfer network                                                                  |
| ROUTER_ADVERTISEMENT_MAX_INTERVAL | 600                         | Max interval between two router advertisements                                                          |
| ROUTER_ADVERTISEMENT_MIN_INTERVAL | 300                         | Min interval between two router advertisements                                                          |
| DHCPV6_PD_PREFIX                  | 2001:db8:ffff:8000::        | Prefix from which the smaller DHCPv6 prefixes are delegateed                                            |
| DHCPV6_PD_PREFIX_LENGTH           | 49                          | Prefix length of the DHCPV6_PD_PREFIX                                                                   |
| DHCPV6_PD_DELEGATION_LENGTH       | 56                          | Prefix length which should be delegated to the CPE                                                      |
| DHCPV6_PD_NAMESERVER              | 2001:4860:4860::8888        | DNS server which should be assigned to the CPE using DHCPv6                                             |
