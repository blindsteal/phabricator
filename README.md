# phabricator
Unofficial Base Docker Image for Phabricator

Updated by [phabricator/bot](https://hub.docker.com/r/phabricator/bot/) every
hour, on the hour.

# local proxy setup
Edit `/etc/hosts` and add a wildcard domain redirecting to localhost (i.e. `127.0.0.1       *.blindsteal.local`) which matches the `$local_domain` specified in `./bin/cert.sh`.
Run `./bin/cert.sh` before `docker-compose up -d --build` to generate a self-signed SSL cert.