#!/bin/bash
#
#PROGRAM: S3Purge.sh
#AUTHOR: BALASEKHAR NELLI
#VERSION: 2.0.0
#DATE: 3/3/2016
#

#A script to purge the objects of S3 bucket.

#
##VARIABLES
#
set -e

S3_BIN="aws s3"
BUCKET_NAME="xxxxxxx-xxxx"
ThirtyDaysInSecs="2592000"
ThirtyDaysOldToBuildDate=$(expr $BuildDate - $ThirtyDaysInSecs)

#Capturing Jenkins job Build time from the follwoing file.
$S3_BIN cp s3://${BUCKET_NAME}/DateFile /tmp/DateFile

BuildDate=`cat /tmp/DateFile|awk {'print $1" "$2'}`
BuildDate=`date -d"$BuildDate" +%s`

$S3_BIN ls s3://${BUCKET_NAME}/test/ --recursive |sed -e '1d'|while read -r line;do
        FileDate=`echo $line|awk {'print $1" "$2'}`
        FileDate=`date -d"$FileDate" +%s`

        if [[ $FileDate -lt $ThirtyDaysOldToBuildDate ]]
        then
        FileName=`echo $line|awk {'print $4'}`
                if [[ $FileName != "" ]]
                then
                        #echo $FileName
                        $S3_BIN rm s3://${BUCKET_NAME}/${FileName}
                fi
        fi
done
