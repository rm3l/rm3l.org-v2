---
author: "Armel Soro"
categories: ["jmx", "jvm", "java", "logging", "logback", "mbean", "monitoring", "slf4j"]
date: 2019-02-14T20:45:00Z
description: ""
draft: false
image: "https://images.unsplash.com/photo-1563251478-37462b112536?ixlib=rb-1.2.1&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=2000&fit=max&ixid=eyJhcHBfaWQiOjExNzczfQ"
slug: "changing-the-logging-level-of-jvm-apps-jmxterm-logback-without-downtime"
summary: "We are going to see how to change the logging level of a running JVM application with jmxterm and Logback, without any application downtime"
tags: ["jmx", "jvm", "java", "logging", "logback", "mbean", "monitoring", "slf4j"]
title: "Changing the logging level of a running JVM application with jmxterm and Logback, without any downtime"
resources:
- name: "featured-image"
  src: "featured-image.jpg"
---


[Java Management Extensions](https://www.oracle.com/technetwork/java/javase/tech/javamanagement-140525.html) (JMX) is a mechanism for managing and monitoring Java applications, system objects, and devices. This is really useful to not only help understand the behavior of running JVM applications, but also perform some operations (e.g., changing the logging level) at runtime without any downtime.

A core concept of JMX is the Managed Bean, also known as an MBean; it is nothing more than a resource exposed through JMX that can be used to collect metrics, run operations or notify for certain events occurring during the lifetime of the application monitored.

On the other hand, [Logback](https://logback.qos.ch/) is one of the most used logging frameworks in the Java Platform community. It is essentially a replacement for [Log4j](https://logging.apache.org/log4j/2.0/manual/index.html), and an implementation of the [Simple Logging Facade for Java](https://www.slf4j.org/) (also referred to as SLF4J) API. It is meant to be faster, and comes with certain useful features such as automatic reloading and a JMX configurator.

There exists a lot of ways for exploring JMX, the most known one being [JConsole](https://docs.oracle.com/javase/7/docs/technotes/guides/management/jconsole.html) (distributed as part of your JDK) or [VisualVM](https://visualvm.github.io/).

But I wanted to shed light on a particular neat tool that I think can be of great help in any production JVM app: [jmxterm](https://github.com/jiaqi/jmxterm) is, as the name suggests, an interactive Command-Line Interface (CLI) for JMX.

jmxterm is lightweight and can be downloaded as a single standalone JAR which can easily be copied and used on any remote host.

### Configuring Logback for JMX

Logback exposes a JMXConfigurator MBean, which lets reconfigure Logback, list loggers and modify logger levels.

Since it is not enabled by default, we need to explicitly modify our configuration files (e.g., _logback.xml_) to include the _<jmxConfigurator/>_ line, e.g:

```xml
<configuration scan="true">

    <property name="LOG_FILE" value="${catalina.base:-${java.io.tmpdir}${file.separator}temp}${file.separator}logs${file.separator}${project.artifactId}.log"/>

    <!-- Stop output INFO at start -->
    <statusListener class="ch.qos.logback.core.status.NopStatusListener" />

    <jmxConfigurator />

    <logger name="org.springframework" level="INFO"/>
    <logger name="org.springframework.boot.actuate.endpoint.mvc" level="INFO"/>
    <logger name="org.springframework.scheduling" level="INFO" />
    <logger name="org.springframework.boot.autoconfigure" level="WARN"/>

    <logger name="DataNucleus" level="WARN"/>
    <!-- Log of all 'native' statements sent to the datastore -->
    <logger name="DataNucleus.Datastore.Native" level="WARN"/>
    <logger name="DataNucleus.Datastore" level="WARN"/>
    <logger name="DataNucleus.Datastore.Retrieve" level="WARN"/>
    <logger name="DataNucleus.Datastore.Schema" level="INFO"/>
    <logger name="DataNucleus.General" level="WARN" />
    <logger name="DataNucleus.Lifecycle" level="WARN" />
    <logger name="DataNucleus.ValueGeneration" level="WARN" />

    <logger name="DataNucleus.JPA" level="WARN" />
    <logger name="org.datanucleus" level="WARN"/>
    <logger name="DataNucleus.Transaction" level="WARN" />
    <logger name="DataNucleus.Connection" level="WARN" />

    <logger name="javax.persistence" level="WARN"/>

    <logger name="org.postgresql" level="WARN"/>
    <logger name="ch.qos.logback" level="ERROR" />
    <logger name="com.zaxxer.hikari" level="WARN" />
    <logger name="com.vladmihalcea.flexypool.metric" level="WARN" />
</configuration>
```

### Downloading and running jmxterm

```bash
❯ wget https://github.com/jiaqi/jmxterm/releases/download/v1.0.2/jmxterm-1.0.2-uber.jar \
  -O /tmp/jmxterm.jar
```

Using it is as simple as running the standalone JAR, which immediately returns an interactive prompt:

```bash
❯ java -jar /tmp/jmxterm.jar
Welcome to JMX terminal. Type "help" for available commands.
$>help
#following commands are available to use:
about    - Display about page
bean     - Display or set current selected MBean. 
beans    - List available beans under a domain or all domains
bye      - Terminate console and exit
close    - Close current JMX connection
domain   - Display or set current selected domain. 
domains  - List all available domain names
exit     - Terminate console and exit
get      - Get value of MBean attribute(s)
help     - Display available commands or usage of a command
info     - Display detail information about an MBean
jvms     - List all running local JVM processes
open     - Open JMX session or display current connection
option   - Set options for command session
quit     - Terminate console and exit
run      - Invoke an MBean operation
set      - Set value of an MBean attribute
subscribe - Subscribe to the notifications of a bean
unsubscribe - Unsubscribe the notifications of an earlier subscribed bean
watch    - Watch the value of one MBean attribute constantly
$>
```

### Connecting to a running application

_jvms_ is a jmxterm command which returns the list of all local JVM application currently running. The goal here is to pick the PID of the JVM process of interest. You may use other tools to grab such info, e.g., _htop_, _ps_, or _jps_.

```bash
$> jvms
2210     ( ) - jmxterm.jar
30682    ( ) - com.intellij.idea.Main
31439    ( ) - org.apache.catalina.startup.Bootstrap
```

Pay attention to running jmxterm with a user that has the rights to see the process of the JVM app you intend to connect to.

In the sample output above, we can clearly identify the Tomcat process ID (_31439_) from the _org.apache.catlina.out_ line.

### Sending commands

Now that the Tomcat process is identified, we need to open a JMX connection to it, target certain MBeans idenfified to gather monitoring metrics and/or send commands.

For example, let say we want to temporarily see all SQL queries sent out by a JPA application to a data store. Assuming we leverage [DataNucleus](http://www.datanucleus.org/) as our JPA provider, this means we need to change the '_DataNucleus.Datastore.Native_' logging level.

```bash
$>open 31439
#Connection to 31439 is opened
$>
```

We can now modify the loggine level with the commands below:

```bash
$>
$> domain ch.qos.logback.classic
#domain is set to ch.qos.logback.classic

$>
$> bean "ch.qos.logback.classic:Name=default,Type=ch.qos.logback.classic.jmx.JMXConfigurator"
#bean is set to ch.qos.logback.classic:Name=default,Type=ch.qos.logback.classic.jmx.JMXConfigurator

$>
$> run setLoggerLevel DataNucleus.Datastore.Native DEBUG
#calling operation setLoggerLevel of mbean ch.qos.logback.classic:Name=default,Type=ch.qos.logback.classic.jmx.JMXConfigurator with params [DataNucleus.Datastore.Native, DEBUG]
#operation returns:null

$>
$> exit
#bye
```

And voila! Logging level has been changed dynamically without any application downtime.

