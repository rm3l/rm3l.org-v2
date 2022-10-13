---
author: "Armel Soro"
categories: ["kubernetes", "k8s", "adguard-home", "openwrt", "ddwrt", "dd-wrt", "raspberry-pi", "rpi", "traefik"]
date: 2022-01-14T22:30:00Z
description: ""
draft: false
image: "https://images.unsplash.com/photo-1545948548-863537438416?crop=entropy&cs=tinysrgb&fit=max&fm=jpg&ixid=MnwxMTc3M3wwfDF8c2VhcmNofDk3fHx0cmFmZmljfGVufDB8fHx8MTY0MTMxNzYyNg&ixlib=rb-1.2.1&q=80&w=2000"
slug: "dns-over-https-with-adguard-home-in-k8s-behind-traefik"
summary: "Migration journey of AdGuard Home from a Raspberry Pi in a private network (backed by an OpenWRT Router) to a public Kubernetes cluster, behind a reverse proxy like Traefik."
tags: ["kubernetes", "k8s", "adguard-home", "openwrt", "ddwrt", "dd-wrt", "raspberry-pi", "rpi", "traefik"]
title: "DNS over HTTPS with AdGuard Home running in Kubernetes, behind Traefik"
resources:
- name: "featured-image"
  src: "featured-image.jpg"

---


Since several years now, my network setup at home includes an instance of [AdGuard Home](https://adguard.com/en/adguard-home/overview.html) running on a [Raspberry Pi](https://www.raspberrypi.com/), and acting as both a [DHCP](https://en.wikipedia.org/wiki/Dynamic_Host_Configuration_Protocol) and [DNS](https://en.wikipedia.org/wiki/Domain_Name_System) server for all the family devices.  AdGuard Home provides a network-wide ads and tracking blocker, while also allowing to save some bandwidth usage (and indirectly CPU / memory consumption) while browsing.

As a reminder, the Dynamic Host and Configuration Protocol (DHCP) allows to automatically assign IP addresses (from a range of addresses) and other configuration (like DNS servers) to devices joining a network. The Domain Name System (DNS) is a protocol allowing to translate human-readable domain names into IP addresses.

After experimenting with Adguard Home and other alternatives like [Pi-Hole](https://pi-hole.net/), I sticked to the former for its simplicity of use and overall resource usage.

This has been running successfully for years now in my private home network setup. So I wanted to benefit from this even on the go, regardless of the network I or any other family member is connected to.

Last year, folks at AdGuard published [a blog post](https://adguard.com/en/blog/adguard-home-on-public-server.html) on how to run and operate Adguard Home on a public server. I therefore set out to migrate AdGuard Home to a public server, ideally running in my existing Kubernetes cluster because I did not want to rent an additional server dedicated to this. Instead, running it in the existing Kubernetes cluster would allow to benefit from automated TLS certificate management already in place and leverage existing nodes.

Sure, another option could have been to set up a publicly-reachable VPN Server in the private network and instruct it to configure devices such that they use the internal AdGuard Home as DNS Server. But for learning purposes, I wanted to get my hands dirty running this in Kubernetes. And if you follow this blog, you might have noticed that I tend to like migrating things to Kubernetes.

## Current setup

Below is an overview of the network setup (10.10.10.0/24) before the migration. The Raspberry Pi running AdGuard Home is assigned a static private IP address (10.10.10.10) and is connected to a router running [OpenWRT](https://openwrt.org/) (10.10.10.254) and performing [Network Address Translation (NAT)](https://en.wikipedia.org/wiki/Network_address_translation).

![Current Network Setup with Adguard Home running locally](https://rm3l-org.s3.us-west-1.amazonaws.com/assets/cms-rm3l-org-adguardhome-migration-home-setup.png)

## Target setup

And this is what I wanted to achieve.

![Target Network Setup, with Adguard Home running in Kubernetes](https://rm3l-org.s3.us-west-1.amazonaws.com/assets/cms-rm3l-org-adguardhome-migration-target.png)

In a nutshell:

* there is no longer an AdGuard Home instance running in the private network. In fact, it would be migrated outside of the home network, in the Kubernetes cluster, but publicly reachable.
* the OpenWRT router would behave as the DHCP and DNS server for the home network, just like it used to be by default.
* the OpenWRT router would forward all DNS requests to the new AdGuard Home server.
* when outside of the home network, devices would just need to set the new AdGuard Home server as their DNS server, for name resolution. DNS Traffic should ideally be secured, via protocols like DNS over HTTPS ([DoH](https://en.wikipedia.org/wiki/DNS_over_HTTPS)) / over TLS ([DoT](https://en.wikipedia.org/wiki/DNS_over_TLS#:~:text=DNS%20over%20TLS%20(DoT)%20is,Layer%20Security%20(TLS)%20protocol.)) / over QUIC ([DoQ](https://datatracker.ietf.org/doc/draft-ietf-dprive-dnsoquic/)), which are natively supported by AdGuard Home.
* my Kubernetes Cluster (powered by [k3s](https://k3s.io/) under the hood) already includes a [Traefik Ingress Controller](https://doc.traefik.io/traefik/providers/kubernetes-ingress/), which acts as a reverse proxy for underlying services, providing [SSL/TLS Termination](https://en.wikipedia.org/wiki/TLS_termination_proxy#:~:text=A%20TLS%20termination%20proxy%20(or,decrypting%20and%2For%20encrypting%20communications.) as well. Adguard Home is no exception here, and would need to live behind Traefik, just like my other services exposed.

## Deployment in Kubernetes

At the time of writing, I found [few Helm Charts for Adguard Home](https://artifacthub.io/packages/search?ts_query_web=adguard&sort=relevance&page=1) out there, but most of them appeared to be either unmaintained or too tedious to configure properly or missing some configuration.

So I set out to create yet another Chart for Adguard Home, hopefully simpler.

A key non-functional point for me is to backup files to external service like S3, just in the event my future-self needs to restore something back. So based on the [same logic used to backup this Ghost blog](https://rm3l.org/leveraging-kubernetes-cronjobs-for-automated-backups-of-a-headless-ghost-blog-to-aws-s3/), I implemented the ability to backup the AdGuard Home configuration file to AWS S3.

This Chart is now listed on [ArtifactHub](https://artifacthub.io/packages/helm/rm3l/adguard-home), and can be used like so:

```shell
❯ helm repo add rm3l https://helm-charts.rm3l.org

❯ helm install my-adguard-home rm3l/adguard-home \
    --version <version> \
    --set backup.enabled="true" \
    --set backup.schedule="@daily" \
    --set backup.aws.enabled="true" \
    --set backup.aws.accessKeyId="my-aws-access-key-id" \
    --set backup.aws.secretKey="my-aws-secret-key" \
    --set backup.aws.s3.destination="s3://path/to/my/adguard-home-s3-export.yaml"
```

Note that there are still few options to pass at the Chart installation time, like the domain name under which you want to expose AdGuard Home. Head over to [https://github.com/rm3l/helm-charts/blob/main/charts/adguard-home/README.md](https://github.com/rm3l/helm-charts/blob/main/charts/adguard-home/README.md) for further details about the Chart configuration.

Once the Chart is deployed in the Kubernetes cluster, and provided you enabled the HTTP Ingress along with a domain name for routing, a new public endpoint should expose your AdGuard Home services over HTTPS: _https://<my_dns_domain_name>/dns-query_, for secure DNS-over-HTTPS (DoH) name resolution.

### Testing the DoH resolver

Our newly deployed DoH resolver can be tested with familiar tools like _curl_, which supports DoH since its [7.62.0 release](https://daniel.haxx.se/blog/2018/09/06/doh-in-curl/):

```shell
❯ curl --doh-url https://<my_dns_domain_name>/dns-query \
    https://facebook.com/ \
    -X OPTIONS -i
    
HTTP/2 301 
location: https://www.facebook.com/
access-control-expose-headers: X-FB-Debug, X-Loader-Length
access-control-allow-methods: OPTIONS
access-control-allow-credentials: true
access-control-allow-origin: https://facebook.com
vary: Origin
strict-transport-security: max-age=15552000; preload
content-type: text/html; charset="utf-8"
x-fb-debug: lM2W9yXZ0CopX4MP0MskmZTHduIvh9Tzb/wwJF58p+3bNBfPbrJUDsuTaH3TIdCBzZiaRy9K11tZ2N6iMYvGCQ==
content-length: 0
date: Mon, 10 Jan 2022 22:51:56 GMT
priority: u=3,i
alt-svc: h3=":443"; ma=3600, h3-29=":443"; ma=3600
```

### Notes

**Unencrypted in-cluster DNS over HTTPS**

As depicted earlier, there is already an Traefik Ingress Controller running in the Kubernetes Cluster, and acting as a reverse proxy for all the services deployed there.

At the moment, such services are externally reachable via HTTPS (via [Kubernetes Ingresses](https://kubernetes.io/docs/concepts/services-networking/ingress/) and automated [Let's Encrypt](https://letsencrypt.org/) certificate management via [cert-manager](https://cert-manager.io/docs/)).  And as far as I can tell, Kubernetes Ingress Resource handles HTTP(S) traffic only, but other protocols are expected to be supported with the newer [Gateway API](https://github.com/kubernetes-sigs/service-apis).

As a consequence, DNS protocols other than HTTP(S) will need to be exposed differently. At this stage, this is configurable, but done by default via Kubernetes Services of type [NodePort](https://kubernetes.io/docs/concepts/services-networking/service/#type-nodeport), allowing to allocate a port on every node in the cluster.

For DNS over HTTPS name resolution, it is however possible to access the Service via a Kubernetes Ingress, handled by the Traefik Ingress Controller. Since Traefik terminates TLS connections, it expects services behind it to be reachable via an unencrypted [Service](https://kubernetes.io/docs/concepts/services-networking/service/).

By default, AdGuard Home does not expose DNS over HTTPS traffic via an unencrypted connection once [encryption is enabled](https://github.com/AdguardTeam/AdGuardHome/wiki/Encryption) in its web interface. Fortunately, this behavior can be changed manually in the Configuration file, by setting the _allow_unencrypted_doh_ configuration property to _true_, as done in the [Helm Chart default values](https://github.com/rm3l/helm-charts/blob/main/charts/adguard-home/values.yaml#L281). More info in the [official FAQ](https://github.com/AdguardTeam/AdGuardHome/wiki/FAQ#disable-doh-encryption-on-adguard-home).

**Preventing potential attacks**

Exposing a public DNS server might be dangerous from the security standpoint, especially when this DNS server is also a critical service in the private network at home.

To alleviate a potential misuse of this resolver, Adguard Home ships anti-DNS amplication features via rate limiting options and options to restrict incoming traffic to trusted networks. These can be configured under **AdGuard Home > Settings > DNS Settings**.

What I did besides this is disable the plain DNS protocol (on port 53) and other protocols I do not need, and use only DNS over HTTPS, since this is the only way I want Adguard Home to be reachable from the outside. This should hopefully mitigate potential DNS spoofing and amplification attacks.

This behavior is configurable by disabling the unused services in the [Helm Chart values.yaml](https://github.com/rm3l/helm-charts/blob/main/charts/adguard-home/values.yaml#L43-L70) file.

## Clients Configuration

At home, the DNS resolver is configured in my router (running OpenWRT), to avoid having to configure each device individually. You may also be able to do so if you are using a different router.

### OpenWRT Router

I make use at home of a [Linksys WRT1900ACS](https://www.linksys.com/au/wireless-routers/wrt-wireless-routers/linksys-wrt1900acs-dual-band-wifi-router-with-ultra-fast-1-6-ghz-cpu/p/p-wrt1900acs/) wireless router, on which I installed [OpenWRT](https://openwrt.org/). I like the idea of open-source operating systems like [DD-WRT](https://dd-wrt.com/) or OpenWRT for embedded devices. This is the reason why I even publish and maintain a popular Android application for managing and monitoring routers running DD-WRT (and OpenWRT to some extent): [DD-WRT Companion](https://ddwrt-companion.app/).

To make an OpenWRT router forward all incoming (plain) DNS requests to a DNS-over-HTTPS (DoH) resolver, we can SSH into the router, install the _https-dns-proxy_ package and configure the DoH resolver accordingly:

```shell
# Install packages
opkg update
opkg install https-dns-proxy

# This adds a menu in the web interface
opkg install luci-app-https-dns-proxy

# Clean-up all existing entries and recreate a single entry with
# the right DoH resolver
while uci -q delete https-dns-proxy.@https-dns-proxy[0]; do :; done

uci set https-dns-proxy.dns="https-dns-proxy"

# A bootstrap DNS allows to resolve the DoH resolver name
uci set https-dns-proxy.dns.bootstrap_dns="1.1.1.1,1.0.0.1"
uci set https-dns-proxy.dns.resolver_url="https://<my_dns_domain_name>/dns-query"
uci set https-dns-proxy.dns.listen_addr="127.0.0.1"
uci set https-dns-proxy.dns.listen_port="5053"

# Commit the changes
uci commit https-dns-proxy

# Restart the DNS Proxy
/etc/init.d/https-dns-proxy restart


```

Once restarted, we can see in the OpenWRT web interface (Services > HTTPS DNS Proxy). Unfortunately, the custom values set manually in the command line will not be displayed. This is perhaps a bug in the interface package, which I will try to investigate later on when I get a chance.

![Overview of the HTTPS DNS Proxy configuration in OpenWRT LuCI](https://rm3l-org.s3.us-west-1.amazonaws.com/assets/openwrt-luci-overview-https-dns-proxy.png)

### External Devices

The process for configuring devices is documented here: [https://github.com/AdguardTeam/AdGuardHome/wiki/Encryption#configure-devices](https://github.com/AdguardTeam/AdGuardHome/wiki/Encryption#configure-devices)

Personally, I'm making use of the Open-Source [Intra](https://github.com/Jigsaw-Code/intra) application on Android devices (until they natively support DNS over HTTPS, which is [reportedly expected in Android 13](https://www.xda-developers.com/android-13-tiramisu-support-dns-over-https/)). It is also possible to directly configure browsers like [Chromium](https://blog.chromium.org/2020/05/a-safer-and-more-private-browsing-DoH.html) and [Firefox](https://support.mozilla.org/en-US/kb/firefox-dns-over-https) since they both support secure DNS over HTTPS.

## Results

It's been a few weeks now since Adguard Home has been migrated to Kubernetes and running, and I am quite happy with the result.

![Overview of Adguard Home in K8s](https://rm3l-org.s3.us-west-1.amazonaws.com/assets/adguard_home_in_k8s_overview.png)

However, as we can see from the screen capture above, there is one caveat worth mentioning: the client IP and hostname seen by Adguard Home is the one of Traefik, the reverse proxy. This should ideally represent the ones of each client connecting to the DNS resolver, so as to make the most of Adguard Home (like advanced query logs or the ability to block clients on an individual basis).

This is what I plan to investigate in a near future: [source IP preservation](https://kubernetes.io/docs/tutorials/services/source-ip/).

Thanks for reading thus far, and stay tuned for other posts.

As usual, feel free to share your thoughts in the comments below.

