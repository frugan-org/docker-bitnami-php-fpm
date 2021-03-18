#!/bin/bash

#https://blog.dockbit.com/templating-your-dockerfile-like-a-boss-2a84a67d28e9

deploy() {
  str="
  s!%%TAG%%!$TAG!g;
"

  sed -r "$str" $1
}

TAGS=(
  7.1
  7.1-prod
  7.2
  7.2-prod
  7.3
  7.3-prod
  7.4
  7.4-prod
  8.0
  8.0-prod
)

ENTRYPOINT=entrypoint.sh

for TAG in ${TAGS[*]}; do

  if [ -d "$TAG" ]; then
    rm -Rf $TAG
  fi

  mkdir $TAG
  deploy Dockerfile.template > $TAG/Dockerfile

  if [ -f "$ENTRYPOINT" ]; then
    cp $ENTRYPOINT $TAG
  fi

done
