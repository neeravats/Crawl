#!/bin/bash

FN_CONFIG=$1
SEED_FILE_PATH=$2
SEED_NAME=$3
DEPTH=$4

FN_JOBID=jobflow.id

if [[ ! -e ${FN_CONFIG} ]]; then
    echo "Config file ${FN_CONFIG} doesn't exist! Exiting."
    exit 1
fi

source ${FN_CONFIG}

Banner

ID_RUN=`date +%Y%m%d-%H%M%S`
RUN_DATE=`date +%Y%m%d`
DIR_PROCESS=${DIR_WORK}/${ID_RUN}

ID_JOBFLOW=${DIR_PROCESS}/${FN_JOBID}

Log "Starting run ID ${ID_RUN}"


# Make the work directory
mkdir ${DIR_PROCESS}


# Construct job flows
Log "Bootstrapping jobflow"
${BIN_PROFILES}/bootstrap-jobflow.sh ${FN_CONFIG} ${ID_JOBFLOW} ${SEED_FILE_PATH} ${SEED_NAME}
if [[ $? -ne 0 ]]; then
    ${BIN_EMR}/elastic-mapreduce -j `head -1 ${ID_JOBFLOW}` --terminate
    ExitOnFail 1 "Failed trying to start jobflow for run ${ID_RUN}. Job flow listed in `hostname`:${ID_JOBFLOW} may still be alive."
fi

JOBFLOWID=`head -1 ${ID_JOBFLOW}`
Log "... Started jobflow ${JOBFLOWID}"


# Submit Crawl job

Log "Submitting Crawl Job"

${BIN_EMR}/elastic-mapreduce \
    -j ${JOBFLOWID} \
    --stream \
    --step-name   "Submitting Crawl Job for  ${SEED_DIR}" \
    --input       ${BUCKET_LIB}/${SEED_NAME} \
    --mapper      'org.apache.nutch.crawl.Crawl' \
    --output      ${BUCKET_RESULTS}/${SEED_NAME} \
    --args        "-depth ${DEPATH}" \
    --arg         "-files"   --arg "${BUCKET_LIB}/apache-nutch-1.7.job" \
    --arg         "-libjars" --arg "${BUCKET_LIB}/apache-nutch-1.7.job" \
    --arg         '-verbose'

if [[ $? -ne 0 ]]; then
    ${BIN_EMR}/elastic-mapreduce -j ${JOBFLOWID} --terminate
    ExitOnFail 1 "Crawl" "Couldn't setup Cral Step for ${SEED_NAME}. Jobflow ${JOBFLOWID} terminated."
fi

WaitForStep ${JOBFLOWID}
if [[ $? -ne 0 ]]; then
    ${BIN_EMR}/elastic-mapreduce -j ${JOBFLOWID} --terminate
    ExitOnFail 1 "Carwl" "Crawl step for run ${ID_RUN} failed. Jobflow ${JOBFLOWID} terminated."
fi
