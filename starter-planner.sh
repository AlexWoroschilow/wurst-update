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
	SCRIPT_LOG_ALL=$3;
	SCRIPT_STD_ERR=$4;
	
	TIMESTAMP="$(date +'%s')";
	SCRIPT_LOG_REMOTE_XML="${TIMESTAMP}.xml";
	SCRIPT_LOG_REMOTE_TXT="${TIMESTAMP}.log";

	SCRIPT_SCP="/usr/bin/scp";
	SCRIPT_SSH="/usr/bin/ssh";
	DESTINATION_USER="wurst";
	DESTINATION_HOST="flensburg.zbh.uni-hamburg.de";
	DESTINATION_FLENSBURG="/home/other/wurst/wurst_rss/xml";
	DESTINATION_FLENSBURG_XML="${DESTINATION_FLENSBURG}/${SCRIPT_LOG_REMOTE_XML}";
	DESTINATION_FLENSBURG_RSS="/home/other/wurst/public_html/rss/log";
	DESTINATION_FLENSBURG_TXT="${DESTINATION_FLENSBURG_RSS}/${SCRIPT_LOG_REMOTE_TXT}";

	echo "<?xml version=\"1.1\" encoding=\"UTF-8\" ?>" > ${SCRIPT_LOG_XML};
	echo "<response>" >> ${SCRIPT_LOG_XML};
	echo "<task>wurst-update</task>" >> ${SCRIPT_LOG_XML};
	echo "<date>$(date +%s)</date>" >> ${SCRIPT_LOG_XML};
	echo "<status>${?}</status>" >> ${SCRIPT_LOG_XML};
	echo "<logfile><![CDATA[${SCRIPT_LOG_REMOTE_TXT}]]></logfile>" >> ${SCRIPT_LOG_XML};
	echo "<info><![CDATA[$(cat ${SCRIPT_LOG_ALL} | grep INFO | head -300)]]></info>" >> ${SCRIPT_LOG_XML};
	echo "<warning><![CDATA[$(cat ${SCRIPT_LOG_ALL} | grep WARN | head -300)]]></warning>" >> ${SCRIPT_LOG_XML};
	echo "<error><![CDATA[$(cat ${SCRIPT_LOG_ALL} | grep ERROR | head -300)]]></error>" >> ${SCRIPT_LOG_XML};
	echo "<fatal><![CDATA[$(cat ${SCRIPT_LOG_ALL} | grep FATAL | head -300)]]></fatal>" >> ${SCRIPT_LOG_XML};
	echo "<stderr><![CDATA[$(head -1000 ${SCRIPT_STD_ERR})]]></stderr>" >> ${SCRIPT_LOG_XML};
	echo "</response>" >> ${SCRIPT_LOG_XML};

	${SCRIPT_SCP} ${SCRIPT_LOG_XML} ${DESTINATION_USER}@${DESTINATION_HOST}:${DESTINATION_FLENSBURG_XML}
	${SCRIPT_SCP} ${SCRIPT_LOG_ALL} ${DESTINATION_USER}@${DESTINATION_HOST}:${DESTINATION_FLENSBURG_TXT}

	${SCRIPT_SSH} ${DESTINATION_USER}@${DESTINATION_HOST} chmod -R 777 ${DESTINATION_FLENSBURG}
	
	kill ${PLANNER_PID}
	exit;
}


PLANNER_PID=0;
# Catch sytem signals needs to write 
# a xml files for rss status stream
trap 'signal_handler ${PLANNER_PID} ${SCRIPT_LOG_XML} ${SCRIPT_LOG_ALL} ${SCRIPT_STD_ERR};' EXIT KILL HUP INT TERM

echo "Run planner: ${SCRIPT_PLANNER}";
${SCRIPT_PLANNER} --configlog=${CONFIG_LOGGER} --configfile=${CONFIG_SERVER} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
PLANNER_PID=$!;
# Catch sytem signals needs to write 
# a xml files for rss status stream
trap 'signal_handler ${PLANNER_PID} ${SCRIPT_LOG_XML} ${SCRIPT_LOG_ALL} ${SCRIPT_STD_ERR};' EXIT KILL HUP INT TERM

echo "Waiting for pid: ${PLANNER_PID}";
wait ${PLANNER_PID};

exit;