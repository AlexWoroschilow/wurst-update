#!/bin/bash
#$ -clear
#$ -cwd
#$ -q stud.q
set -e

CONFIG="$(pwd)/etc/starter.conf";
CONFIG_SERVER="$(pwd)/etc/server.conf";
CONFIG_LOGGER="$(pwd)/etc/logger.conf";

echo "Read config: ${CONFIG}";
. "/${CONFIG}";

sleep 3;

echo "Checking..."
check_file ${CONFIG_SERVER};
check_file ${CONFIG_LOGGER};
check_file ${SCRIPT_WORKER};

echo "Run worker: ${SCRIPT_WORKER}";
${SCRIPT_WORKER} --configlog=${CONFIG_LOGGER} --configfile=${CONFIG_SERVER} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
WORKER_PID=$!;
echo "worker pid: ${WORKER_PID}";
# Kill server if this script
# has been killed or die
trap 'kill ${WORKER_PID};' EXIT KILL HUP INT TERM
wait ${WORKER_PID};
exit;
