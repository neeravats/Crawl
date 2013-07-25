#!/bin/bash -ex

LIBBUCKET=$1
DESTDIR=$2
SEEDFILE=$3

mkdir -p ${DESTDIR}
hadoop fs -copyToLocal ${LIBBUCKET}/apache-nutch-1.7.job  ${DESTDIR}/apache-nutch-1.7.job
hadoop fs -copyToLocal ${LIBBUCKET}/${SEED_FILE}  ${DESTDIR}/apache-nutch-1.7.job
