# Virtual Multihoming Infrastructure - Docker
This docker container emulates an IPv6-only access-network (BNG) of an internet provider for evaluation purposes.
The access-network connects to the internet using a wireguard tunnel.
It runs a DHCPv6-PD and a router-advertisement server to provide prefixes and addresses to CPEs which are connected to the physical interface.

If you start multiple instances of this docker-image with different wireguard tunnel endpoints you get multiple virtual internet connections to evaluate multihoming solutions.  

## Kernel requirements
Your kernel needs to support Wireguard. It's recommended to use kernel >= 5.6 to don't fiddle about dkms.

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
| WIREGUARD_ENDPOINT                | 192.0.2.42:51820            | The endpoint of your wireguard tunnel with port. Might be IPv4 or IPv6. Using domains isn't supported yet, because of https://lists.zx2c4.com/pipermail/wireguard/2021-August/006955.html                                   |
| ASSIGNED_PREFIX                   | 2001:db8:ffff:0::           | Prefix used for the transfer network between BNG and CPE                                                |
| SUBSCRIBER_INTERFACE              | enp2s0           | The subscriber interface where the virtual internet connection should be deployed                                  | 
