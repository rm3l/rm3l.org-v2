---
author: "Armel Soro"
categories: ["ghost", "blog", "kubernetes", "hetzner-cloud", "continuous-deployment", "gitlab"]
date: 2019-09-07T18:08:00Z
description: ""
draft: false
image: "https://images.unsplash.com/photo-1471107340929-a87cd0f5b5f3?ixlib=rb-1.2.1&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=2000&fit=max&ixid=eyJhcHBfaWQiOjExNzczfQ"
slug: "this-ghost-blog-is-now-running-with-lets-encrypt-in-a-cheap-bare-metal-kubernetes-cluster-on-hetzner-cloud-part-2-3"
summary: "On how to run a Ghost blog with Let's Encrypt in a cheap bare-metal Kubernetes Cluster in Hetzner Cloud"
tags: ["ghost", "blog", "kubernetes", "hetzner-cloud", "continuous-deployment", "gitlab"]
title: "This Ghost Blog is now running with Let's Encrypt in a cheap bare-metal Kubernetes Cluster (on Hetzner Cloud) — Part 2/3"
resources:
- name: "featured-image"
  src: "featured-image.jpg"
---


* [Part 1](https://rm3l.org/this-blog-is-now-running-in-a-bare-metal-kubernetes-cluster-this-is-what-i-did/)
* [Part 3](https://rm3l.org/this-ghost-blog-is-now-running-with-lets-encrypt-in-a-cheap-bare-metal-kubernetes-cluster-on-hetzner-cloud-part-3-3/)

## About storage and persistence

A service like a blog needs to run in a stateful manner, so all articles are persisted. This blog was initially set up with a MySQL database along with local on-disk persistence for images and themes. In order to run on Kubernetes, it is therefore needed to rethink of how persistence would be managed, due to the volatile nature of containers in Kubernetes. Containers may come and go at any time, but state needs to be persisted somewhere.

I tested the approaches depicted below, but ended up using the first method (Container Storage Interface). There are however many other options for handling storage that I might explore later on.

### Container Storage Interface (CSI)

CSI is a standard meant to be implemented by most Kubernetes providers, so cloud-native applications could be easily portable. In a nutshell, this specification allows users to claim some classes of volumes (via for example a [PersistentVolumeClaim](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#persistentvolumeclaims)), which could then be mapped under the hood by persistent volumes auto-provisioned by the cloud provider in which the containers are running.

Hetzner Cloud provides an Open-Source CSI-compatible driver: [Github://hetznercloud/csi-driver](https://github.com/hetznercloud/csi-driver).

**Installation**

* Grab your personal account token under your Hetzner Account. Open "_Cloud Console > Access > API Tokens > Generate API Token_"
* Create a secret with the token above
* Apply the secret file created above
* Now we can deploy the storage driver in our Kubernetes Cluster:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: hcloud-csi
  namespace: kube-system
stringData:
  token: <MY_TOKEN>
```

```bash
kubectl apply -f <secret.yml>
```

```bash
kubectl apply -f https://raw.githubusercontent.com/hetznercloud/csi-driver/v1.2.0/deploy/kubernetes/hcloud-csi.yml
```

**Example Usage**

First a YML descriptor for the PersistentVolumeClaim (say saved as _my-blog-pvc,yml_), as follows:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: rm3l-org-content
spec:
  storageClassName: hcloud-volumes
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
```

As you can see, the storage class name is what actually what makes Kubernetes leverage the CSI driver for Hetzner.

Next, we can apply it to our Kubernetes cluster, which should result in a new volume being provisioned in your Hetzner Account:

```bash
kubectl apply -f my-blog-pvc.yml

```

We can now see in our Hetzner Cloud Web Console that a volume (10GB is the minimum at this time) is created:

![Hetzner volume from CSI Driver](https://rm3l-org.s3-us-west-1.amazonaws.com/assets/Hetzner-cloud-pvc-csi.png)

### Network File System (NFS) share, using Rook

[Rook](https://rook.io/) is a Cloud Native Computing Foundation incubating project (at the time of writing), with interesting features such as storage orchestration for Kubernetes.

The steps to use it are very well documented [here](https://rook.io/docs/rook/v1.1/nfs-crd.html), but unfortunately, I didn't explore this any further, due to [port 111 (PortMapper / rpcbind)](https://service-names-port-numbers.services.rm3l.org/graphiql?query=query%20%7B%0A%20%20records(filter%3A%20%7Bports%3A%20111%7D)%20%7B%0A%20%20%20%20serviceName%0A%20%20%20%20description%0A%20%20%20%20transportProtocol%0A%20%20%7D%0A%7D) being open in my nodes and flagged as unsecured traffic by folks at Hetzner Cloud.

In fact, in addition to being potentially abused for DDoS reflection attacks, the Portmapper service may be used by attackers to obtain information on target networks, like available RPC services or network shares (as is the case with NFS). We could mitigate the risk by adding strict firewall rules ([ufw - the uncomplicated firewall](https://wiki.ubuntu.com/UncomplicatedFirewall) might help for this) to make sure this port is not exposed publicly.

## Managing auto-renewable SSL certificates with Let's Encrypt

HTTPS is now becoming more and more important to any website, and Let's Encrypt greatly helps democratize its adoption by:

* providing free SSL/TLS signed certificates and a (relatively simple) API to generate these certificates.
* and being a Certificate Authority recognized by most modern tools, including browsers.

By default, pods of Kubernetes services are not accessible from the external network, but only by other pods within the Kubernetes cluster. Kubernetes has a built‑in configuration for HTTP load balancing, called _Ingress_, that defines rules for external connectivity to Kubernetes services.

If the remote cloud provider of choice supports it, you can even request a load balanced auto-managed IP address or hostname for the Service. This is something that can quickly add up to the usage bill, depending on the traffic.

At this time, Hetzner Cloud does not provide a fully-managed Kubernetes cluster, but we may still set up basic routing rules to different services.

The advantage of using _Ingress_ resources is that we can easily configure for typical load-balancing use cases, such as SSL/TLS Termination or rewrite rules.

_Ingress_ can be backed by different implementations through the use of different Ingress Controllers. The most popular of these is the [NGINX Ingress Controller](https://www.nginx.com/products/nginx/kubernetes-ingress-controller); however there are other options available such as [Traefik](https://docs.traefik.io/) or [Rancher](https://github.com/rancher/lb-controller). Each controller should support a basic configuration, but can even expose other features (rewrite rules, authentication modes) via annotations.

In the scope of this work, we will use NGINX Ingress Controller. Installation instructions are provided [here](https://github.com/kubernetes/ingress-nginx/blob/master/docs/deploy/index.md), but one command to apply is:

```bash
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/mandatory.yaml
```

Once the mandatory setup is done, we need to define an NGINX load-balancer configuration file (e.g.: _ingress-nginx.k8s.yaml_) and instruct Kubernetes to create it:

```yaml
kind: Service
apiVersion: v1
metadata:
  name: ingress-nginx
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
spec:
  type: LoadBalancer
  selector:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
  ports:
    - name: http
      port: 80
      targetPort: http
    - name: https
      port: 443
      targetPort: https
```

We can now apply it and check that the service is actually up and running:

```bash
kubectl apply -f ingress-nginx.k8s.yaml 
```

We should have a Service of type LoadBalancer, with Cluster-IP and External-IP picked from the pool of IP addresses added in the "About Networking" section above (via MetalLB), e.g:

```bash
❯ kubectl get svc --namespace ingress-nginx
Alias tip: kgs --namespace ingress-nginx
NAME            TYPE           CLUSTER-IP     EXTERNAL-IP       PORT(S)                      AGE
ingress-nginx   LoadBalancer   10.99.77.237   116.203.238.174   80:32255/TCP,443:32464/TCP   64d
```

Next step is now to create a dedicated namespace in which cert-manager configuration will live, as depicted below. For reference, cert-manager is a native [Kubernetes](https://kubernetes.io/) certificate management controller. It can help with issuing certificates from a variety of sources, such as [Let’s Encrypt](https://letsencrypt.org/), [HashiCorp Vault](https://www.vaultproject.io/), [Venafi](https://www.venafi.com/), a simple signing key pair, or self signed. It also ensures certificates are valid and up to date, and attempts to renew certificates at a configured time before expiry.

```bash
# Create a namespace to run cert-manager in
kubectl create namespace cert-manager

# Disable resource validation on the cert-manager namespace
kubectl label namespace cert-manager certmanager.k8s.io/disable-validation=true

# Install the CustomResourceDefinitions and cert-manager itself
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v0.10.1/cert-manager.yaml

```

Now that this is done, we need to create certificate issuers resource. Since Let's Encrypt enforces [rate limits](https://letsencrypt.org/docs/rate-limits/) to ensure a fair usage, it is recommended to first test this against their staging environment first, and once confident, switch to the Production environment.

This covers the staging environment, but can be easily translated to Production.

Below is an example of a YAML file to create a Certificate Issuer against the staging environment:

```yaml
   apiVersion: certmanager.k8s.io/v1alpha1
   kind: ClusterIssuer
   metadata:
     name: letsencrypt-staging
   spec:
     acme:
       # The ACME server URL
       server: https://acme-staging-v02.api.letsencrypt.org/directory
       # Email address used for ACME registration
       email: my-admin@my-company.com
       # Name of a secret used to store the ACME account private key
       privateKeySecretRef:
         name: letsencrypt-staging
       # Enable the HTTP-01 challenge provider
       solvers:
       - http01:
           ingress:
             class:  nginx
```

Now we can apply it with _kubectl apply -f ..._

