#!/bin/bash

# Environment Configuration

BIN_EMR=/home/hduser/elastic-mapreduce-ruby-cli
BIN_NUTCH=/usr/local/apache-nutch-1.7
BIN_S3=/home/hduser/s3cmd-1.0.0
NUTCH_EMR_DRIVERS=${BIN_NUTCH}/emr-drivers
DIR_WORK=${BIN_NUTCH}/work
BUCKET_LIB=s3://kvantum-crawler-data/lib
BUCKET_RESULTS=s3://kvantum-crawler-data/results
LOG_PATH=s3://kvantum-crawler-data/logs

# EMR Configuration

EMR_NUM_CORE_NODES=1
EMR_NUM_TASK_NODES=1
EMR_INSTANCETYPE_MASTER=m1.small
EMR_CORE_TASK_NODE_TYPE=c1.medium
EMR_SPOT_BID_PRICE="2.00"

#LOG_PATH=hdfs://10.38.21.169:54310/user/hduser/log
EMRPATH_LIB=/mnt/tmp/crawler

EMR_POLL=300


function WaitForStep {
   local JOBFLOWID=$1
   
   STATUS_DONE=0
   STATUS_ERR=1
   STATUS_FAILURE=2
   STATUS_WAITING=3

   STATUS_CURR=3
   while [[ ${STATUS_CURR} -eq 3 ]] || [[ ${STATUS_CURR} -eq 1 ]] ; do
      ${BIN_EMR}/elastic-mapreduce -j ${JOBFLOWID} --describe 
      STATUS_CURR=$?

      case $STATUS_CURR in
         1) echo "Failed to parse job flow description."; sleep ${EMR_POLL};;
         2) echo "Job flow ${JOBFLOWID} failed."; return 1;;
         3) echo "Last step in progress. Waiting before checking again."; sleep ${EMR_POLL};;
      esac
   done
}

# Function to print a version banner
function Banner {
    echo
    echo "================================================================================"
    echo "  Script: $0"
    echo "      on: ${HOSTNAME}:`pwd`"
    echo "      at: `date`"
    echo "     PID: $$"
    echo "================================================================================"
    echo
    return 0
}

