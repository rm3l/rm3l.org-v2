---
author: "Armel Soro"
categories: ["Blogs"]
date: 2018-10-29T20:39:00Z
description: ""
draft: false
image: "https://images.unsplash.com/photo-1488229297570-58520851e868?ixlib=rb-1.2.1&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=2000&fit=max&ixid=eyJhcHBfaWQiOjExNzczfQ"
slug: "datanucleus-jpa-enhancement-with-gradle"
summary: "A notable behavior of JPA providers is to enhance JPA classes, by modifying their bytecode to add few capabilities. \nDataNucleus (DN) currently provides a Maven Plugin for calling its Enhancer. \nThis article walks through calling DN Enhancer in a Gradle build script in a very efficient way."
tags: ["jpa", "datanucleus", "enhancement", "hibernate", "eclipselink", "gradle", "weaving"]
title: "DataNucleus JPA Enhancement with Gradle"
resources:
- name: "featured-image"
  src: "featured-image.jpg"

---


The Java Persistence Application Programming Interface ([JPA](https://github.com/eclipse-ee4j/jpa-api)) is the Java's specification for bridging the gap between object-oriented domain models and relational database management systems (RDBMS). As JPA is just a standard part of [Jakarta EE](https://jakarta.ee/) (formerly [Java EE](https://en.wikipedia.org/wiki/Java_Platform,_Enterprise_Edition)), there exists different implementations, [DataNucleus](http://www.datanucleus.org/) being one of them (besides [Hibernate](http://hibernate.org/)). Note that the official reference implementation for JPA is [EclipseLink](http://www.eclipse.org/eclipselink/).

### Enhancement / Weaving

A noteworthy behavior of most JPA providers is to "enhance" the domain JPA classes. This technique, also known as weaving, allows to modify the resulting bytecode of your domain classes, in order to essentially add the following capabilities:

* lazy state initialization
* object dirty state tracking, i.e. the ability to track object updates (including collections mutations), and translate such updates into [JPQL](https://en.wikipedia.org/wiki/Java_Persistence_Query_Language) DML queries, which are translated into database-specific SQL queries
* automatic bi-directional mapping, i.e., ensuring that both sides of a relationship are set properly
* optionally, performance optimizations

Some providers such as DataNucleus have chosen to require all domain classes to be enhanced before any use. This means that enhancement has to be done beforehand at build time, or at any time between compile time and packaging time.

On the other hand, other JPA providers such as EclipseLink and Hibernate do not make enhancement a mandatory prerequisite, and can do it by default on-the-fly at run-time. They still allow to perform enhancement at build time, but this may not be the default behavior.

Performing bytecode enhancement at build time clearly has a performance benefit over the use of slow proxies or reflection that might be done at run-time.

Hibernate for example provides an [hibernate-gradle-plugin](https://github.com/hibernate/hibernate-orm/tree/master/tooling/hibernate-gradle-plugin) for calling its enhancer from Gradle, but DataNucleus supports only Maven for now.

### DataNucleus + Maven

If you make use of both DataNucleus and Maven, enhancing your domain classes is as straightforward as calling the official [DataNucleus Maven Plugin](https://github.com/datanucleus/datanucleus-maven-plugin) in your _pom.xml_. For example, to have domain classes auto-enhanced after each compilation :

```xml
<build>
    ...
    <plugins>
        <plugin>
            <groupId>org.datanucleus</groupId>
            <artifactId>datanucleus-maven-plugin</artifactId>
            <version>5.0.2</version>
            <configuration>
                <api>JPA</api>
                <persistenceUnitName>MyPersistenceUnit</persistenceUnitName>
                <log4jConfiguration>${basedir}/log4j.properties</log4jConfiguration>
                <verbose>true</verbose>
            </configuration>
            <executions>
                <execution>
                    <phase>process-classes</phase>
                    <goals>
                        <goal>enhance</goal>
                    </goals>
                </execution>
            </executions>
        </plugin>
    </plugins>
    ...
</build>
```

### DataNucleus + Gradle

If you use Gradle, then one possible solution is to manually call the [DataNucleus Enhancer Ant Task](http://www.datanucleus.org/products/accessplatform/jpa/enhancer.html#ant) in your _build.gradle_. Below is an example of such custom Gradle task calling the DataNucleus one:

```groovy
// define Ant task for DataNucleus Enhancer
task datanucleusEnhance(dependsOn: compileJava) {
    doLast {
        ant.taskdef(
                    name: 'datanucleusEnhancer',
                    classpath: sourceSets.main.runtimeClasspath.asPath,
                    classname: 'org.datanucleus.enhancer.EnhancerTask'
                    // the below is for DataNucleus Enhancer 3.1.1
                    //classname : 'org.datanucleus.enhancer.tools.EnhancerTask')
                    
        // define the entity classes
        def entityFiles = project.fileTree(
            dir:sourceSets.main.output.classesDir, 
            include: 'my/domain/**/*.class')

        // run the DataNucleus Enhancer as an Ant task
        ant.datanucleusEnhancer(
            classpath: sourceSets.main.runtimeClasspath.asPath,
            verbose: project.logger.isDebugEnabled(),
            api: "JPA") {
            entityFiles.addToAntBuilder(ant, 'fileset', FileCollection.AntType.FileSet)
        }
    }
}

classes.dependsOn(datanucleusEnhance)
```

This defines a Gradle task first defining the Ant Task then calling it straight away:

```bash
❯ ./gradlew :MyApp-Domain:build -x test -x integrationtest
...

BUILD SUCCESSFUL in 30s
29 actionable tasks: 27 executed, 1 from cache, 1 up-to-date
```

It goes without saying, but you need to have the related DataNucleus JARs in your dependencies for this to work. This includes _datanucleus-core.jar_, _datanucleus-api-jpa.jar_, and _javax.persistence.jar_.

**Optimizing the Gradle Build time**

One of Gradle's major strengths is its ability to leverage a build cache, by marking tasks as UP-TO-DATE if their input and output are unchanged. The [compileJava](https://docs.gradle.org/current/userguide/java_plugin.html#compilejava) task has, among other things, the Java source files as inputs and the compiled class files as outputs.

At this point, classes are auto-enhanced after compilation. However, our custom _datanucleusEnhance_ task overrides the compiled class files. This invalidates the compiler cache, thus disabling incremental compilation and requires the _compileJava_ Gradle task to never be skipped.

Let's see how we can further reduce build time by skipping re-running the _datanucleusEnhance_ task when source files have not changed at all.

Since the DataNucleus Enhancer modifies and overwrites the class files, we can plug the _datanucleusEnhance_ task execution right after the _compileJava_ one, so the latter sees the enhanced classes as its outputs instead. This way, subsequent builds will run much faster.

Code speaks louder than words:

```groovy
// define Ant task for DataNucleus Enhancer
task datanucleusEnhancerTaskDef(dependsOn: compileJava) {
    inputs.files project.fileTree(dir: "${sourceSets.main.java.srcDirs}", include: 'my/domain/**/*.java')
    outputs.dir sourceSets.main.output.classesDir
    doLast {
        if (!Boolean.getBoolean("datanucleusEnhancerTaskDefRun")) {
            System.setProperty("datanucleusEnhancerTaskDefRun", "true")
            ant.taskdef(
                    name: 'datanucleusEnhancer',
                    classpath: sourceSets.main.runtimeClasspath.asPath,
                    classname: 'org.datanucleus.enhancer.EnhancerTask'
                    // the below is for DataNucleus Enhancer 3.1.1
                    //classname : 'org.datanucleus.enhancer.tools.EnhancerTask'
            )
        }
    }
}

task datanucleusEnhance(dependsOn: datanucleusEnhancerTaskDef) {
    description "Enhance JPA model classes using DataNucleus Enhancer"
    outputs.dir "${project.buildDir}/dn-enhancer"
    doLast {
        if (Boolean.getBoolean("datanucleusEnhancerTaskDefRun")) {
            // define the entity classes
            def entityFiles = project.fileTree(dir: sourceSets.main.output.classesDir, include: 'my/domain/**/*.class')

            // run the DataNucleus Enhancer as an Ant task
            ant.datanucleusEnhancer(
                    classpath: sourceSets.main.runtimeClasspath.asPath,
                    verbose: project.logger.isDebugEnabled(),
                    api: "JPA") {
                entityFiles.addToAntBuilder(ant, 'fileset', FileCollection.AntType.FileSet)
            }
            new File("${project.buildDir}/dn-enhancer").mkdirs()
        }
    }
}

compileJava.doLast {
    if (!Boolean.getBoolean("datanucleusEnhancerTaskDefRun")) {
        System.setProperty("datanucleusEnhancerTaskDefRun", "true")
        ant.taskdef(
                name: 'datanucleusEnhancer',
                classpath: sourceSets.main.runtimeClasspath.asPath,
                classname: 'org.datanucleus.enhancer.EnhancerTask'
                // the below is for DataNucleus Enhancer 3.1.1
                //classname : 'org.datanucleus.enhancer.tools.EnhancerTask'
        )
        // define the entity classes
        def entityFiles = project.fileTree(dir: sourceSets.main.output.classesDir, include: 'my/domain/**/*.class')

        // run the DataNucleus Enhancer as an Ant task
        ant.datanucleusEnhancer(
                classpath: sourceSets.main.runtimeClasspath.asPath,
                verbose: project.logger.isDebugEnabled(),
                api: "JPA") {
            entityFiles.addToAntBuilder(ant, 'fileset', FileCollection.AntType.FileSet)
        }
        new File("${project.buildDir}/dn-enhancer").mkdirs()
    }
}

classes.dependsOn datanucleusEnhance
```

Building the project after the changes above in our build script gives up the following execution time:

```bash
❯ ./gradlew :MyApp-Domain:build -x test -x integrationtest
...

BUILD SUCCESSFUL in 13s
31 actionable tasks: 18 executed, 1 from cache, 12 up-to-date
```

Now notice the build time after re-running the same build command again, with no changes in the Java Domain source files:

```bash
❯ ./gradlew :MyApp-Domain:build -x test -x integrationtest
...

BUILD SUCCESSFUL in 2s
17 actionable tasks: 17 up-to-date
```

### Conclusion

In this blog post, we first recalled a brief definition of what the Java Persistence API is, and what the enhancement technique in JPA means. We then tried to see how to call the DataNucleus JPA Enhancer from a Gradle build script, which is, at this time, not supported officially by folks at DataNucleus.

A possible approach explored here is to define a Gradle Ant Task tied to the official DataNucleus Ant Task under the hood. This solution makes it possible to auto-enhance our domain classes, but has a major drawback in that it invalidates the Gradle compile task output cache. As a consequence, it triggers the execution of both the compile and the enhancer tasks at each build, even when the project source has not been modified.

To further reduce build time, a simple yet powerful solution is to override the compile task outputs, by defining them as the result of the enhancement task execution.

As this is something that might be useful to other Gradle-based projects making use of DataNucleus as their JPA provider, I'm currently working on a simple Open-Source Gradle Plugin, inspired by the official Maven Plugin, which will work exactly as depicted in this article. Stay tuned — the library is coming very soon.

As always, your comments are more than welcome.

