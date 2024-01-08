#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
#!/bin/bash

# This is a list of common functions using cdp cli to create/delete/start/stop DS

#########################
##### ENV FUNCTIONS #####
#########################

function env_status() {
    local ENV_NAME=$1
    if [ -z $ENV_NAME ] ; then
        echo "Cannot get an empty env"
        exit 1
    fi
    ENV_STATUS=$(cdp environments list-environments | jq -r ".environments[] | select(.environmentName == \"${ENV_NAME}\") | .status")
    echo "$ENV_NAME is in state: $ENV_STATUS"
}

function start_env() {
    local ENV_NAME=$1
    env_status $ENV_NAME
    if [ "$ENV_STATUS" == *"FAILED"* ] ; then
        echo "Could not start a failed env: $ENV_NAME"
    else 
        cdp environments start-environment --environment-name $ENV_NAME --with-datahub-start
        sleep 10
        env_status $ENV_NAME
        while [ "$ENV_STATUS" != "AVAILABLE" ] ; do
            sleep 60
            env_status $ENV_NAME
        done
    fi
}

function stop_env() {
    local ENV_NAME=$1
    env_status $ENV_NAME
    if [  "$ENV_STATUS" != 'AVAILABLE' ] ; then
        echo "Could not start a non-started env: $ENV_NAME"
    else 
        cdp environments stop-environment --environment-name $ENV_NAME 
        sleep 10
        env_status $ENV_NAME
        while [ "$ENV_STATUS" != "ENV_STOPPED" ] ; do
            sleep 60
            env_status $ENV_NAME
        done
    fi
}

#########################
##### DataHub FUNCTIONS #####
#########################

function dh_crn() {
    local ENV_NAME=$1
    local DH_NAME=$2

    DH_CRN=$(cdp datahub list-clusters  --environment-name $ENV_NAME | jq -r ".clusters[] | select(.clusterName == \"${DH_NAME}\") | .crn")
    echo "CRN for $DH_NAME in $ENV_NAME is: $DH_CRN"
}

function dh_status() {
    local ENV_NAME=$1
    local DH_NAME=$2
    local EXPECTED_STATUS=$3

    dh_crn $ENV_NAME $DH_NAME
    DH_STATUS=""
   while true ; do
        DH_STATUS=$(cdp datahub describe-cluster --cluster-name $DH_CRN | jq -r ".cluster.status")
        echo "$DH_NAME is in state: $DH_STATUS"
        if [ "$DH_STATUS" == "$EXPECTED_STATUS" ] ; then break ; fi
        sleep 60
    done

}

function create_dh() {
    local CLOUD_PROVIDER=$1
    local ENV_NAME=$2
    local DH_NAME=$3
    local DH_TEMPLATE=$4

    if [ "${CLOUD_PROVIDER}" == "azure" ] ; then
        case $DH_TEMPLATE in
            "data-eng")
                DH_TEMPLATE_NAME="7.2.17 - Data Engineering: Apache Spark, Apache Hive, Apache Oozie" 
                DH_INSTANCE_GROUPS='nodeCount=1,instanceGroupName=master,instanceGroupType=GATEWAY,instanceType=Standard_D16_v3,rootVolumeSize=100,attachedVolumeConfiguration=[{volumeSize=100,volumeCount=1,volumeType=StandardSSD_LRS}],recoveryMode=MANUAL nodeCount=3,instanceGroupName=worker,instanceGroupType=CORE,instanceType=Standard_D5_v2,rootVolumeSize=100,attachedVolumeConfiguration=[{volumeSize=100,volumeCount=1,volumeType=StandardSSD_LRS}],recoveryMode=MANUAL nodeCount=1,instanceGroupName=compute,instanceGroupType=CORE,instanceType=Standard_D5_v2,rootVolumeSize=100,attachedVolumeConfiguration=[{volumeSize=100,volumeCount=0,volumeType=StandardSSD_LRS}],recoveryMode=MANUAL nodeCount=0,instanceGroupName=gateway,instanceGroupType=CORE,instanceType=Standard_D8_v3,rootVolumeSize=100,attachedVolumeConfiguration=[{volumeSize=100,volumeCount=1,volumeType=StandardSSD_LRS}],recoveryMode=MANUAL'
                DH_IMAGE="id=c59551fd-4bc6-400a-9a4e-04c63181bbde,catalogName=cdp-default"
                ;;
        esac    
        
    elif [ "${CLOUD_PROVIDER}" == "aws" ] ; then
        case $DH_TEMPLATE in
            "data-eng")
                DH_TEMPLATE_NAME="7.2.17 - Data Engineering: Apache Spark, Apache Hive, Apache Oozie" 
                DH_INSTANCE_GROUPS='nodeCount=1,instanceGroupName=master,instanceGroupType=GATEWAY,instanceType=m5.4xlarge,rootVolumeSize=100,attachedVolumeConfiguration=[{volumeSize=100,volumeCount=1,volumeType=gp3}],recoveryMode=MANUAL,volumeEncryption={enableEncryption=true} nodeCount=3,instanceGroupName=worker,instanceGroupType=CORE,instanceType=r5d.2xlarge,rootVolumeSize=100,attachedVolumeConfiguration=[{volumeSize=100,volumeCount=1,volumeType=gp3}],recoveryMode=MANUAL,volumeEncryption={enableEncryption=true} nodeCount=1,instanceGroupName=compute,instanceGroupType=CORE,instanceType=r5d.2xlarge,rootVolumeSize=100,attachedVolumeConfiguration=[{volumeSize=300,volumeCount=1,volumeType=ephemeral}],recoveryMode=MANUAL,volumeEncryption={enableEncryption=true} nodeCount=0,instanceGroupName=gateway,instanceGroupType=CORE,instanceType=m5.2xlarge,rootVolumeSize=100,attachedVolumeConfiguration=[{volumeSize=100,volumeCount=1,volumeType=gp3}],recoveryMode=MANUAL,volumeEncryption={enableEncryption=true}'
                DH_IMAGE="id=ef04feea-115c-41ea-8228-2af6d2a27099,catalogName=cdp-default"
                ;;
        esac    
    elif [ "${CLOUD_PROVIDER}" == "gcp" ] ; then  
        DH_TEMPLATE_NAME="" 
        DH_INSTANCE_GROUPS=""
        DH_IMAGE=""
    fi

    cdp datahub create-${CLOUD_PROVIDER}-cluster \
        --cluster-name $DH_NAME \
        --environment-name $ENV_NAME \
        --no-enable-load-balancer \
        --image "$DH_IMAGE" \
        --instance-groups $( echo "$DH_INSTANCE_GROUPS" | tr -d "'") \
        --cluster-template-name "$DH_TEMPLATE_NAME"
}

function delete_dh() {
    local ENV_NAME=$1
    local DH_NAME=$2

    dh_crn $ENV_NAME $DH_NAME

    cdp datahub delete-cluster --cluster-name $DH_CRN
}

function start_dh() {
    local ENV_NAME=$1
    local DH_NAME=$2

    dh_crn $ENV_NAME $DH_NAME

    cdp datahub start-cluster --cluster-name $DH_CRN
}

function stop_dh() {
    local ENV_NAME=$1
    local DH_NAME=$2

    dh_crn $ENV_NAME $DH_NAME

    cdp datahub stop-cluster --cluster-name $DH_CRN
}


#########################
##### CML FUNCTIONS #####
#########################


#########################
##### CDE FUNCTIONS #####
#########################


#########################
##### CDW FUNCTIONS #####
#########################


#########################
##### COD FUNCTIONS #####
#########################


#########################
##### CDF FUNCTIONS #####
#########################