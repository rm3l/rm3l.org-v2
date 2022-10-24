---
author: "Armel Soro"
categories: ["Blogs"]
date: 2019-10-29T21:09:00Z
description: ""
draft: false
image: "https://images.unsplash.com/photo-1471107340929-a87cd0f5b5f3?ixlib=rb-1.2.1&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=2000&fit=max&ixid=eyJhcHBfaWQiOjExNzczfQ"
slug: "this-ghost-blog-is-now-running-with-lets-encrypt-in-a-cheap-bare-metal-kubernetes-cluster-on-hetzner-cloud-part-3-3"
summary: "On how to run a Ghost blog with Let's Encrypt in a cheap bare-metal Kubernetes Cluster in Hetzner Cloud"
tags: ["ghost", "kubernetes", "gitlab", "hetzner", "lets-encrypt", "ci", "cd"]
title: "This Ghost Blog is now running with Let's Encrypt in a cheap bare-metal Kubernetes Cluster (on Hetzner Cloud) — Part 3/3"
resources:
- name: "featured-image"
  src: "featured-image.jpg"

---


* [Part 1](https://rm3l.org/this-ghost-blog-is-now-running-with-lets-encrypt-in-a-cheap-bare-metal-kubernetes-cluster-on-hetzner-cloud-part-2-3/)
* [Part 2](https://rm3l.org/this-ghost-blog-is-now-running-with-lets-encrypt-in-a-cheap-bare-metal-kubernetes-cluster-on-hetzner-cloud-part-2-3/)

## Blog Deployment Descriptors

This will now describe the different sections of the YAML files deployed.

### Storage

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

As discussed previously, we leverage the specific Container Storage Interface (CSI) Implementation for Hetzner, which we installed previously. This will then make Hetzner create a volume and bind it to a single node in Hetzner Cloud.

Note that the CSI driver does not support at the time of writing ReadWriteMany strategy. As a consequence, only one node at a given point in time can access the volume created. We will see below that unfortunately we cannot have more than 1 replicas, and this may imply some downtime when creating the Replica.

### Pods Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rm3l-org
  labels:
    app: rm3l-org
    org.rm3l.services.service_name: rm3l-org
spec:
  # Only 1 replica here, due to PVC limitation in Hetzner!
  replicas: 1
  selector:
    matchLabels:
      app: rm3l-org
  strategy:
    # We accept some downtime, due to the fact that 2 containers cannot share the same PVC in Hetzner Cloud.
    # The CSI Driver for Hetzner does not support ReadWriteMany access mode => we cannot use RollingUpdate
    # strategy since this would imply more than one pod running at the same time
    type: Recreate
  template:
    metadata:
      labels:
        app: rm3l-org
    spec:
      affinity:
        podAntiAffinity:
          # No 2 'rm3l-org' pods should be on the same node host
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchExpressions:
                - key: app
                  operator: In
                  values:
                  - rm3l-org
              topologyKey: "kubernetes.io/hostname"
      containers:
      - name: rm3l-org
        image: registry.gitlab.com/lemra/services/rm3l-org:<VERSION>
        resources:
          limits:
            memory: "500Mi"
          requests:
            memory: "100Mi"
        ports:
        - containerPort: 2368
        lifecycle:
          postStart:
            exec:
              command: ["/bin/sh", "-c", "chmod 700 /data/ghost/populate_ghost_content.sh && /data/ghost/populate_ghost_content.sh"]
        livenessProbe:
          httpGet:
            path: /
            port: 2368
          initialDelaySeconds: 30
          periodSeconds: 90
          timeoutSeconds: 60
        readinessProbe:
          httpGet:
            path: /
            port: 2368
          initialDelaySeconds: 30
          periodSeconds: 60
        volumeMounts:
        - mountPath: /var/lib/ghost/content
          name: rm3l-org-content
        env:
        - name: url
          value: https://rm3l.org
      volumes:
        - name: rm3l-org-content
          persistentVolumeClaim:
            claimName: rm3l-org-content
      imagePullSecrets:
        - name: gitlab-registry-services-creds
```

Note that the container image is pulled from my own private GitLab Docker registry, but the exact steps involved for this will be covered in a separate blog post.

Also, for dynamic resource management, I configured an AutoScaler, to ensure new pods are created once the CPU utilization is above 70% on average:

```yaml
apiVersion: autoscaling/v2beta2
kind: HorizontalPodAutoscaler
metadata:
  name: rm3l-org
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: rm3l-org
  minReplicas: 1
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Services

```yaml
apiVersion: v1
kind: Service
metadata:
  name: rm3l-org
spec:
  selector:
    app: rm3l-org
  ports:
  - protocol: TCP
    port: 2368
    targetPort: 2368
  type: ClusterIP
```

Here I want to expose the Service onto an external IP address, that’s outside of the cluster. The _ClusterIP_ service type exposes the Service on a cluster-internal IP. Choosing this value makes the Service only reachable from within the cluster. This is the default ServiceType.

Remember that NGINX is configured as our Ingress Resource, and as such, will serve as the main reverse-proxy entry-point to the application.

### Ingress

```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: services-rm3l-org-ingress
  annotations:
    kubernetes.io/ingress.class: "nginx"
    certmanager.k8s.io/cluster-issuer: "letsencrypt-staging"
spec:
  tls:
  - hosts:
    - rm3l.org
    secretName: letsencrypt-staging
  rules:
  - host: rm3l.org
    http:
      paths:
      - backend:
          serviceName: rm3l-org
          servicePort: 2368
```

This simply creates an Ingress resource in the cluster which does host-based routing and TLS/SSL termination. This means that the requested host allows the Ingress to determine the right backend service to route the request to. And this is what will actually trigger the Cert-Manager to:

* place orders for a certificate for _rm3l.org_ host
* manage challenges requested by Let's Encrypt for domain validation
* manage certificate auto-renewal

Once this is done, the blog should be reachable via the NGINX Ingress External IP address, which I set as an A resource in my DNS provider settings for this domain. This allows "_rm3l.org_" to be resolved by the NGINX Ingress External IP Address.

## Wrapping up

This was a pretty fun and exciting journey to playing and learning a lot more about Kubernetes (on both the _provision-and-manage_ and the _deploy-in-the-cluster_ perspectives).

_Change being the only constant_, my next step is now to attempt a different deployment strategy for this blog, now that [Ghost 3.0](https://ghost.org/blog/3-0/) has been released with support for a true headless CMS.

I now look forward to deploying this blog using the JAMStack (as in ****J****avaScript, ****A****PIs, ****M****arkup), using [Gatsby.js](https://www.gatsbyjs.org/) (front-end) + [Netlify](https://www.netlify.com/) (PaaS) + Ghost (headless CMS back-end).

Please stay tuned — this other journey will be the topic of another blog post.

