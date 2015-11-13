#!/bin/bash
set -e

CONFIG_STARTER="$(pwd)/etc/starter.conf";
echo "Read config: ${CONFIG_STARTER}";
. "/${CONFIG_STARTER}";


STARTER_SERVER="qsub -S /bin/bash ${SCRIPT_STARTER_SERVER}"
echo "Run: ${STARTER_SERVER}";
${STARTER_SERVER} 1>>${SCRIPT_STD_OUT} 2>> ${SCRIPT_STD_ERR} &
