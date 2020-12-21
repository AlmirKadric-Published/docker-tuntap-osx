#!/bin/bash

set -o nounset
set -o errexit

# Set home so docker doesn't moan
export HOME="${HOME:-/var/root}"

# Local and host tap interfaces
localTapInterface=tap1
hostTapInterface=eth1

# Local and host gateway addresses
localGateway='10.0.75.1/30'
hostGateway='10.0.75.2'
hostNetmask='255.255.255.252'

# Startup local and host tuntap interfaces
sudo ifconfig $localTapInterface $localGateway up
docker run --rm --privileged --net=host --pid=host alpine ifconfig $hostTapInterface $hostGateway netmask $hostNetmask up
