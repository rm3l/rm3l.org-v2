+++
author = "Armel Soro"
date = 2020-08-02T17:51:43Z
description = ""
draft = true
slug = "operating-multiple-openvpn-servers-in-kubernetes"
title = "Operating multiple OpenVPN service in Kubernetes"

+++


cf. [https://github.com/suda/k8s-ovpn-chart](https://github.com/suda/k8s-ovpn-chart)

helm repo add k8s-ovpn [https://raw.githubusercontent.com/suda/k8s-ovpn-chart/master](https://raw.githubusercontent.com/suda/k8s-ovpn-chart/master)

helm repo update

kubectl create namespace openvpn

helm upgrade --install ovpn-canada --namespace openvpn-canada k8s-ovpn/k8s-ovpn-chart --values values.yml



