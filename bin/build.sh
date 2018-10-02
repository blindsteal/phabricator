#!/usr/bin/env bash

tag='matchwerk/phabricator'
dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"

docker build -t $tag:`date +%s` "$dir/../"