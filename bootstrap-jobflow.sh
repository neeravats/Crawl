#!/bin/bash

FN_CONFIG=$1
FN_JOBID=$2
SEED_FILE=$3
SEED_NAME=$4

source ${FN_CONFIG}

Log "Uploading binaries to S3"
Log "... Staging script"
${BIN_S3}/s3cmd --no-progress put ${NUTCH_EMR_DRIVERS}/stage.sh         ${BUCKET_LIB}/stage.sh
Log "... Nutch job file"
${BIN_S3}/s3cmd --no-progress put ${BIN_NUTCH}/runtime/deploy/apache-nutch-1.7.job         ${BUCKET_LIB}/apache-nutch-1.7.job
Log "... Seed Url file file"
${BIN_S3}/s3cmd --no-progress put ${SEED_FILE}      ${BUCKET_LIB}/${SEED_NAME}

echo "Setting up job flow"
${BIN_EMR}/elastic-mapreduce \
   --create \
   --alive \
   --plain-output \
   --instance-group master \
   --instance-type ${EMR_INSTANCETYPE_MASTER} \
   --instance-count 1 \
   --instance-group core \
   --instance-type ${EMR_CORE_TASK_NODE_TYPE} \
   --instance-count ${EMR_NUM_CORE_NODES} \
   --instance-group task \
   --instance-type ${EMR_CORE_TASK_NODE_TYPE} \
   --instance-count ${EMR_NUM_TASK_NODES} \
   --bid-price ${EMR_SPOT_BID_PRICE} \
   --name "Kvantum Crawler Job Flow" \
   --log-uri ${LOG_PATH} \
   --bootstrap-action s3://elasticmapreduce/bootstrap-actions/configure-hadoop \
   --args "-m,mapred.map.child.java.opts=-Xmx1024m" \
   --args "-m,mapred.tasktracker.map.tasks.maximum=4" \
   --args "-m,mapred.reduce.child.java.opts=-Xmx1024m" \
   --args "-m,mapred.tasktracker.reduce.tasks.maximum=3" \
\> ${FN_JOBID}

if [[ $? -eq 0 ]]; then
  JOBFLOWID=`head -1 ${FN_JOBID}`
   Log "Started job flow with ID ${JOBFLOWID}"
else
   Log "elastic-mapreduce exited with nonzero status"
   exit 1;
fi

## Perform bootstrap action
Log "Running bootstrap/setup step"
${BIN_EMR}/elastic-mapreduce \
   -j ${JOBFLOWID} \
   --jar s3://elasticmapreduce/libs/script-runner/script-runner.jar \
   --args "${BUCKET_LIB}/stage.sh,${BUCKET_LIB},${EMRPATH_LIB},${SEED_FILE}" \
   --step-name "Bootstrap libraries"

WaitForStep ${JOBFLOWID}
if [[ $? -ne 0 ]]; then
   Log "Bootstrap step seems to have failed. Leaving job flow ${JOBFLOWID} alive for debugging."
   exit 1
fi
