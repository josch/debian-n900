#!/bin/sh -e

ROOTDIR="n900-chroot"

PACKAGES="ifupdown,openssh-server,udev,procps,netbase,vim,console-setup-mini,man-db,iproute"
PACKAGES="$PACKAGES,module-init-tools,wget,openssh-client,locales,sysklogd,klogd,input-utils,dnsutils"
PACKAGES="$PACKAGES,alsa-base,ntpdate,debconf-english,screen,less,console-tools,iputils-ping,vpnc,rsync"
PACKAGES="$PACKAGES,i2c-tools,watchdog"
cdebootstrap --flavour=minimal --include=$PACKAGES sid "$ROOTDIR"

#cp -a /lib/modules/2.6.28-omap1/ "$ROOTDIR/lib/modules/"
#cp -a /lib/firmware/* "$ROOTDIR/lib/firmware/"
#curl http://my.arava.co.il/~matan/770/n900/power_supply.ko > $ROOTDIR/lib/modules/2.6.28-omap1/power_supply.ko
#curl http://my.arava.co.il/~matan/770/n900/bq27x00_battery.ko > $ROOTDIR/lib/modules/2.6.28-omap1/bq27x00_battery.ko
curl http://mister-muffin.de/n900/modules-2.6.28-omap1.tar.gz | chroot $ROOTDIR tar -C /lib/modules/ -xzf -
curl http://mister-muffin.de/n900/firmware.tar.gz | chroot $ROOTDIR tar -C /lib/ -xzf -

sed -i 's/\(PermitEmptyPasswords\) no/\1 yes/' $ROOTDIR/etc/ssh/sshd_config
sed -i 's/\(root:\)[^:]*\(:\)/\1\/\/plGAV7Hp3Zo\2/' $ROOTDIR/etc/shadow

chroot $ROOTDIR useradd user -p //plGAV7Hp3Zo -s /bin/bash --create-home

cat > $ROOTDIR/etc/watchdog.conf << __EOF__
watchdog-device     = /dev/twl4030_wdt
interval            = 10
realtime            = yes
priority            = 1
__EOF__

sed -i "s/\(FSCKFIX=\)no/\1yes/" $ROOTDIR/etc/default/rcS

chroot $ROOTDIR apt-get update

chroot $ROOTDIR apt-get install xserver-xorg-video-omap3 xserver-xorg-input-evdev xserver-xorg-input-tslib libts-bin nodm

cat > $ROOTDIR/etc/default/nodm << __END__
NODM_ENABLED=true
NODM_USER=user
NODM_XINIT=/usr/bin/xinit
NODM_FIRST_VT=0
NODM_XSESSION=/etc/X11/Xsession
NODM_X_OPTIONS='-nolisten tcp'
NODM_MIN_SESSION_TIME=60
__END__

cat > $ROOTDIR/etc/X11/xorg.conf << __EOF__
Section "Monitor"
	Identifier "Configured Monitor"
EndSection

Section "Screen"
	Identifier "Default Screen"
	Device "Configured Video Device"
EndSection

Section "Device"
	Identifier "Configured Video Device"
	Driver "omapfb"
	Option "fb" "/dev/fb0"
EndSection

# this is only needed when using the maemo kernel
Section "InputClass"
	Identifier	"Keyboard"
	MatchProduct	"omap_twl4030keypad"
	MatchDevicePath	"/dev/input/event*"
	Option		"XkbModel"	"nokiarx51"
	Option		"XkbLayout"	"de"
EndSection
__EOF__

cat > $ROOTDIR/etc/network/interfaces << __EOF__
auto lo
iface lo inet loopback

# usb
auto usb0
iface usb0 inet static
	address 192.168.2.2
	network 192.168.2.0
	netmask 255.255.255.0
	broadcast 192.168.2.255
	gateway 192.168.2.1
	dns-nameservers 192.168.2.1
	dns-search universe

# disable automatic stuff for other devices (so no net.agent script running for them)
noauto phonet0 upnlink0 wlan0 wmaster0
__EOF__

cat > $ROOTDIR/etc/default/keyboard << __EOF__
XKBMODEL="nokiarx51"
XKBLAYOUT="de"
XKBVARIANT=""
XKBOPTIONS=""
__EOF__

cat > $ROOTDIR/etc/modules << __EOF__
bq27x00_battery
g_nokia
__EOF__

cat > $ROOTDIR/root/charging.sh << __EOF__
#!/bin/sh

i2cset -y -m 0x77 2 0x6b 0x04 0x50;
i2cset -y -m 0xff 2 0x6b 0x02 0x8c;
i2cset -y -m 0xff 2 0x6b 0x01 0xc8;
i2cset -y -m 0xc0 2 0x6b 0x00 0x00;

while true ; do
	i2cset -y -m 0x80 2 0x6b 0x00 0x80;
	sleep 28;
done
__EOF__

echo -n "14188 155 -3112200 52 -8740 33129794 65536" > $ROOTDIR/etc/pointercal

chroot $ROOTDIR apt-get remove cdebootstrap-helper-rc.d

chroot $ROOTDIR apt-get clean
