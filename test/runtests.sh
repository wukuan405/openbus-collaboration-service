#!/bin/bash

mode=$1

runconsole="env \
OPENBUS_SDKLUA_HOME=${OPENBUS_CORESDKLUA_HOME} \
OPENBUS_SDKLUA_TEST=${OPENBUS_CORESDKLUA_TEST} \
/bin/bash ${OPENBUS_CORESDKLUA_TEST}/runconsole.sh $mode"

if [[ "$mode" != "DEBUG" && "$mode" != "RELEASE" ]]; then
	echo "Usage: $0 <RELEASE|DEBUG>"
	exit 1
fi

test_prelude="package.path=package.path..';../lua/?.lua;../dist/?.lua;./?.lua'"

cases="interface persistence observer oninvalid_login"

for case in $cases; do
	echo -n "Test '${case}' ... "
	$runconsole -e $test_prelude $case.lua ${@:2:${#@}} || exit $?
	echo "OK"
done
