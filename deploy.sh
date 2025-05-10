#!/bin/bash

# Bash Strict Mode:
# -e  / -o errexit    :: Exit immediately if a command exits with a non-zero status.
# -E  / -o errtrace   :: Inherit ERR trap in functions, subshells, and substitutions (older shells may require -o errtrace instead of -E).
# -u  / -o nounset    :: Treat unset variables as an error and exit immediately.
# -o pipefail         :: Exit on error in pipeline.
# -x  / -o xtrace     :: Print each command and its arguments as they are executed (useful for debugging).
# -T  / -o functrace  :: Allow function tracing (used for DEBUG and RETURN traps within functions and sourced files).
#
# Optional:
# shopt -s inherit_errexit  :: Bash >= 4.4: ensures ERR trap inheritance in all cases
#
# Common practice:
# set -eEuo pipefail  # Strict mode (recommended)
set -eEuo pipefail

#https://blog.dockbit.com/templating-your-dockerfile-like-a-boss-2a84a67d28e9

deploy() {
	str="
  s!%%TAG%%!$TAG!g;
"

	sed -r "$str" "$1"
}

TAGS=(
	#  5.6
	#  5.6-prod
	#  7.0
	#  7.0-prod
	#  7.1
	#  7.1-prod
	#  7.2
	#  7.2-prod
	#  7.3
	#  7.3-prod
	#  7.4
	8.0
	8.1
	8.2
	8.3
	8.4
)

ENTRYPOINT=entrypoint.sh

IFS='
'
# shellcheck disable=SC2048
for TAG in ${TAGS[*]}; do

	if [ -d "$TAG" ]; then
		rm -Rf "$TAG"
	fi

	mkdir "$TAG"
	deploy Dockerfile.template >"$TAG"/Dockerfile

	if [ -f "$ENTRYPOINT" ]; then
		cp $ENTRYPOINT "$TAG"
	fi

done
