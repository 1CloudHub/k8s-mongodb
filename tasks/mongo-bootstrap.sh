#!/bin/bash
###
# This script is idempotent. It can be run as many times as you want
# To add a new shard, just give a higher count and run the script again
# For ex, when creating a 2 shard mongo cluster you would use
# mongo-bootstrap.sh 2
# And when adding a new shard you would run
# mongo-bootstrap.sh 3
# And new shard will get created, initialized automatically
# Note that extra nodes for the shard should exist before running
###

shardcount=${1}

if [ -z "$shardcount" ];
then
  echo "Provide shard count"
  exit 13
fi

if [[ $shardcount -gt 1 ]]
then
    echo "Number of shards to be created $shardcount"
else
    echo "ERROR !!! Number of shards should be greater than one"
    exit 1
fi

#*************  STEP 1  *****************
printf "\n======Ensuring mongodb key file exists===========\n"
#CREATE MONGODB-KEYFILE WHICH WILL BE USED IN ALL MONGO NODES.
adminPwd="Welcome@321"
kubectl get secrets/mongodb-key
if [[ $? -ne 0 ]]
then
echo "*** mongodb-keyfile does not exist. Creating one..."
openssl rand -base64 741 > mongodb-keyfile
echo "Adding to kube secrets"
kubectl create secret generic mongodb-key --from-file=mongodb-keyfile
kubectl create secret generic mongodb-pwd --from-literal=pwd="$adminPwd"
else
echo "mongodob-keyfile exists"
fi

#*************  STEP 2  *****************
printf "\n======Ensuring mongo config is up and running===========\n"
echo "*** Spinning mongo-config"
kubectl apply -f mongo-config.yaml
n=$(kubectl get pods|grep -w 'mongo-config-.'|grep Running|wc -l)
while [ "$n" != "2" ]
do
echo "Waiting for pods to be ready"
sleep 5
n=$(kubectl get pods|grep -w 'mongo-config-.'|grep Running|wc -l)
done
echo "Mongo config pods are up"
echo "Configuring config servers as a replicaset"
nr=$(kubectl exec mongo-config-0 -- mongo --eval "rs.status();"|grep "NotYetInitialized"|wc -l)
if [[ $nr -gt 0 ]]
then
echo "Replicaset not yet initialized, initializing"
kubectl exec mongo-config-0 -- mongo --eval "rs.initiate({_id: \"crs\", configsvr: true, members: [ {_id: 0, host: \"mongo-config-0.mongo-config-svc.default.svc.cluster.local:27017\"}, {_id: 1, host: \"mongo-config-1.mongo-config-svc.default.svc.cluster.local:27017\"} ]});"
else
echo "Replicaset already initialized, skipping"
fi

#*************  STEP 3  *****************
printf "\n======Ensuring mongo query routers are up and running===========\n"
kubectl apply -f mongo-rt.yaml
nqr=$(kubectl get pods|grep "mongo-rt"|grep "Running"|wc -l)
fresh=0
while [[ $nqr -lt 1 ]]
do
  echo "Waiting for pods to be ready"
  sleep 5
  fresh=1
  nqr=$(kubectl get pods|grep "mongo-rt"|grep "Running"|wc -l)
done
echo "Query router pods are up ($nqr)"
if [[ $fresh -eq 1 ]]; then echo "Sleeping 30s for routers to be initialized" && sleep 30; fi
echo "Creating admin user. You can ignore if this step fails because user already exists."
qrPod=$(kubectl get pods|grep "mongo-rt"|head -1|awk '{print $1}')
kubectl exec $qrPod -- mongo --eval "db.getSiblingDB(\"admin\").createUser({user: \"admin\", pwd: \"$adminPwd\", roles: [ { role: \"root\", db: \"admin\" } ] });"

#*************  STEP 4  *****************
printf "\n======Ensuring mongo shards are up and running===========\n"
export shards=0
while [[ $shards -lt $shardcount ]]
do
  echo "*** Spinning mongo-shard$shards"
  sed "s/shard0/shard$shards/g" mongo-shard.yaml > mongo-shard$shards.yaml
  kubectl apply -f mongo-shard$shards.yaml
  n=$(kubectl get pods|grep -w "mongo-shard$shards-."|grep Running|wc -l)
  fresh=0
  while [ "$n" != "2" ]
  do
    echo "Waiting for pods to be ready"
    sleep 5
    fresh=1
    n=$(kubectl get pods|grep -w "mongo-shard$shards-."|grep Running|wc -l)
  done
  echo "Mongo shard$shards pods are up"
  if [[ $fresh -eq 1 ]]; then echo 'Sleeping for 20s' && sleep 20; fi
  nr=$(kubectl exec mongo-shard$shards-0 -- mongo --eval "rs.status();"|grep "NotYetInitialized"|wc -l)
  if [[ $nr -gt 0 ]]
  then
    echo "Replicaset not yet initialized, initializing"
    kubectl exec mongo-shard$shards-0 -- mongo --eval "rs.initiate({_id: \"shard$shards\", members: [ {_id: 0, host: \"mongo-shard$shards-0.mongo-shard$shards-svc.default.svc.cluster.local:27017\"}, {_id: 1, host: \"mongo-shard$shards-1.mongo-shard$shards-svc.default.svc.cluster.local:27017\"} ]});"
    sleep 10
  else
    echo "Replicaset already initialized, skipping"
  fi
  shardIdRows=$(kubectl exec $qrPod -- mongo admin -u admin -p "$adminPwd" --eval "sh.status();"|grep "shard$shards"|wc -l)
  if [[ $shardIdRows -gt 0 ]]
  then
    echo "Shard shard$shards is already added to mongos qr. Skipping addShard"
  else
    echo "Shard shard$shards is not yet added to mongos qr. Invoking addShard"
    kubectl exec $qrPod -- mongo admin -u admin -p "$adminPwd" --eval "sh.addShard(\"shard$shards/mongo-shard$shards-0.mongo-shard$shards-svc.default.svc.cluster.local:27017\");"
  fi
  printf "===\n\n"
  shards=$(($shards+1))
done

