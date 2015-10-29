#!/bin/bash
set -e

CONFIG_STARTER="$(pwd)/etc/starter.conf";
echo "Read config: ${CONFIG_STARTER}";
. "/${CONFIG_STARTER}";

echo "Run: ${SCRIPT_STARTER_SERVER}";
${SCRIPT_STARTER_SERVER} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
sleep 1;

echo "Run: ${SCRIPT_STARTER_PLANNER}";
${SCRIPT_STARTER_PLANNER} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
sleep 3;

for i in {1..6}
do
	echo "Run: ${SCRIPT_STARTER_WORKER}";
	${SCRIPT_STARTER_WORKER} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
done

