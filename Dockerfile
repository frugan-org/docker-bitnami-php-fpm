#https://docs.bitnami.com/bch/apps/wordpress/configuration/install-modules-php/

ARG PHP_TAG

FROM bitnami/php-fpm:${PHP_TAG:-latest}

RUN install_packages \
        rsync \
        vim \
    ;


ARG ENV

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
    # W3TC
    echo 'extension=memcached.so' | tee -a /opt/bitnami/php/etc/php.ini; \
    \
    # apcu
    echo 'extension=apcu.so' | tee -a /opt/bitnami/php/etc/php.ini;


#### sendmail
#https://docs.bitnami.com/bch/apps/wordpress/troubleshooting/send-mail/

RUN if [ "${ENV}" != "develop" ]; then \
        set -eux; \
        install_packages \
            sendmail \
        ; \
        echo 'sendmail_path = "env -i /usr/sbin/sendmail -t -i"' > /opt/bitnami/php/etc/conf.d/sendmail.ini; \
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


#### composer

ARG PHP_COMPOSER_PATH

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
        curl -sS https://getcomposer.org/installer | php -- \
            --install-dir=/usr/local/bin \
            --filename=composer \
        ; \
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


#### newrelic
#https://docs.newrelic.com/docs/agents/php-agent/advanced-installation/install-php-agent-docker

ARG NEWRELIC_VERSION
ARG NEWRELIC_LICENSE_KEY
ARG NEWRELIC_APPLICATION_NAME

#https://stackoverflow.com/a/584926/3929620
RUN if [ ! -z "${NEWRELIC_LICENSE_KEY}" ]; then \
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
	fi


####

COPY app-entrypoint.sh /

#https://github.com/docker-library/postgres/issues/296#issuecomment-308735942
RUN chmod +x /app-entrypoint.sh

ENTRYPOINT [ "/app-entrypoint.sh" ]
CMD [ "php-fpm", "-F", "--pid", "/opt/bitnami/php/tmp/php-fpm.pid", "-y", "/opt/bitnami/php/etc/php-fpm.conf" ]
