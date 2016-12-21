#!/bin/bash

mode=$1
busport=$2

LUA_PATH="${OPENBUS_COLLAB_TEST}/../lua/?.lua;${OPENBUS_COLLAB_TEST}/?.lua;;"
service="env LUA_PATH=$LUA_PATH ${OPENBUS_COLLAB_HOME}/bin/collaboration-service"

if [[ "$mode" == "DEBUG" ]]; then
	service="$service $mode"
elif [[ "$mode" != "RELEASE" ]]; then
	echo "Usage: $0 <RELEASE|DEBUG> <args>"
	exit 1
fi

export COLLAB_CONFIG=$OPENBUS_TEMP/collab.cfg
echo "busport = $busport"                         > $COLLAB_CONFIG
echo "privatekey = \"$OPENBUS_TEMP/collab.key\"" >> $COLLAB_CONFIG
echo "database = \"$OPENBUS_TEMP/collab.db\""    >> $COLLAB_CONFIG

$service -configs $COLLAB_CONFIG 2>&1 &
pid="$!"
trap "kill $pid > /dev/null 2>&1" 0

