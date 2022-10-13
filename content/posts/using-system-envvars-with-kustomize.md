+++
author = "Armel Soro"
categories = ["kubernetes", "kustomize", "continuous-deployment", "tip"]
date = 2020-07-01T19:10:02Z
description = ""
draft = false
image = "https://images.unsplash.com/photo-1547893547-7c2ab2cc9689?ixlib=rb-1.2.1&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=2000&fit=max&ixid=eyJhcHBfaWQiOjExNzczfQ"
slug = "using-system-envvars-with-kustomize"
summary = "After a general overview of what Kustomize allows to do, this blog post is more about  giving few tips about how we can leverage system environment variables to parameterize Kustomize files."
tags = ["kubernetes", "kustomize", "continuous-deployment", "tip"]
title = "Using system environment variables with Kustomize"

+++


**UPDATE (2022/07/28)**: The trick used here was previously documented officially, but the documentation has been reverted (because **it is supposed to be a bug**). Instead, a warning message now shows up: _This Kustomization is relying on a bug that loads values from the environment when they are omitted from an env file. This behaviour will be removed in the next major release of Kustomize. See_ [https://github.com/kubernetes/website/issues/35669](https://github.com/kubernetes/website/issues/35669) and [https://github.com/kubernetes-sigs/kustomize/issues/4731](https://github.com/kubernetes-sigs/kustomize/issues/4731)

**UPDATE(2022/01/07)**: The trick used here to set values from local environment variables has finally been documented in the [official documentation](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/#configmapgenerator): [kubernetes/website#30348](https://github.com/kubernetes/website/pull/30348) 

**UPDATE(2020/07/01)**: This uses an [eschewed (but undocumented) feature of Kustomize](https://kubectl.docs.kubernetes.io/faq/kustomize/eschewedfeatures/#build-time-side-effects-from-cli-args-or-env-variables). This trick may change, break, or inexplicably disappear at any time. So use this at your own risk!

---

On my journey with [Kubernetes](https://kubernetes.io/), I played a little bit with [Kustomize](https://kubernetes-sigs.github.io/kustomize/), which is a great tool for adjusting Kubernetes YAML resources to various deployment environments. I was actually surprised to see how Kustomize enforces the use of files (versioned) to build the Kubernetes manifests. But I also stumbled upon an undocumented feature in its code, allowing to use runtime environment variables.

After a general overview of what Kustomize allows to do, we will walk through leveraging runtime system environment variables to parameterize Kustomize files.

A typical use case for this might be in Continuous Deployment (CD) contexts, where, rather than generating configuration files, we could easily leverage existing environment variables for deployment.

For reference, the whole Kustomize project used throughout this blog post is available at [GitHub://rm3l/kustomize_envvar](https://github.com/rm3l/kustomize_envvar)

## Overview

In a nutshell, using Kustomize, we would be able to:

* start from a set of base (and general-purpose) YAML files, which we do not want to alter
* apply patches to such base YAML files, resulting in customized YAML files which will get submitted to a given Kubernetes cluster

Since version 1.14, the kubectl command comes bundled with Kustomize, allowing us to use commands such as:

```bash
kubectl kustomize /path/to/kustomize/overlay | kubectl apply -f -
```

or

```bash
kubectl apply -k /path/to/kustomize/overlay
```

### Anatomy of a Kustomize project

Let's walk through a simple scenario to better understand what we want to do.

Say we have the following project structure for Kustomize:

```bash
❯ tree     
.
├── base
│   ├── deployment.yaml
│   └── kustomization.yaml
└── overlays
    └── staging
        ├── config.properties
        ├── deployment.yaml
        └── kustomization.yaml
```

### Base

_base_ is the folder containing the set of raw Kubernetes files which we do not want to alter at all.

* _base/deployment.yaml_ is a typical YAML Deployment descriptor for Kubernetes:. For example, it deploys 3 replicas of a Pod configured via a [ConfigMap](https://kubernetes.io/docs/concepts/configuration/configmap/) that needs to be provided. Here we will configure the _ENABLE_RISKY_ environment variable flag.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: the-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      deployment: hello
  template:
    metadata:
      labels:
        deployment: hello
    spec:
      containers:
      - name: the-container
        image: monopole/hello:1
        command: ["/hello",
                  "--port=8080",
                  "--enableRiskyFeature=$(ENABLE_RISKY)"]
        ports:
        - containerPort: 8080
        env:
        - name: ALT_GREETING
          valueFrom:
            configMapKeyRef:
              name: the-map
              key: ALT_GREETING
        - name: ENABLE_RISKY
          valueFrom:
            configMapKeyRef:
              name: the-map
              key: ENABLE_RISKY
```

* And _base/kustomization.yaml_ is a descriptor needed for Kustomize.  In this case, it simply declares all resources that should be included by Kustomize using the _resources_ field:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
```

### Overlays

_Overlays_ contain a set of variants off of a same base Kustomization configuration, and allows to apply patches to cater to various environment needs.

As the name suggests here, _overlays/staging_ contains the variant for a staging environment. It will allow us to provide the _the-map_ ConfigMap with the _ENABLE_RISKY_ key configurable dynamically at runtime via a system environment variable.

* _overlays/staging/kustomization.yaml_ looks like what follows. It declares the base directory, along with the way to generate the _the-map_ ConfigMap from a given key-value properties file, along with a patch to apply to :

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namePrefix: staging-

bases:
  - ../../base

configMapGenerator:
  - name: the-map
    env: config.properties

patchesStrategicMerge:
  - deployment.yaml

```

* _overlays/staging/deployment.yaml_ file is a simple deployment which once merged with the base one, will change the number of replicas from 3 to 2 for the _staging_ variant. As you can see below, we do not need to provide a complete valid Kubernetes Deployment resource. But using the _patchesStrategicMerge_ strategy, Kustomize is able to find the resource using its name (_the-deployment_ here) and merge the two files.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: the-deployment
spec:
  replicas: 2
```

* _overlays/staging/config.properties_ is a simple key-value properties file used by Kustomize to generate the _the-map_ ConfigMap:

```
ALT_GREETING=Hiya
ENABLE_RISKY=false
```

### Building the Kustomize overlay

Now that all the structure of our Kustomize project is defined, we can test it by generating Kubernetes YAML descriptors for our staging overlay:

```bash
❯ kubectl kustomize overlays/staging


apiVersion: v1
data:
  ALT_GREETING: Hiya
  ENABLE_RISKY: "false"
kind: ConfigMap
metadata:
  name: staging-the-map-7c88gg7h68
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: staging-the-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      deployment: hello
  template:
    metadata:
      labels:
        deployment: hello
    spec:
      containers:
      - command:
        - /hello
        - --port=8080
        - --enableRiskyFeature=$(ENABLE_RISKY)
        env:
        - name: ALT_GREETING
          valueFrom:
            configMapKeyRef:
              key: ALT_GREETING
              name: staging-the-map-7c88gg7h68
        - name: ENABLE_RISKY
          valueFrom:
            configMapKeyRef:
              key: ENABLE_RISKY
              name: staging-the-map-7c88gg7h68
        image: monopole/hello:2
        name: the-container
        ports:
        - containerPort: 8080
```

The command above outputs the resulting Kubernetes resources which we can then pipe and apply against out Kubernetes cluster:

```bash
❯ kubectl kustomize overlays/staging  | kubectl apply -f -

configmap/staging-the-map-5mfm8kmm8t created
deployment.apps/staging-the-deployment created
```

## Using system environment variables

As we can see in the sample project below, the ConfigMap keys and values are pretty static, and cannot be overridden easily. For this, we could simply copy the overlays/staging folder and change the new overlay _config.properties_ accordingly, but this is cumbersome to me just for changing values in the ConfigMap.

The _kustomize_ command exposes an _edit_ command, which edits the kustomization.yaml file, and can be called with environment variables if needed.

What I wanted to do instead is use the same _overlays/staging_ variant, but alter the ENABLE_RISKY property at runtime from environment variables, without editing any _kustomization.yaml_ files.

To do so, the trick is basically to change 2 things:

* Declare the alter-able key in the overlays/staging/config.properties file, i.e., with no value, e.g.:

```bash
ALT_GREETING=Hiya
ENABLE_RISKY
```

* Export the environment variable prior to calling Kustomize:

```bash
❯ ENABLE_RISKY="true" kubectl kustomize overlays/staging

apiVersion: v1
data:
  ALT_GREETING: Hiya
  ENABLE_RISKY: "true"
kind: ConfigMap
metadata:
  name: staging-the-map-5mfm8kmm8t
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: staging-the-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      deployment: hello
  template:
    metadata:
      labels:
        deployment: hello
##### The rest of the output has been omitted for brevity ####
```

As we can see in the resulting output, the _ENABLE_RISKY_ variable has been successfully changed to "_true_".

## Explanations

After digging a little bit into [Kustomize source code](https://github.com/kubernetes-sigs/kustomize), I found out that, when keys are set but without values, the key-value loaders in Kustomize generators default to the context environment when parsing env files. See [this code block](https://github.com/kubernetes-sigs/kustomize/blob/master/api/kv/kv.go#L163-L169):

```go
    if len(data) == 2 {
        kv.Value = data[1]
    } else {
        // No value (no `=` in the line) is a signal to obtain the value
        // from the environment.
        kv.Value = os.Getenv(key)
    }
    kv.Key = key
    return kv, nil
```

This is not documented at all, but good to keep in mind, until this behavior eventually changes in the future. I don't know whether this is intentional, but for now, I thought it was worth sharing to people with similar needs.

**EDIT**

* I just stumbled upon this [open issue](https://github.com/kubernetes-sigs/kustomize/issues/2301) in GitHub describing this, along with other possible alternatives (like using the _envsubst_ command).

