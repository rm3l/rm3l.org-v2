+++
author = "Armel Soro"
categories = ["ghost", "kubernetes", "backup", "cronjob", "init-container", "aws", "s3"]
date = 2021-01-03T20:14:00Z
description = ""
draft = false
image = "https://images.unsplash.com/photo-1565486384667-6d87dbd2f02b?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=MXwxMTc3M3wwfDF8c2VhcmNofDEzNnx8c3RvcmFnZXxlbnwwfHx8&ixlib=rb-1.2.1&q=80&w=2000"
slug = "leveraging-kubernetes-cronjobs-for-automated-backups-of-a-headless-ghost-blog-to-aws-s3"
summary = "On how to leverage Kubernetes CronJobs to implement a simple automated backup solution of a headless Ghost blog to S3."
tags = ["ghost", "kubernetes", "backup", "cronjob", "init-container", "aws", "s3"]
title = "Leveraging Kubernetes CronJobs for automated backups of a headless Ghost blog to AWS S3"

+++


### NOTE : This uses an experimental feature of Ghost, which may change, break or inexplicably disappear at any time. So use this at your own risk!

---

## TL;DR

```bash
$ helm repo add rm3l https://helm-charts.rm3l.org
$ helm install my-ghost-export-to-s3 rm3l/ghost-export-to-s3 \
    --version 0.17.2 \
    --set ghost.apiBaseUrl="https://my.ghost.cms/ghost" \
    --set ghost.username="my-ghost-username" \
    --set ghost.password="my-ghost-password" \
    --set aws.accessKeyId="my-aws-access-key-id" \
    --set aws.secretKey="my-aws-secret-key" \
    --set aws.s3.destination="s3://path/to/my/s3-export.json" \
    --set cronJob.schedule="@daily"
```

See [https://github.com/rm3l/helm-charts/blob/main/charts/ghost-export-to-s3/README.md](https://github.com/rm3l/helm-charts/blob/main/charts/ghost-export-to-s3/README.md) for further details.

## Introduction

At the dawn of this new year, I wanted to start with a project I had in mind since I migrated this Ghost Blog to Kubernetes : **Backups**. Until now, backups were performed manually, whenever I thought about it, and made up of a manual export of the blog content to a single JSON file, using the Ghost Content Management System (CMS) administration panel.

![Ghost CMS Admin Panel : Export JSON](https://rm3l-org.s3-us-west-1.amazonaws.com/assets/Ghost_Blog_Export_With_K8s_CronJobs_ghost-lab-export-json.png)

Then I used to manually upload the resulting JSON file to an external system, such as S3 or Google Drive.

As an automation enthusiast, this manual approach could not be entirely satisfactory to me. So I set out to find a simple way to automate such backups, ideally using Kubernetes built-in primitives. And by "simple", I mean leveraging official Docker images with little to no custom code.

## Solution Architecture

![Solution Architecture : Backup Ghost Blog using K8s CronJobs ](https://rm3l-org.s3-us-west-1.amazonaws.com/assets/cms-rm3l-org-backup-ghost-on-k8s.png)

The idea is quite simple:

* The "_[Export your content](https://ghost.org/help/the-importer/)_" feature in the Ghost Administration page is backed by the [Admin API](https://ghost.org/docs/admin-api/) under the cover. We could then implement something in charge of calling this API to download an export file and upload it elsewhere.
* [Kubernetes](https://kubernetes.io/) allows to submit [CronJobs](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/) which create pods as per a specified schedule, and with a great support for parallelism, and retries in case of errors during the execution. They are typically useful for creating periodic and recurring tasks, like running backups or sending emails.
* A [CronJob](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/) could therefore be interesting for this use case, in that it would periodically call the Ghost Admin API so as to download the export JSON file and upload it to S3.
* An [Init Container](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/), part of the Backup Pod, would be in charge of authenticating against the Ghost Admin API and downloading the export file to a volume, shared with the Main Container. The latter would in turn be responsible for uploading the export file to the remote Cloud Storage Service.
* The Backend CMS of my Ghost blog is currently running inside the same Kubernetes cluster, but in the approach depicted here, it could actually be anywhere, as long as it can be reached by the CronJob's Init Container.

## The Kubernetes Resources

To keep the workloads portable, it is recommended to separate the Configurations from our Pods and components. As such, I defined:

* a [ConfigMap](https://kubernetes.io/docs/concepts/configuration/configmap/) that stores non-sensitive configuration data, such as the Ghost CMS API entry point and the target S3 path for the backup file.
* a [Secret](https://kubernetes.io/docs/concepts/configuration/secret/) that stores encoded sensitive data, such as the authentication credentials against both the Ghost instance and Amazon Web Services (AWS).

The Pods spawned by the CronJob would then read such configuration data as needed.

### The ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ghost-export-k8s-to-s3-configmap
data:
  GHOST_URL: http://ghost-cms.blog.svc.cluster.local:2368/ghost
  S3_DESTINATION: s3://my-s3-bucket/folder/my.ghost.blog.com.export.json
```

Or you can also create it manually using the following imperative command:

```bash
kubectl create configmap ghost-export-k8s-to-s3-configmap \
  --from-literal GHOST_URL="http://ghost-cms.blog.svc.cluster.local:2368/ghost" \
  --from-literal S3_DESTINATION="s3://my-s3-bucket/folder/my.ghost.blog.com.export.json"
```

### The Secret

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: ghost-export-k8s-to-s3-secret
stringData:
  AWS_ACCESS_KEY_ID: my-aws-access-key-id
  AWS_SECRET_ACCESS_KEY: my-aws-secret-key
  GHOST_AUTH_PASSWORD: my-ghost-password
  GHOST_AUTH_USERNAME: my-ghost-user
```

Or you can also create it manually using the following imperative command:

```bash
kubectl create secret generic ghost-export-k8s-to-s3-secret \
  --from-literal GHOST_AUTH_USERNAME="my-ghost-user" \
  --from-literal GHOST_AUTH_PASSWORD="my-ghost-password" \
  --from-literal AWS_ACCESS_KEY_ID="my-aws-access-key-id" \
  --from-literal AWS_SECRET_ACCESS_KEY="my-aws-secret-key"
```

### The CronJob Resource

The Pod created by the CronJob is made up of the following:

* a simple [Init Container](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/), responsible for first authenticating against the Ghost API and then downloading the export file. The export file is then stored into a volume shared with the main container. For this, it leverages the official _[curlimages/curl](https://hub.docker.com/r/curlimages/curl)_ Docker image.
* a simple main Container, in charge of uploading the export file to the remote storage service. For this, it leverages the official _[amazon/aws-cli](https://hub.docker.com/r/amazon/aws-cli)_ Docker image.
* The Init and Main Containers share a same temporary Volume, tied to the Pod lifetime.

```yaml
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: ghost-s3-export-cron-job
spec:
  schedule: "@daily"
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      ttlSecondsAfterFinished: 300
      backoffLimit: 1
      parallelism: 1
      template:
        spec:
          restartPolicy: OnFailure
          volumes:
          - name: export-data
            emptyDir: {}

          initContainers:
          - name: download-glorious-json-from-ghost
            image: curlimages/curl:7.74.0
            imagePullPolicy: IfNotPresent
            command:
            - /bin/sh
            - -c
            - |
              curl --fail -sSL -c /tmp/ghost-cookie.txt \
                -d username='$(GHOST_AUTH_USERNAME)' \
                -d password='$(GHOST_AUTH_PASSWORD)' \
                -H 'Origin: ghost-export-to-s3-job' \
                '$(GHOST_URL)'/api/v3/admin/session/ && \
              curl --fail -sSL -b /tmp/ghost-cookie.txt \
                -H 'Origin: ghost-export-to-s3-job' \
                -H 'Content-Type: application/json' \
                '$(GHOST_URL)'/api/v3/admin/db/ \
                -o /data/ghost-export/ghost-export.json && \
              rm -rf /tmp/ghost-cookie.txt
            env:
            - name: GHOST_URL
              valueFrom:
                configMapKeyRef:
                  name: ghost-export-k8s-to-s3-configmap
                  key: GHOST_URL
            - name: GHOST_AUTH_USERNAME
              valueFrom:
                secretKeyRef:
                  name: ghost-export-k8s-to-s3-secret
                  key: GHOST_AUTH_USERNAME
            - name: GHOST_AUTH_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: ghost-export-k8s-to-s3-secret
                  key: GHOST_AUTH_PASSWORD
            volumeMounts:
            - name: export-data
              mountPath: /data/ghost-export

          containers:
          - name: export-ghost-json-to-s3
            image: amazon/aws-cli:2.1.15
            imagePullPolicy: IfNotPresent
            args:
            - s3
            - cp
            - "/data/to-export/ghost-export.json"
            - "$(S3_DESTINATION)"
            env:
            - name: AWS_ACCESS_KEY_ID
              valueFrom:
                secretKeyRef:
                  name: ghost-export-k8s-to-s3-secret
                  key: AWS_ACCESS_KEY_ID
            - name: AWS_SECRET_ACCESS_KEY
              valueFrom:
                secretKeyRef:
                  name: ghost-export-k8s-to-s3-secret
                  key: AWS_SECRET_ACCESS_KEY
            - name: S3_DESTINATION
              valueFrom:
                configMapKeyRef:
                  name: ghost-export-k8s-to-s3-configmap
                  key: S3_DESTINATION
            volumeMounts:
            - name: export-data
              mountPath: /data/to-export
```

Notice the use of parenthesis (instead of brackets) in "_$(S3_DESTINATION)_" (Main Container Args) to allow for Shell variables expansion by Kubernetes.

## Limitations

At the moment, there are few limitations worth bearing in mind.

* The "_Export your content_" feature is marked as a "**Labs**" feature, meaning : **This is a testing ground for new or experimental features. They may change, break or inexplicably disappear at any time**. So **use at your own risk**.
* As stated [here](https://ghost.org/help/the-importer/), the following data is exported: All Settings, Users, Subscribers, Posts, Pages and Tags, but **Images and Theme files will not be exported**. This is however fine for my use case since my Ghost instance is headless (that is, users are presented a separate FrontEnd decoupled from Ghost itself). So Images are already being stored elsewhere and I don't use Ghost Theme files.
* Initially, I wanted to create a dedicated Ghost Custom Integration, which would provide me with a dedicated pair of Admin API Key and Secret, which would in turn be used to generate short-lived single-use JSON Web Tokens on-the-fly for interacting with the Ghost Admin API. Unfortunately, this is something purposely not supported by Ghost for the experimental API I wanted to call (the Export API). So I had to resort to using User Session Authentication, using dedicated username/password credentials.
* To keep things simple, there is currently no support for versioning of the Backup file. So subsequent executions of the periodic backup job overwrite a same target file in S3. But you can always enable versioning in AWS S3 Buckets, which is disabled by default. See [https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html](https://docs.aws.amazon.com/AmazonS3/latest/userguide/Versioning.html) for further details.
* One of the most important challenges of any backup approach is to make sure that the backups are not corrupted, and would work should we need to restore the system to a previous state. So we need to make sure we can test the backup, and, better, prior to saving the backup files. This is something not tested automatically (yet ?), but I am still exploring how to do this. Stay tuned, this will likely be the topic of a dedicated blog post in the near future.

Thanks for reading. As always, any feedback is more than welcome.

