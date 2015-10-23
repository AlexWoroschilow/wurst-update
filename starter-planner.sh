#!/bin/bash
#$ -clear
#$ -cwd
#$ -q stud.q

SCRIPT_PLANNER="$(pwd)/gearman/planner.pl";

OUT="$(pwd)/output/update-out.std";
ERROR="$(pwd)/output/update-error.std";
FATAL="$(pwd)/output/update-fatal.log";
NOTICE="$(pwd)/output/update-error.log";
INFO="$(pwd)/output/update-info.log";

# Define result xml file for rss stream
DEST="/home/sensey/Projects/Wurst/src/wurststatus/xml/update$(date +'%s').xml";


# Write a xml file with status
# for php status-rss stream 
resultxml () {

	PID=$1;
	DEST=$2;
	INFO=$3;
	NOTICE=$4;
	ERROR=$5;
	FATAL=$6;						

	echo "<?xml version=\"1.1\" encoding=\"UTF-8\" ?>" > ${DEST};
	echo "<response>" >> ${DEST};
	echo "<task>wurst-update</task>" >> ${DEST};
	echo "<date>$(date +%s)</date>" >> ${DEST};
	echo "<status>${?}</status>" >> ${DEST};
	echo "<log><![CDATA[$(cat ${INFO})]]></log>" >> ${DEST};
	echo "<notice><![CDATA[$(cat ${NOTICE})]]></notice>" >> ${DEST};
	echo "<error><![CDATA[$(cat ${ERROR})]]></error>" >> ${DEST};
	echo "<fatal><![CDATA[$(cat ${FATAL})]]></fatal>" >> ${DEST};
	echo "</response>" >> ${DEST};
	kill ${PID}
	exit;
}


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
trap 'resultxml ${PLANNER_PID} ${DEST} ${INFO} ${NOTICE} ${ERROR} ${FATAL};' EXIT KILL HUP INT TERM

echo "Run planner: ${SCRIPT_PLANNER}";
${SCRIPT_PLANNER} 1>>${OUT} 2>> ${ERROR} &
PLANNER_PID=$!;

# Catch sytem signals needs to write 
# a xml files for rss status stream
trap 'resultxml ${PLANNER_PID} ${DEST} ${INFO} ${NOTICE} ${ERROR} ${FATAL};' EXIT KILL HUP INT TERM

echo "Waiting for pid: ${PLANNER_PID}";
wait ${PLANNER_PID};
exit;