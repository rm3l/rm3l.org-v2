+++
author = "Armel Soro"
date = 2018-09-20T20:18:47Z
description = ""
draft = true
slug = "draft-ghost-blog-add-permanent-redirection-with-nginx"
title = "[Draft] Ghost blog - add permanent redirection with Nginx"

+++


server {
    listen 80;
    server_name ddwrt-companion.rm3l.org;
    location / {
        return 301 https://ddwrt-companion.app;
    }
}

server {
    listen 80;
    server_name help.ddwrt-companion.rm3l.org;
    location / {
        return 301 https://help.ddwrt-companion.app;
    }  
}

