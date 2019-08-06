#!/bin/bash

printf "\n Installing Prometheus Operator \n"

helm install stable/prometheus-operator --name opc-prom --set prometheus.service.type=NodePort --namespace monitoring
