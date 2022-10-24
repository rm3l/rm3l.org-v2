---
author: "Armel Soro"
categories: ["Blogs"]
date: 2020-10-16T20:20:00Z
description: ""
draft: false
image: "https://images.unsplash.com/photo-1517190525944-4edce215bc4a?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=MXwxMTc3M3wwfDF8c2VhcmNofDExNnx8fGVufDB8fHw&ixlib=rb-1.2.1&q=80&w=2000"
slug: "creating-a-mid-circle-radial-gauge-in-flutter"
summary: "This blog post walks through building a simple and animated mid-circle radial gauge widget in Flutter."
tags: ["flutter", "gauge", "animation", "dart", "android"]
title: "Creating a mid-circle animated radial gauge in Flutter"
resources:
- name: "featured-image"
  src: "featured-image.jpg"
---


It's been almost 2 years now since I first heard about the [Flutter](https://flutter.dev/) Software Development Kit (SDK) and, since then, I never stopped exploring its capabilities by using it in [some of my side project apps](https://rm3l.org/portfolio#flutter).

Unlike native app development that I used to do (mainly [on Android](https://rm3l.org/portfolio#android)) in the past, I found Flutter-based app development to be more straightforward and enjoyable. I enjoyed leveraging [Flutter](https://flutter.dev/) and [Dart](https://dart.dev/) for building high-performance cross-platform apps that render beautifully, despite being easy to fall into the [Widget Hell](https://github.com/flutter/flutter/issues/12706) trap and end up with quite hard-to-read-and-maintain code.

This post will not cover Flutter in general since there is already a lot of material out there about the ins and outs of Flutter. It assumes you have a basic understanding of [how to write a Flutter app](https://flutter.dev/docs/get-started/codelab). Instead, I wanted to shed light on how I recently implemented a simple mid-circle radial gauge widget for a friend of mine who needed to display a nice and animated progress bar, as illustrated in the GIF image just below.

<img alt="Mid-circle Radial Gauge Demo with Flutter" src="https://rm3l-org.s3-us-west-1.amazonaws.com/assets/flutter_radial_gauge_demo.gif" style="width: 360px; height:800px" />

## Implementing the radial gauge

Flutter already provides a bunch of widgets that cater to most needs. For example, we have widgets for building a [circular progress indicator](__GHOST_URL__/p/37bc1f3e-51a4-48d2-9496-fbbf1a02057c/CircularProgressIndicator). For cases not covered by a built-in widget or [community packages](https://pub.dev/), we can always resort to a [CustomPainter](https://api.flutter.dev/flutter/rendering/CustomPainter-class.html) for drawing custom shapes to a [Canvas](https://api.flutter.dev/flutter/dart-ui/Canvas-class.html).

So here is the code for the initial version of the gauge. This is a [Stateless Widget](https://api.flutter.dev/flutter/widgets/StatelessWidget-class.html) that renders a static progress bar, which we will animate in the next sections.

```dart
import 'package:flutter/material.dart';

class MyCustomRadialGauge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final maxValue = 1700;
    final current = 1234.5;

    return CustomPaint(
      foregroundPainter: _MyCustomRadialGaugePainter(maxValue, current),
      child: Container(
        padding: EdgeInsets.only(top: screenHeight * 0.0875),
        width: screenWidth * 0.34,
        child: Center(
          child: Column(
            children: [
              Container(
                height: screenHeight * 0.01,
                color: Colors.transparent,
              ),
              Text(
                '${(100 * current / maxValue).toStringAsFixed(0)}%',
                style: TextStyle(color: Colors.grey, fontSize: 50.0),
              ),
              Container(
                height: screenHeight * 0.027,
                color: Colors.transparent,
              ),
              Container(
                  height: screenHeight * 0.04,
                  child: Text('Title', style: TextStyle(fontSize: 22.0)))
            ],
          ),
        ),
      ),
    );
  }
}
```

As we can see, the widget itself builds a [CustomPaint](https://api.flutter.dev/flutter/widgets/CustomPaint-class.html) parent widget that provides a Canvas on which our sub-class of CustomPainter will paint our custom gauge. This parent widget also contains the Text content centered within the Canvas.

And our custom painter looks like this:

```dart
class _MyCustomRadialGaugePainter extends CustomPainter {
  final num maxValue;
  final num current;

  _MyCustomRadialGaugePainter(this.maxValue, this.current);

  @override
  void paint(Canvas canvas, Size size) {
    final complete = Paint()
      ..color = Colors.blue
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13.0;

    final line = Paint()
      ..color = const Color(0xFFE9E9E9)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = 13.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height);

    final startAngle = -7 * pi / 6;
    final sweepAngle = 4 * pi / 3;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle,
        sweepAngle, false, line);

    final arcAngle = (sweepAngle) * (current / maxValue);
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle,
        arcAngle, false, complete);

    final lowerBoundText = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(text: '0', style: TextStyle(color: Colors.grey))
      ..layout(minWidth: 0, maxWidth: double.maxFinite);
    lowerBoundText.paint(
        canvas, Offset(-size.width * 0.42, size.height / 1.22));

    final upperBoundText = TextPainter(textDirection: TextDirection.ltr)
      ..text = TextSpan(text: '$maxValue', style: TextStyle(color: Colors.grey))
      ..layout(minWidth: 0, maxWidth: double.maxFinite);
    upperBoundText.paint(canvas, Offset(size.width / 0.77, size.height / 1.22));
  }

  @override
  bool shouldRepaint(_MyCustomRadialGaugePainter oldDelegate) => false;
}
```

What's noteworthy here is that we are supplied with a Canvas object, along with its Size. Even if this may seem low-level, it remains nonetheless interesting as we have limitless possibilities for drawing custom shapes. And, as the saying goes: _with great power comes great responsibility_.

Another interesting line here is the following call:

```dart
canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
  startAngle, sweepAngle, false, line);
```

Starting from the center of the canvas size, we are instructing Flutter to draw an Arc bound within a defined Rectangle and with the specified angle constraints. This arc, which starts from _startAngle_ radians up to _startAngle + sweepAngle_ radians, is scaled to fit inside the given rectangle.

![Flutter Custom Painter Illustration With Radial Gauge](https://rm3l-org.s3-us-west-1.amazonaws.com/assets/Flutter_Radial_Gauge_Custom_Painter_Illustration.png)

After that, we included lower and upper bound texts at their respected positions (offsets from the origin).

## Animating the gauge

The [Animation](https://api.flutter.dev/flutter/animation/Animation-class.html) class is the building block object for animating widgets in Flutter. An Animation object can be defined from a [Tween](https://api.flutter.dev/flutter/animation/Tween-class.html) object, which defines interpolation from a start and an end value. And on top of an Animation object, we can use an [AnimationController](https://api.flutter.dev/flutter/animation/AnimationController-class.html) for managing the former.

Below is the diff for animating the static gauge from the previous sections:

```diff
--- a/lib/gauge.dart
+++ b/lib/gauge.dart
@@ -2,7 +2,37 @@ import 'dart:math';
 
 import 'package:flutter/material.dart';
 
-class MyCustomRadialGauge extends StatelessWidget {
+class MyCustomRadialGauge extends StatefulWidget {
+  @override
+  _MyCustomRadialGaugeState createState() => _MyCustomRadialGaugeState();
+}
+
+class _MyCustomRadialGaugeState extends State<MyCustomRadialGauge>
+    with SingleTickerProviderStateMixin {
+  Animation<double> _animation;
+  AnimationController _controller;
+  double _fraction = 0.0;
+
+  @override
+  void initState() {
+    super.initState();
+    _controller = AnimationController(
+        duration: const Duration(milliseconds: 1000), vsync: this);
+    _animation = Tween(begin: 0.0, end: 1.0).animate(_controller)
+      ..addListener(() {
+        setState(() {
+          _fraction = _animation.value;
+        });
+      });
+    _controller.forward();
+  }
+
+  @override
+  void dispose() {
+    _controller.dispose();
+    super.dispose();
+  }
+
   @override
   Widget build(BuildContext context) {
     final screenWidth = MediaQuery.of(context).size.width;
@@ -12,7 +42,8 @@ class MyCustomRadialGauge extends StatelessWidget {
     final current = 1234.5;
 
     return CustomPaint(
-      foregroundPainter: _MyCustomRadialGaugePainter(maxValue, current),
+      foregroundPainter:
+          _MyCustomRadialGaugePainter(_fraction, maxValue, current),
       child: Container(
         padding: EdgeInsets.only(top: screenHeight * 0.0875),
         width: screenWidth * 0.34,
@@ -46,7 +77,9 @@ class _MyCustomRadialGaugePainter extends CustomPainter {
   final num maxValue;
   final num current;
 
-  _MyCustomRadialGaugePainter(this.maxValue, this.current);
+  double _fraction;
+
+  _MyCustomRadialGaugePainter(this._fraction, this.maxValue, this.current);
 
   @override
   void paint(Canvas canvas, Size size) {
@@ -64,15 +97,15 @@ class _MyCustomRadialGaugePainter extends CustomPainter {
     final center = Offset(size.width / 2, size.height / 2);
     final radius = min(size.width, size.height);
 
     final startAngle = -7 * pi / 6;
     final sweepAngle = 4 * pi / 3;
 
     canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle,
         sweepAngle, false, line);
 
     final arcAngle = (sweepAngle) * (current / maxValue);
     canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle,
-        arcAngle, false, complete);
+        arcAngle * _fraction, false, complete);
 
     final lowerBoundText = TextPainter(textDirection: TextDirection.ltr)
       ..text = TextSpan(text: '0', style: TextStyle(color: Colors.grey))
@@ -87,5 +120,6 @@ class _MyCustomRadialGaugePainter extends CustomPainter {
   }
 
   @override
-  bool shouldRepaint(_MyCustomRadialGaugePainter oldDelegate) => false;
+  bool shouldRepaint(_MyCustomRadialGaugePainter oldDelegate) =>
+      oldDelegate._fraction != _fraction;
 }

```

In a nutshell, here is what we are doing:

* switching from a [StatelessWidget](https://api.flutter.dev/flutter/widgets/StatelessWidget-class.html) to a [StatefulWidget](https://api.flutter.dev/flutter/widgets/StatefulWidget-class.html) (because an Animation has a state, and we need some state to animate the widget from a previous progress value to another) with the [SingleTickerProviderStateMixin](https://api.flutter.dev/flutter/widgets/SingleTickerProviderStateMixin-mixin.html) mixin. As a reminder, [mixins](https://dart.dev/guides/language/language-tour#adding-features-to-a-class-mixins) are a [Dart](https://dart.dev/) language feature that are very helpful when we want to share a behavior across multiple classes that don’t share the same class hierarchy, or when it does not make sense to implement such behavior in a super-class. It is a way of re-using code without inheritance.
* As the name suggests, a [SingleTickerProviderStateMixin](https://api.flutter.dev/flutter/widgets/SingleTickerProviderStateMixin-mixin.html) is required when we have only one AnimationController. It is in charge of providing the refresh rate (also known as Ticker) to our animation.
* We listen to animation interpolation values, so as to set a __fraction_ attribute in the widget state. This attribute provides a multiplicative factor for computing subsequent values for the sweep angle, up to the target angle.
* In the last _shouldRepaint_ method, we force-repaint the widget whenever the previous __fraction_ value changes, which is the case via the Animation Listener.

## Conclusion

That's it for today. Throughout this post, we walked through building a simple and animated mid-circle radial gauge with the excellent Flutter SDK.

For reference, the complete code for this gauge widget is available here: [Gist://rm3l/mid_circle_radial_gauge.dart](https://gist.github.com/rm3l/50d608c3595207dc134545ead0101bcc)

And, as always, any feedback on this is more than welcome.





