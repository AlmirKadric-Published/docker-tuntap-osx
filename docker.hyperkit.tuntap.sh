#!/bin/bash

set -o nounset
set -o errexit

# Tap interface to bind to hyperkit VM
tapintf=tap1

# Find index and id of highest network interface argument
ethILast=false
ethIDLast=false

argI=0
while [ $argI -lt $# ]; do
	arg=${@:$argI:1}

	# Find device arguments
	if [ "$arg" == "-s" ]; then
		argDeviceI=$(($argI + 1))
		argDevice=${@:$argDeviceI:1}

		# Check if device argument is a network device
		if echo $argDevice | grep -qE "^2:[0-9]+"; then
			# Finally check if network interface ID is higher than current highest
			# If so update highest
			ethID=$(echo $argDevice | sed -E 's/2:([0-9]+),.*/\1/')
			if [ $ethIDLast = false ] || [ $ethID  -gt $ethIDLast ]; then
				ethILast=$argDeviceI
				ethIDLast=$ethID
			fi
		fi

		# Skip device argument since we already processed it
		argI=$(($argI + 1))
	fi

	argI=$(($argI + 1))
done

# Make sure we found network interfaces
# If not something went wrong
if [ $ethILast = false ] || [ $ethIDLast = false ]; then
	echo "Network interface arguments not found" >&2
	exit 1
fi

# Inject additional tap network interface argument after the highest one
ethintf=$(($ethIDLast + 1))
set -- \
	"${@:1:$ethILast}" \
	"-s" "2:$ethintf,virtio-tap,$tapintf" \
	"${@:$(($ethILast + 1))}"

# Execute real binary with modified argument list
exec $0.original "$@"
