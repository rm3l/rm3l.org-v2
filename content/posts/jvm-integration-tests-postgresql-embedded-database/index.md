---
author: "Armel Soro"
categories: ["junit", "tests", "postgresql", "h2", "hsqldb", "java", "spring"]
date: 2018-09-28T18:46:00Z
description: ""
draft: false
image: "https://images.unsplash.com/photo-1523961131990-5ea7c61b2107?ixlib=rb-1.2.1&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=2000&fit=max&ixid=eyJhcHBfaWQiOjExNzczfQ"
slug: "jvm-integration-tests-postgresql-embedded-database"
tags: ["junit", "tests", "postgresql", "h2", "hsqldb", "java", "spring"]
title: "Running Java Integration Tests against a PostgreSQL Embedded database"
resources:
- name: "featured-image"
  src: "featured-image.jpg"

---


Today, I'm going to walk you through running integration tests on the JVM against a real production-like PostgreSQL database. All without losing in terms of overall testing time or performance (especially when you have a database with hundreds of tables).

In-memory databases (e.g., [H2](http://www.h2database.com/html/main.html), [HSQLDB](http://hsqldb.org/), [SQLite](https://www.sqlite.org/inmemorydb.html), ...) are very often used as drop-in replacements when running integration tests. This is generally in order to make such tests run fast, self-contained and therefore free of side effects. This technique seems to suffice for simple interactions, but may not really mimic the database used in production. So even though all your integration tests pass locally against an in-memory database, there is actually no absolute guarantee that the code will work once deployed in a production environment which makes use of a different database server. Worse, should you happen to use non-standard database-specific queries in your code, you might need to either skip testing such part (which I strongly discourage to do), or implement custom adapters to work with your in-memory database setup.

Now let's start with what we will do in this post:

* We use PostgreSQL in production, and we want our integration tests to run against a local PostgreSQL database. That is, we want to have such database spawned and set up on-demand (programmatically) before all tests, and relinquished after all our tests.
* We want to guarantee that all individual test methods start in a clean state, especially from the database perspective. So the database should be wiped out before (or after) each test method run.
* Ideally, tests must also be as fast as with an in-memory database.

The code of the complete project is available on [Github://rm3l/pgembedded-junit-integration-tests](https://github.com/rm3l/pgembedded-junit-integration-tests).

### PostgreSQL Embedded

We are going to make use of [postgresql-embedded](https://github.com/yandex-qatools/postgresql-embedded), a pretty cool library which allows to programmatically start and stop a PostgreSQL server instance. This library takes care of downloading the specified version, extracting (and optionally caching) it locally, and setting up the database with all the options we defined.

In our Maven's _pom.xml_:

```xml
<dependency>
    <groupId>ru.yandex.qatools.embed</groupId>
    <artifactId>postgresql-embedded</artifactId>
    <version>2.9</version>
    <scope>test</scope>
</dependency>
```

Or, if you use Gradle, in your _build.gradle_:

```groovy
testCompile('ru.yandex.qatools.embed:postgresql-embedded:2.9')
```

### Spinning up a database for the tests

Starting a new database and setting it up (schema creation, default data injection, and so on) may be a very computationally expensive operation. So doing this for each test may end up slowing down the testing phase, thus increasing the feedback loop, thus decreasing developer productivity.

To alleviate this time, we are going to start and set up a single PostgreSQL server once and before all tests start, then close it at the end of all tests.

Remember when I was talking about having tests start in a clean state from the database perspective? In order to do so, we need to make sure this database (which is now shared) is wiped out before or after each individual test.

We can meet the requirements above by leveraging Junit 4 [@BeforeClass](http://junit.sourceforge.net/javadoc/org/junit/BeforeClass.html)/[@AfterClass](http://junit.sourceforge.net/javadoc/org/junit/AfterClass.html) (or Junit 5 [@BeforeAll](https://junit.org/junit5/docs/5.0.0/api/org/junit/jupiter/api/BeforeAll.html)/[@AfterAll](https://junit.org/junit5/docs/5.0.0/api/org/junit/jupiter/api/AfterAll.html)) and Junit 4 [@Before](http://junit.sourceforge.net/javadoc/org/junit/Before.html)/[@After](http://junit.sourceforge.net/javadoc/org/junit/After.html) (or Junit 5 [@BeforeEach](https://junit.org/junit5/docs/5.0.0/api/org/junit/jupiter/api/BeforeEach.html)/[@AfterEach](https://junit.org/junit5/docs/5.0.0/api/org/junit/jupiter/api/AfterEach.html)) lifecycle methods. I personally do prefer using Junit [Rules](https://github.com/junit-team/junit4/wiki/rules) (or [Junit 5 extensions](https://github.com/junit-team/junit5/blob/master/documentation/src/docs/asciidoc/user-guide/extensions.adoc)) to add specific functionality to tests and since they can easily be reused without forcing test inheritance.

Example of test class:

```java

public class MyIntegrationTests {

    @org.junit.ClassRule
    public static final PostgreSQLServer databaseServer = 
        new PostgreSQLServer();
    
    @org.junit.Rule
    public final PostgreSQLServer.Wiper databaseWiper = 
        new PostgreSQLServer.Wiper();
    
    @org.junit.Test
    public void aTest() {
      //...
    }
}

```

The PostgreSQLServer class looks like this:

```java
public class PostgreSQLServer extends org.junit.rules.ExternalResource {

     private static PostgresEmbedded postgres;
     
     private static String jdbcUrl;
     private static final String JDBC_USERNAME = "my_test_username";
     private static final String JDBC_PASSWORD = "my_test_password";
     
     @Override
     protected void before() throws Throwable {
         synchronized (PostgreSQLServer.class) {
             if (postgres == null) {
                 //The line below starts a new PostgreSQL server
                 //listening on any available local port. 
                 //The library makes sure to download the right 
                 //PostgreSQL version, 
                 //to extract and configure it accordingly
                 postgres = PostgreSQLHelper.getAndStartServer(
                     JDBC_USERNAME, JDBC_PASSWORD);
                 jdbcUrl = postgres.getConnectionUrl()
                     .orElseThrow(() -> 
                       new IllegalStateException(
                         "Failed to get PostgreSQL Connection URL"));
                 
                 //Now that we have a JDBC URL, 
                 //we may create the schema/tables 
                 //as well as inject some default data
                 //...
                 
                 //Register hook to shutdown the 
                 //PostgreSQL Embedded server at JVM shutdown.
                 Runtime.getRuntime().addShutdownHook(
                     new Thread(() -> Optional
                         .ofNullable(postgres)
                         .ifPresent(EmbeddedPostgres::stop)));
             }
         }
         
         //Now since this is being used as a Junit ClassRule, 
         //we can set some properties that can be used 
         //later on during the tests.
         // For example, if you make use of Spring/SpringBoot,
         //you can set the datasource as JVM properties that will get 
         //picked when the Spring Application Context is initialized!
         System.setProperty("spring.datasource.url", jdbcUrl);
         System.setProperty("spring.datasource.username", 
             JDBC_USERNAME);
         System.setProperty("spring.datasource.password", 
             JDBC_PASSWORD);
     }
     
     public static class Wiper implements org.junit.rules.TestRule {

         @Override
         public Statement apply(Statement base, Description description) {
                return new Statement() {
                    @Override
                    public void evaluate() throws Throwable {
                        try {
                            before();
                            base.evaluate();
                        } finally{
                            after();
                        }
                    }
                };
         }
         
         private void before() {
             //Discussed later in the "Test" section
         }
         
         private void after() {
             //Discussed later in the "Test" section
         }
         
     
     }

}

```

The JVM shutdown hook allows to ensure the PostgreSQL Embedded server is stopped, and resources relinquished when the JVM stops. Few points worth noting regarding this :

* it requires that all your integration tests inside a same Maven module run in a same JVM process (see Maven Failsafe Plugin [forkCount and reuseForks](https://maven.apache.org/surefire/maven-failsafe-plugin/examples/fork-options-and-parallel-execution.html) parameters to reuse the JVM);
* Per the [Java Virtual Machine Hook API](https://docs.oracle.com/javase/8/docs/technotes/guides/lang/hook-design.html) specifications, there is no guarantee the hook will be called. Anyway, the same goes when using Junit lifecycle methods. Please comment if you think of a better strategy for stopping the database.

At this point, we have a rules-based system allowing to programmatically start a PostgreSQL instance before all tests start, and auto-stop it at JVM termination.

Now let's see how we can actually wipe the database after each individual test method run (and taking performance into account). This is to be considered as the implementation for the PostgreSQLServer#wipeDatabase() method in the code snippet above.

### Wiping out the database after each test

We can consider several approaches for this case.

**Option 1: Truncate all tables**

This is a very efficient strategy when leveraging an in-memory database such as H2. However, TRUNCATE on PostgreSQL may actually be very slow. As explained in this very detailed [StackOverflow answer](https://stackoverflow.com/questions/11419536/postgresql-truncation-speed/11423886), PostgreSQL TRUNCATE does a lot more fixed-cost work and housekeeping than DELETE.

So depending on the database schema, this option may not be the right one. If you were to consider this approach however, below is a sample example of how we would implement the wipeDatabase() method.

```java
@Override
protected void wipeDatabase() throws Exception {
        synchronized (PostgreSQLServer.class) {
            try (final Connection connection =
                         DriverManager.getConnection(
                                 this.postgreSQLServer.getJdbcUrl(),
                                 JDBC_USERNAME, JDBC_PASSWORD);
                 final java.sql.Statement databaseTruncationStatement = connection.createStatement()) {
                databaseTruncationStatement.execute("BEGIN TRANSACTION");
                databaseTruncationStatement.execute(
                        String.format("TRUNCATE %s RESTART IDENTITY CASCADE",
                                String.join(",", this.postgreSQLServer.getAllDatabaseTables())));
                databaseTruncationStatement.execute("COMMIT TRANSACTION"); //Reset constraints
            }
        }

}
```

**Option 2: Delete all tables**

Here we are going to send a DELETE SQL query against all tables in the schema. Note that we have to temporarily deactivate constraints checks prior to sending the DELETE queries against tables with foreign keys references.

```java
@Override
protected void after() throws Exception {

        synchronized (PostgreSQLServer.class) {
            try (final Connection connection =
                         DriverManager.getConnection(
                                 this.postgreSQLServer.getJdbcUrl(),
                                 JDBC_USERNAME, JDBC_PASSWORD);
                 final java.sql.Statement databaseTruncationStatement = connection.createStatement()) {
                databaseTruncationStatement.execute(
                        "SET session_replication_role = replica"); //Disable all constraints
                databaseTruncationStatement.execute("BEGIN TRANSACTION");
                final Set<String> temporaryTablesStatements = new TreeSet<>();
                int index = 0;
                final Collection<String> allDatabaseTables = this.postgreSQLServer.getAllDatabaseTables();
                for (final String table : allDatabaseTables) {
                    //Much faster to delete all tables in a single statement
                    temporaryTablesStatements.add(
                            String.format("table_%s AS (DELETE FROM %s)", index++, table));
                }
                databaseTruncationStatement.execute(
                        String.format("WITH %S SELECT 1", String.join(",", temporaryTablesStatements)));
                databaseTruncationStatement.execute("COMMIT TRANSACTION");
                databaseTruncationStatement.execute(
                        "SET session_replication_role = DEFAULT"); //Reset constraints
            }
        }

}
```

**Option 3: Delete only tables that have been changed by the current test**

This is a variant of the approach #2 above, and the one I like the most here, especially when you have a schema with hundreds of tables. In a nutshell, rather than issuing out a DELETE statement against all tables in the schema, we can automatically detect tables that have been changed by the current test, and delete only those ones.

To auto-detect tables that have been changed, we are going to leverage PostgreSQL built-in [LISTEN / NOTIFY](https://www.postgresql.org/docs/current/static/libpq-notify.html) mechanism which paves the way for asynchronous notifications. Think of it as an implementation of the [publish-subscribe messaging pattern](https://en.wikipedia.org/wiki/Publish%E2%80%93subscribe_pattern).

1. We first LISTEN to incoming changes on a given channel
2. We register a Trigger which sends NOTIFY statements after any INSERT inside any table. The payload in the NOTIFY message contains just the modified table name. Trigger registration should be done only once, right after the database schema has been created.
3. At the end of the test, we can aggregate all NOTIFY payloads to build the set of updated tables, to perform the deletion.
4. As in option #2, we have to temporarily disable constraints checks, then DELETE tables changed, then reactivate such constraints checks.

```java
//LISTEN 
@Override
protected void before() throws SQLException {
        this.eventListenerConnection = DriverManager
                .getConnection(this.postgreSQLServer.getJdbcUrl(),
                        JDBC_USERNAME, JDBC_PASSWORD);
        try (final java.sql.Statement statement = eventListenerConnection.createStatement()) {
            statement.execute("LISTEN table_insertions");
        }
}

//Aggregate all NOTIFY payloads so as to build the list of tables that have been modified
@Override
protected void after() throws SQLException {
        Collection<String> tablesModifiedAndCandidateForTruncation = null;
        synchronized (this) {
            if (eventListenerConnection == null) {
                return;
            }

            // issue a dummy query to contact the backend
            // and receive any pending notifications.
            try (final java.sql.Statement statement = eventListenerConnection.createStatement()) {
                final ResultSet rs = statement.executeQuery("SELECT 1");
                rs.close();

                final PGNotification[] notifications =
                        ((PGConnection) eventListenerConnection).getNotifications();

                if (notifications != null) {
                    tablesModifiedAndCandidateForTruncation =
                            Arrays.stream(notifications)
                                    .map(PGNotification::getParameter)
                                    .collect(Collectors.toSet());
                }
            }

            logger.info("tablesModifiedAndCandidateForTruncation: {}", tablesModifiedAndCandidateForTruncation);

            if (tablesModifiedAndCandidateForTruncation == null ||
                    tablesModifiedAndCandidateForTruncation.isEmpty()) {
                return;
            }
        }
        
        //At ths point,we have the list of tables modified by the current test

        synchronized (PostgreSQLServer.class) {
            this.doWipeTables(tablesModifiedAndCandidateForTruncation);
        }

    }
```

**Option 4: Spring Transactions**

If you make use of the popular [Spring Framework](https://spring.io/), you can also mark your test as [Transactional](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/transaction/annotation/Transactional.html). As a consequence, the test will get executed in a single transaction, which is rolled back by default at the end of the test.

A limitation worth noting though: if your tests run against a real servlet environment (as is the case when using [@SpringBootTest](https://docs.spring.io/spring-boot/docs/current/api/org/springframework/boot/test/context/SpringBootTest.html) with a [webEnvironment](https://docs.spring.io/spring-boot/docs/current/api/org/springframework/boot/test/context/SpringBootTest.WebEnvironment.html) and either `[RANDOM_PORT](https://docs.spring.io/spring-boot/docs/current/api/org/springframework/boot/test/context/SpringBootTest.WebEnvironment.html#RANDOM_PORT)` or `[DEFINED_PORT](https://docs.spring.io/spring-boot/docs/current/api/org/springframework/boot/test/context/SpringBootTest.WebEnvironment.html#DEFINED_PORT)`), the HTTP client and server will run on separate threads. And any transaction initiated on the server will not get rolled back.

Therefore the feasibility of this technique depends upon what you actually do in your tests, and how the code you test leverages transactions as well.

### Conclusion

We just walked through how to leverage a real PostgreSQL database in integration tests, so as to mimic a production database making use of the same database vendor. This is very important to consider, so as to have your tests target a real production-like environment. We saw how [postgresql-embedded](https://github.com/yandex-qatools/postgresql-embedded) library could be of great help in spinning up a PostgreSQL database server programmatically, without having to worry about the download, extraction, configuration overhead tasks.

To also have the tests start with a clean state from the database perspective, we looked into different possible approaches to use at the end of each test:

* Truncating all tables, which may finally end up being very slow, especially when you have hundreds of tables
* Deleting all tables, with a "DELETE" query: interesting, but we may end up sending useless queries against tables that have never been modified by the test
* Detecting tables modified by the test and deleting only those ones. This is my favorite approach, in that we limit the scope of "DELETE" queries to the tables that are of interest, i.e., the ones that have been modified by our tests. This is achieved by leveraging PostgreSQL built-in LISTEN / NOTIFY mechanism
* Truncating only tables that have been modified by the test. This is a variant of the approach above, but it may again suffer from PostgreSQL fixed-cost when truncating tables
* If using the Spring Framework, marking the test as Transactional, so it can be rolled back by default at the end of the test. This has a limitation when targeting real servlet environments.

For reference, the code of the complete project is available on [Github://rm3l/pgembedded-junit-integration-tests](https://github.com/rm3l/pgembedded-junit-integration-tests) .

As always, your comments are more than welcome.



