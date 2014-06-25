i2cset -y -m 0x77 2 0x6b 0x04 0xc9;
# next register 0x03 is device ID, always 4b and r/o; so we skip to 0x04
i2cset -y -m 0xff 2 0x6b 0x02 0x8c;
# 0x8c = 3v5 + .640 + .040 + .020 = 4V200, BE CAREFUL and DON'T CHANGE
# unless you know what you're doing. 4V2 is ABS MAX!
i2cset -y -m 0xff 2 0x6b 0x01 0xc8;
i2cset -y -m 0xc0 2 0x6b 0x00 0x00;

# tickle watchdog, while status indicates 'charging from wallcharger'
while [ $(i2cget -y 2 0x6b 0x00) = 0x90 ] ; do
	sleep 28;
	# reset watchdog timer:
	i2cset -y -m 0x80 2 0x6b 0x00 0x80;
done
echo "charging finished, status(reg0)=$(i2cget -y 2 0x6b 0x00)"
