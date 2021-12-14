# KRM Blueprints Lab

## 0. Prerequisites

* A [GCP Project](https://cloud.google.com/resource-manager/docs/creating-managing-projects#creating_a_project) linked with a valid biiling account
* [Project Owner](https://cloud.google.com/iam/docs/understanding-roles#basic-definitions) (**roles/owner**) for your GCP project

## 1. What You'll Learn

* [Cloud Shell](https://cloud.google.com/shell/docs)
* [Enable Google Cloud API](https://cloud.google.com/service-usage/docs/enable-disable)
* [Config Controller](https://cloud.google.com/anthos-config-management/docs/concepts/config-controller-overview)
* [Config Connector resources](https://cloud.google.com/config-connector/docs/reference/overview)
* [Policy Controller and constraints](https://cloud.google.com/anthos-config-management/docs/concepts/policy-controller)

In this lab you will learn how to can create GCP resources using Kubernetes Resource Management (KRM) style manifests that describe infrastructure resources. You will also learn about Config Controller and its components like Config Connector and Policy Controller.

This lab is the first part of a series that provides an introduction to managing infrastructure using Kubernetes Resource Management (KRM) style blueprints. Please follow the labs in sequence as each lab builds on the concepts introduced in the previous labs.

## 2. Google Cloud SDK

### 2.1 Install Google Cloud SDK

You can **skip** this step, if using [Cloud Shell](https://cloud.google.com/shell/docs)

Go to [Google Cloud SDK](https://cloud.google.com/sdk/docs/downloads-interactive) and download interactive installer for your platform.

### 2.2 Setup your training environment

**01 - Environment Variables**
* Replace **YOUR_PROJECT_ID** with the [GCP Project ID](https://cloud.google.com/resource-manager/docs/creating-managing-projects#before_you_begin) you are using for the training
* Optionally change the name of the Config Controller cluster that you will be creating.

```
export CC_NAME=cc-training
export PROJECT_ID=YOUR_PROJECT_ID
```

**02 - Verify the environment variables are set**
```
echo "Project: ${PROJECT_ID}"
echo "Config Controller Name: ${CC_NAME}"
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

Install `kpt`, the primary command-line tool for KRM blueprints:

```
gcloud components install kpt
```

# 3 Install Config Controller

**01 - Ensure default network exists**

create a default network if it does not exist:

```
gcloud compute networks create default --subnet-mode=auto
```

**02 - Enable Google Cloud APIs**

Enable the APIs needed for the training:

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

Plese note that this step can take 15-20 minutes.

**04 - Verify Config Controller installation**

Get a list of the Config Controllers in the project:

```
gcloud alpha anthos config controller list --location=us-central1
```

Make sure the newly created controller is listed.

**05 - Make sure the Confing Controller cluster is healthy and `kubectl` and `kpt` can connect with it**

Run the following command to verify that `kubectl` can connect to it and that the controller is healthy:

```
kubectl get ConfigConnectorContext -n config-control \
  -o "custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,HEALTHY:.status.healthy"
```

If the above command fails only then manually try to get the credentials for the Config Controller instance just created:

```
gcloud alpha anthos config controller get-credentials ${CC_NAME} \
    --location us-central1
```

This should allow `kubectl` and `kpt` cli tools to connect to the Config Controller.

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

## 4 Create some GCP resources via Config Controller using KRM style yaml config

Clone the training repo locally to get the example yaml files:

```
git clone -b krm-training-202108 https://github.com/kaariger/blueprints.git

cd blueprints/training/krm/beginner/
```

First, let's create a PubSub topic.

Take a look at the pub-sub-topic.yaml file:

```
cat pub-sub-topic.yaml
```

Let's send this config to Config Controller so it can create this GCP resource for us:

```
kubectl apply -f pub-sub-topic.yaml
```

You should see output similar to the following:

```
pubsubtopic.pubsub.cnrm.cloud.google.com/training-topic created
```


You can describe an object to get more details about it:

```
kubectl describe PubSubTopic/training-topic -n config-control
```

Note the Status and Events section in the resource. These two sections provide important information about the state of this resource. If there are any errors in creating this object, these sections will show the appropriate error messages.

You can use the following `gcloud` command to get the list of topics:

```
gcloud pubsub topics list
```

You should see the topic you created above in the list.

Please note the labels attached to this resource. It should include the following:

```
labels:
  created-in: krm-training
  managed-by-cnrm: 'true'
```

`managed-by-cnrm: 'true'` indicates that this resource is being managed by Config Connector.

Now let's create a storage bucket.

Take a look at the storage-bucket.yaml file in the same directory:

```
cat storage-bucket.yaml
```

You will need to edit this file to give this bucket a unique name. You can simply add your project ID to the name and that should make it unique.

Edit the file in an editor of your choice e.g.

```
nano storage-bucket.yaml
```

Please make sure to repace `<PROJECT_ID>` with your project ID.

Once you have edited the file, send this config to Config Controller so it can create the storage bucket for us:

```
kubectl apply -f storage-bucket.yaml
```

Let's look at this object in the cluster:

```
kubectl describe StorageBucket/${PROJECT_ID}-krm-trainig-bucket -n config-control
```

You can navigate to the Cloud Console to view this bucket in the UI as well.

You can get a list of other [Config Connector resources](https://cloud.google.com/config-connector/docs/reference/overview) you can use to create the corresponding GCP resources.

Try to create some other resources by creating the yaml spec and then using `kubectl apply`.

## 5 Working with Policy Controller and constraints

Now let's look at how you can create some constraints to enforce organizational policies.

In this example we will create a policy that only allows Storage Buckets to created in US-Central1 region and prevents users from creating these buckets in any other region.

Look at the constraint definition in the `StorageConstraint.yaml` file:

```
cat StorageConstraint.yaml
```

Let's create this constraint in our cluster.

```
kubectl apply -f StorageConstraint.yaml
```

Now let's try to create a Storage Bucket in asia-southeast1 region.

First edit the `storage-bucket-asia.yaml` file and replace <PROJECT_ID> with your project ID in the name field and the project-id annotation.

```
nano storage-bucket-asia.yaml
```

Now let's try to create this bucket by running the following command:

```
kubectl apply -f storage-bucket-asia.yaml
```

You will see output similar to the following:

```
Error from server ([us-central1-only] Cloud Storage bucket <${PROJECT_ID}-krm-trainig-bucket-asia> uses a disallowed location <asia-southeast1>, allowed locations are ["us-central1"]): error when creating "storage-bucket-asia.yaml": admission webhook "validation.gatekeeper.sh" denied the request: [us-central1-only] Cloud Storage bucket <${PROJECT_ID}-krm-trainig-bucket-asia> uses a disallowed location <asia-southeast1>, allowed locations are ["us-central1"]
```

This shows how the Policy Controller can catch requests sent to the Config Controller that violate some constraint and prevents that request from being completed.

You can edit the location of the this bucket in the yaml file to us-central1 and see if you can successfully create the bucket.

**Clean-up**

You can delete the GCP resources created during the lab by deleting the corresponding resource objects in the Config Controller cluster:

```
kubectl delete PubSubTopic/training-topic -n config-control
kubectl delete StorageBucket/${PROJECT_ID}-krm-trainig-bucket -n config-control
kubectl delete StorageBucket/${PROJECT_ID}-krm-trainig-bucket-asia -n config-control
```

Alternatively, you can also delete these objects by referencing the files that describe these objects.

```
kubectl delete -f pub-sub-topic.yaml
kubectl delete -f storage-bucket.yaml
kubectl delete -f storage-bucket-asia.yaml
```