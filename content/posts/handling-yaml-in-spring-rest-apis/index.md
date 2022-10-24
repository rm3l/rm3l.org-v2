---
author: "Armel Soro"
categories: ["Blogs"]
date: 2021-08-31T19:06:00Z
description: ""
draft: false
image: "https://images.unsplash.com/photo-1459947727010-6267d2c1232f?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=MnwxMTc3M3wwfDF8c2VhcmNofDUzfHxyZXN0JTIwc3ByaW5nfGVufDB8fHx8MTYzODM5ODEzOQ&ixlib=rb-1.2.1&q=80&w=2000"
slug: "handling-yaml-in-spring-rest-apis"
summary: "On how to add support for YAML in a Spring Boot based REST API"
tags: ["spring-boot", "spring", "rest-api", "java", "yaml"]
title: "Handling YAML in a Spring Boot based REST API"
resources:
- name: "featured-image"
  src: "featured-image.jpg"

---


Let's start this article with a simple case: you've got a running [Spring Boot](https://spring.io/projects/spring-boot) API server, happily accepting and returning [JSON](https://www.json.org/json-en.html). This is the default behavior in Spring Boot with no custom configuration. Now say you also want to support [YAML](https://yaml.org/) as possible input content type.

YAML being a superset of JSON, it may be interesting to also support it for your API consumers. In certain cases, YAML can provide more benefits, like much more readability to the API payload.

This blog post assumes a prior knowledge of Spring Boot, along with an existing JDK installation. I recommend using [SDKMAN!](https://sdkman.io/) as a very good tool of choice for playing around with different JDKs. More experienced readers can skip the first section, which provides detailed steps on how the sample code used as the base project has been generated.

As usual, the complete code for this tutorial is available on [GitHub://rm3l/demo-yaml-media-type-spring-boot](https://github.com/rm3l/demo-yaml-media-type-spring-boot)

## Generating a sample project

Spring Initializr ([start.spring.io](https://start.spring.io/)) provides a nice user interface and API to generate JVM-based projects using Spring Boot. We can use it either via its web interface, or even using a simple command-line tool like _curl_ or _wget_. Let's get started by creating our sample project.

You can use [this pre-initialized project](https://start.spring.io/#!type=maven-project&language=java&platformVersion=2.6.1&packaging=jar&jvmVersion=11&groupId=com.example&artifactId=demo-yaml-spring-boot&name=demo-yaml-spring-boot&description=Demonstrating%20how%20to%20support%20YAML%20as%20media%20tpe%20with%20Spring%20Boot&packageName=com.example.yaml&dependencies=web) and click "_Generate_" to download a ZIP archive file. Or you can run the non-interactive command below to generate the project, download and unzip the archive on the fly, assuming you have the _jar_ command (part of the JDK installation) in your _PATH_:

```shell
❯ curl https://start.spring.io/starter.zip  \
  -d groupId=com.example \
  -d artifactId=demo-yaml-spring-boot \
  -d bootVersion=2.6.1 \
  -d baseDir=demo-yaml-spring-boot \
  -d name=demo-yaml-spring-boot \
  -d description="Demonstrating how to support YAML as media tpe with Spring Boot" \
  -d packageName=com.example.yaml \
  -d packaging=jar \
  -d javaVersion=11 \
  -d dependencies=web \
  -d language=java \
  -d type=maven-project --output - | jar x
```

### Adding an API endpoint

Now let's add a new _com.example.yaml.hello_ package containing a simple Controller, delegating calls to a Service implementation.

**Controller**

```java
package com.example.yaml.hello;

import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.bind.annotation.RestController;

@RestController
class HelloController {

  private final HelloService helloService;

  HelloController(HelloService helloService) {
    this.helloService = helloService;
  }

  @PostMapping("/hello")
  @ResponseBody
  public HelloRequest.Response sayHello(@RequestBody final HelloRequest request) {
    return this.helloService.sayHello(request);
  }

}

```

**Service**

```java
package com.example.yaml.hello;

import java.util.List;
import java.util.Optional;
import org.springframework.stereotype.Service;

@Service
class HelloService {

  public HelloRequest.Response sayHello(final HelloRequest helloRequest) {
    return new HelloRequest.Response(
        String.format(
            "Hello message from '%s' to %s",
            Optional.ofNullable(helloRequest.getSender()).orElse("-"),
            String.join(", ", 
                Optional.ofNullable(helloRequest.getReceivers())
                    .orElse(List.of()))));
  }

}

```

**Request and response types**

```java
package com.example.yaml.hello;

import java.util.List;

public class HelloRequest {

  private String sender;
  private List<String> receivers;
  
  // Accessors omitted for brevity

  public static class Response {

    public final String message;

    public Response(String message) {
      if (message == null || message.isBlank()) {
        throw new IllegalArgumentException("message should not be null or blank");
      }
      this.message = message;
    }
  }
}

```

### Testing the endpoint

We can run the server with the following command:

```shell
./mvnw spring-boot:run
```

Let's check now that our new endpoint works as expected:

```shell
❯ curl -i -X POST -H'Content-Type: application/json' http://localhost:8080/hello -d '
{
  "sender": "sender1",
  "receivers": [
    "receiver1",
    "receiver2"
  ]
}
'

HTTP/1.1 200 
Content-Type: application/json
Transfer-Encoding: chunked
Date: Wed, 01 Dec 2021 21:26:41 GMT

{"message":"Hello message from 'sender1' to receiver1, receiver2"}
```

## Adding YAML Support

As we can see when trying to issue a request with a YAML payload, there is no built-in support for YAML by default. At least for the Media Type I would have expected to be supported. I could not find any alternative YAML-related Media Type being supported by default.

```shell
❯ curl -i -X POST -H'Content-Type: application/yaml' http://localhost:8080/hello -d '
sender: sender1
receivers:
- receiver1
- receiver2
'

HTTP/1.1 415 
Accept: application/json, application/*+json
Content-Type: application/json
Transfer-Encoding: chunked
Date: Wed, 01 Dec 2021 22:03:55 GMT

{"timestamp":"2021-12-01T22:03:55.216+00:00","status":415,"error":"Unsupported Media Type","path":"/hello"}
```

### Approach #1 : Manually update Controllers

A quick approach for implementing this could be at first sight to modify the Controllers individually and manually de-serialize the raw request body into a more typed object. We could use whatever deserializer we like, like [ObjectMapper](https://github.com/FasterXML/jackson-databind), which also provides support for YAML via [jackson-dataformat-yaml](https://github.com/FasterXML/jackson-dataformats-text/tree/master/yaml).

Here is the diff:

**pom.xml**

```diff
diff --git a/pom.xml b/pom.xml
index 10b13f6..387e762 100644
--- a/pom.xml
+++ b/pom.xml
@@ -16,6 +16,11 @@
       <artifactId>spring-boot-starter-web</artifactId>
       <groupId>org.springframework.boot</groupId>
     </dependency>
+    <dependency>
+      <artifactId>jackson-dataformat-yaml</artifactId>
+      <groupId>com.fasterxml.jackson.dataformat</groupId>
+      <version>2.12.4</version>
+    </dependency>
 
     <dependency>
       <artifactId>spring-boot-starter-test</artifactId>
```

**HelloController.java**

```diff
diff --git a/src/main/java/com/example/yaml/hello/HelloController.java b/src/main/java/org/rm3l/yaml/hello/HelloController.java
index 2da41ee..52e0db0 100644
--- a/src/main/java/org/rm3l/yaml/hello/HelloController.java
+++ b/src/main/java/org/rm3l/yaml/hello/HelloController.java
@@ -1,5 +1,9 @@
 package com.example.yaml.hello;
 
+import com.fasterxml.jackson.databind.ObjectMapper;
+import com.fasterxml.jackson.dataformat.yaml.YAMLFactory;
+import java.io.IOException;
+import org.springframework.core.io.Resource;
 import org.springframework.web.bind.annotation.PostMapping;
 import org.springframework.web.bind.annotation.RequestBody;
 import org.springframework.web.bind.annotation.ResponseBody;
@@ -20,4 +24,15 @@ class HelloController {
     return this.helloService.sayHello(request);
   }
 
+  @PostMapping(value = "/hello", consumes = {"application/yaml", "application/yml"})
+  @ResponseBody
+  public HelloRequest.Response sayHelloFromYaml(@RequestBody final Resource resource)
+      throws IOException {
+    try (final var inputStream = resource.getInputStream()) {
+      final var helloRequest = new ObjectMapper(new YAMLFactory())
+          .readValue(inputStream, HelloRequest.class);
+      return this.helloService.sayHello(helloRequest);
+    }
+  }
+
 }
```

Now, our previous request should return the expected message:

```shell
❯ curl -i -X POST -H'Content-Type: application/yaml' http://localhost:8080/hello -d '
sender: sender1
receivers:
- receiver1
- receiver2
'
HTTP/1.1 200 
Content-Type: application/json
Transfer-Encoding: chunked
Date: Wed, 01 Dec 2021 22:17:23 GMT

{"message":"Hello message from 'sender1' to receiver1, receiver2"}
```

This approach looks great, but as you might have guessed, we need to modify the Controller to properly deserialize the request body accordingly, which seems cumbersome when there are many Controllers to update.

### Approach #2: Inject an HTTP Message Converter

Within a Spring Web application are injected a bunch of [predefined HTTP Message Converters](https://github.com/spring-projects/spring-framework/tree/main/spring-web/src/main/java/org/springframework/http/converter) out of the box. Some (like for [Byte Arrays](https://github.com/spring-projects/spring-framework/blob/main/spring-web/src/main/java/org/springframework/http/converter/ByteArrayHttpMessageConverter.java) or [String](https://github.com/spring-projects/spring-framework/blob/main/spring-web/src/main/java/org/springframework/http/converter/StringHttpMessageConverter.java) conversion) are present by default, while others are enabled depending on the presence of some JARs in the classpath.

As their name suggests, they are in charge of marshalling and unmarshalling objects from HTTP requests or into HTTP responses. This is essentially how [RequestBody](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/web/bind/annotation/RequestBody.html)-annotated parameters in Controller methods (or [ResponseBody](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/web/bind/annotation/ResponseBody.html)-annotated Controller methods) are resolved to typed objects.

Let's see how we could inject a simple HTTP Message Converter bean into our Application Context, which would allow us to benefit from automatic message conversion depending on the _Accept_ or _Content-Type_ HTTP Headers.

```java
package com.example.yaml;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.dataformat.yaml.YAMLFactory;
import java.nio.charset.StandardCharsets;
import org.springframework.http.MediaType;
import org.springframework.http.converter.json.AbstractJackson2HttpMessageConverter;
import org.springframework.stereotype.Component;

@Component
class DemoYamlMessageConverter extends AbstractJackson2HttpMessageConverter {

  DemoYamlMessageConverter() {
    super(new ObjectMapper(new YAMLFactory()),
        new MediaType("application", "yaml", StandardCharsets.UTF_8),
        new MediaType("text", "yaml", StandardCharsets.UTF_8),
        new MediaType("application", "*+yaml", StandardCharsets.UTF_8),
        new MediaType("text", "*+yaml", StandardCharsets.UTF_8),
        new MediaType("application", "yml", StandardCharsets.UTF_8),
        new MediaType("text", "yml", StandardCharsets.UTF_8),
        new MediaType("application", "*+yaml", StandardCharsets.UTF_8),
        new MediaType("text", "*+yaml", StandardCharsets.UTF_8));
  }

  @Override
  public void setObjectMapper(final ObjectMapper objectMapper) {
    if (!(objectMapper.getFactory() instanceof YAMLFactory)) {
      // Sanity check to make sure we do have an ObjectMapper configured
      // with YAML support, just in case someone attempts to call
      // this method elsewhere.
      throw new IllegalArgumentException(
          "ObjectMapper must be configured with an instance of YAMLFactory");
    }
    super.setObjectMapper(objectMapper);
  }
}

```

Again, we can check that our previous request returns the expected message:

```shell
❯ curl -i -X POST -H'Content-Type: application/yaml' http://localhost:8080/hello -d '
sender: sender1
receivers:
- receiver1
- receiver2
'
HTTP/1.1 200 
Content-Type: application/json
Transfer-Encoding: chunked
Date: Wed, 01 Dec 2021 22:17:23 GMT

{"message":"Hello message from 'sender1' to receiver1, receiver2"}
```

We can also have this message converter serialize responses to YAML, by specifying the _Accept_ Header in our request:

```shell
❯ curl -i -X POST -H'Content-Type: application/yaml' -H'Accept: application/yaml' http://localhost:8080/hello -d '
sender: sender1
receivers:
- receiver1
- receiver2
'
HTTP/1.1 200 
Content-Type: application/yaml;charset=UTF-8
Transfer-Encoding: chunked
Date: Wed, 01 Dec 2021 22:57:34 GMT

---
message: "Hello message from 'sender1' to receiver1, receiver2"

```

## Wrapping Up

In this blog post, we have seen different approaches for supporting YAML as part of a Spring Web application.

Unlike the first approach, the second approach provides a more maintainable strategy, in that Controller methods do not need to be rewritten. A single HTTP Message Converter Bean instance is sufficient to support configured Media Types in a consistent manner.

Bear this in mind anytime you need to add support for a specific Media Type.

As usual, please feel free to share your thoughts in the comments.

