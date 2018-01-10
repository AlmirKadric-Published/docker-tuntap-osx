docker-tuntap-osx
=================
docker-tuntap-osx is a tuntap support shim installer for Docker for Mac.

The Problem
-----------
Current on Docker for Mac has no support for network routing into the Host Virtual Machine that is created using hyperkit. The reason for this is due to the fact that the network interface options used to create the instance does not create a bridge interface between the Physical Machine and the Host Virtual Machine. To make matters worse, the arguments used to create the Host Virtual Machine is hardcoded into the Docker for Mac binary with no means to configure it.

How it works
------------
This installer (`docker_tap_install.sh`) will move the original hyperkit binary (`hyperkit.original`) inside the Docker for Mac application and instead places our shim (`./sbin/docker.hyperkit.tuntap.sh`) in its stead. This shim will then inject the additional arguments required to attach a [TunTap](http://tuntaposx.sourceforge.net/) interface into the Host Virtual Machine, essentially creating a bridge interface between the guest and the host (this is essentially what hvint0 is on Docker for Windows).

From there the `up` script (`docker_tap_up.sh`) is used to bring the network interface up on both the Physical Machine and the Host Virtual Machine. Unlike the install script, which only needs to be run once, this `up` script must be run for every restart of the Host Virtual Machine.

Once done the IP address `10.0.75.2` can be used as a network routing gateway to reach any containers within the Host Virutal Machine:
```
route add -net <IP RANGE> -netmask <IP MASK> 10.0.75.2
```

**Note:** With later versions of Docker, you will need to setup IP Forwarding in the iptables defintion on the Host Virtual Machine:  
(This is not done by the helpers as this is not a OSX or tuntap specific issue. You would need to do the same for Docker for Windows, as such it should be handled outside the scope of this project.)
```
docker run --rm --privileged --pid=host debian nsenter -t 1 -m -u -n -i iptables -A FORWARD -i eth1 -j ACCEPT
```

Dependencies
------------
[Docker for Mac](https://www.docker.com/docker-mac)

[TunTap](http://tuntaposx.sourceforge.net/)
```
brew tap caskroom/cask
brew cask install tuntap
```

How to install it
-----------------
To install it, run the shim installer script. This will automatically check if the currently installed shim is the correct version and make a backup if necessary:
```
./sbin/docker_tap_install.sh
```

After this you will need to bring up the network interfaces every time the docker Host Virtual Machine is restarted:
```
./sbin/docker_tap_up.sh
```

How to remove it
----------------
Currently there is no uninstall script. However to remove the shim you simply need to move the original binary back to its original place:
```
mv /Applications/Docker.app/Contents/Resources/bin/hyperkit.original /Applications/Docker.app/Contents/Resources/bin/hyperkit
```

And remove any backup files that may have been generated:
```
rm /Applications/Docker.app/Contents/Resources/bin/hyperkit.<YYYYMMDD_HHMMSS>
```

License
-------
[MIT](https://github.com/AlmirKadric-Published/exTerm-electron/blob/master/LICENSE.md)

References & Credits
--------------------
 * A big thanks to `michaelhenkel` and [strayerror](https://github.com/mal) on the Docker forums for the inspiration and help to make this package
 * The original thread on the [Docker Forums](https://forums.docker.com/t/support-tap-interface-for-direct-container-access-incl-multi-host/17835)
