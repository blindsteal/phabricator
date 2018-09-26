FROM php:7.1-apache

# Required Components
# @see https://secure.phabricator.com/book/phabricator/article/installation_guide/#installing-required-comp
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    git \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# install the PHP extensions we need
RUN set -ex; \
	\
	if command -v a2enmod; then \
		a2enmod rewrite; \
	fi; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	\
	apt-get update; \
	apt-get install -y --no-install-recommends \
		libcurl4-gnutls-dev \
		libfreetype6-dev \
		libjpeg62-turbo-dev \
		libpng-dev \
	; \
	\
	docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/; \
	docker-php-ext-install -j "$(nproc)" \
    opcache \
		mbstring \
		iconv \
		mysqli \
		curl \
		pcntl \
		gd \
	; \
	\
  # reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
	apt-mark auto '.*' > /dev/null; \
	apt-mark manual $savedAptMark; \
	ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
		| awk '/=>/ { print $3 }' \
		| sort -u \
		| xargs -r dpkg-query -S \
		| cut -d: -f1 \
		| sort -u \
		| xargs -rt apt-mark manual; \
	\
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	rm -rf /var/lib/apt/lists/*

RUN pecl channel-update pecl.php.net \
  && pecl install apcu \
  && docker-php-ext-enable apcu

# set recommended PHP.ini settings
# see https://secure.php.net/manual/en/opcache.installation.php
RUN { \
  		echo 'opcache.memory_consumption=128'; \
  		echo 'opcache.interned_strings_buffer=8'; \
  		echo 'opcache.max_accelerated_files=4000'; \
  		echo 'opcache.revalidate_freq=60'; \
  		echo 'opcache.fast_shutdown=1'; \
  		echo 'opcache.enable_cli=1'; \
		echo 'opcache.validate_timestamps=0'; \
    } > /usr/local/etc/php/conf.d/opcache-recommended.ini

ENV APACHE_DOCUMENT_ROOT /var/www/phabricator/webroot

RUN { \
  		echo '<VirtualHost *:80>'; \
  		echo 'DocumentRoot ${APACHE_DOCUMENT_ROOT}'; \
  		echo 'RewriteEngine on'; \
  		echo 'RewriteRule ^(.*)$ /index.php?__path__=$1 [B,L,QSA]'; \
  		echo '</VirtualHost>'; \
    } > /etc/apache2/sites-available/000-default.conf

# install pygments
RUN apt-get update; \
	apt-get install -y --no-install-recommends python-setuptools sqlite3; \
    easy_install pygments; \
	rm -rf /var/lib/apt/lists/*

# install mysql-client
RUN apt-get update; \
	apt-get install -y --no-install-recommends mysql-client; \
	rm -rf /var/lib/apt/lists/*

# install openssh and sudo (for git ssh)
RUN apt-get update; \
	apt-get install -y --no-install-recommends sudo openssh-server; \
	rm -rf /var/lib/apt/lists/*

# setup phabricator daemon and vcs user
ENV PHABRICATOR_VCS_USER git
ENV PHABRICATOR_DAEMON_USER phabricator

RUN useradd -ms /bin/sh phabricator; \
	useradd -ms /bin/sh git; \
	usermod -aG sudo www-data; \
	usermod -p NP -aG sudo git;

# create sudo permissions file
RUN { \
  		echo 'www-data ALL=(phabricator) SETENV: NOPASSWD: /usr/bin/git, /usr/lib/git-core/git, /usr/lib/git-core/git-http-backend'; \
  		echo 'git ALL=(phabricator) SETENV: NOPASSWD: /usr/bin/git, /usr/lib/git-core/git, /usr/bin/git-upload-pack, /usr/lib/git-core/git-upload-pack, /usr/bin/git-receive-pack, /usr/lib/git-core/git-receive-pack'; \
    } > /etc/sudoers.d/phabricator

# expose git ssh port
ENV PHABRICATOR_GIT_PORT 2222
EXPOSE $PHABRICATOR_GIT_PORT

# create phabricator ssh hook
RUN mkdir -p /opt/sshd; \
	{ \
  		echo '#!/bin/sh'; \
		echo ''; \
		echo 'VCSUSER="git"'; \
		echo 'ROOT="/var/www/phabricator"'; \
		echo ''; \
		echo 'if [ "$1" != "$VCSUSER" ];'; \
		echo 'then'; \
		echo '  exit 1'; \
		echo 'fi'; \
		echo ''; \
		echo 'exec "$ROOT/bin/ssh-auth" $@'; \
    } > /opt/sshd/phabricator-ssh-hook.sh; \
	chown -R root /opt/sshd/; \
	chown -R root /opt/sshd/phabricator-ssh-hook.sh; \
	chmod 755 /opt/sshd/phabricator-ssh-hook.sh;

# create phabricator sshd config
RUN { \
  		echo 'AuthorizedKeysCommand /opt/sshd/phabricator-ssh-hook.sh'; \
		echo 'AuthorizedKeysCommandUser git'; \
		echo 'AllowUsers git'; \
		echo ''; \
		echo 'Port 2222'; \
		echo 'Protocol 2'; \
		echo 'PermitRootLogin no'; \
		echo 'AllowAgentForwarding no'; \
		echo 'AllowTcpForwarding no'; \
		echo 'PrintMotd no'; \
		echo 'PrintLastLog no'; \
		echo 'PasswordAuthentication no'; \
		echo 'ChallengeResponseAuthentication no'; \
		echo 'AuthorizedKeysFile none'; \
		echo ''; \
		echo 'PidFile /var/run/sshd-phabricator.pid'; \
    } > /etc/ssh/sshd_config.phabricator;

# fix for sshd started outside of debian init script
RUN mkdir -p /var/run/sshd

# set php.ini options for phabricator
RUN { \
  		echo 'post_max_size=2G'; \
    } > /usr/local/etc/php/conf.d/phabricator-options.ini

COPY ./ /var/www

WORKDIR /var/www

RUN git submodule update --init --recursive

# add phabricator and git binaries path
ENV PATH "$PATH:/var/www/phabricator/bin:/usr/lib/git-core"

# copy phabricator preamble script
COPY docker/conf/phabricator/preamble.php /var/www/phabricator/support/preamble.php

# copy and set entrypoint
COPY docker/bin/entrypoint.sh /usr/bin/entrypoint.sh
ENTRYPOINT [ "/usr/bin/entrypoint.sh" ]
CMD [ "docker-php-entrypoint", "apache2-foreground" ]