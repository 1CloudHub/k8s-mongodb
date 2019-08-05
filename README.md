# K8s Mongo cluster on AWS IaaS and Prometheus

#### Creating a kubernetes cluster on AWS EC2 instance with MongoDB and Prometheus. 

The following content will walk you through the steps to create a kubernetes cluster in AWS (IaaS) using kops, configure mongoDB with sharding and setup prometheus for monitoring the nodes, K8s cluster and mongoDB using node exporter, mongoDB exporter along with Grafana. 

Kubernetes is an open source container orchestration and management tool. Kubernetes provides you with a framework to run distributed systems resiliently. One of the key benefits of kubernetes is that it is self-healing and clusters can be restarted automatically in case of failure of any nodes.

Kops is a open source tool which can be used for creating, upgrading and destroying kubernetes cluster and underlying infrastructure. 

MongoDB is a document database designed for ease of development and scaling. MongoDB provides high performance data persistence, replication facility (replica set) and horizontal scalability as part of its core functionality. Sharding distributes data across a cluster of machines.

### Who should use this?

This will be helpful for developer, Ops or DevOps person to create kubernetes cluster in AWS IaaS and install mongoDB with minimal manual work. 

**Key benefits:**

-	 Scale the cluster nodes after launch.
-	 Scale the mongoDB shards and replicaset based on the requirement. 
-	 Exporters can be customized and implemented as required. 

##### Table of Contents
 * [Pre-requisites](#pre-requisites)
      - [Client Server - Ubuntu OS](#client-server---ubuntu-os)
      - [SSH Keyfile](#ssh-keyfile)
      - [S3 Bucket](#s3-bucket)
      - [Install AWS CLI](#install-aws-cli)
      - [Install Ansible Kops and Kubectl](#install-ansible-kops-and-kubectl)
 * [Deploying Kubernetes Cluster](#deploying-kubernetes-cluster)
      - [Kubernets cluster setup on AWS EC2](#kubernets-cluster-setup-on-aws-ec2)
 * [Deploying MongoDB Cluster](#deploying-mongodb-cluster)
      - [MongoDB cluster setup on K8s cluster nodes](#mongodb-cluster-setup-on-k8s-cluster-nodes)
 * [Deploying Prometheus](#deploying-prometheus)
      - [Prometheus setup for kubernets cluster and mongoDB](#prometheus-setup-for-kubernets-cluster-and-mongodb)
 * [Configuration](#Configuration)
 * [Reference Blogs and Links](#reference-blogs-and-links)

## Pre-requisites
- #### Client Server - Ubuntu OS
	 In this blog, EC2 instance used as a client server for deployments. Be sure to attach the kops-profile IAM role to the instance with below permissions. 
	 Launch a new EC2 instance ( Ubuntu OS) in AWS with below IAM permissions. 
	 
	 - AmazonEC2FullAccess
	 - AmazonS3FullAccess
	 - IAMFullAccess
	 - AmazonVPCFullAccess
	 - AmazonRoute53FullAccess
- #### SSH Keyfile
	 Create a new ssh key file in Ubuntu server for accessing master and worker nodes from the Kops Instance. Execute all the commands as a root user. 

	 `$ ssh-keygen -t rsa `
	 
	 The above created keyfile will be stored in ~/.ssh/id_rsa.pub path. 
- #### S3 Bucket 
	 Create new S3 bucket ( --state=s3://cluster-state-store) in AWS console for kubernetes cluster setup.
	 
	 Note : update the s3 bucket name in following files, if you have created S3 bucket with new name. 
	 
		update KOPS_STATE_STORE value in `/variables/cluster_variable.yaml`
		update --state=s3://<bucket name> value in `/handlers/main.yaml`
	 
- #### Install AWS CLI
	Detailed steps given in the below link to install AWS CLI on Ububtu server. 
	
	https://docs.aws.amazon.com/cli/latest/userguide/install-linux.html
	
- #### Install Ansible, Kops and Kubectl
	Follow the below steps and reference links to install Ansible, Kops and Kubectl on Ubuntu server
	 - To install Ansible
	 
	 `$ sudo apt install ansible`
	 - To install and configure kops

	 `$ curl -LO https://github.com/kubernetes/kops/releases/download/$(curl -s https://api.github.com/repos/kubernetes/kops/releases/latest | grep tag_name | cut -d '"' -f 4)/kops-linux-amd64 `
	 
	 `$ chmod +x kops-linux-amd64 `
	 
	 `$ sudo mv kops-linux-amd64 /usr/local/bin/kops ` 
	 
	 - To install kubectl
	 
	 kubectl is a CLI used to run commands on the kubernetes cluster. 
		
	 `$ curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl `
	 	
	 `$ chmod +x kubectl `
	 	
	 `$ sudo mv kubectl /usr/local/bin/kubectl `

## Deploying Kubernetes Cluster
- ##### Kubernets cluster setup on AWS EC2

	You can create a cluster in an existing VPC or new, either with a public or private topology. 
	
	In this example, we will be using a pre-existing VPC and subnets for cluster deployment. The gossip based cluster will be deployed with public topology. 

	 Use the below command to set KOPS_STATE_STORE variable pointing to S3 bucket. The KOPS_STATE_STORE is an S3 bucket that stores your cluster configuration and state
	 
	 `$ export KOPS_STATE_STORE=s3://<S3 Bucket name> `
		
	 Now, update the variables in cluster_variable.yaml file to launch cluster nodes in existing VPC, subnets. You can find the yaml file here [https://github.com/1CloudHub/k8s-mongodb/blob/master/variables/cluster_variable.yaml]

	 Execute kubernetes-master.yaml script to launch cluster nodes

	 `$ ansible-playbook kubernetes-master.yaml `

	 After few minutes, ensure the cluster is up and running,
	 
	 `$ kops validate cluster --name <cluster-name> `
	 
	 Verify kubernetes cluster nodes state
	 
	 `$ kubectl get nodes `
	 
	 The above command will result all the nodes with status. 
	 
## Deploying MongoDB Cluster
- ##### MongoDB cluster setup on K8s cluster nodes

	 Set labels to each node except for Master node, before deploying MongoDB inoder to differentiate what is config, what is router and what is for shards. 

	 `$ kubectl label nodes <node name> component=api `
	 
	 `$ kubectl label nodes <node name> component=mongo-config `
	 
	 `$ kubectl label nodes <node name> component=mongo-shard `

	 Now, execute mongodb-master.yaml to setup mongoDB cluster. 

	 This will install mongoDB 3.6.9 on kubernetes 3 node cluster based on the labels configured. 

	 `$ ansible-playbook mongodb-master.yaml `

	 This will deploy 3 sharded cluster with 2 replicaset. 

## Deploying Prometheus

- ##### Prometheus setup for monitoring the nodes, K8s cluster and mongoDB

	 Execute Prometheus-master.yaml script. 

	 `$ ansible-playbook prometheus-master.yaml `

	 This script will create the following serviceaccount, clusterrolebinding, namespace, install prometheus using helm chart, cadvisor and mongoDB exporter. 

-  Prometheus installation

	 - `$ kubectl create serviceaccount --namespace kube-system tiller `
	 - `$ kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller `
	 - `$ kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}' `
	 - `$ kubectl create namespace monitoring `
	 - `$ helm install stable/prometheus-operator --name opc-prom --set prometheus.service.type=NodePort --namespace monitoring `
	 - `$ kubectl apply -f mongoext-deployment.yaml,mongoext-svc.yaml,mongoext-sm.yaml -n monitoring `
	 - `$ kubectl apply -f cadvisor.yaml,cadvisor-svc.yaml,cadvisor-sm.yaml -n monitoring `

In mongoDB exporter, MongoDB URI pointed to shards DNS to collect mongoDB metrics.

    spec:
          affinity: {}
          containers:
          - args:
            - --mongodb.uri=mongodb://mongo-shard0-0.mongo-shard0-svc.default.svc.cluster.local:27017
            - --web.listen-address=:9216
            - --collect.collection
            - --collect.database
            - --collect.indexusage
            - --collect.topmetrics
            image: ssheehy/mongodb-exporter:0.7.0
    
	
## Configuration
Following table shows the different options to deploy kubernetes cluster and mongoDB.

| Parameter   | Description  |  Default |
| :------------ | :------------ | :------------ |
| cluster_name| Name of the cluster to be created. The name has to end with the domain name if DNS zone hoster in Route53 | kubernetes-cluster.k8s.local | 
| state_store | Name of the AWS S3 bucket to be used as kops state store | s3://cluster-state-store |
| aws_region  | AWS region in which cluster nodes to be deployed  | ap-south-1  |
| aws_zones | AWS availability zone in which cluster nodes to be deployed | ap-south-1a |
| master_zones | AWS availability zone to deploy master node | ap-south-1a |
| vpc_id | Mention your VPC id exists in your AWS account to launch cluster instances | for example - vpc-xxxxxxxx |
| network_cidr | Mention your existing VPC CIDR range | For example-10.x.x.x/16 |
| subnet_id | Subnet id of existing public subnet | for exampe - subnet-xxxxxxxxx |
| master_size | EC2 instance size for the kubernetes master node | t2.medium |
| master_count | Number of EC2 master nodes | 1 | 
| master_volume_size | Size of the master node disk volume in GB | 50 |
| node_size | EC2 instance size for the kubernetes worker nodes | t2.medium |
| node_count | Number of EC2 worker nodes | 3 |
| node_volume_size | Size of the worker node disk volume in GB | t2.medium |
| topology | Defines whether the cluster should be deployed into public subnet or private subnet with bastion host | public |
| public_ip | Switch to enable/disable public ip assignment | true |
| base_image | Image used for all the instances | kope.io/k8s-1.11-debian-stretch-amd64-hvm-ebs-2018-08-17 |
| kubernetes_networking | Defines which networking plugin should be used in Kubernetes. Tested with  flannel-vxlan only. | flannel-vxlan |
| kubernetes_version | Version of kubernetes which should be used. | 1.11.3 |
| allow_container_registry| Optional, to allow read access to Amazon ECR | true |
| legacy | Optional, to use the legacy IAM privileges | false |
| mongodbUsername  | MongoDB custom user   | admin   |
| mongodbRootPassword | MongoDb admin Password | Welcome@321

## Reference Blogs and Links

*"Sharded MongoDB on Kubernetes using local persistent volumes on AWS By Sabarish Sasidharan
https://itnext.io/sharded-mongodb-on-kubernetes-using-local-persistent-volumes-on-aws-cb4e1092a69c "*
