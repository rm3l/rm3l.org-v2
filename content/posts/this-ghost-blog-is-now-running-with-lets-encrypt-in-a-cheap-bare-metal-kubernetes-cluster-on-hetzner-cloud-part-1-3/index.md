---
author: "Armel Soro"
categories: ["ghost", "blog", "kubernetes", "gitlab", "hetzner", "lets-encrypt", "continuous-deployment"]
date: 2019-04-25T18:58:00Z
description: ""
draft: false
image: "https://images.unsplash.com/photo-1471107340929-a87cd0f5b5f3?ixlib=rb-1.2.1&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=2000&fit=max&ixid=eyJhcHBfaWQiOjExNzczfQ"
slug: "this-ghost-blog-is-now-running-with-lets-encrypt-in-a-cheap-bare-metal-kubernetes-cluster-on-hetzner-cloud-part-1-3"
summary: "On how to run a Ghost blog with Let's Encrypt in a cheap bare-metal Kubernetes Cluster in Hetzner Cloud"
tags: ["ghost", "blog", "kubernetes", "gitlab", "hetzner", "lets-encrypt", "continuous-deployment"]
title: "This Ghost Blog is now running with Let's Encrypt in a cheap bare-metal Kubernetes Cluster (on Hetzner Cloud) — Part 1/3"
resources:
- name: "featured-image"
  src: "featured-image.jpg"
---


With the goal of experimenting a little bit with Kubernetes and learn more about it, I recently set out to deploy and run this blog (powered by Ghost, under the hood) in a Kubernetes Cluster.

You may find it a bit overkill, but right now, this blog is running in a cheap bare-metal Kubernetes Cluster on Hetzner Cloud. Auto-renewable SSL certificates signed by [Let's Encrypt](https://letsencrypt.org/) authority are also provided in the Kubernetes Cluster. I found this to be not only a great hands-on training, but also a good example of running a highly-available, fast and scalable website combining modern tools.

I first experimented with a simple home-based setup leveraging a local Minikube deployment, but that was for local testing purposes only, and not a production-grade deployment. Then started the quest for a cheap way to deploy and manage a real Kubernetes Cluster.

Managed Clusters provided by Cloud Providers look way too expensive for such side projects, even if they provide a much more reliable and hassle-free setup, so users can focus on what they do best. For learning purposes, I wanted instead to "reinvent the wheel", by starting from scratch :)

I selected [Hetzner Cloud](https://www.hetzner.com/cloud) as the cheapest provider for setting up a bare-metal 3-nodes Kubernetes cluster (minimum number of nodes for distributed coordination), which at the time of writing would overall cost a little less than €9/month.

This post covers the underlying architecture of the blog, and the concrete steps that head me there, in the form of a tutorial. Before proceeding, you may want to have a very high level overview of Kubernetes, along with a definition of the core concepts behind it. There are already tons of resources available out there, but the [official documentation](https://kubernetes.io/docs/concepts/) is a good starting point for that matter.

## Architecture Overview

Below is a high level view of the deployment workflow, from a push to the Git Repository to a live deployment to the Kubernetes Cluster:

![CI and CD with Gitlab and an on-premise K8s cluster](https://rm3l-org.s3-us-west-1.amazonaws.com/assets/rm3l-org_CI_CD---k8s.png)

At this time, the GitLab repository contains:

* a _Dockerfile_ instructions to build the Ghost blog container image, along with any accompanying resource
* a set of YAML descriptors to apply to request resources in the Kubernetes cluster.
* a _.gitlab-ci.yml_ file containing the pipelines for build, test, continuous integration and deployment

## Creating the bare-metal cluster

First things first, you obviously need nodes in the cluster. Kubernetes recommends a cluster of at least 3 nodes, for better coordination.

* I picked 3 nodes with the minimum characteristics for the moment: Ubuntu 18.04 Operating System image, Local SSD storage, for €2.99/month. Bear in mind that the cluster can be scaled horizontally at any time later on, i.e. more nodes may be added to or removed from the cluster as needed.
* I also created a (free) private network in Hetzner for a better control of the internal IP addressing, e.g. a 192.168.33.0/24 network.
* Then you select one node as Master and the other ones as regular non-master nodes. I arbitrarily assigned the following internal private addresses: Master: 192.168.33.1, and the two other ones: 192.168.33.10 and 192.168.33.11
* On each node, make sure you installed [kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/) and [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/).
* Then, following the official instructions, we can bootstrap the cluster with the official `kubeadm` command as `root`:

```bash
kubeadm init \
  --apiserver-cert-extra-sans=master.k8s,192.168.33.1 \
  --node-name=master.k8s \
  --pod-network-cidr=10.244.0.0/16 \
  --ignore-preflight-errors=NumCPU
```

This might take a while the very first time, but consider it done when the following line is printed out: _Your Kubernetes control-plane has initialized successfully!_

Also do not forger to grab the 'kubeadm join' command printed out. This is what we will need to run in order for all other non-master nodes to join the cluster.

* To start using the cluster, we then need to run the command below as a regular user:

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

* Next step is now to deploy a pod network to the cluster. All options are documented [here](https://kubernetes.io/docs/concepts/cluster-administration/addons/#networking-and-network-policy). I selected [Weave Net](https://www.weave.works/docs/net/latest/kubernetes/kube-addon/), which I had read a lot about. Creating the pod network is as simple as running the command below:

```bash
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"

```

* Once the pod network is installed, we can log into each other non-master node, and make it join the network, e.g., with the command above (make sure to use the right token, CA certificate hash and the right master DNS or IP address):

```bash
kubeadm join 192.168.33.1:6443 \
  --token <token> \
  --discovery-token-ca-cert-hash <cert-hash> \
  --node-name=`hostname -s`
```

* Although not generally recommended, I intended for this side project to have the Master node act as a worker node, so as to be eligible to running actual workload pods.

```bash
kubectl taint nodes --all node-role.kubernetes.io/master-
```

* Now we can make sure our cluster is set up and running:

```bash
❯ kubectl get nodes
Alias tip: kgno
NAME           STATUS   ROLES    AGE   VERSION
k8s-master     Ready    <none>   60d   v1.16.0
k8s-node-2     Ready    <none>   60d   v1.16.0
k8s-node-3     Ready    <none>   60d   v1.16.0
```

## About networking

As depicted in the architecture diagram above, I intended to use a software Load Balancer to handle incoming traffic to the Kubernetes cluster.

However Kubernetes per se does not offer an implementation of network load balancers for bare-metal clusters like this one, but instead encourages to leverage a supported Cloud Provider (Google Cloud Platform GCP, Amazon Web Services AWS, Microsoft Azure, Digital Ocean, ...).

To overcome this limitation for bare-metal clusters, I stumbled upon [MetalLB](https://metallb.universe.tf/concepts/), a great Network Load Balancer implementation for Kubernetes that can even integrate with standard network equipment like BGP routers.

Note however that MetalLB is still in Beta at this time, so you should not (yet) consider it production-safe.

Installing MetalLB is as easy as deploying its manifest, which will install components under the metalb namespace:

```bash
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.8.3/manifests/metallb.yaml
```

At this stage, MetalLB's components will be installed, but in order for them to be utterly up, we need to define and apply a ConfigMap. The one I used is pretty basic and looks like this:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - <my_node1_public_ip_address>/32
      - <my_node2_public_ip_address>/32
      - <my_node3_public_ip_address>/32
```

This essentially tells MetalLB to operate in Layer 2 mode, by handling Address Resolution Protocol (ARP) requests. It is possible to specify a pool of IP addresses under the addresses section.

We can confirm that everything is up and running by issuing the following command:

```bash
❯ kubectl get pods --namespace metallb-system
Alias tip: kgp --namespace metallb-system
NAME                          READY   STATUS    RESTARTS   AGE
controller-6bcfdfd677-62rf6   1/1     Running   0          59d
speaker-5szn8                 1/1     Running   0          59d
speaker-8l25w                 1/1     Running   0          59d
speaker-h5qd5                 1/1     Running   1          59d
speaker-lq8vg                 1/1     Running   0          59d

```

* [Part 2](https://rm3l.org/this-ghost-blog-is-now-running-with-lets-encrypt-in-a-cheap-bare-metal-kubernetes-cluster-on-hetzner-cloud-part-2-3/)
* [Part 3](https://rm3l.org/this-ghost-blog-is-now-running-with-lets-encrypt-in-a-cheap-bare-metal-kubernetes-cluster-on-hetzner-cloud-part-3-3/)





