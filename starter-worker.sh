#!/bin/bash
#$ -clear
#$ -cwd
#$ -t 1-8 
#$ -p -20
#$ -q stud.q
#$ -S /bin/bash
set -e

CONFIG_SERVER="$(pwd)/etc/server.conf";
CONFIG_STARTER="$(pwd)/etc/starter.conf";
CONFIG_LOGGER="$(pwd)/etc/logger.conf";

echo "Read config: ${CONFIG_STARTER}";
. "/${CONFIG_STARTER}";

sleep 3;

echo "Checking server config..."
check_file ${CONFIG_SERVER};
echo "Checking logger config..."
check_file ${CONFIG_LOGGER};
echo "Checking worker script..."
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
