#!/bin/bash
#$ -clear
#$ -cwd
#$ -q stud.q
#$ -S /bin/bash
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
echo "Checking worker script..."
check_file ${SCRIPT_WORKER};

# Write a xml file with status
# for php status-rss stream 
signal_handler () {

	PLANNER_PID=$1;
	WORKER_PID=$2;
	SCRIPT_LOG_XML=$3;
	SCRIPT_LOG_ALL=$4;
	SCRIPT_STD_ERR=$5;
	
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
	
	kill ${PLANNER_PID} ${WORKER_PID};
	exit;
}


WORKER_PID=0
PLANNER_PID=0;
# Catch sytem signals needs to write 
# a xml files for rss status stream
trap 'signal_handler ${PLANNER_PID} ${WORKER_PID} ${SCRIPT_LOG_XML} ${SCRIPT_LOG_ALL} ${SCRIPT_STD_ERR};' EXIT KILL HUP INT TERM

echo "Run planner: ${SCRIPT_PLANNER}";
${SCRIPT_PLANNER} --configlog=${CONFIG_LOGGER} --configfile=${CONFIG_SERVER} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
PLANNER_PID=$!;
echo "Planner pid: ${PLANNER_PID}";

# run worker here do do some 
# job even if other workers
# has not been started
echo "Run worker: ${SCRIPT_WORKER}";
${SCRIPT_WORKER} --configlog=${CONFIG_LOGGER} --configfile=${CONFIG_SERVER} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
WORKER_PID=$!;
echo "Worker pid: ${WORKER_PID}";

# Catch sytem signals needs to write 
# a xml files for rss status stream
trap 'signal_handler ${PLANNER_PID} ${WORKER_PID} ${SCRIPT_LOG_XML} ${SCRIPT_LOG_ALL} ${SCRIPT_STD_ERR};' EXIT KILL HUP INT TERM

# Start planner 
# it is not possible to use a dependency in tasks
# so i have to start a workers after planner started
# it is something like a dependency
##STARTER_WORKER="qsub -S /bin/bash ${SCRIPT_STARTER_WORKER}"
##echo "Run: ${STARTER_WORKER}";
##${STARTER_WORKER} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &


echo "Waiting for pid: ${PLANNER_PID}";
wait ${PLANNER_PID};

exit;