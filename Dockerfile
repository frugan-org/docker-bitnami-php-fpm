#https://docs.bitnami.com/bch/apps/wordpress/configuration/install-modules-php/
#https://blog.armesto.net/i-didnt-know-you-could-do-that-with-a-dockerfile/

ARG PHP_TAG

FROM bitnami/php-fpm:${PHP_TAG:-latest}

RUN install_packages \
        patch \
        rsync \
        vim \
    ;


ARG ENV

#https://jtreminio.com/blog/running-docker-containers-as-current-host-user/#ok-so-what-actually-works
ARG USER_ID
ARG GROUP_ID

RUN if [ ${USER_ID:-0} -ne 0 ] && [ ${GROUP_ID:-0} -ne 0 ]; then \
        userdel -f daemon; \
        if getent group daemon; then \
            groupdel daemon; \
        fi; \
        groupadd -g ${GROUP_ID} daemon; \
        useradd -l -u ${USER_ID} -g daemon daemon; \
        install -d -m 0755 -o daemon -g daemon /home/daemon; \
        #chown --changes --silent --no-dereference --recursive --from=33:33 ${USER_ID}:${GROUP_ID} \
        #    /home/daemon \
        #    /.composer \
        #    /var/run/php-fpm \
        #    /var/lib/php/sessions \
        #; \
    fi


#https://medium.com/@tomahock/passing-system-environment-variables-to-php-fpm-when-using-nginx-a70045370fad
#https://stackoverflow.com/a/58067682
#https://stackoverflow.com/a/30822781
#https://wordpress.stackexchange.com/a/286098/99214
RUN set -ex; \
    { \
        echo ''; \
        echo 'env[ENV] = $ENV'; \
    } >> /opt/bitnami/php/etc/environment.conf; \
    \
    if [ "${ENV}" = "develop" ]; then \
	    { \
	        echo 'user_ini.filename = ".user-'"${ENV}"'.ini"'; \
	        echo 'user_ini.cache_ttl = 0'; \
	    } >> /opt/bitnami/php/etc/php.ini; \
	fi; \
	\
	#https://make.wordpress.org/hosting/handbook/handbook/server-environment/#php-extensions
    { \
        echo 'extension=apcu.so'; \
        #echo 'extension=imap.so'; \
        #echo 'extension=maxminddb.so'; \
        # W3TC
        echo 'extension=memcached.so'; \
        #echo 'extension=newrelic.so'; \
        #echo 'extension=opcache.so'; \
        #echo 'extension=pdo_dblib.so'; \
        #echo 'extension=pdo_pgsql.so'; \
        #echo 'extension=pgsql.so'; \
    } | tee -a /opt/bitnami/php/etc/php.ini;


#### ImageMagick
#https://github.com/bitnami/bitnami-docker-php-fpm/issues/121
#https://community.bitnami.com/t/imagemagick-is-not-installed/70980/3

RUN install_packages \
        # Runtime requirements for ImageMagick PHP extension.
        fontconfig-config \
        fonts-dejavu-core \
        imagemagick-6-common \
        libfftw3-double3 \
        libfontconfig1 \
        libglib2.0-0 \
        libgomp1 \
        libjbig0 \
        liblcms2-2 \
        liblqr-1-0 \
        libltdl7 \
        libmagickcore-6.q16-6 \
        libmagickwand-6.q16-6 \
        libopenjp2-7 \
        libtiff5 \
        libx11-6 \
        libx11-data \
        libxau6 \
        libxcb1 \
        libxdmcp6 \
        libxext6 \
        unzip \
        \
        # Compile-time requirements for ImageMagick PHP extension.
        autoconf \
        gcc \
        libc-dev \
        libmagickwand-dev \
        make \
        pkg-config \
    ; \
    \
    # Install imagick php extension and enable it
    # At one point in the installer, a default value should be used, which
    # requires the user to press enter the echo simulates this interaction
    pecl channel-update pecl.php.net; \
    pecl install imagick; \
    \
    echo "extension=imagick.so" > /opt/bitnami/php/etc/conf.d/imagemagick.ini; \
    \
    echo "[www]\nenv[MAGICK_CODER_MODULE_PATH]='/usr/lib/x86_64-linux-gnu/ImageMagick-6.9.10/modules-Q16/coders'" > /opt/bitnami/php/etc/php-fpm.d/imagemagick.conf; \
    \
    # remove stuff which is only required for installation of ImageMagick
    apt-get -y remove --auto-remove \
        autoconf \
        gcc \
        libc-dev \
        libmagickwand-dev \
        make \
        pkg-config \
    ; \
    rm -rf /usr/include/*; \
    rm -rf /tmp/*;


#### composer
#https://docs.php.earth/docker/composer/
#https://medium.com/@c.harrison/speedy-composer-installs-in-docker-builds-41eea6d0172b
#https://blog.martinhujer.cz/17-tips-for-using-composer-efficiently/
#https://github.com/composer/composer/issues/4892#issuecomment-328511850
#https://getcomposer.org/doc/articles/autoloader-optimization.md
#https://hackernoon.com/get-composer-to-run-on-docker-container-a-how-to-guide-y86g36z7

ARG PHP_COMPOSER_PATH
ARG PHP_COMPOSER_VERSION

RUN if [ ! -z "${PHP_COMPOSER_PATH}" ]; then \
        set -ex; \
        install_packages \
	        ca-certificates \
	        curl \
	        git \
            # As there is no 'unzip' command installed zip files are being unpacked using the PHP zip extension.
            # This may cause invalid reports of corrupted archives. Besides, any UNIX permissions (e.g. executable) defined in the archives will be lost.
            # Installing 'unzip' may remediate them.
            unzip \
        ; \
        if [ ! -z "${PHP_COMPOSER_VERSION}" ]; then \
            curl -sS https://getcomposer.org/installer | php -- \
                --install-dir=/usr/local/bin \
                --filename=composer \
                --version=${PHP_COMPOSER_VERSION} \
            ; \
        else \
            curl -sS https://getcomposer.org/installer | php -- \
                --install-dir=/usr/local/bin \
                --filename=composer \
            ; \
        fi; \
        rm -Rf ~/.composer; \
    fi


#### wp-cli
#https://wp-cli.org/it/#installazione
#https://github.com/tatemz/docker-wpcli/blob/master/Dockerfile

ARG PHP_WP_CLI_ENABLED

RUN if [ ! -z "${PHP_WP_CLI_ENABLED}" ]; then \
        set -ex; \
        curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar; \
        chmod +x /usr/local/bin/wp; \
	fi


#### mailhog

ARG MAILHOG_VERSION

RUN if [ "${ENV}" = "develop" ]; then \
        set -eux; \
        install_packages \
            ca-certificates \
            curl \
        ; \
        curl --location --output /usr/local/bin/mhsendmail https://github.com/mailhog/mhsendmail/releases/download/v${MAILHOG_VERSION}/mhsendmail_linux_amd64; \
        chmod +x /usr/local/bin/mhsendmail; \
        #https://github.com/swiftmailer/swiftmailer/issues/633
        echo 'sendmail_path="/usr/local/bin/mhsendmail --smtp-addr=mailhog:1025 -f noreply@localhost"' > /opt/bitnami/php/etc/conf.d/mailhog.ini; \
    fi


#### newrelic
#https://docs.newrelic.com/docs/agents/php-agent/advanced-installation/install-php-agent-docker

ARG NEWRELIC_VERSION
ARG NEWRELIC_LICENSE_KEY
ARG NEWRELIC_APPLICATION_NAME

#https://stackoverflow.com/a/584926/3929620
RUN if [ ! -z "${NEWRELIC_LICENSE_KEY}" ]; then \
        #https://stackoverflow.com/a/53935189/3929620
        #https://superuser.com/a/442395
        #https://curl.haxx.se/mail/archive-2018-02/0027.html
        #https://stackoverflow.com/a/56503723/3929620
        #https://superuser.com/a/657174
        #https://superuser.com/a/590170
        #https://superuser.com/a/1249678
        #https://superuser.com/a/742421
        CURL_OUTPUT=$(curl --head --silent --location --connect-timeout 10 --write-out "%{http_code}" --output /dev/null --show-error --fail https://download.newrelic.com/php_agent/release/newrelic-php5-${NEWRELIC_VERSION}-linux.tar.gz); \
        if [ ${CURL_OUTPUT} -eq 200 ]; then \
	        curl -L https://download.newrelic.com/php_agent/release/newrelic-php5-${NEWRELIC_VERSION}-linux.tar.gz | tar -C /tmp -zx && \
	        export NR_INSTALL_USE_CP_NOT_LN=1 && \
	        export NR_INSTALL_SILENT=1 && \
	        /tmp/newrelic-php5-*/newrelic-install install && \
	        rm -rf /tmp/newrelic-php5-* /tmp/nrinstall* && \
	        #sed -i -e 's/"REPLACE_WITH_REAL_KEY"/"${NEWRELIC_LICENSE_KEY}"/' \
	        sed -i -e 's/"REPLACE_WITH_REAL_KEY"/"'"${NEWRELIC_LICENSE_KEY}"'"/' \
	        #-e 's/newrelic.appname = "PHP Application"/newrelic.appname = "${NEWRELIC_APPLICATION_NAME}"/' \
	        -e 's/newrelic.appname = "PHP Application"/newrelic.appname = "'"${NEWRELIC_APPLICATION_NAME}"'"/' \
	        /opt/bitnami/php/etc/conf.d/newrelic.ini; \
	    fi \
	fi


####

COPY app-entrypoint.sh /

#https://github.com/docker-library/postgres/issues/296#issuecomment-308735942
RUN chmod +x /app-entrypoint.sh

ENTRYPOINT [ "/app-entrypoint.sh" ]
CMD [ "php-fpm", "-F", "--pid", "/opt/bitnami/php/tmp/php-fpm.pid", "-y", "/opt/bitnami/php/etc/php-fpm.conf" ]
