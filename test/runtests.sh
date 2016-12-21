#!/bin/bash

mode=$1

runconsole="source ${OPENBUS_SDKLUA_TEST}/runconsole.sh $mode"

if [[ "$mode" != "DEBUG" && "$mode" != "RELEASE" ]]; then
	echo "Usage: $0 <RELEASE|DEBUG>"
	exit 1
fi

cases="interface persistence observer oninvalid_login"

for case in $cases; do
	echo -n "Test '${case}' ... "
	$runconsole $case.lua ${@:2:${#@}} || exit $?
	echo "OK"
done
