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

# Helper function to check if variable is enabled
is_enabled() {
	local var="${1}"
	[[ "${var,,}" =~ ^(yes|true|1)$ ]]
}

# Helper function to check if variable is disabled
is_disabled() {
	local var="${1}"
	[[ -z "${var}" || "${var,,}" =~ ^(no|false|0)$ ]]
}

# Helper function to add environment variables
add_env_var() {
	local var_name="$1"
	local default_value="${2:-}"
	local allow_empty="${3:-false}"

	local current_value="${!var_name:-$default_value}"

	# Handles empty values
	if [[ -n "$current_value" ]]; then
		echo "env[${var_name}] = ${current_value}"
	elif [[ "$allow_empty" == "true" ]]; then
		# Force an empty value with quotes
		echo "env[${var_name}] = \"\""
	else
		echo "# SKIPPED: env[${var_name}] (empty value)"
	fi
}

# Helper function for enabling locale only when it was not added before
enable_locale() {
	local -r locale="${1:?missing locale}"
	if ! grep -q -E "^${locale}$" "$SUPPORTED_LOCALES_FILE"; then
		echo "Locale ${locale} is not supported in this system"
		return 1
	fi
	if ! grep -q -E "^${locale}" "$LOCALES_FILE"; then
		echo "$locale" >>"$LOCALES_FILE"
	else
		echo "Locale ${locale} is already enabled"
	fi
}

#https://jtreminio.com/blog/running-docker-containers-as-current-host-user/#ok-so-what-actually-works
if [ "${USER_ID:-0}" -ne 0 ] && [ "${GROUP_ID:-0}" -ne 0 ]; then
	userdel -f daemon
	if getent group daemon; then
		groupdel daemon
	fi
	groupadd -g "${GROUP_ID}" daemon
	useradd -l -u "${USER_ID}" -g daemon daemon
	install -d -m 0755 -o daemon -g daemon /home/daemon
	#chown --changes --silent --no-dereference --recursive --from=33:33 ${USER_ID}:${GROUP_ID}
	#    /home/daemon
	#    /.composer
	#    /var/run/php-fpm
	#    /var/lib/php/sessions
	#;
fi

#https://docs.docker.com/compose/startup-order/
if [ -n "${PHP_WAITFORIT_CONTAINER_NAME:-}" ] && [ -n "${PHP_WAITFORIT_CONTAINER_PORT:-}" ]; then
	#https://git.eeqj.de/external/mailinabox/commit/1d6793d12434a407d47efa7dc276f63227ad29e5
	if curl https://raw.githubusercontent.com/vishnubob/wait-for-it/master/wait-for-it.sh --output /tmp/wait-for-it.sh -sS --fail >/dev/null 2>&1; then
		if [ "$(file -b --mime-type '/tmp/wait-for-it.sh')" == "text/x-shellscript" ]; then
			chmod +x /tmp/wait-for-it.sh
			/tmp/wait-for-it.sh "${PHP_WAITFORIT_CONTAINER_NAME}":"${PHP_WAITFORIT_CONTAINER_PORT}" -t 0
		fi
		rm /tmp/wait-for-it.sh
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

if is_enabled "${WITH_ALL_LOCALES:-}"; then
	echo "Enabling all locales"
	cp "$SUPPORTED_LOCALES_FILE" "$LOCALES_FILE"
else
	# shellcheck disable=SC2001
	LOCALES_TO_ADD="$(sed 's/[,;]\s*/\n/g' <<<"$EXTRA_LOCALES")"
	while [[ -n "$LOCALES_TO_ADD" ]] && read -r locale; do
		echo "Enabling locale ${locale}"
		enable_locale "$locale"
	done <<<"$LOCALES_TO_ADD"
fi

locale-gen

{
	echo ''

	# === MANDATORY VARIABLES ===
	#DEPRECATED
	add_env_var "ENV" "production"

	#https://medium.com/@tomahock/passing-system-environment-variables-to-php-fpm-when-using-nginx-a70045370fad
	#https://stackoverflow.com/a/58067682
	#https://stackoverflow.com/a/30822781
	#https://wordpress.stackexchange.com/a/286098/99214
	#https://laravel.com/docs/10.x/configuration
	#https://medium.com/@tomahock/passing-system-environment-variables-to-php-fpm-when-using-nginx-a70045370fad
	add_env_var "APP_ENV" "production"

	# === CUSTOM VARIABLES VIA LIST ===
	# Example: PHP_CUSTOM_ENV_VARS="GITHUB_TOKEN,SENTRY_DSN,NEWRELIC_ENABLED"
	if [[ -n "${PHP_CUSTOM_ENV_VARS:-}" ]]; then
		echo "# Custom environment variables from PHP_CUSTOM_ENV_VARS"
		IFS=',' read -ra custom_vars <<<"${PHP_CUSTOM_ENV_VARS}"
		for var_name in "${custom_vars[@]}"; do
			var_name="$(echo -e "${var_name}" | tr -d '[:space:]')"
			[[ -n "$var_name" ]] && add_env_var "$var_name"
		done
	fi

	# === CUSTOM VARIABLES VIA FILE ===
	CUSTOM_ENV_FILE="${PHP_CUSTOM_ENV_FILE:-/php-env.conf}"
	if [[ -f "${CUSTOM_ENV_FILE}" ]]; then
		echo "# Custom environment variables from ${CUSTOM_ENV_FILE}"
		while IFS='=' read -r key value || [[ -n "$key" ]]; do
			# Skip blank lines and comments
			[[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue

			key="$(echo -e "${key}" | tr -d '[:space:]')"
			if [[ -n "$key" ]]; then
				if [[ -z "$value" ]]; then
					# If empty, use environment variable
					add_env_var "$key"
				else
					# Expand variables in value and write directly
					expanded_value="$(eval echo "$value")"
					if [[ -n "$expanded_value" ]]; then
						echo "env[${key}] = ${expanded_value}"
					else
						echo "# SKIPPED: env[${key}] (empty expanded value)"
					fi
				fi
			fi
		done <"${CUSTOM_ENV_FILE}"
	fi

	#https://mattallan.me/posts/how-php-environment-variables-actually-work/
	#https://github.com/docker-library/php/issues/74
	#https://stackoverflow.com/a/58067682/3929620
	#echo 'clear_env = no';
} >>/opt/bitnami/php/etc/environment.conf

if [ "${APP_ENV:-production}" != "production" ]; then
	{
		echo 'user_ini.filename = ".user-'"${APP_ENV:-production}"'.ini"'
		echo 'user_ini.cache_ttl = 0'
	} >>/opt/bitnami/php/etc/php.ini
else
	sed -i \
		-e 's/^expose_php = On/expose_php = Off/' \
		/opt/bitnami/php/etc/php.ini
fi

#https://make.wordpress.org/hosting/handbook/handbook/server-environment/#php-extensions
{
	# W3TC: memcached, newrelic, pdo_dblib, pdo_pgsql, pgsql, opcache
	if is_enabled "${PHP_APCU_ENABLED:-}"; then
		echo 'extension = apcu' # available (not actived) in bitnami/php-fpm
	fi
	if is_enabled "${PHP_MCRYPT_ENABLED:-}"; then
		echo 'extension = mcrypt' # available (not actived) in bitnami/php-fpm
	fi
	if is_enabled "${PHP_IMAGICK_ENABLED:-}"; then
		echo 'extension = imagick' # available (not actived) in bitnami/php-fpm
	fi
	if is_enabled "${PHP_MAXMINDDB_ENABLED:-}"; then
		echo 'extension = maxminddb' # available (not actived) in bitnami/php-fpm
	fi
	if is_enabled "${PHP_MONGODB_ENABLED:-}"; then
		echo 'extension = mongodb' # available (not actived) in bitnami/php-fpm
	fi
	if is_enabled "${PHP_XDEBUG_ENABLED:-}"; then
		echo 'zend_extension = xdebug' # available (not actived) in bitnami/php-fpm
	fi
	if is_enabled "${PHP_MEMCACHED_ENABLED:-}"; then
		echo 'extension = memcached' # available (not actived) in bitnami/php-fpm
	fi
	if is_enabled "${PHP_PDO_DBLIB_ENABLED:-}"; then
		echo 'extension = pdo_dblib' # available (not actived) in bitnami/php-fpm
	fi
	#if is_enabled "${PHP_OPCACHE_ENABLED:-}"; then
	#  echo 'zend_extension = opcache'; # available (actived) in bitnami/php-fpm
	#fi
	if is_enabled "${PHP_SODIUM_ENABLED:-}"; then
		echo 'extension = sodium' # available (not actived) in bitnami/php-fpm
	fi

	#https://php.watch/articles/jit-in-depth
	if [ -n "${PHP_JIT_BUFFER_SIZE:-}" ]; then
		echo "opcache.jit_buffer_size = ${PHP_JIT_BUFFER_SIZE:-0}" # not available in bitnami/php-fpm
	fi

	if is_enabled "${PHP_REDIS_ENABLED:-}"; then
		echo 'extension = redis'
		echo 'extension = igbinary'
		echo 'extension = msgpack'
	elif is_enabled "${PHP_IGBINARY_ENABLED:-}" || is_enabled "${PHP_MSGPACK_ENABLED:-}"; then
		if is_enabled "${PHP_IGBINARY_ENABLED:-}"; then
			echo 'extension = igbinary'
		fi
		if is_enabled "${PHP_MSGPACK_ENABLED:-}"; then
			echo 'extension = msgpack'
		fi
	fi
} | tee -a /opt/bitnami/php/etc/php.ini

#https://www.baeldung.com/linux/imagemagick-security-policy
#https://askubuntu.com/a/1127265/543855
#https://stackoverflow.com/a/53180170/3929620
if is_enabled "${PHP_IMAGICK_ENABLED:-}"; then
	if [[ -n "${PHP_IMAGICK_POLICY_RULES:-}" ]]; then
		policy_file=$(find /etc/ -type f -name "policy.xml" | grep -E "ImageMagick-[0-9]+/policy.xml")
		if [[ -n "${policy_file}" ]]; then
			# `sed -i "/pattern/i text" file` (add `text` before `pattern` in `file`)
			# `sed -i "/pattern/a text" file` (add `text` after `pattern` in `file`)
			# `-i` stands for in-place editing of the file
			# `${VAR//pattern/replacement}` is bash syntax for replacing all occurrences of `pattern` with `replacement` in `VAR`
			# `$'\n'` represents a new line in bash
			sed -i "/<\/policymap>/i ${PHP_IMAGICK_POLICY_RULES//$'\n'/\\n}" "${policy_file}"
		fi
	fi
fi

#### composer
#https://www.cyberciti.biz/open-source/command-line-hacks/linux-run-command-as-different-user/
#https://stackoverflow.com/a/43878779/3929620
#https://bugzilla.redhat.com/show_bug.cgi?id=1245780
if [ -n "${PHP_COMPOSER_VERSION:-}" ]; then
	curl -sS https://getcomposer.org/installer | php -- \
		--install-dir=/usr/local/bin \
		--filename=composer \
		--version="${PHP_COMPOSER_VERSION}" \
		;

	rm -Rf ~/.composer
fi

if [ -n "${GITHUB_TOKEN:-}" ]; then
	runuser -l daemon -c "PATH=$PATH; composer config -g github-oauth.github.com ${GITHUB_TOKEN}"
fi

#https://blog.martinhujer.cz/17-tips-for-using-composer-efficiently/
#https://github.com/composer/composer/issues/8913
if [ -n "${PHP_COMPOSER_ARG:-}" ]; then
	runuser -l daemon -c "PATH=$PATH; composer self-update ${PHP_COMPOSER_ARG}"
fi

if [[ -n "${PHP_COMPOSER_GLOBAL_LIBS}" ]]; then
	runuser -l daemon -c "PATH=$PATH; composer global require ${PHP_COMPOSER_GLOBAL_LIBS//,/ }"
fi

IFS=',' read -ra paths <<<"${PHP_COMPOSER_PATHS}"
for path in "${paths[@]}"; do
	if [[ -d "${path}" ]]; then
		if [ "${APP_ENV:-production}" = "production" ]; then
			#https://getcomposer.org/doc/articles/autoloader-optimization.md
			runuser -l daemon -c "PATH=$PATH; cd ${path}; composer update --optimize-autoloader --classmap-authoritative --no-dev --no-interaction"
		else
			#https://github.com/composer/composer/issues/4892#issuecomment-328511850
			#composer clear-cache;
			runuser -l daemon -c "PATH=$PATH; cd ${path}; composer update --optimize-autoloader --no-interaction"
			runuser -l daemon -c "PATH=$PATH; cd ${path}; composer validate --no-check-all" # --strict
		fi
	fi
done

#### wp-cli
#https://wp-cli.org/it/#installazione
#https://github.com/tatemz/docker-wpcli/blob/master/Dockerfile
if is_enabled "${PHP_WP_CLI_ENABLED:-}"; then
	curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
	chmod +x /usr/local/bin/wp
fi

#### sendmail, msmtp
#https://wiki.archlinux.org/title/Msmtp
#https://github.com/ilyasotkov/docker-php-msmtp
#https://github.com/crazy-max/docker-msmtpd
#https://github.com/neiltheblue/ssmtp-wordpress
#https://gist.github.com/orlando/42883f9ed188e45817c50359bc3fa680
#https://webworxshop.com/my-road-to-docker-sorting-out-smtp/
#https://www.wpdiaries.com/mail-functionality-for-official-docker-wordpress-image/
#https://github.com/swiftmailer/swiftmailer/issues/633

#https://github.com/netdata/netdata/issues/7572
if [ -f "/home/daemon/.msmtprc" ]; then
	ln -sfn /home/daemon/.msmtprc /etc/msmtprc
fi

if [ -n "${PHP_SENDMAIL_PATH:-}" ]; then
	echo 'sendmail_path="'"${PHP_SENDMAIL_PATH}"'"' >/opt/bitnami/php/etc/conf.d/sendmail.ini
else
	echo 'sendmail_path="/usr/bin/msmtp -t"' >/opt/bitnami/php/etc/conf.d/msmtp.ini
fi

#### supercronic
#https://github.com/aptible/supercronic
if is_enabled "${PHP_SUPERCRONIC_ENABLED:-}" && [[ -f "/etc/crontab" ]]; then
	# shellcheck disable=SC2086
	runuser -l daemon -c "PATH=${PATH}; /usr/local/bin/supercronic ${PHP_SUPERCRONIC_FLAGS:-} /etc/crontab" &
fi

#### newrelic
#https://docs.newrelic.com/docs/agents/php-agent/advanced-installation/install-php-agent-docker
#https://stackoverflow.com/a/584926/3929620
if is_enabled "${PHP_NEWRELIC_ENABLED:-}"; then
	#https://stackoverflow.com/a/53935189/3929620
	#https://superuser.com/a/442395
	#https://curl.haxx.se/mail/archive-2018-02/0027.html
	#https://stackoverflow.com/a/56503723/3929620
	#https://superuser.com/a/657174
	#https://superuser.com/a/590170
	#https://superuser.com/a/1249678
	#https://superuser.com/a/742421
	CURL_OUTPUT=$(curl --head --silent --location --connect-timeout 10 --write-out "%{http_code}" --output /dev/null --show-error --fail https://download.newrelic.com/php_agent/archive/"${NEWRELIC_VERSION}"/newrelic-php5-"${NEWRELIC_VERSION}"-linux.tar.gz)
	if [ "${CURL_OUTPUT}" -eq 200 ]; then
		# shellcheck disable=SC2211
		curl -L https://download.newrelic.com/php_agent/archive/"${NEWRELIC_VERSION}"/newrelic-php5-"${NEWRELIC_VERSION}"-linux.tar.gz | tar -C /tmp -zx &&
			export NR_INSTALL_USE_CP_NOT_LN=1 &&
			export NR_INSTALL_SILENT=1 &&
			/tmp/newrelic-php5-*/newrelic-install install &&
			rm -rf /tmp/newrelic-php5-* /tmp/nrinstall* # && \
		#sed -i \
		#  -e 's/"REPLACE_WITH_REAL_KEY"/"'"${NEWRELIC_LICENSE_KEY}"'"/' \
		#  -e 's/newrelic.appname = "PHP Application"/newrelic.appname = "'"${NEWRELIC_APPLICATION_NAME}"'"/' \
		#  /opt/bitnami/php/etc/conf.d/newrelic.ini;
	fi
fi

####

FILE=/entrypoint-after.sh
# shellcheck source=/dev/null
if [ -f "$FILE" ]; then
	. $FILE
fi

exec "$@"
