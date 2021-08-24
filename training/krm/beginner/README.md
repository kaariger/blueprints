# KRM Blueprints Lab

## 0. Prerequisite

* A [GCP Project](https://cloud.google.com/resource-manager/docs/creating-managing-projects#creating_a_project) linked with a valid biiling account
* [Project Owner](https://cloud.google.com/iam/docs/understanding-roles#basic-definitions) (**roles/owner**) for your GCP account

## 1. What You'll Learn

* [Google Cloud SDK](https://cloud.google.com/sdk/)
* [Cloud Shell](https://cloud.google.com/shell/docs)
* [Enable Google Cloud API](https://cloud.google.com/service-usage/docs/enable-disable)
* [Config Controller](https://cloud.google.com/anthos-config-management/docs/concepts/config-controller-overview)
* [KRM blueprints](https://github.com/GoogleCloudPlatform/blueprints/)

## 2. Google Cloud SDK

### 2.1 Install Google Cloud SDK

You can **skip** this step, if using [Cloud Shell](https://cloud.google.com/shell/docs)

Go to [Google Cloud SDK](https://cloud.google.com/sdk/docs/downloads-interactive) and download interactive installer for your platform.

### 2.2 Setup your training environment

**01 - Environment Variables**
* Replace **YOUR_PROJECT_ID** with the [GCP Project ID](https://cloud.google.com/resource-manager/docs/creating-managing-projects#before_you_begin) you are using for the training
* Replace **YOUR_GCP_ACCOUNT_EMAIL** with your GCP account

```
export PROJECT_ID=YOUR_PROJECT_ID
export CC_NAME=cc-training
```

**02 - Verify the environment variables are set**
```
echo "Project: ${PROJECT_ID}"
echo Config Controller Name: ${CC_NAME}
```

**03 - Setup & Verify [gcloud configurations](https://cloud.google.com/sdk/gcloud/reference/config) for the training**
```
gcloud config configurations create krm-training
gcloud config set project ${PROJECT_ID}
gcloud config set compute/zone us-central1-b
gcloud config list
```

**04 - Login and authorize gcloud to access GCP with your training user credential**
Use the following command to authorize gcloud to run commands on your behalf. Logging in with application-default mode stores temporary credentials in a well-known location locally for applications like Terraform to use.
```
gcloud auth application-default login
```
**05 - Install additional components required for this training**

Install `kubectl`, the primary command-line interface for Kubernetes:

```
gcloud components install kubectl
```

Install `kpt`, the primary command-line interface for KRM blueprints:

```
gcloud components install kpt
```

# 3 Install Config Controller

**01 - Ensure default network exists**

create a default network if it does not exist

```
gcloud compute networks create default --subnet-mode=auto
```

**02 - Enable Google Cloud APIs**

```
gcloud services enable krmapihosting.googleapis.com \
    container.googleapis.com \
    cloudresourcemanager.googleapis.com
```

**03 - Install Config Controller**

Run the following command to create the Config Controller instance:

```
gcloud alpha anthos config controller create ${CC_NAME} \
    --location=us-central1
```

This step can take 15-25 minutes.

**04 - Verify Config Controller installation**

List the config controllers in the project:

```
gcloud alpha anthos config controller list --location=us-central1
```

**05 - Fetch the credentials for Config Controller so `kubectl` and `kpt` can connect to it**

Get the credentials for the Config Controller instance just created:

```
gcloud alpha anthos config controller get-credentials ${CC_NAME} \
    --location us-central1
```

Run the following command to make sure `kubectl` can connect to it and that the controller is healthy:

```
kubectl get ConfigConnectorContext -n config-control \
  -o "custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,HEALTHY:.status.healthy"
```

**06 - Grant permission to Config Controller to create resources in your project**

First get the service account used by Config Controller.

```
export SA_EMAIL="$(kubectl get ConfigConnectorContext -n config-control \
    -o jsonpath='{.items[0].spec.googleServiceAccount}' 2> /dev/null)"
```

Now grant the project owner role to the service account:

```
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member "serviceAccount:${SA_EMAIL}" \
    --role "roles/owner" \
    --project "${PROJECT_ID}"
```

# 4 Create some GCP resources using KRM style yaml config

Clone the training repo locally to get the example yaml files:

```
git clone -b krm-training-202108 https://github.com/kaariger/blueprints.git
```


```
kubectl apply -f storage-bucket.yaml
```

```
kubectl get StorageBucket -n config-control
```

```
kubectl apply -f pub-sub-topic.yaml
```

```
kubectl get PubSubTopic -n config-control
```

```
kubectl describe PubSubTopic/training-topic -n config-control
```

Look at other [Config Connector resources](https://cloud.google.com/config-connector/docs/reference/overview) you can create

# 5 Create a GCP VPC using a KRM blueprint

**Let's deploy a simple KRM style blueprint**

Clone the package:

```
kpt pkg get https://github.com/GoogleCloudPlatform/blueprints.git/catalog/networking/network/vpc@$main
```

Move into the local package directory:

```
cd "./vpc/"
```

Edit the setters.yaml file

Execute the function pipeline

```
kpt fn render
```

Initialize the resource inventory

```
kpt live init --namespace config-control
```

Apply the package resources to your cluster

```
kpt live apply
```

Wait for the resources to be ready

```
kpt live status --output table --poll-until current
```

Clean-up

Destroy the resources created

```
kpt live destroy
```
