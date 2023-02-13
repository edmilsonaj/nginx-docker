FROM nginx:alpine AS builder

# Nginx HTTP Cache Purge version
ENV NGX_CACHE_PURGE_VERSION 2.5.2
ENV NGX_FANCY_INDEX_VERSION 0.5.2

# Download sources
RUN wget "https://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz" -O nginx.tar.gz && \
    wget "https://github.com/nginx-modules/ngx_cache_purge/archive/${NGX_CACHE_PURGE_VERSION}.tar.gz" -O ngx_http_cache_purge_module.tar.gz && \
    wget "https://github.com/aperezdc/ngx-fancyindex/archive/v${NGX_FANCY_INDEX_VERSION}.tar.gz" -O ngx_http_fancyindex_module.tar.gz


# For latest build deps, see https://github.com/nginxinc/docker-nginx/blob/master/mainline/alpine/Dockerfile
RUN apk add --no-cache --virtual .build-deps \
    gcc \
    libc-dev \
    make \
    openssl-dev \
    pcre-dev \
    zlib-dev \
    linux-headers \
    libxslt-dev \
    gd-dev \
    geoip-dev \
    perl-dev \
    libedit-dev \
    mercurial \
    bash \
    alpine-sdk \
    findutils

SHELL ["/bin/ash", "-eo", "pipefail", "-c"]

RUN rm -rf /usr/src/nginx && mkdir -p /usr/src/nginx && \
    rm -rf /usr/src/ngx_http_cache_purge_module && mkdir -p /usr/src/ngx_http_cache_purge_module && \
    rm -rf /usr/src/ngx_http_fancyindex_module && mkdir -p /usr/src/ngx_http_fancyindex_module && \
    tar -zxC /usr/src/nginx -f nginx.tar.gz && \
    tar -xzC /usr/src/ngx_http_cache_purge_module -f ngx_http_cache_purge_module.tar.gz && \
    tar -xzC /usr/src/ngx_http_fancyindex_module -f ngx_http_fancyindex_module.tar.gz

WORKDIR /usr/src/nginx/nginx-${NGINX_VERSION}

# Reuse same cli arguments as the nginx:alpine image used to build
RUN CONFARGS=$(nginx -V 2>&1 | sed -n -e 's/^.*arguments: //p') && \
    CACHEPURGEARGS="--add-dynamic-module=/usr/src/ngx_http_cache_purge_module/*" && \
    FANCYINDEXARGS="--add-dynamic-module=/usr/src/ngx_http_fancyindex_module/*" && \
    sh -c "./configure --with-compat $CONFARGS $CACHEPURGEARGS $FANCYINDEXARGS" && \
    make modules

# Production container starts here
FROM nginx:alpine
COPY --from=builder /usr/src/nginx/nginx-${NGINX_VERSION}/objs/*_module.so /etc/nginx/modules/