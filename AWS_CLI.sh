#!/bin/bash

# AUTHOR: BALASEKHAR NELLI


# Shell script includes the following components:

# CREATING SECURITY GROUP AND AUTHORIZING PORTS 
# CREATING KEY PAIR AND DOWNLOADING IT TO LOCAL M/C
# CREATING UBUNTU EC2 INSTANCE USING AMI-ID
# INSTALLING PACKAGES ON EC2 INSTANCE
# ALLOCATING ELASTIC IP ADDRESS
# ASSIGNING ELASTIC IP ADDRESS TO EC2 INSTANCE 
# CREATING RDS INSTANCE
# CONNECT TO RDS FROM EC2

set -e
#------------
# VARIABLES #
#------------

AMI_ID="ami-fce3c696"
INSTANCE_TYPE="t2.micro"
EC2_BIN="aws --region us-east-1 ec2"
RDS_BIN="aws --region us-east-1 rds"
DB_ENGINE="mysql"
DB_USER="user"
DB_PASSWORD="password"
DB_IDENTIFIER="sg-cli-test"

#Cleaning Directory. To avoid conflicts if we run script more than once
rm -f /tmp/Auth_key.pem
rm -f /tmp/Output.txt

#-----------------------------------------------
# CREATING SECURITY GROUP AND AUTHORIZING PORTS#
#-----------------------------------------------

echo "Creating Security Group"
$EC2_BIN create-security-group \
--group-name Security_Group \
--description "Security Group 1" > output.txt  2>&1
for port in 22 80 3306
do
    $EC2_BIN authorize-security-group-ingress --group-name Security_Group --protocol tcp --port $port --cidr 0.0.0.0/0
done


#---------------------------------------
# CREATING KEY PAIR AND DOWNLOADING IT #
#---------------------------------------

echo "Creating Key pair"
$EC2_BIN create-key-pair \
--key-name Auth_key \
--query 'KeyMaterial' \
--output text > /tmp/Auth_key.pem

chmod 400 /tmp/Auth_key.pem


#-------------------------------
# CREATING UBUNTU EC2 INSTANCE #
#-------------------------------

echo "Launching instance"
$EC2_BIN run-instances \
--image-id $AMI_ID \
--count 1 \
--instance-type ${INSTANCE_TYPE} \
--key-name Auth_key \
--security-groups Security_Group > /tmp/Output.txt

INSTANCE_ID=$(cat /tmp/Output.txt | grep InstanceId|awk -F '"' '{print $4}')

#--------------------------------
# ALLOCATING ELASTIC IP ADDRESS #
#--------------------------------

$EC2_BIN allocate-address > /tmp/Output.txt

PUBLIC_IP=$(cat /tmp/Output.txt | grep PublicIp|awk -F '"' '{print $4}')


#-----------------------------------------------
# ASSIGNING ELASTIC IP ADDRESS TO EC2 INSTANCE #
#-----------------------------------------------

$EC2_BIN associate-address --instance-id $INSTANCE_ID --public-ip $PUBLIC_IP

#--------------------------------------
# INSTALLING PACKAGES ON EC2 INSTANCE #
#-------------------------------------

sleep 200
ssh -i /tmp/Auth_key.pem -o "StrictHostKeyChecking no" ubuntu@${PUBLIC_IP} "sudo apt-get update"
ssh -i /tmp/Auth_key.pem -o "StrictHostKeyChecking no" ubuntu@${PUBLIC_IP} "sudo apt-get install python mysql-client apache2 -y"

aws rds create-db-security-group --db-security-group-name rds_security_group --db-security-group-description "My new security group" > /tmp/Output.txt
OWNER_ID=$(cat /tmp/Output.txt | grep OwnerId | awk -F '"' '{print $4}')
aws rds authorize-db-security-group-ingress --db-security-group-name rds_security_group --ec2-security-group-name Security_Group --cidrip 0.0.0.0/0 --ec2-security-group-owner-id $OWNER_ID

#------------------------
# CREATING RDS INSTANCE #
#------------------------
$RDS_BIN create-db-instance \
--db-instance-identifier ${DB_IDENTIFIER} \
--allocated-storage 8 \
--db-instance-class db.t2.micro \
--engine ${DB_ENGINE} \
--master-username  ${DB_USER} --master-user-password ${DB_PASSWORD}

aws rds describe-db-instances --db-instance-identifier ${DB_IDENTIFIER} > /tmp/Output.txt
DB_HOSTNAME=$(cat /tmp/Output.txt|grep Address|awk -F '"' '{print $4}')

#--------------------------
# CONNECT TO RDS FROM EC2 #
#--------------------------

ssh -i /tmp/Auth_key.pem -o "StrictHostKeyChecking no" ubuntu@${PUBLIC_IP} "mysql -h ${DB_HOSTNAME}  -u ${DB_USER} -p ${DB_PASSWORD}"

