#!/bin/bash
set -e

TIMEOUT="120"
CONFIG="$(pwd)/etc/starter.conf";
CONFIG_SERVER="$(pwd)/etc/server.conf";
CONFIG_LOGGER="$(pwd)/etc/logger.conf";

echo "Read config: ${CONFIG}";
. "/${CONFIG}";


echo "Checking..."
check_file ${SCRIPT_SERVER};
check_file ${CONFIG_SERVER};
check_file ${CONFIG_LOGGER};

echo "Run: ${SCRIPT_SERVER}";
${SCRIPT_SERVER} --configlog=${CONFIG_LOGGER} --configfile=${CONFIG_SERVER} --timeout=${TIMEOUT} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
SERVER_PID=$!;
echo "Server pid: ${SERVER_PID}";

# Kill server if this script
# has been killed or die
trap 'kill ${SERVER_PID};' EXIT KILL HUP INT TERM

wait ${SERVER_PID};
exit;