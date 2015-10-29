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
echo "Clean logs: ${SCRIPT_LOG_INF}";
rm -f ${SCRIPT_LOG_INF};
echo "Clean logs: ${SCRIPT_LOG_WRN}";
rm -f ${SCRIPT_LOG_WRN};
echo "Clean logs: ${SCRIPT_LOG_ERR}";
rm -f ${SCRIPT_LOG_ERR};
echo "Clean logs: ${SCRIPT_LOG_FAT}";
rm -f ${SCRIPT_LOG_FAT};


echo "Run: ${SCRIPT_STARTER_SERVER}";
SERVER=$(qsub -p 0 -S /bin/bash ${SCRIPT_STARTER_SERVER} | tr -d -c 0-9);
echo "Server SGE Job id: ${SERVER}";

STARTER_PLANNER="qsub -p -1 -S /bin/bash  ${SCRIPT_STARTER_PLANNER}"
echo "Run: ${SCRIPT_STARTER_PLANNER}";
PLANNER=$(${STARTER_PLANNER} | tr -d -c 0-9)
echo "Planner SGE Job id: ${PLANNER}";

STARTER_WORKER="qsub -p -2 -S /bin/bash ${SCRIPT_STARTER_WORKER}"
for i in {1..6}
do
	echo "Run: ${STARTER_WORKER}";
	${STARTER_WORKER} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
done

