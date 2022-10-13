---
author: "Armel Soro"
categories: ["maven", "archetype", "tip", "jvm", "java", "build"]
date: 2019-05-15T18:44:00Z
description: ""
draft: false
slug: "about-maven-archetypes"
summary: "The goal of this tutorial post is to first give a quick introduction to Maven Archetypes, to see how useful they can be and how we can easily create and use one. And finally we will walk through few tips I think can be useful to bear in mind when working with Maven Archetypes."
tags: ["maven", "archetype", "tip", "jvm", "java", "build"]
title: "About Maven Archetypes"
resources:
- name: "featured-image"
  src: "featured-image.jpg"

---


I've been using Maven Archetypes for several years as helpers to quickly bootstrap a Maven Project. Few years ago, in an attempt to debug some of those archetypes, I found little to no resource out there to make them log useful messages, apart from using the (way too) verbose Maven Debug option.

The goal of this tutorial post is to first give a quick introduction to Maven Archetypes, then show how we can easily create and use one, and finally provide few tips I think can be useful to bear in mind.

## Overview

When starting a new project, it can be tedious and time-consuming to start over and over again from scratch. Fortunately, Maven has a built-in feature which allows to generate a project from a template. This template is called an Archetype.

Put simply, a Maven Archetype can be seen as a template Project which can be used to generate and customize new Maven Projects. A Maven archetype is _per se_ a special type of Maven project which comes bundled with template resources, which are specialized at generation time.

Using Archetypes provides a great way to standardize projects inside and outside an organization, which allows developers to quickly follow best practices in a consistent way.

## Creating a Maven Archetype

What's interesting with Maven Archetypes is that we can create one from an existing project, or create one from scratch.

### Starting off of an existing Project

This assumes that you already have an existing Maven Project, which you would like to make available as a template.

Say, your project, is _my-test-project_. All you have to do is _cd_ to your root project, and run the following command:

```bash
mvn archetype:create-from-project

```

The Archetype Project source code can then be found under the _target/generated-sources/archetype_ directory.

Example Output:

```bash
~/P/t/my-test-project
❯ mvn archetype:create-from-project
[INFO] Scanning for projects...                                                        
[INFO]                                                                                 
[INFO] ----------------------< org.rm3l:my-test-project >----------------------                                                                                                
[INFO] Building my-test-project 1.0-SNAPSHOT                                   
[INFO] --------------------------------[ jar ]---------------------------------
[INFO]                                                                                 
[INFO] >>> maven-archetype-plugin:3.0.1:create-from-project (default-cli) > generate-sources @ my-test-project >>>
[INFO]                                                                                 
[INFO] <<< maven-archetype-plugin:3.0.1:create-from-project (default-cli) < generate-sources @ my-test-project <<<
[INFO] 
[INFO]                           
[INFO] --- maven-archetype-plugin:3.0.1:create-from-project (default-cli) @ my-test-project ---
[INFO] Setting default groupId: org.rm3l
[INFO] Setting default artifactId: my-test-project
[INFO] Setting default version: 1.0-SNAPSHOT
[INFO] Setting default package: org.rm3l
[INFO] Scanning for projects...
[INFO] 
[INFO] -----------------< org.rm3l:my-test-project-archetype >-----------------
[INFO] Building my-test-project-archetype 1.0-SNAPSHOT
[INFO] --------------------------[ maven-archetype ]---------------------------
[INFO] 
[INFO] --- maven-resources-plugin:3.1.0:resources (default-resources) @ my-test-project-archetype ---
[WARNING] Using platform encoding (UTF-8 actually) to copy filtered resources, i.e. build is platform dependent!
[INFO] Copying 4 resources
[INFO] 
[INFO] --- maven-resources-plugin:3.1.0:testResources (default-testResources) @ my-test-project-archetype ---
[WARNING] Using platform encoding (UTF-8 actually) to copy filtered resources, i.e. build is platform dependent!
[INFO] Copying 2 resources
[INFO] 
[INFO] --- maven-archetype-plugin:3.0.1:jar (default-jar) @ my-test-project-archetype ---
[INFO] Building archetype jar: /home/rm3l/Projects/tmp/my-test-project/target/generated-sources/archetype/target/my-test-project-archetype-1.0-SNAPSHOT
[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  1.674 s
[INFO] Finished at: 2019-11-01T21:34:58+01:00
[INFO] ------------------------------------------------------------------------
[INFO] Archetype project created in /home/rm3l/Projects/tmp/my-test-project/target/generated-sources/archetype
[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  5.875 s
[INFO] Finished at: 2019-11-01T21:34:58+01:00
[INFO] ------------------------------------------------------------------------

~/P/t/my-test-project
❯ ls target/generated-sources/archetype
pom.xml  src  target

```

In order for our Archetype to be usable, we need to publish it, either locally (by installing it) or a remote Maven repository (such as Artifactory or Nexus). For simplicity, we will install it in our local Maven repository (usually under your _${HOME}/.m2/repository_ folder):

```bash
~/P/t/my-test-project/generated-sources/archetype
❯ mvn install

```

### Creating from scratch

The simplest and most straightforward way to create a new Archetype is using the [Maven Archetype Archetype](https://maven.apache.org/archetypes/maven-archetype-archetype/) (yes! you read it twice :)), which is an Archetype that generates sample Archetype Projects:

```bash
mvn archetype:generate \
-DarchetypeGroupId=org.apache.maven.archetypes \
-DarchetypeArtifactId=maven-archetype-archetype
```

This interactively prompts for the _groupId_, _artifactId_, _version_ and _package_ for the project to create.

To run non-interactively, either pass the _--batch-mode_ option or set the _interactive_ property to _false_ (i.e, _-Dinteractive=false_). Doing so requires that you also pass all the options required to generate the project: _groupId_, _artifactId_, _version_, _package_. For instance:

```bash
mvn archetype:generate \
--batch-mode \
-DarchetypeGroupId=org.apache.maven.archetypes \
-DarchetypeArtifactId=maven-archetype-archetype \
-DgroupId=com.company \
-DartifactId=my-sample-archetype \
-Dversion=1.0-SNAPSHOT \
-Dpackage=com.company.archetype

```

The command above generates a new folder named _my-sample-archetype_, which represents our generated Maven Archetype Project.

In order for our Archetype to be usable, we need to publish it, either locally (by installing it) or a remote Maven repository (such as Artifactory or Nexus). For simplicity, we will install it in our local Maven repository (usually under your _${HOME}/.m2/repository_ folder) :

```bash
~/P/t/my-sample-archetype
❯ mvn install

```

## Anatomy of a Maven Archetype

```bash
>/tmp/my-sample-archetype$ tree
.
├── pom.xml
└── src
    ├── main
    │   └── resources
    │       ├── archetype-resources
    │       │   ├── pom.xml
    │       │   └── src
    │       │       ├── main
    │       │       │   └── java
    │       │       │       └── App.java
    │       │       └── test
    │       │           └── java
    │       │               └── AppTest.java
    │       └── META-INF
    │           └── maven
    │               └── archetype-metadata.xml
    └── test
        └── resources
            └── projects
                └── it-basic
                    ├── archetype.properties
                    └── goal.txt

15 directories, 7 files

```

Archetypes consist of a descriptor (_src/main/resources/META-INF/maven/archetype-metadata.xml_), and a set of [Velocity](http://velocity.apache.org/) templates (under _src/main/resources/archetype-resources_) which make up the prototype project.

Bear in mind that archetype projects can not only generate single-module Maven projects, but also multi-modules projects.

* _pom.xml_ : the Archetype POM. This is a Maven project with a special type of packaging: _maven-archetype_
* _src/main/resources/META-INF/maven/rchetype-metadata.xml_ : this is the Archetype descriptor; it lists not only all template files, but also any properties that could be required to generate a project. This means that users of the archetype will need to pass such properties at generation time, e.g,: _-DmyRequiredProperty=myValue_.
* _src/main/resources/archetype-resources_ : here we can find the actual template files that will make up any generated project. You may use Velocity variables available out of the box, or declared in the archetype descriptor required properties. Such template variables will be initialized from the command-line when calling _archetype:generate_. Note that the template source files have to placed under _src/main/resources/archetype-resources/src/main/java_, without the actual package name (which is determined at generation time). This means that if you want to have a Java source file (say _A.java_) generated under _${package}.a.subpackage_, it should be placed into _src/main/resources/archetype-resources/src/main/java/a/subpackage_.
* _src/test_ : as any other Maven project, testing is a first-class citizen in Maven Archetypes. By default, integration tests consist in generating a project using the _archetype.properties_ file, then running the list of goals specified in _goal.txt_ against the generated project, and asserting that the overall execution is successful. You may want to specify an optional _reference/_ directory containing a reference project. This way, the test will also check that the generated project is exactly the same copy of the reference one.

## Using a Maven Archetype

You can either use your IDE (e.g., IntelliJ IDEA)  capabilities to create a new Maven Project off of a given Archetype, or you can use the command-line.

For example, in IntelliJ IDEA : _"File > New Project > Maven > Create from archetype"_

![IntelliJ IDEA: create Maven Project off of an Archetype](https://rm3l-org.s3-us-west-1.amazonaws.com/assets/IntelliJ_IDEA_Project_Off_Maven_Archetype.png)

From the command-line, you can run the following general-purpose command which allows you to interactively pick the archetype of your choice, and provide your project _groupId_, _artifactId_ and _version_:

```bash
mvn archetype:generate \
-DgroupId=org.rm3l \
-DartifactId=my-new-project \
-Dversion=0.0.1-SNAPSHOT
```

This works for archetypes accessible from the default remote Maven repository (Maven Central), but in our case, the archetype is installed in our local Maven repository. We can reference it right away instead, using the following command anywhere on our file system:

```bash
mvn archetype:generate \
-DarchetypeGroupId=org.rm3l \
-DarchetypeArtifactId=my-test-project-archetype \
-DarchetypeVersion=1.0-SNAPSHOT \
-DgroupId=org.rm3l \
-DartifactId=my-new-project \
-Dversion=0.0.1-SNAPSHOT
```

## Tips & Tricks

### Templating resource folders

Until now, Velocity variables (e.g,: _${shortName}_) were used entirely inside files, but what if we want to have a folder name templated as well?

The trick seems to be to use doubled underscores instead of the curly braces syntax, so _${shortName}_ becomes ___shortName___. In this case, you need to name your folder: ___shortName___

### Handling runtime logging levels

At its core, Maven uses the [SLF4J API](http://slf4j.org/apidocs/) for logging combined with the [SLF4J Simple](http://www.slf4j.org/apidocs/org/slf4j/impl/SimpleLogger.html) implementation.

We may use the _-X_ (or _--debug_) Maven option, but this appears to be sometimes way too verbose depending on the number of plugins executed. Instead, we can have a finer control over the logging levels of some plugin packages used during the different Maven phases, by setting the logging level at runtime (by specifying the `org.slf4j.simpleLogger.log._a.b.c_` __ JVM __ property)_._ This specifies logging detail level for a SimpleLogger instance named "_a.b.c_". Value must be one of "_trace_", "_debug_", "_info_", "_warn_", "_error_" or "_off_".

For example, when generating a new project off of our archetype:

```bash
mvn archetype:generate \
-Dorg.slf4j.simpleLogger.log.com.company=trace \
-DarchetypeGroupId=org.rm3l \
-DarchetypeArtifactId=my-test-project-archetype \
-DarchetypeVersion=1.0-SNAPSHOT \
-DgroupId=org.rm3l \
-DartifactId=my-new-project \
-Dversion=0.0.1-SNAPSHOT

```

## Conclusion

Throughout this article, we have seen what a Maven archetype is, how we could create one, and few useful tricks have been provided. Stay tuned, as this list of tips and tricks will get updated as I come across other "hidden" (a.k.a. undocumented) ways of using Maven Archetypes.



