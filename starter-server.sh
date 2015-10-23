#!/bin/bash
. "$(pwd)/starter-settings.sh";

TIMEOUT="120"

echo "Run server: ${SCRIPT_SERVER}";
${SCRIPT_SERVER} --timeout=${TIMEOUT} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
SERVER_PID=$!;
echo "Server pid: ${SERVER_PID}";
wait ${SERVER_PID};
exit;