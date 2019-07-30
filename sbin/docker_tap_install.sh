#!/bin/bash

set -o nounset
set -o errexit

# Folder where this install script resides
SCRIPT_DIR=$(cd $(dirname ${BASH_SOURCE}) && pwd)

# Make sure tap interface we will bind to hyperkit VM is owned by us
tapintf=tap1
sudo chown ${USER} /dev/tap1

# Make sure shim script we will install exists
shimPath="${SCRIPT_DIR}/docker.hyperkit.tuntap.sh"
if [ ! -f "${shimPath}" ]; then
	echo 'Could not find shim script "docker.hyperkit.tuntap.sh"'
	exit 1
fi

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

# Check if we have already been installed with the current version
if file "${hyperkitPath}" | grep -Eiq '(Bourne-Again shell script|text executable|ASCII text)'; then
	if cmp -s "${shimPath}" "${hyperkitPath}"; then
		if [ -x "${hyperkitPath}" ]; then
			echo 'Already installed';
			if ! echo $@ | grep -q '\-f'; then
				echo 'Use "-f" argument if you want to restart hyperkit anyway'
				exit 0
			fi
		else
			chmod +x "${hyperkitPath}"
		fi
	else
		timestamp=$(date +%Y%m%d_%H%M%S)
		mv "${hyperkitPath}" "${hyperkitPath}.${timestamp}"
		cp "${shimPath}" "${hyperkitPath}"
		chmod +x "${hyperkitPath}"
		echo 'Updated existing installation'
	fi
elif file "${hyperkitPath}" | grep -q 'Mach-O.*executable'; then
	mv "${hyperkitPath}" "${hyperkitPath}.original"
	cp "${shimPath}" "${hyperkitPath}"
	chmod +x "${hyperkitPath}"
	echo 'Installation complete'
else
	echo 'The hyperkit executable file was of an unknown type' >&1
	exit 1
fi

# Restarting docker
echo "Restarting Docker"
osascript -e 'quit app "Docker"'

open --background -a Docker
echo 'Process restarting, ready to go'
