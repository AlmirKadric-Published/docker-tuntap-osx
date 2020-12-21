#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

log() {
  echo "$(date +%Y-%d-%mT%H:%M:%S) $1"
}

subnet_for() {
	local network=$1

  # I don't like pulling out the first config - what if there are more than one?
  # Can I iterate over them?
  # What if one doesn't have a Subnet value?
  # Are they all ipv4? What happens if it's ipv6?
	docker network inspect "$network" --format '{{(index .IPAM.Config 0).Subnet}}'
}

tap1_exists() {
	ifconfig -r tap1 2> /dev/null | grep 10.0.75.1 > /dev/null
}

add_route_for() {
	local subnet=$1
	if tap1_exists; then
		# Doesn't fail if route already exists
		sudo route add -net "$subnet" 10.0.75.2
	else
		log "Not adding a route for $network because tap1 interface does not exist"
	fi
}


get_all_networks() {
	docker network ls \
	  --filter 'driver=bridge' \
	  --format '{{.ID}}'
}

get_all_docker_network_subnets() {
	local docker_networks; docker_networks=$(get_all_networks)
	for network in $docker_networks; do
  	subnet_for "$network"
	done
}

to_full_subnet() {
	local subnet=$1
	local periods; periods=$(set +e; grep -o '\.' <<< "$subnet" | wc -l | tr -d ' '; set -e)
		if [ "$periods" -eq 0 ]; then
			echo "$subnet.0.0.0/32"
		elif [ "$periods" -eq 1 ]; then
			echo "$subnet.0.0/16"
		elif [ "$periods" -eq 2 ]; then
			echo "$subnet.0/8"
		else
			echo "$subnet"
		fi
}

get_existing_routes() {
	local route_subnets; route_subnets=$(netstat -nr -f inet | grep tap1 | grep 10.0.75.2 | cut -d' ' -f1)
	for route_subnet in $route_subnets; do
	  to_full_subnet "$route_subnet"
	done
}

is_subnet_of_docker_network() {
	local docker_subnets=$1
	local existing_route=$2
	echo "$docker_subnets" | grep "$existing_route" 1>/dev/null
}

find_routes_to_delete() {
	local existing_routes=$1
	local docker_subnets=$2
	for existing_route in $existing_routes; do
  	if ! is_subnet_of_docker_network "$docker_subnets" "$existing_route"; then
  		echo "$existing_route"
		fi
	done
}

is_subnet_of_route() {
	local existing_routes=$1
	local docker_subnet=$2
	echo "$existing_routes" | grep "$docker_subnet" 1>/dev/null
}

find_routes_to_add() {
	local existing_routes=$1
	local docker_subnets=$2
	for docker_subnet in $docker_subnets; do
  	if ! is_subnet_of_route "$existing_routes" "$docker_subnet"; then
  		echo "$docker_subnet"
		fi
	done
}

delete_unused_routes() {
	local docker_subnets=$1
  local existing_routes=$2

  local routes_to_delete; routes_to_delete=$(find_routes_to_delete "$existing_routes" "$docker_subnets")
  for route_to_delete in $routes_to_delete; do
  	sudo route rm "$route_to_delete"
	done
}

add_missing_routes() {
	local docker_subnets=$1
  local existing_routes=$2

	local routes_to_add; routes_to_add=$(find_routes_to_add "$existing_routes" "$docker_subnets")
  for route_to_add in $routes_to_add; do
  	add_route_for "$route_to_add"
	done
}

update_routes_as_networks_change() {
	docker events \
	  --filter 'type=network' \
	  --format '{{.Action}} {{index .Actor.Attributes "type"}} {{.Actor.ID}}' \
		  | while read -r event; do
					IFS=' ' read -r action type network <<< "$event"
					if [ "$type" = 'bridge' ]; then
						if [ "$action" = 'create' ]; then
							local subnet; subnet=$(subnet_for "$network")
							add_route_for "$subnet"
						elif [ "$action" = 'destroy' ]; then
							delete_unused_routes "$(get_all_docker_network_subnets)" "$(get_existing_routes)"
						else
							log "Skipping action [$action] for network [$network] of type [$type] - we only react to create and destroy actions"
						fi
					else
						log "Skipping action [$action] for network [$network] of type [$type] - we only create routes for bridge networks"
					fi
				done
}

synchronize_networks() {
	local docker_subnets; docker_subnets=$(get_all_docker_network_subnets)
  local existing_routes; existing_routes=$(get_existing_routes)

  delete_unused_routes "$docker_subnets" "$existing_routes"
  add_missing_routes "$docker_subnets" "$existing_routes"
}

main() {
	update_routes_as_networks_change &
  synchronize_networks
}

main "$@"
