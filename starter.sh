#!/bin/sh
set -e
. "$(pwd)/starter-settings.sh";

STARTER_QSUB="qsub -S /bin/bash";
STARTER_WORKER="${STARTER_QSUB} $(pwd)/starter-worker.sh";
STARTER_PLANNER="${STARTER_QSUB} $(pwd)/starter-planner.sh"
STARTER_SERVER="${STARTER_QSUB} $(pwd)/starter-server.sh";


echo "Run: ${STARTER_SERVER}";
${STARTER_SERVER} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
sleep 1;

echo "Run: ${STARTER_PLANNER}";
${STARTER_PLANNER} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
sleep 3;

for i in {1..4}
do
	echo "Run: ${STARTER_WORKER}";
	${STARTER_WORKER} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
done

