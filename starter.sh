#!/bin/bash
set -e

CONFIG_STARTER="$(pwd)/etc/starter.conf";
echo "Read config: ${CONFIG_STARTER}";
. "/${CONFIG_STARTER}";


echo "Clean logs: ${SCRIPT_STD_OUT}";
rm -f ${SCRIPT_STD_OUT};
echo "Clean logs: ${SCRIPT_STD_ERR}";
rm -f ${SCRIPT_STD_ERR};
echo "Clean logs: ${SCRIPT_LOG_ALL}";
rm -f ${SCRIPT_LOG_ALL};
echo "Clean logs: ${SCRIPT_LOG_XML}";
rm -f ${SCRIPT_LOG_XML};



echo "Run: ${SCRIPT_STARTER_SERVER}";
SERVER=$(qsub -p 0 -S /bin/bash ${SCRIPT_STARTER_SERVER} | tr -d -c 0-9);
echo "Server SGE Job id: ${SERVER}";

STARTER_PLANNER="qsub -p -10 -S /bin/bash  ${SCRIPT_STARTER_PLANNER}"
echo "Run: ${STARTER_PLANNER}";
PLANNER=$(${STARTER_PLANNER} | tr -d -c 0-9)
echo "Planner SGE Job id: ${PLANNER}";

STARTER_WORKER="qsub -t 1-8 -p -20 -S /bin/bash ${SCRIPT_STARTER_WORKER}"
echo "Run: ${STARTER_WORKER}";
${STARTER_WORKER} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &

