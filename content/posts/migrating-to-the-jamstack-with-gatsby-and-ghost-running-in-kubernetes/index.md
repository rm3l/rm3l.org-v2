---
author: "Armel Soro"
categories: ["gatsbyjs", "reactjs", "netlify", "ghost", "kubernetes", "k8s", "cms", "gatsby", "react", "jamstack"]
date: 2020-01-23T20:33:00Z
description: ""
draft: false
image: "https://images.unsplash.com/photo-1518459384564-ecfd8e80721f?ixlib=rb-1.2.1&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=2000&fit=max&ixid=eyJhcHBfaWQiOjExNzczfQ"
slug: "migrating-to-the-jamstack-with-gatsby-and-ghost-running-in-kubernetes"
summary: "This blog post depicts how a last year experiment of running this Ghot blog in Kubernetes went further by migrating to the JAMstack: Gatsby as the FrontEnd (deployed to Netlify) and Ghost as a headless CMS running in Kubernetes."
tags: ["gatsbyjs", "reactjs", "netlify", "ghost", "kubernetes", "k8s", "cms", "gatsby", "react", "jamstack"]
title: "Migrating this blog to the JAMstack: Gatsby as the FrontEnd, with Ghost as a headless CMS running in a self-hosted Kubernetes cluster"
resources:
- name: "featured-image"
  src: "featured-image.jpg"
---


First of all, Happy New Year 2020 to you all!

Last year, I set out to run this Ghost-powered Blog in a Kubernetes (K8s) cluster, namely for learning purposes. You can read more about this journey in the following series: [Part 1](https://rm3l.org/this-blog-is-now-running-in-a-bare-metal-kubernetes-cluster-this-is-what-i-did/), [Part 2](https://rm3l.org/this-ghost-blog-is-now-running-with-lets-encrypt-in-a-cheap-bare-metal-kubernetes-cluster-on-hetzner-cloud-part-2-3/) and [Part 3](https://rm3l.org/this-ghost-blog-is-now-running-with-lets-encrypt-in-a-cheap-bare-metal-kubernetes-cluster-on-hetzner-cloud-part-3-3/).

However, as the site itself was running on commodity low-resources nodes, rendering was not as fast as I would have expected. Meanwhile, I heard about Ghost 3.0 joining the JAMstack (for **J**avaScript, **A**PIs, **M**arkup stack) movement by revamping its architecture so as to make it a completely decoupled headless Content Management System (CMS). This means we could plug any FrontEnd (even statically generated sites) to Ghost, in order to make the most of it.

This is how my last-year journey went further, when I set out to refresh (again) this website with:

* Ghost as a headless CMS, still continuously deployed and running in my Kubernetes Cluster
* A static site generator, hosted and served by a fast Content Delivery Network (CDN) provider (e.g, Netlify), so as to provide a blazing fast end-user experience

## Architecture Overview

![rm3l.org Architecture Overview](https://rm3l-org.s3-us-west-1.amazonaws.com/assets/rm3l.org+-+Ghost+%2B+Gatsby+%2B+Netlify.png)

In a nutshell, here are the main components behind this architecture:

* The actual self-hosted Ghost CMS, where I can edit the blog content. This is running in a personal on-premises Kubernetes cluster. Here we talk about content solely, regardless of how such content is supposed to look like to the readers. Ghost natively exposes a GraphQL API for all content published, which will get consumed by the FrontEnd below.
* The Frontend is then powered by a public dedicated [GitHub://rm3l/rm3l.org](https://github.com/rm3l/rm3l.org) Git repository in GitHub, which contains sources for GatsbyJS. I started by using the official gastby-ghost-starter, then customized it for my case.

## Why Gatsby?

Performance being a key non-functional requirement for me, I selected Gatsby simply because it really is very fast, both in generating an optimized static website and rendering it. Also, it allows to get started very quickly by using a bunch of starters we are provided with. For example, Ghost provides an official [gastby-starter-ghost](https://github.com/tryghost/gatsby-starter-ghost) starter plugin. Integrating with Ghost (or even any other data sources) is pretty straightforward, and testing is even simpler. Local development is also made possible.

## Running a headless Ghost CMS in Kubernetes

Here, the setup did not change too much after the previous work depicted in following series: [Part 1](https://rm3l.org/this-blog-is-now-running-in-a-bare-metal-kubernetes-cluster-this-is-what-i-did/), [Part 2](https://rm3l.org/this-ghost-blog-is-now-running-with-lets-encrypt-in-a-cheap-bare-metal-kubernetes-cluster-on-hetzner-cloud-part-2-3/) and [Part 3](https://rm3l.org/this-ghost-blog-is-now-running-with-lets-encrypt-in-a-cheap-bare-metal-kubernetes-cluster-on-hetzner-cloud-part-3-3/), with the following exceptions:

* Ghost will essentially be running as a headless CMS, i.e, the FrontEnd will be running elsewhere. This means we do not have to bother with handling styles in Ghost itself.
* We still need to handle persistence, as a blog is stateful _per se_.
* For maximum productivity, the Ghost instance is also deployed continuously in Kubernetes, from a dedicated Git repository on GitLab, used for continuous deployment in the Kubernetes cluster.

### Building the Ghost container image

Ghost provides [official Docker images](https://hub.docker.com/_/ghost/), which I used as base images for my use case. The corresponding Dockerfile is quite straightforward:

```bash
#
# Ghost-powered Blog (mainly used as a headless CMS)
#
FROM ghost:3.19.2-alpine

LABEL maintainer="armel@rm3l.org"

RUN apk add --no-cache curl
```

Please note that the base Ghost image leverages a local SQLite database by default; therefore, in order not to lose everything due to the volatile nature of containers in K8s, we need to store content outside of the running containers. This is depicted in the section below.

### Deploying the Ghost headless CMS

As already mentioned above, the Ghost CMS is deployed entirely in my custom K8s cluster. Nothing really changed from the previous setup, except the storage part, which is [reportedly hard to handle in Kubernetes](https://softwareengineeringdaily.com/2019/01/11/why-is-storage-on-kubernetes-is-so-hard/).

Fortunately, as I explored more and more about this part, I came across [OpenEBS](https://openebs.io/), an open-source solution that aims to simplify storage in Kubernetes.

OpenEBS essentially provides a storage pool of nodes on top of the Kubernetes Cluster along with a control plane as well.

Installing it is just a matter of installing the corresponding [Helm](https://helm.sh/) chart, as an administrator of the K8s cluster leveraging Helm, e.g.:

```bash
helm install openebs --namespace openebs stable/openebs --version 1.5.0
```

This will install the storage class _openebs-jiva-default_, which installs Jiva, the default and lightweight storage engine that is recommended for low capacity workloads. At the moment, this covers the needs of this Ghost CMS. Please head to [this page](https://docs.openebs.io/docs/next/casengines.html) to learn more about the different storage engines in OpenEBS.

Once OpenEBS is installed in the K8s cluster, we can now request [Persistent Volumes Claims](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) (PVCs) (using the appropriate storage class installed) as regular users. For example, here is what I used:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cms-rm3l-org
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: openebs-jiva-default
```

Once the PVC is bound, the StatefulSet descriptor for this blog can be written easily so as to mount the Persistent Volume to the _/var/lib/ghost/content_ mount point in the pod containers:

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: cms-rm3l-org
  labels:
    app: cms-rm3l-org
    org.rm3l.services.service_name: cms-rm3l-org
spec:
  replicas: 3
  selector:
    matchLabels:
      app: cms-rm3l-org
  serviceName: cms-rm3l-org
  template:
    metadata:
      labels:
        app: cms-rm3l-org
    spec:
      volumes:
      - name: cms-rm3l-org-ghost-root
        persistentVolumeClaim:
          claimName: cms-rm3l-org
          readOnly: false

      containers:
      - name: cms-rm3l-org
        image: ghost:3.19.2-alpine
        ports:
        - name: liveness-port
          containerPort: 2368
        startupProbe:
          tcpSocket:
            port: liveness-port
          periodSeconds: 10
          failureThreshold: 30
        livenessProbe:
          tcpSocket:
            port: liveness-port
          initialDelaySeconds: 30
          periodSeconds: 90
          timeoutSeconds: 60
        readinessProbe:
          tcpSocket:
            port: liveness-port
          initialDelaySeconds: 30
          periodSeconds: 60
        volumeMounts:
          - name: cms-rm3l-org-ghost-root
            mountPath: /var/lib/ghost/content
```

The _Dockerfile_ and YAML descriptors for Kubernetes are pushed to a GitLab repository, which also contains a _.gitlab-ci.yml_ file, which is used not only for continuous integration but also for continuous deployment of the Ghost CMS in K8s.

### Making Ghost operate as a headless CMS

Thanks to its RESTful [Content API](https://ghost.org/docs/api/v3/content/), Ghost can operate as a completely decoupled CMS. In order to do so and pave the way to integrating with any external FrontEnd, we need to:

* Enable the Content API, and retrieve Content API Keys. A Content Key can be provided by creating an integration within Ghost Admin. Navigate to "_Settings > Integrations > Add custom integration_". Name the integration appropriately and click "_Create_". We need to keep note of the Content API Key, as we will use it in the steps below.
* Disable the default Ghost FrontEnd by marking the CMS site as private. For this, head to "_Settings > General > Advanced Settings > Make this site private_".

At this point, we now have Ghost operating as an entire Headless CMS. We are now ready to plug Gastby to generate and expose a static site.

## Using Gatsby as FrontEnd

Ghost provides an official starter for Gatsby. Just like with a [Maven archetype](https://rm3l.org/about-maven-archetypes/), this provides a great starting point for generating a structured Gatsby/React Git project configured with sensible defaults for using Ghost as its content source, along with the ability to deploy with Netlify.

Using it is as easy as [installing Gatsby CLI](https://www.gatsbyjs.org/docs/quick-start) first and then calling:

```bash
$ gatsby new <my-website> https://github.com/TryGhost/gatsby-starter-ghost

```

The local Git repository (in _<my-website>_) can then be pushed in any remote Git repo, e.g.:

```bash
$ cd <my-website>
$ git remote set-url origin git@github.com:<my-username-or-org>/<my-website>.git
$ git push origin master
```

In my case, I slightly updated the site repository with the following:

* a [portfolio](https://github.com/rm3l/rm3l.org/blob/master/src/pages/portfolio.js) React Component
* [CircleCI configuration](https://github.com/rm3l/rm3l.org/tree/master/.circleci), for continuous integration (CI)
* [Dependabot](https://dependabot.com/) configuration, to keep dependencies up-to-date
* [Cypress](https://www.cypress.io/) tests that test not only the local mode of Gatsby, but also deployed sites. This will be covered in detail in a separate blog post. In particular, we will explore how deployed websites can be tested via a Netlify webhook that calls a serverless function in Kubernetes; this function in turn is responsible for triggering a CircleCI build with the deployed website URL as parameter.

## Integration with Netlify

Integrating with Netlify is already covered in [this official guide](https://ghost.org/integrations/netlify/), so nothing more to add here. In an upcoming blog post, we will instead focus on configuring Netlify for Cypress-based testing of deployed websites.

At this point, if everything is set up correctly, any single modification in the headless CMS (like a new blog post published, or existing blog post updated) should trigger a Gatsby build in Netlify.

## Performance results

A quick performance test using [PageSpeed Insights](https://developers.google.com/speed/pagespeed/insights/?url=https%3A%2F%2Frm3l.org&tab=desktop) gave the following on Desktop. As we can see, the overall score is really great, thanks to that static website.

![Page Speed Insights - rm3l.org - Desktop](https://rm3l-org.s3-us-west-1.amazonaws.com/assets/PageSpeedInsignts_rm3l-org_Desktop.png)

Of course, there is still room for improvement in various areas, which I will work on later on. This includes tasks such as optimizing images rendering, which are still stored and served by the Ghost headless CMS itself.

## Conclusion

This has been an exciting journey that allowed me not only to be much more familiar with the JAMStack, but also to have a blazing fast blog running now. Ghost and Gatsby were quite easy to configure and play with.

Please stay tuned for the upcoming blog post which will cover testing for such static websites.

As always, please free to comment if you have any questions.

