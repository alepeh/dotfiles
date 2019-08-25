#!/bin/bash
ORG_DIR=$1
echo $ORG_DIR
if [ "$RUNNING_IN_NEW_XTERM" != t ] ; then
        RUNNING_IN_NEW_XTERM=t exec xterm -e "$0 $*"
fi

# X11 settings for docker
export ip=`ifconfig en0 | grep "inet " | cut -d " " -f2`
#export ip=`ifconfig en8 | grep "inet " | cut -d " " -f2`

function startx() {
	if [ -z "$(ps -ef|grep XQuartz|grep -v grep)" ] ; then
	    open -a XQuartz
        socat TCP-LISTEN:6000,reuseaddr,fork UNIX-CLIENT:\"$ip:0\" &
	fi
}
 
startx 
xhost + $ip
docker run -e DISPLAY=$ip:0 -e TZ=Europe/Vienna -e UNAME=alepeh -v /tmp/.X11-unix:/tmp/.X11-unix -v "$ORG_DIR":/mnt/workspace alepeh/spacemacs:latest 
