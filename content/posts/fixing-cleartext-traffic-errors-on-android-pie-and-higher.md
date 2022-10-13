+++
author = "Armel Soro"
categories = ["android", "aosp", "network", "http", "https", "security", "apps", "mobile"]
date = 2019-03-21T22:32:00Z
description = ""
draft = false
image = "https://images.unsplash.com/photo-1535378273068-9bb67d5beacd?ixlib=rb-1.2.1&q=80&fm=jpg&crop=entropy&cs=tinysrgb&w=2000&fit=max&ixid=eyJhcHBfaWQiOjExNzczfQ"
slug = "fixing-cleartext-traffic-errors-on-android-pie-and-higher"
summary = "This blog post covers different strategies to fix Cleartext Traffic errors in Android Pie 9.0 and beyond."
tags = ["android", "aosp", "network", "http", "https", "security", "apps", "mobile"]
title = "Fixing Cleartext Traffic Errors in Android Pie 9.0 and higher"

+++


It's been a couple of months now since Android Pie 9.0 was released, on August 2018. And, per the official [distribution dashboard](https://developer.android.com/about/dashboards), over 10% of devices run this version at this time. Anyways, it is always a good idea to have your apps target the latest release.

When I tried upgrading my apps to Android Pie, I came across the error below due to a behavior change aiming at improving security defaults:

```
Cleartext HTTP traffic to ... not permitted
```

Before Android Pie, apps could communicate with remote servers over unencrypted protocols, such as HTTP, which could easily be eavesdropped or liable to a wide range of  attacks.

Android Pie 9.0 and higher enforce the use of secure traffic in apps by default, unless developers really really do need to use Cleartext (which, again, is strongly discouraged). In such cases, the error above can be fixed using any of the approaches depicted below:

* Obviously, the best option is to only communicate using a secure protocol, such as HTTPS. This implies configuring your remote servers to use such secure connections, if possible. A lot of solutions exist out there to that end, such as [Let's Encrypt](https://letsencrypt.org/), [Caddy](https://caddyserver.com/) or [CertMagic](https://github.com/mholt/certmagic), just to name a few.
* Altering the default behavior by authorizing Cleartext traffic throughout the entire app, at the risk of exposing your app to potential data integrity issues.

To do so, you need to update your _AndroidManifest.xml_, by including the "_usesCleartextTraffic_" attribute:

```xml
<application
    android:name=".MyApplication"
    android:usesCleartextTraffic="true"
    ...>
    ...
</application>
```

* A better alternative is to leverage an explicit [network security configuration](https://developer.android.com/training/articles/security-config) file, which allows you to selectively define the domains against which the app is authorized to communicate over Cleartext traffic, on a case by case basis.

To do so, you need to first create a new XML file under _src/main/res/xml_ (say _network_security_config.xml_), with the "_cleartextTrafficPermitted_" attribute set to true for the domain of interest. For example:

```xml
<network-security-config xmlns:tools="http://schemas.android.com/tools">
    <base-config cleartextTrafficPermitted="false"/>
    <domain-config cleartextTrafficPermitted="true">
        <domain includeSubdomains="true">my_domain_without_https.com</domain>
        <domain includeSubdomains="false">my_other_domain_without_https.com</domain>
    </domain-config>
</network-security-config>
```

Then update your _AndroidManifest.xml_ to point to that file, using the "_networkSecurityConfig_" attribute:

```xml
<application
    android:name=".MyApplication"
    android:networkSecurityConfig="@xml/network_security_config"
    ...>
    ...
</application>
```

Note that, as far as I can tell, it is not yet possible at this time to programmatically configure domains in such network security configuration file.

