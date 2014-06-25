#/bin/bash
# Reset

#echo -n Reset...
#i2cset -y -m 0x80 2 0x6b 0x04 80
#echo -n Done. Sleep 1...
#sleep 1
#echo -n Done.

echo "Charger: " $(cat /sys/devices/platform/musb_hdrc/charger)

# Disable charger for configuration:
i2cset -y 2 0x6b 0x01 0xcc # No limit, 3.4V weak threshold, enable term, charger disable


# Register 0x04
# 8: reset
# 4: 27.2mV  # charge current
# 2: 13.6mV
# 1: 6.8mV
# 8: N/A
# 4: 13.6mV # termination current
# 2: 6.8mV
# 1: 3.4mV
# 7-1250 6-1150 5-1050 4-950 3-850 2-750 1-650 0-550
# 7-400 6-350 5-300 4-250 3-200 2-150 1-100 0-50
i2cset -y -m 0xFF 2 0x6b 0x04 0x50;

# Register 0x02
# 8: .640 V
# 4: .320 V
# 2: .160 V
# 1: .080
# 8: .040
# 4: .020 (+ 3.5)
# 2: otg pin active at high (default 1)
# 1: enable otg pin
i2cset -y -m 0xfc 2 0x6b 0x02 0x8c; 
# 4.2 = 3.5 + .640 + .040 + .02 = 8c
# 4.16 = 3.5 + .640V + .020 = 84
# 4.1 = 3.5 + .320 + .160 + .08 + .04 = 78
# 4.0 = 3.5 + .320 + .160 + .02 = 64
# 3.9 = 3.5 + .320 + .080 = 50

# Register 0x1
# 8: 00 = 100, 01 = 500, 10 = 800mA
# 4: 11 = no limit
# 2: 200mV weak threshold default 1
# 1: 100mV weak treshold defsult 1 (3.4 - 3.7)
# 8: enable termination
# 4: charger disable
# 2: high imp mode
# 1: boost
i2cset -y 2 0x6b 0x01 0xc8; 

# Register 0x00
# 8: Read:  OTG Pin Status
#    Write: Timer Reset
# 4: Enable Stat Pin
# 2: Stat : 00 Ready 01 In Progress
# 1:      : 10 Done  11 Fault
# 8: Boost Mode
# 4: Fault: 000 Normal 001 VBUS OVP 010 Sleep Mode 
# 2:        011 Poor input or Vbus < UVLO 
# 1:        100 Battery OVP 101 Thermal Shutdown
#           110 Timer Fault 111 NA
i2cset -y 2 0x6b 0x00 0x00; 

echo -n "Charge parameters programmed. Sleep 1..."
sleep 1
echo "Status: " $(i2cget -y 2 0x6b 0x00)
i2cset -y 2 0x6b 0x00 0x80 # timer reset
cat /sys/devices/platform/musb_hdrc/charger >/dev/null

# Initialize variables
THROTTLE=0
FULL=0
MODE="STANDBY"
WALLCHARGER=0

# Assuming a nice round number 20mOhm for bq27200 sense resistor
RS=20

get_nac ()
{
    NAC=$(i2cget -y 2 0x55 0x0c w)
    NAC=$(($NAC * 3570 / $RS / 1000))
}
get_rsoc ()
{
    RSOC=$(i2cget -y 2 0x55 0x0b)
    RSOC=$((RSOC))
}
get_volt ()
{
   VOLT=$(i2cget -y 2 0x55 0x08 w)
   VOLT=$(($VOLT))
}

STATUS=$(i2cget -y 2 0x6b 0x00)
while true ; do
   sleep 15; 
   STATUS=$(i2cget -y 2 0x6b 0x00)
   #echo $STATUS

   i2cset -y -m 0x80 2 0x6b 0x00 0x80; # timer reset
   get_nac
   get_rsoc
   get_volt

   if [ $MODE == "STANDBY" ] ; then
      if [ $STATUS == 0x10 ] || [ $STATUS == 0x90 ] ; then
         MODE="CHARGING"
         echo $(date) "standby -> CHARGING. Current available capacity: " $NAC "mAh" >> /home/user/MyDocs/charger.log
         WALLCHARGER=$(cat /sys/devices/platform/musb_hdrc/charger)
      fi
   fi
   if [ $MODE == "CHARGING" ] ; then
      if [ $STATUS == 0x00 ] ; then
         MODE="STANDBY"
         echo $(date) "charging -> STANDBY. Current available capacity: " $NAC "mAh" >> /home/user/MyDocs/charger.log
         WALLCHARGER=0
         # This will stop USB from eating power as long as you haven't plugged it into a PC
         echo 0 > /sys/devices/platform/musb_hdrc/connect
      fi
   fi

   if [ $STATUS == 0xa0 ] && [ $FULL == 0 ] ; then
      echo "Charge done"
      echo $(date) "FULL: " $NAC "mAh" >> /home/user/MyDocs/charger.log
      FULL=1
   fi
   if [ $STATUS == 0x00 ] && [ $FULL == 1 ] ; then
      FULL=0
   fi
   echo Status: $STATUS Mode: $MODE Full: $FULL WallCharger: $WALLCHARGER Battery Voltage: $VOLT NAC: $NAC Battery level: $RSOC %
done
