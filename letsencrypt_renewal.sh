#!/bin/bash

#####################################
# Created Date: April 20, 2020
# Author: Alfonso Brown
# 
# Copyright (c) 2020 Alfonso Brown
#####################################


# To automatically try and renew the certificates
#
# Depends on certbot-auto
#
# wget https://dl.eff.org/certbot-auto
# sudo mv certbot-auto /usr/local/bin/certbot-auto
# sudo chown root /usr/local/bin/certbot-auto
# sudo chmod 0755 /usr/local/bin/certbot-auto
# /usr/local/bin/certbot-auto --help
#
# Script renews your pre-existing LetsEncrypt wildcard (dns-01) based certs automatically.
# Add it to your cron.daily or other method. It has a 15 minute sleep, so if adding it to
# cron.daily, place it last by renaming it or symlinking it (i.e. zzzletsencrypt_renewal.sh)
# This is so it does not delay the execution of other scripts in cron.daily.
#
# Assumes you already ran the letsencrypt process, similar to this:
# https://lightsail.aws.amazon.com/ls/docs/en_us/articles/amazon-lightsail-using-lets-encrypt-certificates-with-lamp

# USAGE: letsencrypt_renewal.sh <domain_name>

domain=$1
combined_cert="/etc/haproxy/certs/${domain}.pem"

cert_file="/etc/letsencrypt/live/$domain/fullchain.pem"
key_file="/etc/letsencrypt/live/$domain/privkey.pem"

le_path='/usr/local/bin/'

exp_limit=7;
max_wait=900;

web_service='haproxy'
service_user='haproxy'

if [ ! -f $cert_file ]; then
	echo "[ERROR] certificate file not found for domain $domain."
fi

exp=$(date -d "`openssl x509 -in $cert_file -text -noout|grep "Not After"|cut -c 25-`" +%s)
datenow=$(date -d "now" +%s)
days_exp=$(echo \( $exp - $datenow \) / 86400 |bc)

echo "Checking expiration date for $domain..."

if [ "$days_exp" -gt "$exp_limit" ] ; then
	echo "The certificate is up to date, no need for renewal ($days_exp days left)."
else
	echo "The certificate for $domain is about to expire soon. Starting Let's Encrypt DNS $domain renewal script..."
	echo "Random pause (up to $max_wait seconds) before executing renewal command..."

	/usr/bin/sleep $((RANDOM % $max_wait))

	$le_path/certbot-auto --no-self-upgrade --quiet renew

	echo "Creating combined cert chain for haproxy with latest certificates...."
	cat /etc/letsencrypt/live/$domain/fullchain.pem /etc/letsencrypt/live/$domain/privkey.pem > $combined_cert
	/usr/bin/chown $service_user:root $combined_cert
	/usr/bin/chmod 440 $combined_cert

	echo "Reloading $web_service"
	/usr/bin/systemctl reload $web_service
	echo "Renewal process finished for domain $domain"
fi
