# Prep

gcloud auth login
gcloud config set project [PROJECT_ID]
gcloud config set compute/region us-east1
gcloud config set compute/zone us-east1-b

# Task 1: Create a project jumphost instance (zone: us-east1-b) 

gcloud compute instances create nucleus-jumphost \
--machine-type f1-micro \
--image-family debian-9 \
--image-project debian-cloud

# Task 2: Create a Kubernetes service cluster 

gcloud container clusters create nucleus-cluster \
--num-nodes 1

gcloud container clusters get-credentials nucleus-cluster

kubectl create deployment nucleus-deployment \
--image gcr.io/google-samples/hello-app:2.0

kubectl expose deployment nucleus-deployment \
--type LoadBalancer --port 8080

# Task 3: Create the web server frontend

cat << EOF > startup.sh
#! /bin/bash
apt-get update
apt-get install -y nginx
service nginx start
sed -i -- 's/nginx/Google Cloud Platform - '"\$HOSTNAME"'/' /var/www/html/index.nginx-debian.html
EOF

gcloud compute instance-templates create web-server-template \
--machine-type f1-micro \
--metadata-from-file startup-script=startup.sh \
--tags nucleus-web-server

gcloud compute instance-groups managed create web-server-group \
--base-instance-name web-server \
--size 2 \
--template web-server-template

gcloud compute instance-groups managed set-named-ports web-server-group \
--named-ports http:80

gcloud compute firewall-rules create web-server-firewall \
--allow tcp:80 \
--target-tags nucleus-web-server

gcloud compute health-checks create http http-basic-check \
--port 80 \
--global

gcloud compute backend-services create web-server-backend \
--protocol HTTP \
--port-name http \
--health-checks http-basic-check \
--global

gcloud compute backend-services add-backend web-server-backend \
--instance-group web-server-group \
--global

gcloud compute url-maps create web-server-map \
--default-service web-server-backend

gcloud compute target-http-proxies create http-lb-proxy \
--url-map web-server-map


gcloud compute forwarding-rules create http-rule \
--global \
--target-http-proxy http-lb-proxy \
--ports 80

gcloud compute forwarding-rules list

# UnPrep

gcloud config unset compute/zone
gcloud config unset compute/region
gcloud config unset project
gcloud auth revoke