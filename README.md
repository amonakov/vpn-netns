vpn-netns
=========

Linux network namespaces allow isolation of network configuration on a
per-process basis.  This is useful when running a VPN client:

  - you can run the VPN client in a network namespace so that it does not
    interfere with your network configuration (does not overwrite routes or
    /etc/resolv.conf);
  - you can let the VPN client set default route via the VPN tunnel and have
    the applications spawned inside the namespace use the VPN by default;
    applications outside the namespace do not see the VPN tunnel at all;
  - you can set up two namespaced VPN connections simultaneously even if they
    provide access to networks with overlapping IP address ranges.

This script handles basic bring up of a network namespace and gives you a tmux
session in the network namespace.  You can then start your VPN client and
other applications from there.

Requirements: kernel with network namespace support (CONFIG_NET_NS=y),
iproute2, iptables, tmux.

The namespace is connected to the host with a veth (virtual ethernet pair)
device, and the host provides access to the outside network for the namespace
via NAT.

To start:

    sudo ./vpn.sh start vpn 192.168.99

The first argument names the network namespace; veth interfaces' names are
derived from that by adding suffixes '.1' for the host and '.2' for the
namespace.  The second argument gives the local IP prefix for the veth
connection.

You reattach to the tmux server running in the namespace:

    ./vpn.sh attach vpn

To remove the network namespace, veth interface and NAT rule:

    sudo ./vpn.sh stop vpn

The name and IP prefix arguments can be omitted, in which case the default
values are implicitely substituted.
