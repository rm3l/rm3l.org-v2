+++
author = "Armel Soro"
categories = ["Blogs"]
date = 2017-10-03T22:37:24Z
description = ""
draft = true
slug = "spring-testing-asynchronous-code-call-from-synchronous-controller"
tags = ["spring", "java", "async", "test", "junit"]
title = "Spring: Testing asynchronous code call from synchronous component"

+++


Recently, I was in a situation where I needed to write an end-to-end integration test against a REST endpoint returning a response quite quickly, but publishing an event, handled later at the service layer asynchronously by one or more listeners.
Of course, the intent of the test was:
1. check the response of the endpoint
1. make sure that the event is handled asynchronously
1. check the state of the system after the potentially long running operations performed by all the asynchronous threads

Below is an example of such controller:
```java
@PostMapping("/actions/sayHelloAndPerformBgTask")
@ResponseBody
@ResponseStatus(HttpStatus.CREATED)
public String doSayHelloAndPerformBgTask(
        @RequestParam(value = "message", required = false) final String message,
        @RequestParam(value = "delay", required = false) final Integer delaySeconds) {
    final String result = String.format("Hello %s!", 
        Optional.ofNullable(message).orElse(""));
    //Event is handled asynchronously in the background by one or more services
    this.applicationEventPublisher.publishEvent(
        new MessageReceivedEvent(this, message, delaySeconds));
    return result;
}
```

And the corresponding integration test:

```java
@RunWith(SpringRunner.class)
@SpringBootTest(classes = SpringAsyncTestingApplication.class)
public class SpringAsyncTestingApplicationTests {

    //initialization omitted for brevity
    
    @Test
    public void testRequestAndAsyncHandlers() {
         this.mockMvc.perform(
                 post(url).param("delay", "3").param("message", "Leia"))
             .andExpect(status().isCreated())
             .andExpect(content().string("Hello Leia!"));
     
         //At this point, we need to test the async handling of the event
     }
 }
```

The goal of this post is to analyze the different options considered.

# Approach #1: using a dummy while loop
TODO

# Approach #2: leveraging a CountDownLatch
TODO

# Approach #3: using awaitility library
TODO

