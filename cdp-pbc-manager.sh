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
echo "Starting CDP Public Cloud Manager" 

# Required
export CLUSTER_NAME=""
export WHITELIST_IPS=""
export CLOUD_PROVIDER=""

## For Azure
export AZ_ARM_CLIENT_ID=""
export AZ_ARM_CLIENT_SECRET=""
export AZ_ARM_TENANT_ID=""
export AZ_ARM_SUBSCRIPTION_ID="" 
export SSH_USER_KEY=""

## For AWS
export AWS_AWS_ACCESS_KEY_ID=""
export AWS_AWS_SECRET_ACCESS_KEY=""
export AWS_KEY_PAIR=""

# Optional 
export ACTION="create"
export SCOPE="dl"
export DEPLOYMENT_TYPE="public"
export DEBUG="false"

## For AWS
export AWS_REGION="eu-west-3"

## For Azure
export AZ_REGION="eastus"

#### DATA SERVICES ####
#### DATAHUB
DH_NAME=
DH_TEMPLATE="data-eng" # Can be : data-eng ; data-mart ; streaming ; data-flow ; data-discovery

#### CDE
CDE_SERVICE_NAME=

#### CML


#### CDW


#### CDF


#### COD



## INTERNAL
TEST=false
SCOPE_DL=false
SCOPE_DH=false
SCOPE_CDE=false
SCOPE_CDW=false
SCOPE_CML=false
SCOPE_CDF=false
SCOPE_COD=false


function usage()
{
    echo "This script aims to create, start, stop or delete a Cloudera Public Cloud Cluster"
    echo ""
    echo "Usage is the following : "
    echo ""
    echo "./cdp-pbc-manager.sh"
    echo "  -h --help"
    echo "  --cluster-name=$CLUSTER_NAME Required as it will be the name of the cluster (Default) "
    echo "  --whitelist-ips=$WHITELIST_IPS Required to access the cluster (Default) "
    echo "  --cloud-provider=$CLOUD_PROVIDER Required to know on which cloud to deploy, either: aws, azure or gcp (Default) "
    echo ""
    echo " Required for Azure: "
    echo "  --arm-client-id=$AZ_ARM_CLIENT_ID Required to create machines (Default) "
    echo "  --arm-client-secret=$AZ_ARM_CLIENT_SECRET Required to create machines (Default) "
    echo "  --arm-tenant-id=$AZ_ARM_TENANT_ID Required to create machines (Default) "
    echo "  --arm-subscription-id=$AZ_ARM_SUBSCRIPTION_ID Required to create machines (Default) "
    echo "  --ssh-user-key=$SSH_USER_KEY Required to acces the cluster (Default) "
    echo ""
    echo " Required for AWS: "
    echo "  --aws-access-key-id=$AWS_AWS_ACCESS_KEY_ID Required to create machines (Default) "
    echo "  --aws-access-key-secret=$AWS_AWS_SECRET_ACCESS_KEY Required to create machines (Default) "
    echo "  --aws-key-pair=$AWS_KEY_PAIR Required to access the cluster (Default) "
    echo ""
    echo " Optional: "
    echo "  --action=$ACTION Required to know what to do, to choose between: create, start, stop or delete (Default) $ACTION"
    echo "  --scope=$SCOPE Required to know on what to exec actions: all, dl, dh, cde, cml, cdw, cdf, cod (Default) $SCOPE"
    echo "  --deployment-type=$DEPLOYMENT_TYPE Deployment type between: public, private or semi-private (Default) $DEPLOYMENT_TYPE "
    echo "  --aws-region=$AWS_REGION (Default) $AWS_REGION "
    echo "  --az-region=$AZ_REGION (Default) $AZ_REGION "
    echo ""
    echo " Optional Specific to Data Services: "
    echo " --dh-template=$DH_TEMPLATE Can be : data-eng ; data-mart ; streaming ; data-flow ; data-discovery (Default) $DH_TEMPLATE"
    echo " --dh-name=$DH_NAME To specify different Datahub names (if creating multiple datahubs on one datalake) (Default) $DH_NAME"
    echo ""
    echo "  --debug=$DEBUG (Default) $DEBUG "
    echo ""
}

while [ "$1" != "" ]; do
    PARAM=`echo $1 | awk -F= '{print $1}'`
    VALUE=`echo $1 | awk -F= '{print $2}'`
    case $PARAM in
        -h | --help)
            usage
            exit
            ;;
        --cluster-name)
            CLUSTER_NAME=$VALUE
            ;;    
        --whitelist-ips)
            WHITELIST_IPS=$VALUE
            ;;
        --cloud-provider)
            CLOUD_PROVIDER=$VALUE
            ;;
        --arm-client-id)
            AZ_ARM_CLIENT_ID=$VALUE
            ;; 
        --arm-client-secret)
            AZ_ARM_CLIENT_SECRET=$VALUE
            ;;
        --arm-tenant-id)
            AZ_ARM_TENANT_ID=$VALUE
            ;;
        --arm-subscription-id)
            AZ_ARM_SUBSCRIPTION_ID=$VALUE
            ;;
        --ssh-user-key)
            SSH_USER_KEY=$VALUE
            ;;
        --aws-access-key-id)
            AWS_AWS_ACCESS_KEY_ID=$VALUE
            ;;
        --aws-access-key-secret)
            AWS_AWS_SECRET_ACCESS_KEY=$VALUE
            ;;
        --aws-key-pair)
            AWS_KEY_PAIR=$VALUE
            ;;
        --action)
            ACTION=$VALUE
            ;;
        --scope)
            SCOPE=$VALUE
            ;;
        --deployment-type)
            DEPLOYMENT_TYPE=$VALUE
            ;;
        --aws-region)
            AWS_REGION=$VALUE
            ;;
        --az-region)
            AZ_REGION=$VALUE
            ;;
        --test)
            TEST=$VALUE
            ;;   
        --debug)
            DEBUG=$VALUE
            ;; 
        --dh-template)
            DH_TEMPLATE=$VALUE
            ;;
        --dh-name)
            DH_NAME=$VALUE
            ;;  
        *)
            ;;
    esac
    shift
done

# Load functions
. ./actions.sh

# TODO: Implement Checks on params passed

# Check and setup scope of script
if [ -z ${SCOPE} ] 
then 
    export SCOPE="dl"
fi
if [ $SCOPE == "all" ]
then
    export SCOPE_DL=true
    export SCOPE_DH=true
    export SCOPE_CDE=true
    export SCOPE_CDW=true
    export SCOPE_CML=true
    export SCOPE_CDF=true
    export SCOPE_COD=true
fi
if [[ ${SCOPE} == *"dl"* ]]
then
    export SCOPE_DL=true
fi
if [[ "${SCOPE}" == *"dh"* ]]
then
    export SCOPE_DH=true
    if [ -z $DH_NAME ] ; then
        DH_NAME=${CLUSTER_NAME}-dh
    fi
    if [ -z $DH_TEMPLATE ] ; then
        DH_TEMPLATE="data-eng"
    fi
fi
if [[ "${SCOPE}" == *"cde"* ]]
then
    export SCOPE_CDE=true
fi
if [[ "${SCOPE}" == *"cdw"* ]]
then
    export SCOPE_CDW=true
fi
if [[ "${SCOPE}" == *"cml"* ]]
then
    export SCOPE_CML=true
fi
if [[ "${SCOPE}" == *"cdf"* ]]
then
    export SCOPE_CDF=true
fi
if [[ "${SCOPE}" == *"cod"* ]]
then
    export SCOPE_COD=true
fi

ENV_NAME="${CLUSTER_NAME}-cdp-env"


if [ "${DEBUG}" == "true" ]
then
    echo ""
    echo "****************************** ENV VARIABLES ******************************"
    env | sort 
    echo "***************************************************************************"
    echo ""
    set -o xtrace
fi

if [ "${TEST}" = true ]
then
    exit
fi


##### CREATION #####
if [ "${ACTION}" == "create" ]
then
    if [ "${SCOPE_DL}" = true ]
    then
        echo "Creating Environment"
        cd ../cdp-tf-quickstarts/
        ./setup-cluster.sh \
            --cloud-provider=$CLOUD_PROVIDER \
            --action=$ACTON \
            --cluster-name=$CLUSTER_NAME \
            --whitelist-ips="$WHITELIST_IPS" \
            --arm-client-id=$AZ_ARM_CLIENT_ID \
            --arm-client-secret=$AZ_ARM_CLIENT_SECRET \
            --arm-tenant-id=$AZ_ARM_TENANT_ID \
            --arm-subscription-id=$AZ_ARM_SUBSCRIPTION_ID \
            --ssh-user-key="$SSH_USER_KEY" \
            --aws-access-key-id=$AWS_AWS_ACCESS_KEY_ID \
            --aws-access-key-secret=$AWS_AWS_SECRET_ACCESS_KEY \
            --aws-key-pair=$AWS_KEY_PAIR 
        cd ../one-script-deploy-public-cloud/
    fi

    # TODO: Provision other on top of the DL: DataHub, CDW, CDE, CML, CDF, COD
    if [ "${SCOPE_DH}" = true ]
    then
        echo "Creating Datahub with parameters: $CLOUD_PROVIDER $ENV_NAME $DH_NAME $DH_TEMPLATE"
        create_dh $CLOUD_PROVIDER $ENV_NAME $DH_NAME $DH_TEMPLATE
    fi

    # TODO: Wait for everything to be running
    if [ "${SCOPE_DH}" = true ]
    then
        echo "Checking Datahub is AVAILABLE"
        dh_status $ENV_NAME $DH_NAME "AVAILABLE"
    fi


fi


##### DELETION #####
if [ "${ACTION}" == "delete" ]
then
    # TODO: Delete everything on top of the DL: DataHub, CDW, CDE, CML, CDF, COD

    # TODO: Wait for everything to be deleted
    if [ "${SCOPE_DH}" = true ]
    then
        echo "Deleting Datahub"
        delete_dh $ENV_NAME $DH_NAME
        dh_status $ENV_NAME $DH_NAME ''
    fi

    if [ "${SCOPE_DL}" = true ]
    then
        echo "Deleting Environment"
        cd ../cdp-tf-quickstarts/
        ./setup-cluster.sh \
            --cloud-provider=$CLOUD_PROVIDER \
            --action=$ACTON \
            --cluster-name=$CLUSTER_NAME \
            --whitelist-ips="$WHITELIST_IPS" \
            --arm-client-id=$AZ_ARM_CLIENT_ID \
            --arm-client-secret=$AZ_ARM_CLIENT_SECRET \
            --arm-tenant-id=$AZ_ARM_TENANT_ID \
            --arm-subscription-id=$AZ_ARM_SUBSCRIPTION_ID \
            --ssh-user-key=$SSH_USER_KEY \
            --aws-access-key-id=$AWS_AWS_ACCESS_KEY_ID \
            --aws-access-key-secret=$AWS_AWS_SECRET_ACCESS_KEY \
            --aws-key-pair=$AWS_KEY_PAIR 
        cd ../one-script-deploy-public-cloud/
    fi
fi


##### STOP #####
if [ "${ACTION}" == "stop" ]
then
    # TODO: Stop everything on top of the DL: DataHub, CDW, CDE, CML, CDF, COD
    if [ "${SCOPE_DH}" = true ]
    then
        echo "Stopping Datahub"
        stop_dh $ENV_NAME $DH_NAME 
    fi

    # TODO: Wait for everything to be stopped
    if [ "${SCOPE_DH}" = true ]
    then
        echo "Checking Datahub is Stopped"
        dh_status $ENV_NAME $DH_NAME "STOPPED"
    fi

    if [ "${SCOPE_DL}" = true ]
    then
        echo "Stopping Environment"
        stop_env $ENV_NAME
    fi
fi


##### START #####
if [ "${ACTION}" == "start" ]
then
    if [ "${SCOPE_DL}" = true ]
    then
        echo "Starting Environment"
        start_env $ENV_NAME
    fi

    # TODO: Start everything on top of the DL: DataHub, CDW, CDE, CML, CDF, COD 
    if [ "${SCOPE_DH}" = true ]
    then
        echo "Starting Datahub"
        start_dh $ENV_NAME $DH_NAME 
    fi

    # TODO: Wait for everything to be started
    if [ "${SCOPE_DH}" = true ]
    then
        echo "Checking Datahub is AVAILABLE"
        dh_status $ENV_NAME $DH_NAME "AVAILABLE"
    fi
fi

set +o xtrace
echo "Finished CDP Public Cloud Manager" 