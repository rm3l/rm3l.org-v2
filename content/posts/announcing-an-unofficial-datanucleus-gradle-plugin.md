+++
author = "Armel Soro"
categories = ["jpa", "datanucleus", "enhancement", "gradle", "weaving", "oss"]
date = 2018-11-11T20:02:00Z
description = ""
draft = false
image = "https://images.unsplash.com/photo-1488229297570-58520851e868?ixlib=rb-1.2.1&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=2000&fit=max&ixid=eyJhcHBfaWQiOjExNzczfQ"
slug = "announcing-an-unofficial-datanucleus-gradle-plugin"
tags = ["jpa", "datanucleus", "enhancement", "gradle", "weaving", "oss"]
title = "Announcing an unofficial DataNucleus Gradle Plugin"

+++


Following my previous [article](https://rm3l.org/datanucleus-jpa-enhancement-with-gradle/) on JPA enhancement in general and particularly how to perform build-time enhancement / weaving using [DataNucleus](http://www.datanucleus.org/) and [Gradle](https://gradle.org/) Ant Tasks, _a promise is a promise_ :). I am excited to announce __ [datanucleus-gradle-plugin](https://datanucleus-gradle-plugin.rm3l.org/), an open-source plugin for Gradle-based projects. It aims at providing the same set of capabilities as the official [DataNucleus Maven Plugin](https://github.com/datanucleus/datanucleus-maven-plugin).

For the moment, the only capability added is for bytecode enhancement of the user domain model, although other capabilities (such as schema operations) are planned.

**Website** : [https://datanucleus-gradle-plugin.rm3l.org/](https://datanucleus-gradle-plugin.rm3l.org/)

**Repository**: [Github://rm3l/datanucleus-gradle-plugin](https://github.com/rm3l/datanucleus-gradle-plugin)

This plugin adds few tasks and capabilities related to DataNucleus. Those tasks are configurable via a very straightforward DSL extension. So it may be useful if you make use of both DataNucleus as your JPA / JDO provider and Gradle as your build tool.

Using it is as easy as applying the plugin, so as to have enhancement auto-performed at build-time. This way, the resulting artifacts are packaged with the classes already enhanced.

Below is an example of a _build.gradle_ applying the plugin and configuring it. Please refer to the [plugin website](https://datanucleus-gradle-plugin.rm3l.org/) for more details about the different tasks and their options.

```groovy
plugins {
  id "org.rm3l.datanucleus-gradle-plugin" version "1.0-SNAPSHOT"
}

//... other things, such as dependencies, ...

datanucleus {
  enhance {
    api 'JPA'
    persistenceUnitName 'myPersistenceUnit'
    //... other options are possible
  }
}
```

As always, feedback, contributions or issue reporting are more than welcome. So to help out, do feel free to fork the repository and open up a pull request. I’ll review and merge your changes as quickly as possible.

You can use [GitHub issues](https://github.com/rm3l/datanucleus-gradle-plugin/issues) to report bugs or just drop me a line at _armel+dn_gradle_plugin AT rm3l DOT org_. However, please make sure your description is clear enough and has sufficient instructions to be able to reproduce the issue.

**Notes**

* The plugin has just (Nov. 11, 2018) been submitted to the Gradle Plugins [repository](https://plugins.gradle.org/), and the approval from folks at Gradle is still pending. I'll let you know once the plugin is effectively published.

UPDATE: The plugin submission has just (Nov. 12, 2018) been approved — it is now available in the [Gradle Plugin Portal](https://plugins.gradle.org/plugin/org.rm3l.datanucleus-gradle-plugin) !

* The plugin is provided **as is**, under an MIT [License](https://github.com/rm3l/datanucleus-gradle-plugin/blob/master/LICENSE).

