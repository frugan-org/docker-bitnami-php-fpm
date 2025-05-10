FROM bitnami/php-fpm:8.0 as builder

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# redis, igbinary, msgpack, etc.
RUN install_packages \
        autoconf \
        build-essential \
        libzstd-dev \
        liblz4-dev \
        && pecl channel-update pecl.php.net \
        && pecl install igbinary msgpack \
        # enable igbinary serializer support? [no] : 
        # enable lzf compression support? [no] : 
        # enable zstd compression support? [no] : 
        # enable msgpack serializer support? [no] : 
        # enable lz4 compression? [no] : 
        # use system liblz4? [yes] :
        && printf "yes\nyes\nyes\nyes\nyes\nyes\n" | pecl install redis \
        && rm -rf /tmp/pear \
    ;

FROM bitnami/php-fpm:8.0

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --from=builder /opt/bitnami/php/lib/php/extensions /opt/bitnami/php/lib/php/extensions

# Latest releases available at https://github.com/aptible/supercronic/releases
ENV SUPERCRONIC_URL=https://github.com/aptible/supercronic/releases/download/v0.2.30/supercronic-linux-amd64 \
    SUPERCRONIC=supercronic-linux-amd64 \
    SUPERCRONIC_SHA1SUM=9f27ad28c5c57cd133325b2a66bba69ba2235799

RUN install_packages \
        # global
        ca-certificates \
        curl \
        file \
        # required by wp ewwwio optimize https://docs.ewww.io/article/25-optimizing-with-wp-cli
        less \
        locales \
        #FIXED "sh: 1: tput: not found" with kint-php
        ncurses-bin \
        patch \
        rsync \
        vim \
        zip \
        \
        # composer
        #https://docs.php.earth/docker/composer/
        #https://medium.com/@c.harrison/speedy-composer-installs-in-docker-builds-41eea6d0172b
        #https://blog.martinhujer.cz/17-tips-for-using-composer-efficiently/
        #https://github.com/composer/composer/issues/4892#issuecomment-328511850
        #https://getcomposer.org/doc/articles/autoloader-optimization.md
        #https://hackernoon.com/get-composer-to-run-on-docker-container-a-how-to-guide-y86g36z7
        git \
        # used in some projects with repositories -> type: svn
        subversion \
        # As there is no 'unzip' command installed zip files are being unpacked using the PHP zip extension.
        # This may cause invalid reports of corrupted archives. Besides, any UNIX permissions (e.g. executable) defined in the archives will be lost.
        # Installing 'unzip' may remediate them.
        unzip \
        \
        # Looks like sSMTP is no longer maintained, MSMTP is the suggested replacement
        msmtp \
        \
        # supercronic
        tzdata \
        && curl -fsSLO "$SUPERCRONIC_URL" \
        && echo "${SUPERCRONIC_SHA1SUM}  ${SUPERCRONIC}" | sha1sum -c - \
        && chmod +x "$SUPERCRONIC" \
        && mv "$SUPERCRONIC" "/usr/local/bin/${SUPERCRONIC}" \
        && ln -s "/usr/local/bin/${SUPERCRONIC}" /usr/local/bin/supercronic \
    ;

COPY entrypoint.sh /

#https://github.com/docker-library/postgres/issues/296#issuecomment-308735942
RUN chmod +x /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "php-fpm", "-F", "--pid", "/opt/bitnami/php/tmp/php-fpm.pid", "-y", "/opt/bitnami/php/etc/php-fpm.conf" ]
