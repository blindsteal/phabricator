#!/usr/bin/env bash

dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
certdir=$dir/../certs
openssl_cnf='/usr/lib/ssl/openssl.cnf'
local_domain='blindsteal.local'

mkdir -p $certdir
cd $certdir
openssl req \
    -newkey rsa:2048 \
    -x509 \
    -nodes \
    -keyout $local_domain.key \
    -new \
    -out $local_domain.crt \
    -subj /CN=\*.$local_domain \
    -reqexts SAN \
    -extensions SAN \
    -config <(cat $openssl_cnf \
        <(printf '[SAN]\nsubjectAltName=DNS:\*.'$local_domain)) \
    -sha256 \
    -days 3650