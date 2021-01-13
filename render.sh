#!/bin/bash

#https://blog.dockbit.com/templating-your-dockerfile-like-a-boss-2a84a67d28e9

render() {
  sedStr="
  s!%%TAG%%!$TAG!g;
"

  sed -r "$sedStr" $1
}

TAGS=(7.3.13)
ENTRYPOINT=app-entrypoint.sh

for TAG in ${TAGS[*]}; do
  if [ -d "$TAG" ]; then
    rm -Rf $TAG
  fi

  mkdir $TAG
  render Dockerfile.template > $TAG/Dockerfile

  if [ -f "$ENTRYPOINT" ]; then
    cp $ENTRYPOINT $TAG
  fi
done
