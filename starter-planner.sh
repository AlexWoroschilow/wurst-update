#!/bin/bash
#$ -clear
#$ -cwd
#$ -q stud.q
set -e

CONFIG="$(pwd)/etc/starter.conf";
CONFIG_SERVER="$(pwd)/etc/server.conf";
CONFIG_LOGGER="$(pwd)/etc/logger.conf";
echo "Read config: ${CONFIG}";
. "/${CONFIG}";

echo "Checking..."
check_file ${CONFIG_SERVER};
check_file ${CONFIG_LOGGER};
check_file ${SCRIPT_PLANNER};

OUT="${SCRIPT_STD_OUT}";
ERROR="${SCRIPT_STD_ERR}";
FATAL="${SCRIPT_STD_FAT}";
NOTICE="${SCRIPT_STD_NOT}";
INFO="${SCRIPT_STD_LOG}";
XML="${SCRIPT_STD_XML}";

echo "Clean: ${OUT}";
rm -f ${OUT};
echo "Clean: ${ERROR}";
rm -f ${ERROR};
echo "Clean: ${FATAL}";
rm -f ${FATAL};
echo "Clean: ${NOTICE}";
rm -f ${NOTICE};
echo "Clean: ${INFO}";
rm -f ${INFO};


PLANNER_PID=0;
# Catch sytem signals needs to write 
# a xml files for rss status stream
trap 'resultxml ${PLANNER_PID} ${XML} ${INFO} ${NOTICE} ${ERROR} ${FATAL};' EXIT KILL HUP INT TERM

echo "Run planner: ${SCRIPT_PLANNER}";
${SCRIPT_PLANNER} --configlog=${CONFIG_LOGGER} --configfile=${CONFIG_SERVER} 1>>${OUT} 2>> ${ERROR} &
PLANNER_PID=$!;

# Catch sytem signals needs to write 
# a xml files for rss status stream
trap 'resultxml ${PLANNER_PID} ${XML} ${INFO} ${NOTICE} ${ERROR} ${FATAL};' EXIT KILL HUP INT TERM

echo "Waiting for pid: ${PLANNER_PID}";
wait ${PLANNER_PID};
exit;