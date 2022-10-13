---
author: "Armel Soro"
categories: ["code", "ghost", "blog", "highlighting", "prism", "prismjs", "cdn", "dart", "syntax"]
date: 2018-12-13T20:24:00Z
description: ""
draft: false
image: "https://images.unsplash.com/photo-1528660544347-95a93c58e424?ixlib=rb-1.2.1&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=2000&fit=max&ixid=eyJhcHBfaWQiOjExNzczfQ"
slug: "adding-code-syntax-highlighting-to-a-ghost-blog-with-prism-js"
tags: ["code", "ghost", "blog", "highlighting", "prism", "prismjs", "cdn", "dart", "syntax"]
title: "Adding Code Syntax Highlighting to a Ghost Blog with Prism.js"
resources:
- name: "featured-image"
  src: "featured-image.jpg"

---


[Ghost](https://ghost.org/) is an awesome and user-friendly Open-Source platform for blogging. But by default, it does not support syntax highlighting, which may not be very practical if you happen to add code snippets to your posts.

Thankfully, Ghost is very easy to customize in different ways, and one way we are going to explore here is via [Code Injection](https://blog.ghost.org/post-code-injection/), as in use throughout my own blog.

Ghost's Code Injection feature allows to add custom CSS styles and JS code to the header and footer of all or individual articles.

There are several code syntax highlighting libraries out there, such as:

* [Prism.js](https://prismjs.com/)
* [highlight.js](https://highlightjs.org/)
* [Rainbow.js](https://craig.is/making/rainbows)

They essentially almost have the same features. So no matter what you chose, the steps depicted below will be pretty much the same.

## Prism.js Code Injection

Go to **Settings > Code Injection** from the Admin menu.

Then add the CSS in the Blog Header section, and the JS files (core + all languages you wish to use) in the Blog Footer section.

![Code injection in Ghost Blog Settings](https://rm3l-org.s3-us-west-1.amazonaws.com/assets/Ghost_Blog_Code_Injection_Settings.png)

### Blog Header

```xml
<link rel="stylesheet" type="text/css" href="https://cdnjs.cloudflare.com/ajax/libs/prism/1.15.0/themes/prism.min.css"></link>
```



### Blog Footer

Here you have to first include the core library (prism.min.js), and all JS files for all individual languages you wish to have highlighting support for.

You can link to a CDN like [https://cdnjs.com/libraries/prism](https://cdnjs.com/libraries/prism) to select exactly the languages libraries you wish to have included.

For example:

```xml
<!-- Core -->
<script type="text/javascript" src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.15.0/prism.min.js"></script>

<!-- All individual language files -->
<!-- Java syntax highlighting-->
<script type="text/javascript" src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.15.0/components/prism-java.min.js"></script>
<!-- Golang syntax highlighting -->
<script type="text/javascript" src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.15.0/components/prism-go.min.js"></script>
<!-- GraphQL syntax highlighting -->
<script type="text/javascript" src="https://cdnjs.cloudflare.com/ajax/libs/prism/1.15.0/components/prism-graphql.min.js"></script>

```

Rather than manually include each individual language library, if you are able to auto-host and serve your own files, you can also head to the [Prism.js download page](https://prismjs.com/download.html), where you can  pick whatever language and download tailored JS and CSS files, which you can then include as above.



### Using Prism.js

At this point, Prism.js will be automatically activated as soon as a valid Markdown code syntax is encountered with the language specified.

Remember to use **```language** before the code snippet and **```** after to have your code block highlighted.

Example with a Dart code snippet which has to be written like this:

````
```dart
import 'dart:async';

const news = '<gathered news goes here>';
const oneSecond = Duration(seconds: 1);

// Imagine that this function is more complex and slow. :)
Future<String> gatherNewsReports() =>
    Future.delayed(oneSecond, () => news);

Future<void> printDailyNewsDigest() async {
  var newsDigest = await gatherNewsReports();
  print(newsDigest);
}

main() {
  printDailyNewsDigest();
}
```
````

This is highlighted as follows:

```dart
import 'dart:async';

const news = '<gathered news goes here>';
const oneSecond = Duration(seconds: 1);

// Imagine that this function is more complex and slow. :)
Future<String> gatherNewsReports() =>
    Future.delayed(oneSecond, () => news);

Future<void> printDailyNewsDigest() async {
  var newsDigest = await gatherNewsReports();
  print(newsDigest);
}

main() {
  printDailyNewsDigest();
}
```

Thanks for reading.

As always, your feedback and comments are more than welcome!

