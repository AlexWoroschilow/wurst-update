#!/bin/bash
#$ -clear
#$ -cwd
#$ -q stud.q
#$ -S /bin/bash
set -e

SERVER_TIMEOUT="120"
CONFIG_SERVER="$(pwd)/etc/server.conf";
CONFIG_STARTER="$(pwd)/etc/starter.conf";
CONFIG_LOGGER="$(pwd)/etc/logger.conf";

echo "Read config: ${CONFIG_STARTER}";
. "/${CONFIG_STARTER}";

echo "Checking server script...";
check_file ${SCRIPT_SERVER};
echo "Checking server config...";
check_file ${CONFIG_SERVER};
echo "Checking logger config...";
check_file ${CONFIG_LOGGER};

echo "Run: ${SCRIPT_SERVER}";
${SCRIPT_SERVER} --configlog=${CONFIG_LOGGER} --configfile=${CONFIG_SERVER} --timeout=${SERVER_TIMEOUT} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
SERVER_PID=$!;
echo "Server pid: ${SERVER_PID}";

# Kill server if this script
# has been killed or die
trap 'kill ${SERVER_PID};' EXIT KILL HUP INT TERM

wait ${SERVER_PID};
exit;