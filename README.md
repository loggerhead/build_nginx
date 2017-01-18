[![Build Status](https://travis-ci.org/loggerhead/build_nginx.svg?branch=master)](https://travis-ci.org/loggerhead/build_nginx)

A static nginx binary build script running on Ubuntu/Debian.

```bash
./build.sh
mkdir -p $NGINX_LOG_DIR $NGINX_CACHE_DIR
```

# Compile with

* HTTP 2
* ngx_pagespeed
* libressl
* pcre
* file-aio
