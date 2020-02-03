#!/bin/sh

set -e

if [ ! -z "${PHP_COMPOSER_PATH}" ]; then

  if [ ! -z "${GITHUB_TOKEN}" ]; then
    composer config -g github-oauth.github.com ${GITHUB_TOKEN}
  fi

  #https://blog.martinhujer.cz/17-tips-for-using-composer-efficiently/
  composer self-update;

  cd ${PHP_COMPOSER_PATH};

  if [ "${ENV}" = "develop" ]; then
    #https://github.com/composer/composer/issues/4892#issuecomment-328511850
    #composer clear-cache;
    composer update --optimize-autoloader --no-interaction;
    composer validate --no-check-all; # --strict
  else
    #https://getcomposer.org/doc/articles/autoloader-optimization.md
    composer update --optimize-autoloader --classmap-authoritative --no-dev --no-interaction;
  fi

fi

exec "$@"
