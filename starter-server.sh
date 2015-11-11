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
echo "Checking worker script..."
check_file ${SCRIPT_WORKER};

echo "Run: ${SCRIPT_SERVER}";
${SCRIPT_SERVER} --configlog=${CONFIG_LOGGER} --configfile=${CONFIG_SERVER} --timeout=${SERVER_TIMEOUT} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
SERVER_PID=$!;
echo "Server pid: ${SERVER_PID}";

sleep 5;

# run worker here do do some 
# job even if other workers
# has not been started
echo "Run worker: ${SCRIPT_WORKER}";
${SCRIPT_WORKER} --configlog=${CONFIG_LOGGER} --configfile=${CONFIG_SERVER} --timeout1=${SERVER_TIMEOUT} --timeout2=${SERVER_TIMEOUT} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
WORKER_PID=$!;
echo "worker pid: ${WORKER_PID}";

# Kill server if this script
# has been killed or die
trap 'kill ${SERVER_PID} ${WORKER_PID};' EXIT KILL HUP INT TERM

# Start planner 
# it is not possible to use a dependency in tasks
# so i have to start a planner after server started
# it is something like a dependency
STARTER_PLANNER="qsub -S /bin/bash  ${SCRIPT_STARTER_PLANNER}"
echo "Run: ${STARTER_PLANNER}";
PLANNER=$(${STARTER_PLANNER} | tr -d -c 0-9)
echo "Planner SGE Job id: ${PLANNER}";

wait ${SERVER_PID};
exit;