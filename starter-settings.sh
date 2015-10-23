SCRIPT_SERVER="$(pwd)/gearman/server.pl";
SCRIPT_PLANNER="$(pwd)/gearman/planner.pl";
SCRIPT_WORKER="$(pwd)/gearman/worker.pl";

SCRIPT_STD_XML="$(pwd)/output/update.xml";
SCRIPT_STD_OUT="$(pwd)/output/update-out.std";
SCRIPT_STD_ERR="$(pwd)/output/update-error.std";
SCRIPT_STD_LOG="$(pwd)/output/update-info.log";
SCRIPT_STD_FAT="$(pwd)/output/update-fatal.log";
SCRIPT_STD_NOT="$(pwd)/output/update-error.log";


# Write a xml file with status
# for php status-rss stream 
xml () {

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


echo_std_err () {
	echo "${@}" 1>&2;
}

# Check is variable is empty 
# write to std error
check_variable () {
	if [ ! -n "${2}" ];then
		echo_std_err "Empty variable: ${1}";
	fi	
}

check_folder () {
	if [ ! -d "$@" ]; then
		echo_std_err "Missed folder: ${@}";
	fi
}


check_file () {
	if [ ! -f "$@" ]; then
		echo_std_err "Missed file: ${@}";
	fi
}
