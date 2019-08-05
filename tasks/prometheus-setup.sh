#!/bin/bash

printf "\n Setting up Prometheus Monitoring \"n"

curl -LO https://git.io/get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh
helm init
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
kubectl create namespace monitoring
helm install stable/prometheus-operator --name opc-prom --set prometheus.service.type=NodePort --namespace monitoring
kubectl apply -f mongoext-deployment.yaml,mongoext-svc.yaml,mongoext-sm.yaml -n monitoring
kubectl apply -f cadvisor.yaml,cadvisor-svc.yaml,cadvisor-sm.yaml -n monitoring


