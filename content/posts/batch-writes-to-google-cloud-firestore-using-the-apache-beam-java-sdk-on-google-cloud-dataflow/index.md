---
author: "Armel Soro"
categories: ["data-pipeline", "java", "apache-beam", "google-cloud", "google-cloud-dataflow", "google-cloud-firestore"]
date: 2021-04-23T20:35:00Z
description: ""
draft: false
image: "https://images.unsplash.com/photo-1609923519519-7f470620fa10?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=MnwxMTc3M3wwfDF8c2VhcmNofDEyfHxmYXN0fGVufDB8fHx8MTYyMzM2NjUxNA&ixlib=rb-1.2.1&q=80&w=2000"
slug: "batch-writes-to-google-cloud-firestore-using-the-apache-beam-java-sdk-on-google-cloud-dataflow"
summary: "On how to leverage Apache Beam DoFn lifecycle methods to optimize writing to Google Cloud Firestore, when running in Google Cloud Dataflow."
tags: ["data-pipeline", "java", "apache-beam", "google-cloud", "google-cloud-dataflow", "google-cloud-firestore"]
title: "Batch writes to Google Cloud Firestore using the Apache Beam Java SDK on Google Cloud Dataflow"
resources:
- name: "featured-image"
  src: "featured-image.jpg"
  
---


Few months ago at work, we needed to write a relatively simple data processing pipeline and deploy it on [Google Cloud Dataflow](https://cloud.google.com/dataflow). The goal of this pipeline was to handle data coming from various sources (like local files, [Google Cloud Pub/Sub](https://cloud.google.com/pubsub/docs) or [Google Cloud Storage](https://cloud.google.com/storage)), validate and transform it, and ultimately save such data as [Firestore](https://cloud.google.com/firestore) documents.

Google Cloud Dataflow is a managed service for stream and batch processing. It uses [Apache Beam](https://beam.apache.org/) under the cover, which provides a [unified programming model](https://beam.apache.org/documentation/programming-guide/) for such tasks. Apache Beam also allows to run a same pipeline code using a broad set of engines, like Google Cloud Dataflow, Apache Spark or even locally via the [Direct Runner](https://beam.apache.org/documentation/runners/direct/). For more details, read the official documentation about the [execution model of Apache Beam](https://beam.apache.org/documentation/runtime/model/). This sounded appealing, namely to avoid vendor lock-in, while benefiting from auto-scaling capabilities.

This article assumes you are already familiar with the Apache Beam programming model, regardless of your SDK language of choice. We will start with a sample Apache Beam project, which we will adapt to write its output to Firestore. We will finish by looking into a simple technique to further optimize the overall execution time of our pipeline.

For reference, the source code of this is available on [GitHub://rm3l/apache-beam-pipeline-with-firestore-batch-writes](https://github.com/rm3l/apache-beam-quickstart-java-firestore-batch).

## Generating a sample Apache Beam Project

Let's start with the official quickstart Maven Archetype. You may want to read [my other article](https://rm3l.org/about-maven-archetypes/) to learn more about Maven Archetypes.

```bash
mvn archetype:generate \
  -DarchetypeGroupId=org.apache.beam \
  -DarchetypeArtifactId=beam-sdks-java-maven-archetypes-examples \
  -DarchetypeVersion=2.29.0 \
  -DgroupId=org.rm3l \
  -DartifactId=apache-beam-quickstart-java-firestore-batch \
  -Dversion="0.1.0-SNAPSHOT" \
  -Dpackage=org.rm3l.beam \
  -DinteractiveMode=false
```

This Archetype (_org.apache.beam:beam-sdks-maven-archetypes-examples_) generates a sample Maven project with a set of sample pipelines based on the [WordCount examples](https://beam.apache.org/get-started/wordcount-example/). The WordCount examples walk through setting up a processing pipeline that reads from a public dataset containing the text of King Lear (by William Shakespeare), tokenizes the text lines into individual words, and performs a frequency count on each of those words.

Running this is as simple as executing the main Java class, by picking a supported runner (like [DirectRunner](https://beam.apache.org/documentation/runners/direct/) for local execution, or [DataflowRunner](https://beam.apache.org/documentation/runners/dataflow/) for running on Dataflow). Here, we will execute our pipelines using the Dataflow Runner, so they can be comparable.

While Apache Beam provides built-in connectors for several external services (like Pub/Sub for stream processing), none exists for Firestore at the time of writing, as far as I can tell. Thankfully, Apache Beam being extremely extensible, it remains possible to write our own [Transforms](https://beam.apache.org/documentation/programming-guide/#transforms).

To test writing to Firestore, let's introduce a slightly modified version of the WordCount pipeline : [WordCountToFirestorePipeline](https://github.com/rm3l/apache-beam-quickstart-java-firestore-batch/blob/main/src/main/java/org/rm3l/beam/firestore/WordCountToFirestorePipeline.java), which will attempt to write frequency count for each word into Firestore documents.

## Naive Implementation : One write operation per item

In this very first implementation, mainly used to test-drive writes to Firestore.

![Overview of the Naive implementation](https://rm3l-org.s3.us-west-1.amazonaws.com/assets/apache_beam_firestore_write_naive_implementation.png)

A PTransform function creates a different Firestore client per single element processed, like so:

```java
static class NaiveImplementation extends AbstractImplementation {

    @Override
    protected Pipeline doCreatePipeline(final String[] args) {
      final Options options =
          PipelineOptionsFactory.fromArgs(args).withValidation().as(Options.class);
      final Pipeline wordCountToFirestorePipeline = Pipeline.create(options);

      final String outputGoogleCloudProject = options.getOutputGoogleCloudProject();
      final String inputFile = options.getInputFile();
      final String outputFirestoreCollectionPath = options
          .getOutputFirestoreCollectionPath() != null ?
          options.getOutputFirestoreCollectionPath() :
          inputFile.substring(inputFile.lastIndexOf("/") + 1, inputFile.length());

      wordCountToFirestorePipeline.apply("ReadLines", TextIO.read().from(inputFile))
          .apply(new CountWords())
          .apply("Write Counts to Firestore",
              new PTransform<PCollection<KV<String, Long>>, PDone>() {
                @Override
                public PDone expand(PCollection<KV<String, Long>> input) {

                  input.apply("Write to Firestore", ParDo.of(new DoFn<KV<String, Long>, Void>() {

                    @ProcessElement
                    public void processElement(@Element KV<String, Long> element,
                        OutputReceiver<Void> out) {

                      try (final Firestore firestore = FirestoreOptions.getDefaultInstance()
                          .toBuilder()
                          .setCredentials(GoogleCredentials.getApplicationDefault())
                          .setProjectId(outputGoogleCloudProject)
                          .build().getService()) {

                        final Map<String, Long> documentData = new HashMap<>();
                        documentData.put("count", element.getValue());

                        firestore.collection(outputFirestoreCollectionPath)
                            .document(element.getKey())
                            .set(documentData).get(1L, TimeUnit.MINUTES);

                      } catch (final Exception e) {
                        logger.warn("Error while writing to Firestore", e);
                        throw new IllegalStateException(e);
                      }

                      out.output(null);
                    }
                  }));

                  return PDone.in(input.getPipeline());
                }
              });

      return wordCountToFirestorePipeline;
    }
  }
```

This is obviously sub-optimal, since a pipeline distributes work across many compute resources. And here, we are making a single call to Firestore for each distinct word flowing through the system. Such call is blocking until it completes, before returning to the Apache Beam Pipeline Driver program.

This gives us an overall average execution time of approximately 15 minutes for 4555 documents persisted, which seems pretty long:

```bash
❯ time (mvn compile exec:java -Dexec.mainClass=org.rm3l.beam.firestore.WordCountToFirestorePipeline \
  -Dexec.args="--outputGoogleCloudProject=my-gcp-project \
  --runner=dataflow \
  --project=my-gcp-project \
  --region=us-central1 \
  --gcpTempLocation=gs://my-bucket/tmp/" \
  -Pdataflow-runner)

### Omitted for brevity ###

[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  15:10 min
[INFO] ------------------------------------------------------------------------
( mvn compile exec:java   -Pdataflow-runner; )  32.29s user 1.39s system 7% cpu 15:10.95 total
```

## Optimizing via Batch Writes

As the name suggests, the point behind this other approach is to buffer the different write requests and flush them in a single transaction per batch once the maximum batch size is reached. The batch size is configurable, defaulting to 500 elements, which is at this time the [maximum](https://firebase.google.com/docs/firestore/quotas#writes_and_transactions) number of document operations allowed in a single Firestore batched transaction.

![Overview of the Batch Write implementation](https://rm3l-org.s3.us-west-1.amazonaws.com/assets/apache_beam_firestore_write_batch_implementation.png)

Here is the new implementation, as compared to the naive implementation above:

```java
static class BatchWriteImplementation extends AbstractImplementation {

    @Override
    protected Pipeline doCreatePipeline(final String[] args) {
      final BatchWriteImplementationOptions options =
          PipelineOptionsFactory.fromArgs(args).withValidation()
              .as(BatchWriteImplementationOptions.class);
      final Pipeline wordCountToFirestorePipeline = Pipeline.create(options);

      final String outputGoogleCloudProject = options.getOutputGoogleCloudProject();
      final String inputFile = options.getInputFile();
      final String outputFirestoreCollectionPath = options
          .getOutputFirestoreCollectionPath() != null ?
          options.getOutputFirestoreCollectionPath() :
          inputFile.substring(inputFile.lastIndexOf("/") + 1, inputFile.length());

      wordCountToFirestorePipeline.apply("ReadLines", TextIO.read().from(inputFile))
          .apply(new CountWords())
          .apply("Write Counts to Firestore",
              new PTransform<PCollection<KV<String, Long>>, PDone>() {
                @Override
                public PDone expand(PCollection<KV<String, Long>> input) {
                  input.apply("Batch write to Firestore", 
                  
                  //FirestoreUpdateDoFn is a DoFn custom function that handles batch writes to Firestore
                  ParDo.of(new FirestoreUpdateDoFn<>(
                      outputGoogleCloudProject, options.getFirestoreMaxBatchSize(),
                      (final Firestore firestoreDb, final KV<String, Long> element) -> {
                        final Map<String, Long> documentData = new HashMap<>();
                        documentData.put("count", element.getValue());

                        firestoreDb.collection(outputFirestoreCollectionPath)
                            .document(element.getKey())
                            .set(documentData);
                      }
                  )));
                  return PDone.in(input.getPipeline());
                }

              });

      return wordCountToFirestorePipeline;
    }

    public interface BatchWriteImplementationOptions extends Options {

      @Description("Max batch size for Firestore writes")
      @Default.Integer(FirestoreUpdateDoFn.DEFAULT_MAX_BATCH_SIZE)
      int getFirestoreMaxBatchSize();

      void setFirestoreMaxBatchSize(int firestoreMaxBatchSize);
    }
  }
```

The interesting bits can be found in the [FirestoreUpdateDoFn](https://github.com/rm3l/apache-beam-quickstart-java-firestore-batch/blob/main/src/main/java/org/rm3l/beam/firestore/FirestoreUpdateDoFn.java) class, which leverages the following Apache Beam method annotations in order to collect operations and issue transactional requests when this collection reaches the configured batch size:

* [@StartBundle](https://beam.apache.org/releases/javadoc/2.29.0/index.html?org/apache/beam/sdk/transforms/DoFn.StartBundle.html): this prepares the current instance of _FirestoreUpdateDoFn_ for processing a batch of elements. This is where we create a new Firestore Client object.

```java
  @StartBundle
  public void startBundle() throws Exception {
    logger.debug("Starting processing bundle...");
    this.firestoreDb = FirestoreOptions.getDefaultInstance()
        .toBuilder()
        .setCredentials(GoogleCredentials.getApplicationDefault())
        .setProjectId(outputFirestoreProjectId)
        .build().getService();
  }
```

* [@ProcessElement](https://beam.apache.org/releases/javadoc/2.29.0/index.html?org/apache/beam/sdk/transforms/DoFn.ProcessElement.html): this is a typical mandatory Apache Beam annotation on a method, which will get executed for each element of the bundle being processed. This is where we append the element to the batch collection, and trigger a transaction flush if the container size is to exceed the maximum batch size configured.

```java
  @ProcessElement
  public void processElement(final ProcessContext context)
      throws ExecutionException, InterruptedException {
    final T element = context.element();
    logger.debug("Adding element to batch: {}", element);
    this.elementsBatch.add(element);
    if (this.elementsBatch.size() >= this.maxBatchSize) {
      this.flushUpdates();
    }
  }
```

* [@FinishBundle](https://beam.apache.org/releases/javadoc/2.29.0/index.html?org/apache/beam/sdk/transforms/DoFn.FinishBundle.html): this is executed once the batch of elements is finished. Here, we force a flush of the remaining items in the batch container. We finish by relinquishing all resources associated to the Firestore Client object.

```java
  @FinishBundle
  public void finishBundle() throws Exception {
    logger.debug("Finishing processing bundle...");
    this.flushUpdates();
    if (this.firestoreDb != null) {
      this.firestoreDb.close();
    }
  }
```

* [@Teardown](https://beam.apache.org/releases/javadoc/2.29.0/index.html?org/apache/beam/sdk/transforms/DoFn.Teardown.html): this method is our last chance to clean up the current instance of FirestoreUpdateDoFn. Here, we make sure the Firestore Client object is really closed:

```java
  @Teardown
  public void teardown() throws Exception {
    try {
      if (this.firestoreDb != null) {
        this.firestoreDb.close();
      }
    } catch (final Exception e) {
      logger.warn("Error in teardown method", e);
    }
  }

```

The [flushUpdates](https://github.com/rm3l/apache-beam-quickstart-java-firestore-batch/blob/main/src/main/java/org/rm3l/beam/firestore/FirestoreUpdateDoFn.java#L78-L95) does the work of processing all the batched elements and sending the appropriate requests to Firestore:

```java
private void flushUpdates() throws ExecutionException, InterruptedException {
    if (elementsBatch.isEmpty()) {
      return;
    }
    logger.debug("Flushing {} operations to Firestore...", elementsBatch.size());
    final long start = System.nanoTime();
    final WriteBatch writeBatch = firestoreDb.batch();
    final List<T> processed = new ArrayList<>();
    elementsBatch.forEach(element -> {
      inputToDocumentRefUpdaterFunction
          .updateDocumentInFirestore(this.firestoreDb, element);
      processed.add(element);
    });
    writeBatch.commit().get();
    logger.info("... Committed {} operations to Firestore in {} ms...", processed.size(),
        TimeUnit.NANOSECONDS.toMillis(System.nanoTime() - start));
    this.elementsBatch.removeAll(processed);
  }
```

Running it on Dataflow gives us an average time of 3 minutes.

```shell
❯ time (mvn compile exec:java -Dexec.mainClass=org.apache.beam.examples.firestore.WordCountToFirestorePipeline \
  -Dexec.args="--implementation=batch \
  --outputGoogleCloudProject=my-gcp-project \
  --runner=dataflow \
  --project=my-gcp-project \
  --region=us-central1 \
  --gcpTempLocation=gs://my-bucket/tmp/" \
  -Pdataflow-runner)

### Omitted for brevity ###

INFO: Done running 'batch' implemention in 178440534611 nanos (178440 ms)
[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  03:03 min
[INFO] ------------------------------------------------------------------------
( mvn-or-mvnw compile exec:java   -Pdataflow-runner; )  40.15s user 1.28s system 22% cpu 3:04.34 total

```

As we can see from the screen capture above, we were able to commit write operations to Firestore by batches of 500 elements at most.

### Why this works ?

What we did above was simply to leverage the Apache Beam [DoFn lifecycle methods](https://beam.apache.org/documentation/programming-guide/#dofn) to batch our calls to Firestore. This technique can be quite useful, e.g in other use cases., when calling external services to avoid putting too much load on those servers.

### Notes

There is a small thing to bear in mind with this second approach: we have no control whatsoever on the sizes of the different bundles, which depend on each runner implementation. For example, running the same Batch Pipeline locally (using the Direct Runner) resulted in a lot of bundles created, but each containing a single element, which kind of defeats the whole purpose of batching.

The Dataflow Runner however does a great work here in dynamically determining the sizes of the different bundles, based on what's currently happening inside the pipeline and its workers (which can be auto-scaled up or down). In Streaming Pipelines, the bundles will generally be smaller in size, so as to maximize throughput.

Thanks for reading. As always, any feedback is welcome.



