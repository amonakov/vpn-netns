#!/bin/bash

# Guess the outgoing interface from default route
: ${natiface=$(ip route show to 0/0 |
	       sed -n '/^default/{s/.* dev \([^ ]*\).*/\1/p;q}')}

# Spawn or attach to a tmux server running in the network namespace
attach()
{
  name=${1-vpn}
  if [ $UID -ne 0 ]; then
    exec tmux -L $name attach
  else
    exec ip netns exec $name su -c "exec tmux -L $name new -A" $SUDO_USER
  fi
}

# Set up a network namespace
start()
{
  name=${1-vpn}
  addrbase=${2-192.168.99}

  # Create a virtual ethernet pair device to let the namespace reach us
  ip link add $name.1 type veth peer name $name.2

  # Set up our end of the veth device
  ip addr add $addrbase.1 peer $addrbase.2 dev $name.1
  ip link set $name.1 up

  # Basic NAT
  iptables -t nat -A POSTROUTING -s $addrbase.2 -o $natiface -j MASQUERADE

  # Create custom resolv.conf for the namespace
  mkdir -p /etc/netns/$name
  sed /127.0.0.1/d </etc/resolv.conf >/etc/netns/$name/resolv.conf

  # Create the namespace itself
  ip netns add $name

  # Hand off the other end of the veth device to the namespace
  ip link set $name.2 netns $name

  # Set up networking in the namespace
  ip netns exec $name bash -c "
    ip addr add $addrbase.2 peer $addrbase.1 dev $name.2
    ip link set $name.2 up
    ip route add default via $addrbase.1
    ip link set lo up"

  # Create a tmux session in the namespace and attach to it
  attach $1
}

# Tear down a previously created network namespace
stop()
{
  name=${1-vpn}
  addrbase=$(ip addr show $name.1 |
    sed -n 's/.*inet \([0-9]*\.[0-9]*\.[0-9]*\).*/\1/p')
  pids=$(ip netns pids $name)

  # Refuse further operation if some processes are still running there
  if [ -n "$pids" ]; then
    echo "namespace still in use by:"
    ps $pids
    exit 1
  fi

  ip link del $name.1
  iptables -t nat -D POSTROUTING -s $addrbase.2 -o $natiface -j MASQUERADE
  ip netns del $name
}

command="$1"
shift

case "$command" in
  "start" | "stop" | "attach")
    "$command" "$@"
    ;;
  *)
    echo "usage: $0 {start | stop | attach} [vpn-name] [vpn-addr-base]"
esac
