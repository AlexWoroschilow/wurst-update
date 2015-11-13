#!/bin/bash
#$ -clear
#$ -cwd
#$ -t 1-8 
#$ -q stud.q
#$ -S /bin/bash
set -e

CONFIG_STARTER="$(pwd)/etc/starter.conf";
echo "Read config: ${CONFIG_STARTER}";
. "/${CONFIG_STARTER}";

echo "Run worker: ${SCRIPT_WORKER}";
${SCRIPT_WORKER} --config=${CONFIG_UPDATER} --logger=${CONFIG_LOGGER} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
WORKER_PID=$!;
echo "worker pid: ${WORKER_PID}";

trap 'kill ${WORKER_PID};' EXIT KILL HUP INT TERM
wait ${WORKER_PID};
exit;
