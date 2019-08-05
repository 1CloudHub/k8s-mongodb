#!/bin/bash

kubectl apply -f mongoext-deployment.yaml,mongoext-svc.yaml,mongoext-sm.yaml -n monitoring
kubectl apply -f cadvisor.yaml,cadvisor-svc.yaml,cadvisor-sm.yaml -n monitoring
