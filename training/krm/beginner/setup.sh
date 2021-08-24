export PROJECT_ID=krm-training-01
export CC_NAME=cc-training

gcloud config configurations create krm-training
gcloud config set project ${PROJECT_ID}
gcloud config list

#Login and authorize gcloud to access GCP with your training user credential
gcloud auth application-default login

#install kubectl if using a personal project
gcloud components install kubectl

# create a default network if it does not exist
gcloud compute networks create default --subnet-mode=auto

gcloud services enable krmapihosting.googleapis.com \
    container.googleapis.com \
    cloudresourcemanager.googleapis.com

gcloud alpha anthos config controller create ${CC_NAME} \
    --location=us-central1

gcloud alpha anthos config controller list --location=us-central1

gcloud alpha anthos config controller get-credentials ${CC_NAME} \
    --location us-central1

kubectl get ConfigConnectorContext -n config-control \
  -o "custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,HEALTHY:.status.healthy"

export SA_EMAIL="$(kubectl get ConfigConnectorContext -n config-control \
    -o jsonpath='{.items[0].spec.googleServiceAccount}' 2> /dev/null)"

gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member "serviceAccount:${SA_EMAIL}" \
    --role "roles/owner" \
    --project "${PROJECT_ID}"

kubectl apply -f storage-bucket.yaml

kubectl get StorageBucket -n config-control

kubectl apply -f pub-sub-topic.yaml

kubectl get PubSubTopic -n config-control

kubectl describe PubSubTopic/training-topic -n config-control

# Look at other resource types you can create: https://cloud.google.com/config-connector/docs/reference/overview

# Let's deploy a blueprint
#Clone the package:

kpt pkg get https://github.com/GoogleCloudPlatform/blueprints.git/catalog/networking/network/vpc@$main

#Move into the local package:

cd "./vpc/"

#Edit the setters.yaml

#Execute the function pipeline
kpt fn render

#Initialize the resource inventory
kpt live init --namespace config-control

#Apply the package resources to your cluster

kpt live apply

# Wait for the resources to be ready
kpt live status --output table --poll-until current
