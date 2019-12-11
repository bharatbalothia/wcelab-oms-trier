#!/bin/bash

# Licensed Materials - Property of IBM
# IBM Sterling Selling and Fulfillment Suite
# (C) Copyright IBM Corp. 2001, 201SCHEMA_TYPE= $(SCHEMA_TYPE) "3All Rights Reserved.
# US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.

##############################################################
# Shell Script For Triggering OpenShift deployment
#############################################################

function usage()
{

	cat <<-USAGE #| fmt
    	
        Usage: $0 [OPTIONS] [arg]
        OPTIONS:
        =======
        
        --namespace        [namespace]           - The name of the RHOS project to create/use for DB2/MQ prerequisite creation
        --deployOMS        [namespace]		 - The name of the RHOS	project on which to DEPLOY OMS
        
        !!!! PLEASE ENSURE YOU ARE LOGGED INTO RHOS BEFORE EXECUTING THIS SCRIPT !!!!

	This scipt is 2 parts:

        1) --namespace builds out the DB2 and MQ instances on RHOS as PREREQS for deploying OMS on RHOS
        2) --deployOMS deploys a UBI version of OMS with console and SBC (app) and agent servers

        If you need to create the prerequisite project with DB2 and MQ,
        then run the script using the --namespace arg and value: $0 --namespace <projectname>

        If you already have a RHOS project with DB2 and MQ created and ready for OMS on RHOS, 
        run this script with --deployOMS and the project name: $0 --deployOMS <projectname>

	USAGE
}

function namespace()
{

	cp ./helm-charts/scc.yaml ./helm-charts/scc.yaml.bak
	cp ./helm-charts/namespace.yaml ./helm-charts/namespace.yaml.bak
	sed -i -e "s/%NAMESPACE%/${NAMESPACE}/g" ./helm-charts/scc.yaml
	sed -i -e "s/%NAMESPACE%/${NAMESPACE}/g" ./helm-charts/namespace.yaml
	

	if [ `oc get projects | grep $NAMESPACE | wc -l` -gt 0 ]; then

	   echo "Namespace $NAMESPACE already exists. Selecting $NAMESPACE as  active  "
	else
	   echo "Creating project $NAMESPACE for OMS Deployment"
	   oc create -f ./helm-charts/namespace.yaml
	#   oc new-project $NAMESPACE --description="OMS Deployment for $NAMESPACE" --display-name="OMS_$NAMESPACE"	
	   echo "Selecting $NAMESPACE as active"
	#   oc get project $NAMESPACE
	fi

	export OCNAMESPACE=$NAMESPACE
	sleep 10s
	oc project $NAMESPACE

	echo "Creating Security Context Constraints for OMS on ${NAMESPACE} project"
	
	oc policy add-role-to-group system:image-puller system:serviceaccounts:${NAMESPACE} -n ${NAMESPACE}
	oc adm policy add-scc-to-user privileged  "system:serviceaccount:${NAMESPACE}:default"
	oc create sa mq-sa
	oc apply -f ./helm-charts/mq_scc.yaml
	oc adm policy add-scc-to-user ibm-mq-dev-scc "system:serviceaccount:${NAMESPACE}:mq-sa"
	mv ./helm-charts/scc.yaml.bak ./helm-charts/scc.yaml
	mv ./helm-charts/namespace.yaml.bak ./helm-charts/namespace.yaml
}

function demoReset()
{
	echo "Reseting OMS on RHOS Project"
	./buildReset.sh

}

function createSecret()
{
	echo "Creating Secret for MQ"
#	cp ./helm-charts/mq-secret.yaml ./helm-charts/mq-secret.yaml.bak
#	sed -i -e "s/%SECRETNAME%/${SECRETNAME}/g" ./helm-charts/mq-secret.yaml
	oc create -f ./helm-charts/mq-secret.yaml
}

function database()
{
#	echo "IBM DB2 container instantiation function here" 
	helm install --namespace $NAMESPACE --tiller-namespace tiller --name oms-db-$BUILDSUFFIX  -f ./helm-charts/ibm-db2oltp-dev/values.yaml ./helm-charts/ibm-db2oltp-dev
}
	
function messaging()
{
#	echo "IBM MQ container instantiation function here"
	helm install --namespace $NAMESPACE --tiller-namespace tiller --name oms-mq-$BUILDSUFFIX -f ./helm-charts/ibm-mqadvanced-server-dev/values.yaml ./helm-charts/ibm-mqadvanced-server-dev
}

function applyYaml()
{
	oc apply -f $1
}

function setApplyOMSSecret()
{
	cp ./helm-charts/omsSecret.yaml ./helm-charts/omsSecret.yaml.bak
        sed -i -e "s/%LIBERTY_ADMIN_PWORD%/${LIBERTY_ADMIN_PWORD}/g" ./helm-charts/omsSecret.yaml
	sed -i -e "s/%LIBERTY_CONSOLE_PWORD%/${LIBERTY_CONSOLE_PWORD}/g" ./helm-charts/omsSecret.yaml
	sed -i -e "s/%DB_PWORD%/${DB_PWORD}/g" ./helm-charts/omsSecret.yaml
#	applyYaml "./helm-charts/omsSecret.yaml"
	mv ./helm-charts/omsSecret.yaml.bak ./helm-charts/omsSecret.yaml
}

function setApplyDB2LB ()
{
	cp ./helm-charts/db2LBforpublicAccess.yaml ./helm-charts/db2LBforpublicAccess.yaml.bak
        sed -i -e "s/%DB_PORT%/${DB_PORT}/g" ./helm-charts/db2LBforpublicAccess.yaml
        sed -i -e "s/%DB2_SVC_HOSTNAME%/${DB2_SVC_HOSTNAME}/g" ./helm-charts/db2LBforpublicAccess.yaml
#	applyYaml "./helm-charts/db2LBforpublicAccess.yaml"
	mv ./helm-charts/db2LBforpublicAccess.yaml.bak ./helm-charts/db2LBforpublicAccess.yaml

}

function editMultischemaxml ()
{
	cp ./helm-charts/ibm-oms-ent-prod/config/multischema.xml ./helm-charts/ibm-oms-ent-prod/config/multischema.xml.bak
	sed -i -e "s/%DB_SVC_HOSTNAME%/${DB_SVC_HOSTNAME}/g" ./helm-charts/ibm-oms-ent-prod/config/multischema.xml
	sed -i -e "s/%DB_PORT%/${DB_PORT}/g" ./helm-charts/ibm-oms-ent-prod/config/multischema.xml
	sed -i -e "s/%DB_UNAME%/${DB_UNAME}/g" ./helm-charts/ibm-oms-ent-prod/config/multischema.xml
	sed -i -e "s/%DB_PWORD%/${DB_PWORD}/g" ./helm-charts/ibm-oms-ent-prod/config/multischema.xml
	sed -i -e "s/%MASTER_SCHEMA_NAME%/${MASTER_SCHEMA_NAME}/g" ./helm-charts/ibm-oms-ent-prod/config/multischema.xml
	sed -i -e "s/%TRANS_SCHEMA_NAME%/${TRANS_SCHEMA_NAME}/g" ./helm-charts/ibm-oms-ent-prod/config/multischema.xml
	sed -i -e "s/%STATS_SCHEMA_NAME%/${STATS_SCHEMA_NAME}/g" ./helm-charts/ibm-oms-ent-prod/config/multischema.xml
	sed -i -e "s/%CONFIG_SCHEMA_NAME%/${CONFIG_SCHEMA_NAME}/g" ./helm-charts/ibm-oms-ent-prod/config/multischema.xml
}

function createDBSchema ()
{

	if [ "${SCHEMA_TYPE^^}" == 'S' ]; then
		printf "\nPreparing helm charts for SINGLE schema instance.\n"
		cp ./helm-charts/ibm-oms-ent-prod/values.yaml ./helm-charts/ibm-oms-ent-prod/values.yaml.bak
		sed -i -e "s/%SCHEMA_NAME%/OMS_$RHOS_PROJ_NAME/g" ./helm-charts/ibm-oms-ent-prod/values.yaml
		export OMS_SCHEMA_NAME=TEST_OMS_${RHOS_PROJ_NAME^^}
#		export OMS_SCHEMA_NAME=OMS_${RHOS_PROJ_NAME^^}
		OMS_SCHEMA_NAME=${OMS_SCHEMA_NAME//-/_}
	elif [ "${SCHEMA_TYPE^^}" == 'M' ]; then
		printf "\nPreparing helm charts for MULTI schema instance.\n"
		cp ./helm-charts/ibm-oms-ent-prod/values.yaml ./helm-charts/ibm-oms-ent-prod/values.yaml.bak
		sed -i -e "s/%SCHEMA_NAME%/META_$RHOS_PROJ_NAME/g" ./helm-charts/ibm-oms-ent-prod/values.yaml
		export OMS_SCHEMA_NAME=TEST_META_${RHOS_PROJ_NAME^^}
#		export OMS_SCHEMA_NAME=META_${RHOS_PROJ_NAME^^}
		export TRANS_SCHEMA_NAME=TEST_TRANS_${RHOS_PROJ_NAME^^}
#		export TRANS_SCHEMA_NAME=TRANS_${RHOS_PROJ_NAME^^}
		export MASTER_SCHEMA_NAME=TEST_MASTER_${RHOS_PROJ_NAME^^}
#		export MASTER_SCHEMA_NAME=MASTER_${RHOS_PROJ_NAME^^}
		export STATS_SCHEMA_NAME=TEST_STATS_${RHOS_PROJ_NAME^^}
#		export STATS_SCHEMA_NAME=STATS_${RHOS_PROJ_NAME^^}
		export CONFIG_SCHEMA_NAME=TEST_CONFIG_${RHOS_PROJ_NAME^^}
#		export CONFIG_SCHEMA_NAME=CONFIG_${RHOS_PROJ_NAME^^}
		OMS_SCHEMA_NAME=${OMS_SCHEMA_NAME//-/_}
		TRANS_SCHEMA_NAME=${TRANS_SCHEMA_NAME//-/_}
		MASTER_SCHEMA_NAME=${MASTER_SCHEMA_NAME//-/_}
		STATS_SCHEMA_NAME=${STATS_SCHEMA_NAME//-/_}
		CONFIG_SCHEMA_NAME=${CONFIG_SCHEMA_NAME//-/_}
	else
	        printf "\nInvalid Schema type entered. Exiting deployment script.\n"	
		exit 2 #CODE 2 - INVALID SCHEMA TYPE ENTERED
	fi

	printf "\n\tSchema to be created:  $OMS_SCHEMA_NAME \n"

	if [ "${SCHEMA_TYPE^^}" == 'M' ]; then
		printf "\nThe additional schema names to be created for the multi-schema DB are as follows: \n"
		printf "\n\t Transactional data schema name: ${TRANS_SCHEMA_NAME}"
		printf "\n\t Master data schema name       : ${MASTER_SCHEMA_NAME}"
		printf "\n\t Statistical data schema name  : ${STATS_SCHEMA_NAME}"
		printf "\n\t Configuration data schema name: ${CONFIG_SCHEMA_NAME}\n\n"
	fi

	read -n 1 -s -r -p "Press any key to continue or CTRL-C to exit now"
	
	
	printf "\nConnecting to database ibmoms as user $DB_UNAME...\n"
	printf "\n\toc exec $DB_PODNAME -i -t /opt/ibm/db2/V11.5/bin/db2 CONNECT to ibmoms user $DB_UNAME using $DB_PWORD\n"
	oc exec $DB_PODNAME -i -t /opt/ibm/db2/V11.5/bin/db2 CONNECT to ibmoms user $DB_UNAME using $DB_PWORD
	printf "\nCreating schema $OMS_SCHEMA_NAME..."
	printf "\n\toc exec $DB_PODNAME -i -t /opt/ibm/db2/V11.5/bin/db2 create schema $OMS_SCHEMA_NAME"
	oc exec $DB_PODNAME -i -t /opt/ibm/db2/V11.5/bin/db2 create schema $OMS_SCHEMA_NAME

	if [ "${SCHEMA_TYPE^^}" == 'M' ]; then
		printf "\nCreating schema $TRANS_SCHEMA_NAME..."
		oc exec $DB_PODNAME -i -t /opt/ibm/db2/V11.5/bin/db2 create schema $TRANS_SCHEMA_NAME
		printf "\nCreating schema $MASTER_SCHEMA_NAME..."
		oc exec $DB_PODNAME -i -t /opt/ibm/db2/V11.5/bin/db2 create schema $MASTER_SCHEMA_NAME
		printf "\nCreating schema $STATS_SCHEMA_NAME..."
		oc exec $DB_PODNAME -i -t /opt/ibm/db2/V11.5/bin/db2 create schema $STATS_SCHEMA_NAME
		printf "\nCreating schema $CONFIG_SCHEMA_NAME..."
		oc exec $DB_PODNAME -i -t /opt/ibm/db2/V11.5/bin/db2 create schema $CONFIG_SCHEMA_NAME
	
	editMultischemaxml	
	
	
	fi	
}


function deployOMS()
{
	
	echo $NAMESPACE
	printf "\nValidating RHOS project. Please wait...\n"
	#get needed values for deployment
	if [ `oc get projects | grep $NAMESPACE | wc -l` -eq 0 ]; then
		 printf "\nRHOS Namespace $NAMESPACE does not exist or is not accessible. Exiting OMS Deployment.\n"
		 exit 1 # Code 1 - RHOS DOES NOT EXIST OR IS NOT ACCESSIBLE
	fi
	 	
	export RHOS_PROJ_NAME=$NAMESPACE

	promptForInput "Please enter the WAS Liberty Console ADMIN password:" LIBERTY_ADMIN_PWORD
	promptForInput "Please enter the WAS Liberty Console password:" LIBERTY_CONSOLE_PWORD
	promptForInput "Please enter the DB2 password:" DB_PWORD

	printf "\nGetting the default secret...\n"
#	kubectl -n default get secret default-us-icr-io -o yaml | sed "s/default/$RHOS_PROJ_NAME/g" | kubectl -n $RHOS_PROJ_NAME create -f -
	printf "\nApplying OMS Secret yaml...\n"
	setApplyOMSSecret

	promptForInput "Will this be a (S)ingle or (M)ulti schema OMS instance? Please enter 'S' or 'M': " SCHEMA_TYPE
	promptForInput "Please enter the DB2 username:" DB_UNAME
	promptForInput "Please enter the DB2 pod name:" DB_PODNAME
 	promptForInput "Please enter the DB2 port:" DB_PORT
	promptForInput "Please enter the DB2 Service hostname: " DB_SVC_HOSTNAME

	printf "\nCreating load balancer for DB access...\n "	
	setApplyDB2LB

	createDBSchema


#	helm install --name $RHOS_PROJ_NAME -f ./ibm-oms-ent-prod/values.yaml ./ibm-oms-ent-prod --timeout 3600 --namespace $RHOS_PROJ_NAME --tiller-namespace tiller
}
function createPrereqs()
{
	namespace
	createSecret
	database	
	messaging

	echo "oc project ${NAMESPACE}" > buildReset.sh
	echo "helm del --purge oms-db-${BUILDSUFFIX} --tiller-namespace tiller" >> buildReset.sh
	echo "helm del --purge oms-mq-${BUILDSUFFIX} --tiller-namespace tiller" >> buildReset.sh
	echo "oc delete secret ${SECRETNAME}" >> buildReset.sh
	echo "oc delete project ${NAMESPACE}" >> buildReset.sh
	chmod 777 ./buildReset.sh

}

function promptForInput
{
	INPUT=''

	while [ "$INPUT" == "" ]
	do
		read -p "$1 " INPUT

		if [[ -z "$INPUT" ]]; then
	           printf '%s\n' "No input entered. Repsonse is required."	
		fi
	done

	export $2=$INPUT

}	

BUILDSUFFIX=01
SECRETNAME=mq-secret


if [ "$#" -lt 1 ]; then
   usage >&2
   exit 1
fi

while [ -n "$1" ]
do
   case $1 in
      --namespace)
        NAMESPACE=$2
        shift 2
	createPrereqs
        ;;
      --reset)
        demoReset
	;;	
      --help|-h)
        usage >&2
        exit 0
        ;;
      --deployOMS)
        NAMESPACE=$2
	shift 2
	deployOMS
	;;
      *)
        echo "Unknown option: $1"
        usage >&2
        exit 1
        ;;
   esac
done
