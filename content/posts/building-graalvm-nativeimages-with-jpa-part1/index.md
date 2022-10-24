---
author: "Armel Soro"
categories: ["Blogs"]
date: 2019-01-11T19:02:00Z
description: ""
draft: false
image: "https://images.unsplash.com/photo-1461896836934-ffe607ba8211?ixlib=rb-1.2.1&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=2000&fit=max&ixid=eyJhcHBfaWQiOjExNzczfQ"
slug: "building-graalvm-nativeimages-with-jpa-part1"
summary: "The goal of this blog post is to go beyond the basic HelloWorld program, and see how we can leverage GraalVM against a sample real-world JPA-based application, able to interact with a database. We will walk through what can be done along with the potential limitations. "
tags: ["graalvm", "jpa", "java", "ruby", "native-image", "jit", "aot"]
title: "GraalVM with JPA-based applications (Part 1)"
resources:
- name: "featured-image"
  src: "featured-image.jpg"

---


First of all, Happy New Year 2019 to each and every single one of you, dear readers!!!

I wanted to start the first technical blog post of this new year with one particular piece of JVM-related project I discovered last year and am really enthusiastic about: [GraalVM](https://www.graalvm.org/), from Oracle.

In a nutshell, GraalVM is a (still experimental) very powerful polyglot virtual machine aiming at supporting and mixing different programming languages in a same application. It currently supports languages such as:

* JavaScript. Actually, JavaScript in the JVM has been supported for a long time via lightweight runtimes, first with the [Rhino](https://developer.mozilla.org/en-US/docs/Mozilla/Projects/Rhino) engine (released in JDK 6) and later with the [Nashorn](https://www.oracle.com/technetwork/articles/java/jf14-nashorn-2126515.html) engine (released in JDK 8 but deprecated in JDK 11). GraalVM's support for JavaScript in the JVM is a much more complete and faster implementation of the latest JavaScript standards, and also provides a full support for the [Node.js](https://nodejs.org/en/) server framework.
* Ruby
* Python
* R
* JVM-based languages, like Java, Kotlin, Groovy, Scala, Clojure
* LLVM-based languages, such as C and C++

You see how awesome this can be?! Using GraalVM, it should be possible for example to call Ruby code from a C++ program, and share cross-language data structures.

For JVM-based applications, GraalVM also provides the following capabilities:

* a brand-new efficient Just-In-Time (JIT) compiler. As a reminder, Java code is compiled to bytecode (the famous _.class_ files), which can be seen as an idealized platform-agnostic code, which is then interpreted by the JRE, and later compiled on the fly into machine code as the application runs; hence the terms "just in time". Unlike the default HotSpot JIT compiler, which is written in C++ (but criticized as hard to maintain and extend), the Graal JIT compiler is written in Java, as a concrete implementation of a new interface in the JVM called the JVMCI - the [JVM compiler interface](http://openjdk.java.net/jeps/243) - introduced in JDK 9.
* an Ahead-Of-Time (AOT) compiler to improve startup times. Unlike a JIT compiler, an AOT compiler analyzes the code up-front (along with all its dependencies) and produces a standalone platform-specific binary program. To emulate the capabilities of the JVM (such as garbage collection), the Graal AOT compiler produces Native Images that leverage [Substrate VM](https://github.com/oracle/graal/tree/master/substratevm), a Java-based framework that is also shipped with GraalVM.

The goal of this blog post is to go beyond the basic [HelloWorld](https://www.graalvm.org/docs/getting-started/#native-images) program, and see how we can leverage GraalVM against a sample real-world JPA-based application, able to interact with a database. We will walk through what can be done along with the potential limitations.

As always, the code for this blog post is available at [Github://rm3l/jpa-graalvm](https://github.com/rm3l/jpa-graalvm).

We will be using [DataNucleus](http://www.datanucleus.org/) as the JPA implementation, though the example project contains a set of Maven Profiles allowing to use other JPA implementations, such as [EclipseLink](https://www.eclipse.org/eclipselink/) (the reference one) or [Hibernate](http://hibernate.org/).

## Installing GraalVM

I highly recommend [SDKMAN!](https://sdkman.io/) as a tool to manage multiple versions of JVM-related Development Kits. Please head to the official instructions to see [how to install SDKMAN!](https://sdkman.io/install)

Once done, you can list all JDKs available with the following command:

```bash
❯ sdk list java

================================================================
Available Java Versions
================================================================
     13.ea.02-open       8.0.202.j9-adpt                                        
     12.ea.26-open       8.0.202.hs-adpt                                        
     11.0.2-zulu         8.0.201-zulu                                           
     11.0.2-open         8.0.201-oracle                                         
     11.0.2.j9-adpt      8.0.192-zulufx                                         
     11.0.2.hs-adpt      7.0.201-zulu                                           
   + 11.0.1-open         6.0.119-zulu                                           
     11.0.1-zulufx     * 1.0.0-rc-12-grl                                        
     10.0.2-zulu         1.0.0-rc-11-grl                                        
     10.0.2-open         1.0.0-rc-10-grl                                        
     9.0.7-zulu          1.0.0-rc-9-grl                                         
     9.0.4-open          1.0.0-rc-8-grl                                         
   + 9.0.1-oracle                                                               
 > + 8u151-oracle                                                               
     8.0.202-amzn                                                               

================================================================
+ - local version
* - installed
> - currently in use
================================================================
```

Installing GraalVM is then just as easy as picking the right JDK, e.g.:

```bash
❯ sdk install java 1.0.0-rc-12-grl
```

You may choose to make it your default JDK system-wide, or use it temporarily just for testing:

```bash
❯ sdk use java 1.0.0-rc-12-grl
```

Let's check the JDK we have just installed and confirm we are using GraalVM:

```bash
❯ java -version
openjdk version "1.8.0_192"
OpenJDK Runtime Environment (build 1.8.0_192-20181024121959.buildslave.jdk8u-src-tar--b12)
GraalVM 1.0.0-rc12 (build 25.192-b12-jvmci-0.54, mixed mode)
```

## Using the Graal Compiler

Our sample project makes use of the Java Persistence API - JPA - to persist and update few people data in an in-memory database. It then pretty-prints such records in JSON on the standard output, using the Ruby programming language, in order to showcase how polyglot GraalVM is.

This is done in the following code snippet:

```java
import org.graalvm.polyglot.*;

//...

private static void prettyPrintWithRuby(final Collection<Person> people) {
        try (final Context context = Context.create("ruby")) {
            final Value json = context.eval("ruby",
                    "require 'json'; " +
                    "JSON.pretty_generate(" +
                    " JSON.parse('" +
                    "   [" + people.stream()
                    .map(Person::toJsonString)
                    .collect(Collectors.joining(", ")) + "]'))");
            System.out.println(json.asString());
        }
    }
```

What this code does is pretty straightforward:

1. creating an execution context for the "ruby" language. For this, we may need to install the engine for such language using the _gu_ (Graal Updater) command. More on that below.
2. evaluating the provided Ruby script and wrapping the result in a language-agnostic _org.graalvm.polyglot.Value_ object, which is then manipulated back in Java and printed to screen

We can also do the same using the JavaScript language engine, by evaluating multiple native JS functions:

```java
import org.graalvm.polyglot.*;

//...

private static void prettyPrintWithJS(final Collection<Person> people) {
        try (final Context context = Context.create("js")) {
            final Value parse = context.eval("js", "JSON.parse");
            final Value stringify = context.eval("js", "JSON.stringify");
            final Value parseResult = parse.execute("[" + people.stream()
                    .map(Person::toJsonString)
                    .collect(Collectors.joining(", ")) + "]");
            System.out.println(stringify.execute(parseResult, null, 2).asString());
        }
    }
```

First, let's build the project:

```bash
❯ mvn package -P datanucleus

```

Running with the optimized Graal JIT compiler is then straightforward:

```
❯ java \
  -Dgraal.ShowConfiguration=info \
  -XX:+UseJVMCICompiler \
  -XX:+EagerJVMCI \
  -cp "target/jpa-graalvm-5.2.jar:target/lib/*" \
  -Dprofile=datanucleus \
  mydomain.MySampleApplication
```

If we run the command above, we may get an error indicating that the 'ruby' language is not installed:

```bash
❯ java -Dgraal.ShowConfiguration=info -XX:+UseJVMCICompiler -XX:+EagerJVMCI -cp "target/jpa-graalvm-5.2.jar:target/lib/*" -Dprofile=datanucleus mydomain.MySampleApplication      
[Use -Dgraal.LogFile=<path> to redirect Graal log output to a file.]                                                                                                              
Using Graal compiler configuration 'community' provided by org.graalvm.compiler.hotspot.CommunityCompilerConfigurationFactory loaded from jar:file:/home/rm3l/.sdkman/candidates/ja
va/1.0.0-rc-12-grl/jre/lib/jvmci/graal.jar!/org/graalvm/compiler/hotspot/CommunityCompilerConfigurationFactory.class                                                              
Exception in thread "main" java.lang.IllegalStateException: Failed test : A language with id 'ruby' is not installed. Installed languages are: [js, llvm].                        
        at mydomain.MySampleApplication.executeInTransaction(MySampleApplication.java:132)                                                                                        
        at mydomain.MySampleApplication.main(MySampleApplication.java:76)
```

In this case, we need to install the Ruby language engine, using Graal's _gu_ (Graal Updater) command:

```bash
❯ gu install ruby
```

Re-runing the _java_ command above will then pretty-print our database records using Ruby code in our Java code:

```js
❯ java -Dgraal.ShowConfiguration=info -XX:+UseJVMCICompiler -XX:+EagerJVMCI -cp "target/jpa-graalvm-5.2.jar:target/lib/*" -Dprofile=datanucleus mydomain.MySampleApplication


[Use -Dgraal.LogFile=<path> to redirect Graal log output to a file.]
Using Graal compiler configuration 'community' provided by org.graalvm.compiler.hotspot.CommunityCompilerConfigurationFactory loaded from jar:file:/home/rm3l/.sdkman/candidates/java/1.0.0-rc-12-grl/jre/lib/jvmci/graal.jar!/org/graalvm/compiler/hotspot/CommunityCompilerConfigurationFactory.class                                                              
Using Graal compiler configuration 'community' provided by org.graalvm.compiler.hotspot.CommunityCompilerConfigurationFactory loaded from jar:file:/home/rm3l/.sdkman/candidates/java/1.0.0-rc-12-grl/jre/lib/jvmci/graal.jar!/org/graalvm/compiler/hotspot/CommunityCompilerConfigurationFactory.class                                                              
[
  {
    "uuid": "c5e02d7f-348f-4e0f-85d4-a17c8613bc62",
    "uniqueName": "person 2 (renamed)",
    "lastAddress": {
      "uuid": "61121487-1671-4c08-a556-ae29bf81d5e7",
      "zipCode": 22,
      "number": 2,
      "street": "Avenue FHB",
      "city": "Abidjan",
      "countryCode": "CI"
    }
  },
  {
    "uuid": "a1727ea1-c5c2-41d7-b44b-13ed8c1543ca",
    "uniqueName": "person 1 (renamed)",
    "lastAddress": {
      "uuid": "eefffc6a-9866-4421-8ccf-8206faffb215",
      "zipCode": 21,
      "number": 1,
      "street": "Avenue FHB",
      "city": "Lyon",
      "countryCode": "FR"
    }
  }
]

```

That's it for the moment, now that we have seen how we can easily leverage GraalVM to write polyglot code that extends JPA-based applications. In the second part of this blog post, we'll see how we can further improve startup time by building a Native Image of our JPA-based application, if at all possible.

Stay tuned for the upcoming blog post, and as always, your feedback is more than welcome.

