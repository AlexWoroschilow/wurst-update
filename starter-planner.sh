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

echo "Checking server config..."
check_file ${CONFIG_SERVER};
echo "Checking logger config..."
check_file ${CONFIG_LOGGER};
echo "Checking planner script..."
check_file ${SCRIPT_PLANNER};

# Write a xml file with status
# for php status-rss stream 
signal_handler () {

	PLANNER_PID=$1;
	SCRIPT_LOG_XML=$2;
	SCRIPT_LOG_INF=$3;
	SCRIPT_LOG_WRN=$4;
	SCRIPT_LOG_ERR=$5;
	SCRIPT_STD_ERR=$6;
	SCRIPT_LOG_FAT=$7;

	SCRIPT_SCP="/usr/bin/scp";
	SCRIPT_SCP="/usr/bin/ssh";
	DESTINATION_USER="wurst";
	DESTINATION_HOST="flensburg";
	DESTINATION_FLENSBURG="/home/other/wurst/wurst_rss/xml";

	echo "<?xml version=\"1.1\" encoding=\"UTF-8\" ?>" > ${SCRIPT_LOG_XML};
	echo "<response>" >> ${SCRIPT_LOG_XML};
	echo "<task>wurst-update</task>" >> ${SCRIPT_LOG_XML};
	echo "<date>$(date +%s)</date>" >> ${SCRIPT_LOG_XML};
	echo "<status>${?}</status>" >> ${SCRIPT_LOG_XML};
	echo "<info><![CDATA[$(cat ${SCRIPT_LOG_INF})]]></info>" >> ${SCRIPT_LOG_XML};
	echo "<warning><![CDATA[$(cat ${SCRIPT_LOG_WRN})]]></warning>" >> ${SCRIPT_LOG_XML};
	echo "<error><![CDATA[$(cat ${SCRIPT_LOG_ERR})]]></error>" >> ${SCRIPT_LOG_XML};
	echo "<stderr><![CDATA[$(cat ${SCRIPT_LOG_ERR})]]></stderr>" >> ${SCRIPT_LOG_XML};
	echo "<fatal><![CDATA[$(cat ${SCRIPT_LOG_FAT})]]></fatal>" >> ${SCRIPT_LOG_XML};
	echo "</response>" >> ${SCRIPT_LOG_XML};

	${SCRIPT_SCP} ${DEST} ${DESTINATION_USER}@${DESTINATION_HOST}:${DESTINATION_FLENSBURG}
	${SCRIPT_SCP} ${DESTINATION_USER}@${DESTINATION_HOST} chmod -R 777 ${DESTINATION_FLENSBURG}
	
	kill ${PLANNER_PID}
	exit;
}


PLANNER_PID=0;
# Catch sytem signals needs to write 
# a xml files for rss status stream
trap 'signal_handler ${PLANNER_PID} ${SCRIPT_LOG_XML} ${SCRIPT_LOG_INF} ${SCRIPT_LOG_WRN} ${SCRIPT_LOG_ERR} ${SCRIPT_STD_ERR} ${SCRIPT_LOG_FAT};' EXIT KILL HUP INT TERM

echo "Run planner: ${SCRIPT_PLANNER}";
${SCRIPT_PLANNER} --configlog=${CONFIG_LOGGER} --configfile=${CONFIG_SERVER} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
PLANNER_PID=$!;
# Catch sytem signals needs to write 
# a xml files for rss status stream
trap 'signal_handler ${PLANNER_PID} ${SCRIPT_LOG_XML} ${SCRIPT_LOG_INF} ${SCRIPT_LOG_WRN} ${SCRIPT_LOG_ERR} ${SCRIPT_STD_ERR} ${SCRIPT_LOG_FAT};' EXIT KILL HUP INT TERM

echo "Waiting for pid: ${PLANNER_PID}";
wait ${PLANNER_PID};

exit;