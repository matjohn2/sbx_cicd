#!/bin/bash

if [ -z ${PLUGIN_NAMESPACE} ]; then
  PLUGIN_NAMESPACE="default"
fi

if [ ! -z ${PLUGIN_KUBERNETES_TOKEN} ]; then
  KUBERNETES_TOKEN=$PLUGIN_KUBERNETES_TOKEN
fi

if [ ! -z ${PLUGIN_KUBERNETES_SERVER} ]; then
  KUBERNETES_SERVER=$PLUGIN_KUBERNETES_SERVER
fi

if [ ! -z ${PLUGIN_KUBERNETES_CERT} ]; then
  KUBERNETES_CERT=${PLUGIN_KUBERNETES_CERT}
fi

kubectl config set-credentials default --token=${KUBERNETES_TOKEN}
if [ ! -z ${KUBERNETES_CERT} ]; then
  echo ${KUBERNETES_CERT} | base64 -d > ca.crt
  kubectl config set-cluster default --server=${KUBERNETES_SERVER} --certificate-authority=ca.crt
else
  echo "WARNING: Using insecure connection to cluster"
  kubectl config set-cluster default --server=${KUBERNETES_SERVER} --insecure-skip-tls-verify=true
fi

kubectl config set-context default --cluster=default --user=default
kubectl config use-context default



# kubectl version
IFS=',' read -r -a DEPLOYMENTS <<< "${PLUGIN_DEPLOYMENT}"
IFS=',' read -r -a CONTAINERS <<< "${PLUGIN_CONTAINER}"
for DEPLOY in ${DEPLOYMENTS[@]}; do
  echo Deploying to $KUBERNETES_SERVER
  #check deployment existing
  output=$(kubectl get deployment $DEPLOY 2>&1)
  if [[ $output =~ .*found.* ]]; then    
    echo Creating deployment ${DEPLOY}
    kubectl create deployment ${DEPLOY} --image ${PLUGIN_REPO}:${PLUGIN_TAG}
    kubectl expose deployment ${DEPLOY} --type=NodePort --name=${DEPLOY} --port=80 --target-port=8080
  fi
   
  for CONTAINER in ${CONTAINERS[@]}; do
    echo Set deployment image ${CONTAINER}
    kubectl -n ${PLUGIN_NAMESPACE} set image deployment/${DEPLOY} \
      ${CONTAINER}=${PLUGIN_REPO}:${PLUGIN_TAG} --record
  done
done
