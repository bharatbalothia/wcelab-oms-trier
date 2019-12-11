oc project dev-oms
helm del --purge oms-db-01 --tiller-namespace tiller
helm del --purge oms-mq-01 --tiller-namespace tiller
oc delete secret mq-secret
oc delete project dev-oms
