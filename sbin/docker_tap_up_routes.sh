#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

subnet_for() {
	local network=$1

	docker network inspect "$network" --format '{{(index .IPAM.Config 0).Subnet}}'
}

add_route_for() {
	local network=$1
	local subnet; subnet=$(subnet_for "$network")
	sudo route add -net "$subnet" 10.0.75.2
}

add_routes_for_new_networks() {
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
