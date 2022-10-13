---
author: "Armel Soro"
categories: ["helm", "helm-chart", "kubernetes", "dynamic-data", "gotpl"]
date: 2021-10-06T20:01:00Z
description: ""
draft: false
image: "https://images.unsplash.com/photo-1584786379647-c10852954d2b?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=MnwxMTc3M3wwfDF8c2VhcmNofDF8fG1lcmdpbmd8ZW58MHx8fHwxNjQwMTIxNjM1&ixlib=rb-1.2.1&q=80&w=2000"
slug: "merging-dynamic-config-data-in-helm-charts"
summary: "On how to merge dynamic data with Helm Charts"
tags: ["helm", "helm-chart", "kubernetes", "dynamic-data", "gotpl"]
title: "Merging dynamic configuration data in Helm Charts"
resources:
- name: "featured-image"
  src: "featured-image.jpg"
---


[Helm](https://helm.sh/) provides a nice way to distribute [Kubernetes](https://kubernetes.io/) applications, by allowing providers to define a set a templates ([Charts](https://helm.sh/docs/topics/charts/)) that make use of overridable inputs. Charts can then be instantiated and customized (as [Releases](https://helm.sh/docs/intro/using_helm/#three-big-concepts)), using inputs that can be set in [various ways](https://helm.sh/docs/intro/using_helm/#customizing-the-chart-before-installing), either via the command line, or via one or more [Values files](https://helm.sh/docs/chart_template_guide/values_files/).

At some point however, one might want to merge dynamic data, i.e. end-user values not known in advance by the Chart developers. For example, I had a simple case where, given a YAML object representing a base configuration to be used as a Kubernetes [ConfigMap](https://kubernetes.io/docs/concepts/configuration/configmap/), I wanted users to be able to override part of this configuration or append new properties to it, without me knowing the exact keys in the first place. This was needed for example in a [SpringBoot](https://spring.io/projects/spring-boot) application, which could define a lot of [Configuration properties](https://docs.spring.io/spring-boot/docs/current/reference/html/application-properties.html); and I did not want to explicitly list all possible properties in the default Chart Values file.

In other words, the Helm Chart would provide certain predefined configuration data, while users might specify other configuration data. And all these data would then get merged into a single Kubernetes [ConfigMap](https://kubernetes.io/docs/concepts/configuration/configmap/) or [Secret](https://kubernetes.io/docs/concepts/configuration/secret/), so as to be consumed in the Application [Pods](https://kubernetes.io/docs/concepts/workloads/pods/).

This is the point of this article, where I wanted to share how I stumbled upon a nice builtin template function in Helm that I thought would be useful in similar contexts.

As usual, you can find the repository that backs this article on [GitHub://rm3l/demo-merging-dynamic-configuration-in-helm](https://github.com/rm3l/demo-merging-dynamic-configuration-in-helm)

A picture being worth a thousand words, let's jump right in with a big picture of what we are trying to achieve here:

![Merging dynamic data with Helm](https://rm3l-org.s3.us-west-1.amazonaws.com/assets/cms-rm3l-org-helm-merged-dicts.drawio.png)

## Sample Chart

Let's quickly get started by generating a sample Helm Chart using the "_helm create_" command:

```shell
helm create demo-merging-dynamic-configuration-in-helm
```

This command creates a _demo-merging-dynamic-configuration-in-helm_ directory, along with the common files and directories typically used in a Chart:

```shell
❯ tree demo-merging-dynamic-configuration-in-helm 
demo-merging-dynamic-configuration-in-helm
├── charts
├── Chart.yaml
├── templates
│ ├── deployment.yaml
│ ├── _helpers.tpl
│ ├── hpa.yaml
│ ├── ingress.yaml
│ ├── NOTES.txt
│ ├── serviceaccount.yaml
│ ├── service.yaml
│ └── tests
│     └── test-connection.yaml
└── values.yaml

3 directories, 10 files

```

At any time, we can check locally how Helm would render those templates using the "_helm template_" command and inspecting its output, like so:

```shell
helm template demo-merging-dynamic-configuration-in-helm
```

To limit the rendering to a single template, we can use the "_-s relative/path/to/template/file_" option, e.g.:

```shell
helm template demo-merging-dynamic-configuration-in-helm \
  -s templates/deployment.yaml
```

## Configuration

### Predefined non-overridable configuration

This can be done by leveraging the Chart Helper [named template](https://helm.sh/docs/chart_template_guide/named_templates/) to define a new element. The Helper template can perform more complex work, but we will keep it simple for now. It simply defines our base configuration data as a YAML object.

```diff
diff --git a/templates/_helpers.tpl b/templates/_helpers.tpl
index 5abdb85..1e8fff1 100644
--- a/templates/_helpers.tpl
+++ b/templates/_helpers.tpl
@@ -60,3 +60,12 @@ Create the name of the service account to use
 {{- default "default" .Values.serviceAccount.name }}
 {{- end }}
 {{- end }}
+
+{{/*
+Default configuration
+*/}}
+{{- define "demo-merging-dynamic-configuration-in-helm.baseConfig" -}}
+myConfig1:
+  nonUpdatableParameter1: some-value
+nonUpdatableOption1: value1
+{{- end }}
```

### Overridable configuration

Properties that can be overridden are typically defined in the Chart _values.yaml_ file, like so:

```diff
diff --git a/values.yaml b/values.yaml
index f918f2d..e5ee9fd 100644
--- a/values.yaml
+++ b/values.yaml
@@ -80,3 +80,9 @@ nodeSelector: {}
 tolerations: []
 
 affinity: {}
+
+config:
+  myConfig1:
+    parameter11: value11
+    parameter12: value12
+
```

This provides providing a single source of truth and documentation for all accepted inputs. This way, they may also end up in some sort of documentation for the Helm Chart, which could be generated by tools like [helm-docs](https://github.com/norwoodj/helm-docs).

But bear in mind that users can specify any other data under the _config_ element, even if they were not explicitly declared in the _values.yaml_ file.

## Approaches for meeting the requirements

Now suppose you want to inject a [ConfigMap](https://kubernetes.io/docs/concepts/configuration/configmap/) (representing the target application configuration) into this Chart, and mount it under a Volume in any of the Pods part of the Deployment. This last point is not covered in this article, but left as an exercise to the reader. See [https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/](https://kubernetes.io/docs/tasks/configure-pod-container/configure-pod-configmap/) for more details.

Predefined configuration data defined in the _templates/_helpers.tpl_ file are considered mandatory, and should not change. But all other configuration data exposed in _values.yaml_ under the _config_ field are customizable.

### Approach #1 — Using static values

A very simple way to do this could be to first declare all of the properties expected in the ConfigMap in the default _values.yaml_ file (so they can be overridden by users installing this Chart), and then update our _ConfigMap_ template file to manually define where each property comes from.

The code for this approach can be found in the [approach_1_values_containing_all_confimap_properties](https://github.com/rm3l/demo-merging-dynamic-configuration-in-helm/compare/approach_1_values_containing_all_confimap_properties) branch.

Here is the _ConfigMap_ template (in a _templates/configmap.yaml_ file):

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myconfig.properties: |
    myConfig1:
      nonUpdatableParameter1: {{ include "demo-merging-dynamic-configuration-in-helm.baseConfig.myConfig1.nonUpdatableParameter1" . }}
      parameter11: {{ .Values.config.myConfig1.parameter11 }}
      parameter12: {{ .Values.config.myConfig1.parameter12 }}
    myConfig2:
      parameter21: {{ .Values.config.myConfig2.parameter21 }}
    nonUpdatableOption1: {{ include "demo-merging-dynamic-configuration-in-helm.baseConfig.nonUpdatableOption1" . }}
    option2: {{ .Values.config.option2 }}
```

And the diff for the other files:

```diff
diff --git a/templates/_helpers.tpl b/templates/_helpers.tpl
index 1e8fff1..cc5e49e 100644
--- a/templates/_helpers.tpl
+++ b/templates/_helpers.tpl
@@ -64,8 +64,9 @@ Create the name of the service account to use
 {{/*
 Default configuration
 */}}
-{{- define "demo-merging-dynamic-configuration-in-helm.baseConfig" -}}
-myConfig1:
-  nonUpdatableParameter1: some-value
-nonUpdatableOption1: value1
+{{- define "demo-merging-dynamic-configuration-in-helm.baseConfig.myConfig1.nonUpdatableParameter1" -}}
+some-value
+{{- end }}
+{{- define "demo-merging-dynamic-configuration-in-helm.baseConfig.nonUpdatableOption1" -}}
+value1
 {{- end }}
diff --git a/values.yaml b/values.yaml
index e5ee9fd..30433ca 100644
--- a/values.yaml
+++ b/values.yaml
@@ -85,4 +85,7 @@ config:
   myConfig1:
     parameter11: value11
     parameter12: value12
-
+  myConfig2:
+    parameter21: value21
+  option1: value1
+  option2: value2

```

We can check that we get the expected result:

```shell
❯ helm template . \
    -s templates/configmap.yaml \
    --set config.myConfig1.nonUpdatableParameter1="my-value-that-should-not-get-changed" \
    --set config.myConfig1.parameter11="my-value11-overridden" \
    --set config.myConfig2.parameter21="my-value21" \
    --set config.option2="my-value2" \
    --set config.userDefinedDynamicOption="my value"

---
# Source: demo-merging-dynamic-configuration-in-helm/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: RELEASE-NAME-configmap
data:
  myconfig.properties: |
    myConfig1:
      nonUpdatableParameter1: some-value
      parameter11: my-value11-overridden
      parameter12: value12
    myConfig2:
      parameter21: my-value21
    nonUpdatableOption1: value1
    option2: my-value2

```

As you can guess, this does not quite meet our initial requirement, because it requires all configuration keys to be known in advance and declared in the default Chart _values.yaml_ file.

Also, additional user-defined values (like _config.userDefinedDynamicOption_), not explicitly declared in the Chart Values file and consumed in the ConfigMap template, will just get ignored.

### Approach #2 (recommended) — Allowing users to inject dynamic data

The code for this approach can be found in the [approach_2_dynamic_data](https://github.com/rm3l/demo-merging-dynamic-configuration-in-helm/compare/approach_2_dynamic_data) branch.

This approach, which is the recommended one, builds upon 2 simple principles:

* The initial state is that all mandatory configuration data that should not be customized are defined in a _baseConfig_ Helper variable, as a complete YAML object. Configuration that are explicitly customizable are defined in the Chart _values.yaml_ file.
* Any other configuration data passed at runtime (nested under the _config_ field)  by end-users is just merged as is to construct the final _ConfigMap_.

Without further ado, here is the ConfigMap template (in _templates/configmap.yaml_):

```yaml
{{- $baseConfig := include "demo-merging-dynamic-configuration-in-helm.baseConfig" . | fromYaml -}}
{{- $mergedConfig := mustMergeOverwrite (dict) .Values.config $baseConfig -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Release.Name }}-configmap
data:
  myconfig.properties: |
    {{- toYaml $mergedConfig | nindent 4 }}
```

We can check that we also get the expected result:

```shell
❯ helm template . \
    -s templates/configmap.yaml \
    --set config.myConfig1.nonUpdatableParameter1="my-value-that-should-not-get-changed" \
    --set config.myConfig1.parameter11="my-value11-overridden" \
    --set config.myConfig2.parameter21="my-value21" \
    --set config.option2="my-value2" \
    --set config.userDefinedDynamicOption="my value"
    
---
# Source: demo-merging-dynamic-configuration-in-helm/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: RELEASE-NAME-configmap
data:
  myconfig.properties: |
    myConfig1:
      nonUpdatableParameter1: some-value
      parameter11: my-value11-overridden
      parameter12: value12
    myConfig2:
      parameter21: my-value21
    nonUpdatableOption1: value1
    option2: my-value2
    userDefinedDynamicOption: my value

```

We can see that :

* _config.myConfig1.nonUpdatableParameter1_ was set to be overridden, but its value finally did not change in the resulting ConfigMap. This means that our _baseConfig_ variable has precedence over user-defined configuration.
* Unlike the approach #1 above, _config.myConfig2_, _config.option2_ and _config.userDefinedDynamicOption_ were not defined anywhere in the Chart, but set at runtime. They ended up being merged to construct the resulting _ConfigMap_. And this provides much more flexibility.

## Why approach #2 works

Approach #2 leverages the [mustMergeOverwrite](https://helm.sh/docs/chart_template_guide/function_list/#mergeoverwrite-mustmergeoverwrite) template function to work with dictionaries in Helm Charts.

```go
{{- $baseConfig := include "demo-merging-dynamic-configuration-in-helm.baseConfig" . | fromYaml -}}
{{- $mergedConfig := mustMergeOverwrite (dict) .Values.config $baseConfig -}}
```

This is quite useful in the scope of this article, as it allows to merge two or more dictionaries into one, giving precedence from one dictionary to another.

That's it for this post. As usual, feel free to share your valuable thoughts in the comments.

