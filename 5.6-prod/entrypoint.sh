#!/bin/bash

# shellcheck disable=SC1091

set -e
#set -o errexit
#set -o nounset
#set -o pipefail
#set -o xtrace # Uncomment this line for debugging purpose


#https://jtreminio.com/blog/running-docker-containers-as-current-host-user/#ok-so-what-actually-works
if [ ${USER_ID:-0} -ne 0 ] && [ ${GROUP_ID:-0} -ne 0 ]; then
  userdel -f daemon;
  if getent group daemon; then
      groupdel daemon;
  fi
  groupadd -g ${GROUP_ID} daemon;
  useradd -l -u ${USER_ID} -g daemon daemon;
  install -d -m 0755 -o daemon -g daemon /home/daemon;
  #chown --changes --silent --no-dereference --recursive --from=33:33 ${USER_ID}:${GROUP_ID}
  #    /home/daemon
  #    /.composer
  #    /var/run/php-fpm
  #    /var/lib/php/sessions
  #;
fi


#https://docs.docker.com/compose/startup-order/
if [ ! -z "${PHP_WAITFORIT_CONTAINER_NAME:-}" ] && [ ! -z "${PHP_WAITFORIT_CONTAINER_PORT:-}" ]; then
  #https://git.eeqj.de/external/mailinabox/commit/1d6793d12434a407d47efa7dc276f63227ad29e5
  if curl https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh --output /tmp/wait-for-it.sh -sS --fail > /dev/null 2>&1 ; then
    if [ "$(file -b --mime-type '/tmp/wait-for-it.sh')" == "text/x-shellscript" ]; then
      chmod +x /tmp/wait-for-it.sh;
      /tmp/wait-for-it.sh ${PHP_WAITFORIT_CONTAINER_NAME}:${PHP_WAITFORIT_CONTAINER_PORT} -t 0;
    fi
    rm /tmp/wait-for-it.sh;
  fi
fi


#https://github.com/bitnami/bitnami-docker-moodle/pull/123
#https://github.com/bitnami/bitnami-docker-moodle/blob/master/3/debian-10/rootfs/opt/bitnami/scripts/locales/add-extra-locales.sh
#https://github.com/bitnami/bitnami-docker-moodle#installing-additional-language-packs
# Defaults
WITH_ALL_LOCALES="${PHP_WITH_ALL_LOCALES:-no}"
EXTRA_LOCALES="${PHP_EXTRA_LOCALES:-}"

# Constants
LOCALES_FILE="/etc/locale.gen"
SUPPORTED_LOCALES_FILE="/usr/share/i18n/SUPPORTED"

# Helper function for enabling locale only when it was not added before
enable_locale() {
    local -r locale="${1:?missing locale}"
    if ! grep -q -E "^${locale}$" "$SUPPORTED_LOCALES_FILE"; then
        echo "Locale ${locale} is not supported in this system"
        return 1
    fi
    if ! grep -q -E "^${locale}" "$LOCALES_FILE"; then
        echo "$locale" >> "$LOCALES_FILE"
    else
        echo "Locale ${locale} is already enabled"
    fi
}

if [[ "$WITH_ALL_LOCALES" =~ ^(yes|true|1)$ ]]; then
    echo "Enabling all locales"
    cp "$SUPPORTED_LOCALES_FILE" "$LOCALES_FILE"
else
    LOCALES_TO_ADD="$(sed 's/[,;]\s*/\n/g' <<< "$EXTRA_LOCALES")"
    while [[ -n "$LOCALES_TO_ADD" ]] && read -r locale; do
        echo "Enabling locale ${locale}"
        enable_locale "$locale"
    done <<< "$LOCALES_TO_ADD"
fi

locale-gen


{
  echo '';

  #https://medium.com/@tomahock/passing-system-environment-variables-to-php-fpm-when-using-nginx-a70045370fad
  #https://stackoverflow.com/a/58067682
  #https://stackoverflow.com/a/30822781
  #https://wordpress.stackexchange.com/a/286098/99214
  echo 'env[ENV] = '"${ENV}";

  #https://mattallan.me/posts/how-php-environment-variables-actually-work/
  #https://github.com/docker-library/php/issues/74
  #https://stackoverflow.com/a/58067682/3929620
  #echo 'clear_env = no';
} >> /opt/bitnami/php/etc/environment.conf;

if [ "${ENV}" = "develop" ]; then
  {
    echo 'user_ini.filename = ".user-'"${ENV}"'.ini"';
    echo 'user_ini.cache_ttl = 0';
  } >> /opt/bitnami/php/etc/php.ini;
fi

#https://make.wordpress.org/hosting/handbook/handbook/server-environment/#php-extensions
{
  # W3TC: memcached, newrelic, pdo_dblib, pdo_pgsql, pgsql, opcache
  if [ ! -z "${PHP_APCU_ENABLED:-}" ]; then
    echo 'extension = apcu'; # available (not actived) in bitnami/php-fpm
  fi
  if [ ! -z "${PHP_MCRYPT_ENABLED:-}" ]; then
    echo 'extension = mcrypt'; # available (not actived) in bitnami/php-fpm
  fi
  if [ ! -z "${PHP_IMAGICK_ENABLED:-}" ]; then
    echo 'extension = imagick'; # available (not actived) in bitnami/php-fpm
  fi
  if [ ! -z "${PHP_MAXMINDDB_ENABLED:-}" ]; then
    echo 'extension = maxminddb'; # available (not actived) in bitnami/php-fpm
  fi
  if [ ! -z "${PHP_MONGODB_ENABLED:-}" ]; then
    echo 'extension = mongodb'; # available (not actived) in bitnami/php-fpm
  fi
  if [ ! -z "${PHP_XDEBUG_ENABLED:-}" ]; then
    echo 'zend_extension = xdebug'; # available (not actived) in bitnami/php-fpm
  fi
  if [ ! -z "${PHP_MEMCACHED_ENABLED:-}" ]; then
    echo 'extension = memcached'; # available (not actived) in bitnami/php-fpm
  fi
  if [ ! -z "${PHP_PDO_DBLIB_ENABLED:-}" ]; then
    echo 'extension = pdo_dblib'; # available (not actived) in bitnami/php-fpm
  fi
  #if [ ! -z "${PHP_OPCACHE_ENABLED}" ]; then
  #  echo 'zend_extension = opcache'; # available (actived) in bitnami/php-fpm
  #fi
} | tee -a /opt/bitnami/php/etc/php.ini;


#### composer
#https://www.cyberciti.biz/open-source/command-line-hacks/linux-run-command-as-different-user/
#https://stackoverflow.com/a/43878779/3929620
#https://bugzilla.redhat.com/show_bug.cgi?id=1245780
if [ ! -z "${PHP_COMPOSER_PATHS:-}" ]; then

  if [ ! -z "${PHP_COMPOSER_VERSION:-}" ]; then
    curl -sS https://getcomposer.org/installer | php -- \
      --install-dir=/usr/local/bin \
      --filename=composer \
      --version=${PHP_COMPOSER_VERSION} \
    ;
  else
    curl -sS https://getcomposer.org/installer | php -- \
      --install-dir=/usr/local/bin \
      --filename=composer \
    ;
  fi

  rm -Rf ~/.composer;

  if [ ! -z "${GITHUB_TOKEN:-}" ]; then
    runuser -l daemon -c "PATH=$PATH; composer config -g github-oauth.github.com ${GITHUB_TOKEN}";
  fi

  #https://blog.martinhujer.cz/17-tips-for-using-composer-efficiently/
  #https://github.com/composer/composer/issues/8913
  if [ ! -z "${PHP_COMPOSER_ARG:-}" ]; then
    composer self-update ${PHP_COMPOSER_ARG};
  else
    composer self-update;
  fi

  IFS=',' read -ra paths <<< "${PHP_COMPOSER_PATHS}";
  for path in "${paths[@]}"
  do
    if [ "${ENV}" = "develop" ]; then
      #https://github.com/composer/composer/issues/4892#issuecomment-328511850
      #composer clear-cache;
      runuser -l daemon -c "PATH=$PATH; cd ${path}; composer update --optimize-autoloader --no-interaction";
      runuser -l daemon -c "PATH=$PATH; cd ${path}; composer validate --no-check-all"; # --strict
    else
      #https://getcomposer.org/doc/articles/autoloader-optimization.md
      runuser -l daemon -c "PATH=$PATH; cd ${path}; composer update --optimize-autoloader --classmap-authoritative --no-dev --no-interaction";
    fi
  done
fi


#### wp-cli
#https://wp-cli.org/it/#installazione
#https://github.com/tatemz/docker-wpcli/blob/master/Dockerfile

if [ ! -z "${PHP_WP_CLI_ENABLED:-}" ]; then
  curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar;
  chmod +x /usr/local/bin/wp;
fi


#### msmtp/mailhog
#https://github.com/ilyasotkov/docker-php-msmtp
#https://github.com/crazy-max/docker-msmtpd
#https://github.com/neiltheblue/ssmtp-wordpress
#https://gist.github.com/orlando/42883f9ed188e45817c50359bc3fa680
#https://webworxshop.com/my-road-to-docker-sorting-out-smtp/
#https://www.wpdiaries.com/mail-functionality-for-official-docker-wordpress-image/

if [ "${ENV}" = "develop" ]; then
  curl --location --output /usr/local/bin/mhsendmail https://github.com/mailhog/mhsendmail/releases/download/v${MAILHOG_SENDMAIL_VERSION}/mhsendmail_linux_amd64;
  chmod +x /usr/local/bin/mhsendmail;

  #https://github.com/swiftmailer/swiftmailer/issues/633
  if [ ! -z "${PHP_SENDMAIL_PATH:-}" ]; then
    echo 'sendmail_path="'${PHP_SENDMAIL_PATH}'"' > /opt/bitnami/php/etc/conf.d/mailhog.ini;
  else
    echo 'sendmail_path="/usr/local/bin/mhsendmail --smtp-addr=mailhog:1025 -f noreply@localhost"' > /opt/bitnami/php/etc/conf.d/mailhog.ini;
  fi
elif [ ! -z "${PHP_SENDMAIL_PATH:-}" ]; then
  echo 'sendmail_path="'${PHP_SENDMAIL_PATH}'"' > /opt/bitnami/php/etc/conf.d/msmtp.ini;
else
  echo 'sendmail_path="/usr/bin/msmtp -t"' > /opt/bitnami/php/etc/conf.d/msmtp.ini;
fi


#### newrelic
#https://docs.newrelic.com/docs/agents/php-agent/advanced-installation/install-php-agent-docker
#https://stackoverflow.com/a/584926/3929620

if [ ! -z "${PHP_NEWRELIC_ENABLED:-}" ]; then
  #https://stackoverflow.com/a/53935189/3929620
  #https://superuser.com/a/442395
  #https://curl.haxx.se/mail/archive-2018-02/0027.html
  #https://stackoverflow.com/a/56503723/3929620
  #https://superuser.com/a/657174
  #https://superuser.com/a/590170
  #https://superuser.com/a/1249678
  #https://superuser.com/a/742421
  CURL_OUTPUT=$(curl --head --silent --location --connect-timeout 10 --write-out "%{http_code}" --output /dev/null --show-error --fail https://download.newrelic.com/php_agent/archive/${NEWRELIC_VERSION}/newrelic-php5-${NEWRELIC_VERSION}-linux.tar.gz);
  if [ ${CURL_OUTPUT} -eq 200 ]; then
    curl -L https://download.newrelic.com/php_agent/archive/${NEWRELIC_VERSION}/newrelic-php5-${NEWRELIC_VERSION}-linux.tar.gz | tar -C /tmp -zx && \
    export NR_INSTALL_USE_CP_NOT_LN=1 && \
    export NR_INSTALL_SILENT=1 && \
    /tmp/newrelic-php5-*/newrelic-install install && \
    rm -rf /tmp/newrelic-php5-* /tmp/nrinstall*; # && \
    #sed -i \
    #  -e 's/"REPLACE_WITH_REAL_KEY"/"'"${NEWRELIC_LICENSE_KEY}"'"/' \
    #  -e 's/newrelic.appname = "PHP Application"/newrelic.appname = "'"${NEWRELIC_APPLICATION_NAME}"'"/' \
    #  /opt/bitnami/php/etc/conf.d/newrelic.ini;
  fi
fi


####

FILE=/entrypoint-after.sh
if [ -f "$FILE" ]; then
  . $FILE;
fi


exec "$@"
