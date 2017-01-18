#!/bin/bash

# stop on first error
set -e

# names of latest versions of each package
NGINX_VERSION=1.11.6
NPS_VERSION=1.11.33.4
VERSION_PCRE=pcre-8.40
VERSION_NGINX=nginx-$NGINX_VERSION
VERSION_LIBRESSL=libressl-2.4.4
VERSION_PAGESPEED=release-${NPS_VERSION}-beta
PAGESPEED_DIRNAME=ngx_pagespeed-${VERSION_PAGESPEED}

# URLs to the source directories
SOURCE_PCRE=http://ftp.cs.stanford.edu/pub/exim/pcre
SOURCE_NGINX=http://nginx.org/download
SOURCE_LIBRESSL=http://ftp.openbsd.org/pub/OpenBSD/LibreSSL
SOURCE_PAGESPEED=https://github.com/pagespeed/ngx_pagespeed/archive

# set where LibreSSL and nginx will be built
DOWNLOAD_LIST=packages_list.txt
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
BPATH=$DIR/build
STATICLIBSSL=$BPATH/$VERSION_LIBRESSL

# clean out previous compile result
if [ -d "$BPATH" ]; then
    rm -rf $BPATH
fi
mkdir -p $BPATH
cd $BPATH

echo "Downloading sources..."
echo -n > $DOWNLOAD_LIST
echo $SOURCE_PCRE/$VERSION_PCRE.tar.gz           >> $DOWNLOAD_LIST
echo $SOURCE_NGINX/$VERSION_NGINX.tar.gz         >> $DOWNLOAD_LIST
echo $SOURCE_LIBRESSL/$VERSION_LIBRESSL.tar.gz   >> $DOWNLOAD_LIST
echo $SOURCE_PAGESPEED/$VERSION_PAGESPEED.tar.gz >> $DOWNLOAD_LIST
aria2c -q -c -j20 -Z -i $DOWNLOAD_LIST
echo "Extracting Packages..."
tar xzf $VERSION_PCRE.tar.gz
tar xzf $VERSION_NGINX.tar.gz
tar xzf $VERSION_LIBRESSL.tar.gz

tar xzf $PAGESPEED_DIRNAME.tar.gz
cd $PAGESPEED_DIRNAME
aria2c -q -c https://dl.google.com/dl/page-speed/psol/${NPS_VERSION}.tar.gz
tar xzf ${NPS_VERSION}.tar.gz
cd $BPATH/../

# build static LibreSSL
echo "Configure & Building LibreSSL..."
cd $STATICLIBSSL
./configure LDFLAGS=-lrt --prefix=${STATICLIBSSL}/.openssl/ \
&& make -s -j $(nproc) install-strip

# build nginx, with various modules included/excluded
echo "Configure & Building Nginx..."
cd $BPATH/$VERSION_NGINX
export NGX_LOG_DIR=/var/log/nginx
export NGX_RUN_DIR=/var/log/nginx
export NGX_CACHE_DIR=/var/cache/nginx

CC_OPT="-O2 -static"
LD_OPT="-static"

if [ "$CC" != "clang" ]; then
    CC_OPT="$CC_OPT -static-libgcc"
fi

./configure --with-openssl=$STATICLIBSSL \
            --with-cc-opt="$CC_OPT" \
            --with-ld-opt="$LD_OPT" \
            --prefix=/etc/nginx \
            --sbin-path=/usr/sbin/nginx \
            --conf-path=/etc/nginx/nginx.conf \
            --error-log-path=$NGX_LOG_DIR/error.log \
            --http-log-path=$NGX_LOG_DIR/access.log \
            --pid-path=$NGX_RUN_DIR/nginx.pid \
            --lock-path=$NGX_RUN_DIR/nginx.lock \
            --http-client-body-temp-path=$NGX_CACHE_DIR/client_temp \
            --http-proxy-temp-path=$NGX_CACHE_DIR/proxy_temp \
            --http-fastcgi-temp-path=$NGINX_CACHE_DIR/fastcgi_temp \
            --http-uwsgi-temp-path=$NGINX_CACHE_DIR/uwsgi_temp \
            --http-scgi-temp-path=$NGINX_CACHE_DIR/scgi_temp \
            --user=nobody \
            --group=nobody \
            --without-mail_pop3_module \
            --without-mail_smtp_module \
            --without-mail_imap_module \
            --with-ipv6 \
            --with-http_v2_module \
            --with-http_ssl_module \
            --with-http_stub_status_module \
            --with-http_realip_module \
            --with-http_auth_request_module \
            --with-http_addition_module \
            --with-http_gzip_static_module \
            --with-file-aio \
            --with-pcre-jit \
            --with-pcre=$BPATH/$VERSION_PCRE \
            --add-module=$BPATH/$PAGESPEED_DIRNAME

touch $STATICLIBSSL/.openssl/include/openssl/ssl.h
echo "compiling static nginx file..."
make -s -j $(nproc)

cd objs
./nginx -v
tar zcf $HOME/nginx.tar.gz nginx

echo "Run following command if you need run nginx in another PC:"
echo
echo "    mkdir -p $NGX_LOG_DIR $NGX_CACHE_DIR"
