#!/bin/sh
set -e

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
