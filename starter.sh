#!/bin/bash
#$ -clear
#$ -cwd
#$ -q stud.q
#$ -S /bin/bash
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


# Write a xml file with status
# for php status-rss stream 
signal_handler () {

	SERVER_PID=$1;
	WORKER_PID=$2;
	PLANNER_PID=$3;
	SCRIPT_LOG_XML=$4;
	SCRIPT_LOG_ALL=$5;
	SCRIPT_STD_ERR=$6;
	
	TIMESTAMP="$(date +'%s')";
	SCRIPT_LOG_REMOTE_XML="${TIMESTAMP}.xml";
	SCRIPT_LOG_REMOTE_TXT="${TIMESTAMP}.log";

	echo "<?xml version=\"1.1\" encoding=\"UTF-8\" ?>" > ${SCRIPT_LOG_XML};
	echo "<response>" >> ${SCRIPT_LOG_XML};
	echo "<task>wurst-update</task>" >> ${SCRIPT_LOG_XML};
	echo "<date>$(date +%s)</date>" >> ${SCRIPT_LOG_XML};
	echo "<status>${?}</status>" >> ${SCRIPT_LOG_XML};
	echo "<logfile><![CDATA[${SCRIPT_LOG_REMOTE_TXT}]]></logfile>" >> ${SCRIPT_LOG_XML};
	echo "<info><![CDATA[$(cat ${SCRIPT_LOG_ALL} | grep INFO | head -50)]]></info>" >> ${SCRIPT_LOG_XML};
	echo "<warning><![CDATA[$(cat ${SCRIPT_LOG_ALL} | grep WARN | head -50)]]></warning>" >> ${SCRIPT_LOG_XML};
	echo "<error><![CDATA[$(cat ${SCRIPT_LOG_ALL} | grep ERROR | head -50)]]></error>" >> ${SCRIPT_LOG_XML};
	echo "<fatal><![CDATA[$(cat ${SCRIPT_LOG_ALL} | grep FATAL | head -50)]]></fatal>" >> ${SCRIPT_LOG_XML};
	echo "<stderr><![CDATA[$(head -50 ${SCRIPT_STD_ERR})]]></stderr>" >> ${SCRIPT_LOG_XML};
	echo "</response>" >> ${SCRIPT_LOG_XML};

	DESTINATION_USER="wurst";
	DESTINATION_HOST="flensburg.zbh.uni-hamburg.de";

	DESTINATION_FLENSBURG="/home/other/wurst/wurst_rss/xml";
	DESTINATION_FLENSBURG_XML="${DESTINATION_FLENSBURG}/${SCRIPT_LOG_REMOTE_XML}";
	scp ${SCRIPT_LOG_XML} ${DESTINATION_USER}@${DESTINATION_HOST}:${DESTINATION_FLENSBURG_XML}

	DESTINATION_FLENSBURG_RSS="/home/other/wurst/public_html/rss/log";
	DESTINATION_FLENSBURG_TXT="${DESTINATION_FLENSBURG_RSS}/${SCRIPT_LOG_REMOTE_TXT}";	
	cat ${SCRIPT_STD_ERR} >> ${SCRIPT_LOG_ALL};
	scp ${SCRIPT_LOG_ALL} ${DESTINATION_USER}@${DESTINATION_HOST}:${DESTINATION_FLENSBURG_TXT}

	ssh ${DESTINATION_USER}@${DESTINATION_HOST} chmod -R 777 ${DESTINATION_FLENSBURG}
	
	kill ${PLANNER_PID} ${WORKER_PID} ${SERVER_PID};
	exit;
}


WORKER_PID=0;
PLANNER_PID=0;
SERVER_PID=0;

# Run configurator script
# needs to read configs from perl variables
# and write current actual config for planner
# with library, source, clusters and so on
echo "Run: ${SCRIPT_CONFIGURATOR}";
${SCRIPT_CONFIGURATOR} --config=${CONFIG_UPDATER} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
CONFIGURATOR_PID=$!;
echo "Configurator pid: ${CONFIGURATOR_PID}";


echo "Run: ${SCRIPT_SERVER}";
${SCRIPT_SERVER} --config=${CONFIG_UPDATER} --logger=${CONFIG_LOGGER} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
SERVER_PID=$!;
echo "Server pid: ${SERVER_PID}";

# run worker here do do some  job even if 
# other workers has not been started
echo "Run worker: ${SCRIPT_WORKER}";
${SCRIPT_WORKER} --config=${CONFIG_UPDATER} --logger=${CONFIG_LOGGER} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
WORKER_PID=$!;
echo "worker pid: ${WORKER_PID}";

echo "Run planner: ${SCRIPT_PLANNER}";
${SCRIPT_PLANNER} --configlog=${CONFIG_LOGGER} --configfile=${CONFIG_SERVER} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
PLANNER_PID=$!;
echo "Planner pid: ${PLANNER_PID}";

# Kill only server process if this 
# shell has bee closed with signal
# Catch sytem signals needs to write 
# a xml files for rss status stream
trap 'signal_handler ${SERVER_PID} ${PLANNER_PID} ${WORKER_PID} ${SCRIPT_LOG_XML} ${SCRIPT_LOG_ALL} ${SCRIPT_STD_ERR};' EXIT KILL HUP INT TERM

wait ${PLANNER_PID};
exit;