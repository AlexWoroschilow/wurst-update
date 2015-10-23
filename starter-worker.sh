#!/bin/bash
#$ -clear
#$ -cwd
#$ -q stud.q
. "$(pwd)/starter-settings.sh";


sleep 3;

echo "Run worker: ${SCRIPT_WORKER}";
${SCRIPT_WORKER} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
WORKER_PID=$!;
echo "worker pid: ${WORKER_PID}";
wait ${WORKER_PID};
exit;
