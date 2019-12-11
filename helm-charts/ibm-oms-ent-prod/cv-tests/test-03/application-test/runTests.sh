# Licensed Materials - Property of IBM
# IBM Order Management Software (5725-D10)
# (C) Copyright IBM Corp. 2019 All Rights Reserved.
# US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#!/bin/bash
#
# runTests script REQUIRED ONLY IF additional application verification is 
# needed above and beyond helm tests.
#
# Parameters : 
#   -c <chartReleaseName>, the name of the release used to install the helm chart
#
# Pre-req environment: authenticated to cluster, kubectl cli install / setup complete, & chart installed

# Exit when failures occur (including unset variables)
set -o errexit
set -o nounset
set -o pipefail

# Parameters 
# Below is the current set of parameters which are passed in to the app test script.
# The script can process or ignore the parameters
# The script can be coded to expect the parameter list below, but should not be coded such that additional parameters
# will cause the script to fail
#   -e <environment>, IP address of the environment
#   -r <release>, ie V.R.M.F-tag, the release notation associated with the environment, this will be V.R.M.F, plus an option -tag
#   -a <architecture>, the architecture of the environment 
#   -u <userid>, the admin user id for the environment
#   -p <password>, the password for accessing the environment, base64 encoded, p=`echo p_enc | base64 -d` to decode the password when using


# Verify pre-req environment
command -v kubectl > /dev/null 2>&1 || { echo "kubectl pre-req is missing."; exit 1; }

# Setup and execute application test on installation
echo "Running application test"



# Process parameters notify of any unexpected
while test $# -gt 0; do
	[[ $1 =~ ^-e|--environment$ ]] && { environment="$2"; shift 2; continue; };
    [[ $1 =~ ^-r|--release$ ]] && { release="$2"; shift 2; continue; };
    [[ $1 =~ ^-a|--architecture$ ]] && { architecture="$2"; shift 2; continue; };
    [[ $1 =~ ^-u|--userid$ ]] && { userid="$2"; shift 2; continue; };
    [[ $1 =~ ^-p|--password$ ]] && { password="$2"; shift 2; continue; };
    [[ $1 =~ ^-c|--chartReleaseName$ ]] && { chartReleaseName="$2"; shift 2; continue; };
    echo "Parameter not recognized: $1, ignored"
    shift
done
: "${chartReleaseName:="default"}"

echo "List of all environment variables:"
env
echo "End of variable list"

agentPod=$(kubectl get pods -l release==${chartReleaseName} --selector=serverName=agentserver1 --output=jsonpath={.items..metadata.name})

function checkIndexBuild() {
    kubectl exec -ti $agentPod -- find /shared/SearchIndex -name write.lock \
     -exec bash -c 'export path={} && basename $(dirname $(dirname $path))' \; | grep 'CatalogIndex' | wc -l;
}
export -f checkIndexBuild

kubectl exec -ti $agentPod -- /opt/ssfs/runtime/bin/triggeragent.sh CATALOG_INDEX_BUILD

time=0
while [[ ! $(checkIndexBuild) -gt 0 && $time -lt 10 ]]; do
    echo "Index build still in progress at: $(date)"
    time=$(($time+1))
    sleep 60
done

if [ $(checkIndexBuild) -eq 0 ]; then
    echo "Index build not complete"
    exit 1;
else
    echo "Index build successful"
    exit 0;
fi