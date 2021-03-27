FROM bitnami/php-fpm:5.6

RUN install_packages \
        # required by wp ewwwio optimize https://docs.ewww.io/article/25-optimizing-with-wp-cli
        less \
        locales \
        #FIXED "sh: 1: tput: not found" with kint-php
        ncurses-bin \
        patch \
        rsync \
        vim \
        zip \
    ;


#### composer
#https://docs.php.earth/docker/composer/
#https://medium.com/@c.harrison/speedy-composer-installs-in-docker-builds-41eea6d0172b
#https://blog.martinhujer.cz/17-tips-for-using-composer-efficiently/
#https://github.com/composer/composer/issues/4892#issuecomment-328511850
#https://getcomposer.org/doc/articles/autoloader-optimization.md
#https://hackernoon.com/get-composer-to-run-on-docker-container-a-how-to-guide-y86g36z7

RUN install_packages \
        ca-certificates \
        curl \
        git \
        # As there is no 'unzip' command installed zip files are being unpacked using the PHP zip extension.
        # This may cause invalid reports of corrupted archives. Besides, any UNIX permissions (e.g. executable) defined in the archives will be lost.
        # Installing 'unzip' may remediate them.
        unzip \
    ;


#### msmtp/mailhog
# Looks like sSMTP is no longer maintained, MSMTP is the suggested replacement.

RUN install_packages \
        ca-certificates \
        curl \
        msmtp \
    ;


####

COPY entrypoint.sh /

#https://github.com/docker-library/postgres/issues/296#issuecomment-308735942
RUN chmod +x /entrypoint.sh

ENTRYPOINT [ "/entrypoint.sh" ]
CMD [ "php-fpm", "-F", "--pid", "/opt/bitnami/php/tmp/php-fpm.pid", "-y", "/opt/bitnami/php/etc/php-fpm.conf" ]
