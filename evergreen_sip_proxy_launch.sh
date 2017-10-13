#!/bin/bash

PATH_TO_SIP_SERVER="/sip_proxy/sip_proxy.pl"
PATH_TO_CONF="/mnt/share/sip_proxy/sip_server.conf"
PATH_TO_REBOOT="/mnt/share/sip_proxy/reboot.txt"
LAST_CONF="/sip_proxy/sip_server_last.conf"
AUTOSSH_SHORT_NAME_LABEL="ME"

rm ~/.ssh/known_hosts
# If the "last" version of the config file doesn't exist, let's create it
if [ ! -f $LAST_CONF ];
    then
    cat $PATH_TO_CONF > $LAST_CONF
fi

if [ -f $PATH_TO_REBOOT ];
    then
    rm -f $PATH_TO_REBOOT && /sbin/reboot
fi

CURRENT_CONF_MD5=`cat $PATH_TO_CONF | md5sum`
LAST_CONF_MD5=`cat $LAST_CONF | md5sum`

PID=`ps aux|grep -v grep|grep sip_proxy.pl|awk '{print $2}'`
AUTOSSHPID=`ps aux|grep -v grep|grep autossh|awk '{print $2}'`

if [ "$AUTOSSHPID" -gt "1" ];
then
    echo "autossh is running"
else    
    autossh -N -M 0 -f $AUTOSSH_SHORT_NAME_LABEL
fi

START_FLAG="0"

echo "Running on '$PID'"
if [ "$PID" -gt "1" ];
then
    echo "running"
    if [ "$CURRENT_CONF_MD5" != "$LAST_CONF_MD5" ];
    then
        START_FLAG="1"
        echo "Killing pid $PID"
        cat $PATH_TO_CONF > $LAST_CONF
        kill $PID
    else
        echo "$CURRENT_CONF_MD5 = $LAST_CONF_MD5"
    fi
else
    echo "need to start the service"
    START_FLAG="1"
fi

if [ $START_FLAG == "1" ];
then
    echo "Starting fresh"
    $PATH_TO_SIP_SERVER --config $PATH_TO_CONF
fi
