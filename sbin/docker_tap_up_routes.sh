#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

log() {
  echo "$(date +%Y-%d-%mT%H:%M:%S) $1"
}

subnet_for() {
	local network=$1

	docker network inspect "$network" --format '{{(index .IPAM.Config 0).Subnet}}'
}

add_route_for() {
	local network=$1
	local subnet; subnet=$(subnet_for "$network")
	sudo route add -net "$subnet" 10.0.75.2
}

delete_route_for() {
	local network=$1
	local subnet; subnet=$(subnet_for "$network")
	echo sudo route delete "$subnet"
}

listen_to_network_events() {
	docker events --filter 'type=network' --format '{{.Action}} {{index .Actor.Attributes "type"}} {{.ID}}' | \
	while read -r event; do
		IFS=' ' read -r action type network <<< "$event"
		if [ "$type" = "bridge" ]; then
			"${action}_route_for" "$network"
		fi
	done
}

main() {

	listen_to_network_events &

  local networks; networks=$(docker network ls --filter driver=bridge --format '{{.ID}}')
  for network in $networks; do
  	add_route_for "$network"
	done
}

main "$@"
