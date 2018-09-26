#!/bin/sh
set -e

# wait for mysql
echo 'Waiting for mysql to be available'
maxTries=$MAX_DB_TRIES
while [ "$maxTries" -gt 0 ] && ! mysql -h"$MYSQL_HOST" -P"$MYSQL_PORT" -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" -e 'select 1;'; do
    sleep 1
done
echo
if [ "$maxTries" -le 0 ]; then
    echo >&2 "error: unable to contact mysql after $MAX_DB_TRIES tries"
    exit 1
fi

phabricator_home='/var/www/phabricator'
phabricator_domain="https://$PHABRICATOR_DOMAIN"
phabricator_file_domain="https://$PHABRICATOR_FILE_DOMAIN"
phabricator_repo_path='/var/repo'
phabricator_tz='Europe/Berlin'
phabricator_storage='/var/file'

# source apache env so we can get run user and group
. $APACHE_ENVVARS

mkdir -p "$phabricator_storage"
chown -R "$APACHE_RUN_USER:$APACHE_RUN_GROUP" "$phabricator_storage"
mkdir -p "$phabricator_repo_path"
chown -R "$APACHE_RUN_USER:$APACHE_RUN_GROUP" "$phabricator_repo_path"

cd $phabricator_home

./bin/config set mysql.user 'root'
./bin/config set mysql.pass "$MYSQL_ROOT_PASSWORD"
./bin/config set mysql.host "$MYSQL_HOST"
./bin/config set mysql.port "$MYSQL_PORT"
./bin/config set phabricator.base-uri "$phabricator_domain"
./bin/config set pygments.enabled 'true'
./bin/config set phabricator.timezone "$phabricator_tz"
./bin/config set storage.local-disk.path "$phabricator_storage"
./bin/config set security.alternate-file-domain "$phabricator_file_domain"

./bin/config set metamta.default-address "$PHABRICTOR_MAIL_FROM"
./bin/config set metamta.domain "$phabricator_domain"
./bin/config set metamta.mail-adapter PhabricatorMailImplementationMailgunAdapter
./bin/config set mailgun.domain "$phabricator_domain"
./bin/config set mailgun.api-key "$PHABRICATOR_MAILGUN_API_KEY"

./bin/storage upgrade --force

phd start

exec "$@"