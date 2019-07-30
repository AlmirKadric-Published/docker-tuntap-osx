#!/bin/bash

set -o nounset
set -o errexit

# Return tap interface to root
sudo chown root /dev/tap1

# Find docker hyperkit binary file
hyperkitPath=false
for possibleLocation in $(echo '
	/Applications/Docker.app/Contents/MacOS/com.docker.hyperkit
	/Applications/Docker.app/Contents/Resources/bin/com.docker.hyperkit
	/Applications/Docker.app/Contents/Resources/bin/hyperkit
'); do
	if [ -f "${possibleLocation}" ]; then
		hyperkitPath=${possibleLocation}
		break;
    elif [ -f "${HOME}${possibleLocation}" ]; then
		hyperkitPath=${HOME}${possibleLocation}
		break;
	fi
done

if [ "${hyperkitPath}" = false ]; then
	echo 'Could not find hyperkit executable' >&2
	exit 1
fi

# Restore the original hyperkit executable
if [ -f "${hyperkitPath}.original" ]; then
	mv "${hyperkitPath}.original" "${hyperkitPath}"
else
	echo 'The hyperkit original was not found' >&1
	exit 1
fi

# Remove backup files
if [ -e "${hyperkitPath}."* ]; then
	rm "${hyperkitPath}."*
fi

# Restarting docker
echo "Restarting Docker"
osascript -e 'quit app "Docker"'

open --background -a Docker
echo 'Process restarting, ready to go'
