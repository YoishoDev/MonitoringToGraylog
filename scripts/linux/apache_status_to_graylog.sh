#!/bin/bash

# Script for determining selected monitoring parameters and integration into Graylog
# Tested on Debian 12
# (C) Michael Schmidt
# Version 0.1 (01.12.2023)

# build a valid gelf message
# see https://go2docs.graylog.org/5-0/getting_in_log_data/gelf.html
version="1.1"
short_message="Apache http server status message"
full_message="Apache http server status message"
level=6
host=` hostname`
hostIpAddress=`hostname -I | cut -d' ' -f1`
grayLogServer=siemserver.domain.com
grayLogServerPort=12201
sourceModuleName="apache_httpd_status"
apacheStatusFile="/tmp/apache_httpd_status.tmp"

idleWorkers=0
busyWorkers=0
freeWorkers=0

loop=0

jsonString="{ \"version\": \"$version\","

curl -k https://$hostIpAddress/server-status?auto -o "$apacheStatusFile"

while read -r line
do
	case "$loop" in
		1)	jsonString="$jsonString \"ApacheVersion\" : \"`echo $line | cut -f2 -d":" | sed 's/^.//'`\"," ;;
		9) 	jsonString="$jsonString \"ApacheUptime\" : \"`echo $line | cut -f2 -d":" | sed 's/^.//'`\"," ;;
		13) 	jsonString="$jsonString \"ApacheTotalAccesses\" : \"`echo $line | cut -f2 -d":" | sed 's/^.//'`\"," ;;
		25) 	jsonString="$jsonString \"ApacheDurationPerReq\" : \"`echo $line | cut -f2 -d":" | sed 's/^.//'`\"," ;;
		26) 	busyWorkers=`echo $line | cut -f2 -d":" | sed 's/^.//'`
				jsonString="$jsonString \"ApacheBusyWorkers\" : \"$busyWorkers\"," ;;
		27) 	idleWorkers=`echo $line | cut -f2 -d":" | sed 's/^.//'`
				jsonString="$jsonString \"ApacheIdleWorkers\" : \"$idleWorkers\"," ;;
	esac
	loop=`expr $loop + 1`
done < "$apacheStatusFile"

if [[ $busyWorkers =~ ^[0-9]+$ ]] && [[ $idleWorkers =~ ^[0-9]+$ ]]
then
	freeWorkers=`expr $idleWorkers - $busyWorkers`
	jsonString="$jsonString \"ApacheFreeWorkers\" : \"$freeWorkers\","
fi

jsonString="$jsonString \"short_message\" : \"$short_message\","
jsonString="$jsonString \"full_message\" : \"$full_message\","
jsonString="$jsonString \"level\" : $level,"
jsonString="$jsonString \"host\" : \"$host\","
jsonString="$jsonString \"SourceModuleName\" : \"$sourceModuleName\","
jsonString="$jsonString \"timestamp\" : `date '+%s'`"

jsonString="$jsonString }"

echo $jsonString | ncat -w 2 --ssl $grayLogServer $grayLogServerPort
