#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

subnet_for() {
	local network=$1

  # I don't like pulling out the first config - what if there are more than one?
  # Can I iterate over them?
  # What if one doesn't have a Subnet value?
  # Are they all ipv4? What happens if it's ipv6?
	docker network inspect "$network" --format '{{(index .IPAM.Config 0).Subnet}}'
}

add_route_for() {
	local network=$1
	local subnet; subnet=$(subnet_for "$network")
	# I'd like this to only work if it would be on netif tap1, but don't know how...
	# Doesn't fail if route already exists
	sudo route add -net "$subnet" 10.0.75.2
}

add_routes_for_new_networks() {
	# TODO need to remove routes on 'event=destroy'
	# Because the network has been destroyed, `docker network inspect` will not work.
	# Options:
	# 1) Maintain state somewhere (ID to subnet) when we add the route, so that on event=destroy we can look up the subnet and remove the route
	# 2) Synchronize routes on each event - find all routes to tap1, find all bridge networks, add and delete as appropriate
	docker events --filter 'type=network' --filter 'event=create' --format '{{index .Actor.Attributes "type"}} {{.ID}}' | \
		while read -r event; do
			IFS=' ' read -r type network <<< "$event"
			if [ "$type" = "bridge" ]; then
				add_route_for "$network"
			fi
		done
}

main() {

	add_routes_for_new_networks &

  local networks; networks=$(docker network ls --filter driver=bridge --format '{{.ID}}')
  for network in $networks; do
  	add_route_for "$network"
	done
}

main "$@"
