#!/bin/bash
set -e

CONFIG="$(pwd)/etc/starter.conf";
echo "Read config: ${CONFIG}";
. "/${CONFIG}";


echo "Checking scripts..."
check_file ${SCRIPT_STARTER_SERVER};
check_file ${SCRIPT_STARTER_PLANNER};
check_file ${SCRIPT_STARTER_WORKER};

#STARTER_QSUB="qsub -S /bin/bash";
#STARTER_WORKER="${STARTER_QSUB} $(pwd)/starter-worker.sh";
#STARTER_PLANNER="${STARTER_QSUB} $(pwd)/starter-planner.sh"
#STARTER_SERVER="${STARTER_QSUB} $(pwd)/starter-server.sh";


echo "Starting scripts..."
echo "Run: ${SCRIPT_STARTER_SERVER}";
${SCRIPT_STARTER_SERVER} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
sleep 1;

echo "Run: ${SCRIPT_STARTER_PLANNER}";
${SCRIPT_STARTER_PLANNER} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
sleep 3;

for i in {1..4}
do
	echo "Run: ${SCRIPT_STARTER_WORKER}";
	${SCRIPT_STARTER_WORKER} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
done

