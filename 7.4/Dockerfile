FROM bitnami/php-fpm:7.4

RUN install_packages \
        locales \
        #FIXED "sh: 1: tput: not found" with kint-php
        ncurses-bin \
        patch \
        rsync \
        vim \
    ;


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
