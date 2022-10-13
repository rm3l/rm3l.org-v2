---
author: "Armel Soro"
date: 2019-02-10T19:41:05Z
description: ""
draft: true
slug: "graalvm-with-jpa-based-applications-part-2"
title: "GraalVM with JPA-based applications (Part 2)"

---


In the first part of this blog post, ...

## Building a GraalVM Native Image

Let's see how we can further improve startup time by building a Native Image of our JPA-based application, if at all possible.

Things start to get tricky here when attempting to build our native image.

```bash
❯ native-image --no-server -cp "target/jpa-graalvm-5.2.jar:target/lib/*" mydomain.MySampleApplication


[mydomain.mysampleapplication:11283]    classlist:   6,927.33 ms                                                                                                                  
[mydomain.mysampleapplication:11283]        (cap):   2,972.90 ms
[mydomain.mysampleapplication:11283]        setup:   7,127.80 ms                                                                                                                  
[mydomain.mysampleapplication:11283]     analysis:  14,754.19 ms                                                                                                                  
Error: Error encountered while parsing com.oracle.svm.core.deopt.DeoptimizationSupport.get()                                                                                      
...
Original error: com.oracle.svm.core.util.UserError$UserException: ImageSingletons do not contain key com.oracle.svm.core.deopt.DeoptimizationSupport
...
Error: Use -H:+ReportExceptionStackTraces to print stacktrace of underlying exception
Error: Image building with exit status 1
```

TODO

## Wrapping Up

TODO

