#!/bin/bash

printf "\n Deploying exporters for monitoring \n"

kubectl apply -f mongoext-deployment.yaml -n monitoring
kubectl apply -f mongoext-svc.yaml -n monitoring
kubectl apply -f mongoext-sm.yaml -n monitoring
kubectl apply -f cadvisor.yaml -n monitoring
kubectl apply -f cadvisor-svc.yaml -n monitoring
kubectl apply -f cadvisor-sm.yaml -n monitoring
