#!/bin/bash

# Licensed Materials - Property of IBM
# IBM Sterling Selling and Fulfillment Suite
# (C) Copyright IBM Corp. 2001, 2013 All Rights Reserved.
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
        --namespace        [namespace]           - The name of the namespace OMS  deployment.
	USAGE
}

function namespace()
{

	cp scc.yaml scc.yaml.bak
	cp namespace.yaml namespace.yaml.bak
	sed -i -e "s/%NAMESPACE%/${NAMESPACE}/g" scc.yaml
	sed -i -e "s/%NAMESPACE%/${NAMESPACE}/g" namespace.yaml

	if [ `oc get projects | grep $NAMESPACE | wc -l` -gt 0 ]; then

	   echo "Namespace $NAMESPACE already exists. Selecting $NAMESPACE as  active  "
	   oc get project $NAMESPACE
	else
	   echo "Creating project $NAMESPACE for OMS Deployment"
	   oc create -f namespace.yaml
	#   oc new-project $NAMESPACE --description="OMS Deployment for $NAMESPACE" --display-name="OMS_$NAMESPACE"	
	   echo "Selecting $NAMESPACE as  active  "
	   oc get project $NAMESPACE
	fi

	echo "Creating Security Context Constraints for OMS on ${NAMESPACE} project"
	
	oc apply -f scc.yaml
	oc policy add-role-to-group system:image-puller system:serviceaccounts:${NAMESPACE} -n ${NAMESPACE}
	oc adm policy add-scc-to-user privileged  "system:serviceaccount:${NAMESPACE}:default"
	mv scc.yaml.bak scc.yaml
	mv namespace.yaml.bak namespace.yaml
}

function database()
{
#	echo "IBM DB2 container instantiation function here" 
	helm install --namespace $NAMESPACE --tiller-namespace tiller --name oms-db2-xx -f ibm-db2oltp-dev/values.yaml ./ibm-db2oltp-dev
}
	
function messaging()
{
	echo "IBM MQ container instantiation function here"
}

function buildOMS()
{
	echo "IBM Sterling OMS build function here"
}



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
        ;;
      --help|-h)
        usage >&2
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        usage >&2
        exit 1
        ;;
   esac
done

namespace
database
messaging
buildOMS
