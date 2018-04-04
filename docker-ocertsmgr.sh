#!/bin/sh

BASEDIR=/etc/ocserv/
USER=$2
GROUP=$3
DAYS=365

function help() {
	echo "Usages: ocusermgr [option] username usergrops."
}

function generating_client_certificates() {
	if [ -f $BASEDIR/certs/$USER/$GROUP/user-cert.pem ]; then
		revoking_client_certificate
		rm -rf $BASEDIR/certs/$USER/$GROUP/
	fi
	mkdir -p $BASEDIR/certs/$USER/$GROUP/
	certtool --generate-privkey --outfile $BASEDIR/certs/$USER/$GROUP/user-key.pem
	cat > $BASEDIR/certs/$USER/$GROUP/user.tmpl <<-EOUSER
	cn = "$USER"
	unit = "$GROUP"
	expiration_days = "$DAYS"
	signing_key
	tls_www_client 
	EOUSER
	certtool --generate-certificate --load-privkey $BASEDIR/certs/$USER/$GROUP/user-key.pem --load-ca-certificate $BASEDIR/certs/ca.pem --load-ca-privkey $BASEDIR/certs/ca-key.pem --template $BASEDIR/certs/$USER/$GROUP/user.tmpl --outfile $BASEDIR/certs/$USER/$GROUP/user-cert.pem
	certtool --to-p12 --load-privkey $BASEDIR/certs/$USER/$GROUP/user-key.pem --pkcs-cipher 3des-pkcs12 --p12-name=$USER-$GROUP --load-certificate $BASEDIR/certs/$USER/$GROUP/user-cert.pem --outfile $BASEDIR/certs/$USER/$GROUP/$USER-$GROUP.p12 --outder
}

function revoking_client_certificate() {
	cat > $BASEDIR/certs/crl.tmpl <<-EOCRL
	crl_next_update = 365
	crl_number = `date +%Y%H%M%S`
	EOCRL
	cat $BASEDIR/certs/$USER/$GROUP/user-cert.pem >> $BASEDIR/certs/revoked.pem
	certtool --generate-crl --load-ca-privkey $BASEDIR/certs/ca-key.pem --load-ca-certificate $BASEDIR/certs/ca.pem --load-certificate $BASEDIR/certs/revoked.pem --template $BASEDIR/certs/crl.tmpl --outfile $BASEDIR/certs/crl.pem
}

if [ "$1" == "add" ] && [ ! "$USER" == "" ] && [ ! "$GROUP" == "" ] && [ ! "$DAYS" == "" ]; then
	generating_client_certificates
elif [ "$1" == "del" ] && [ ! "$USER" == "" ] && [ ! "$GROUP" == "" ]; then
	revoking_client_certificate
else
	help
fi
