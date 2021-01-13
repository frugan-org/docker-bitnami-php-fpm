#!/bin/sh
set -e

#https://jtreminio.com/blog/running-docker-containers-as-current-host-user/#ok-so-what-actually-works
if [ ${USER_ID} -ne 0 ] && [ ${GROUP_ID} -ne 0 ]; then \
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
{ \
  echo ''; \
  echo 'env[ENV] = $ENV'; \
} >> /opt/bitnami/php/etc/environment.conf;

if [ "${ENV}" = "develop" ]; then \
  { \
    echo 'user_ini.filename = ".user-'"${ENV}"'.ini"'; \
    echo 'user_ini.cache_ttl = 0'; \
  } >> /opt/bitnami/php/etc/php.ini; \
fi; \

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

#https://www.cyberciti.biz/open-source/command-line-hacks/linux-run-command-as-different-user/
#https://stackoverflow.com/a/43878779/3929620
#https://bugzilla.redhat.com/show_bug.cgi?id=1245780
if [ ! -z "${PHP_COMPOSER_PATH}" ]; then

  if [ ! -z "${GITHUB_TOKEN}" ]; then
    runuser -l daemon -c "PATH=$PATH; composer config -g github-oauth.github.com ${GITHUB_TOKEN}";
  fi

  #https://blog.martinhujer.cz/17-tips-for-using-composer-efficiently/
  #https://github.com/composer/composer/issues/8913
  if [ ! -z "${PHP_COMPOSER_VERSION}" ]; then
    composer self-update ${PHP_COMPOSER_VERSION};
  else
    composer self-update;
  fi

  if [ "${ENV}" = "develop" ]; then
    #https://github.com/composer/composer/issues/4892#issuecomment-328511850
    #composer clear-cache;
    runuser -l daemon -c "PATH=$PATH; cd ${PHP_COMPOSER_PATH}; composer update --optimize-autoloader --no-interaction";
    runuser -l daemon -c "PATH=$PATH; cd ${PHP_COMPOSER_PATH}; composer validate --no-check-all"; # --strict
  else
    #https://getcomposer.org/doc/articles/autoloader-optimization.md
    runuser -l daemon -c "PATH=$PATH; cd ${PHP_COMPOSER_PATH}; composer update --optimize-autoloader --classmap-authoritative --no-dev --no-interaction";
  fi

fi

exec "$@"
