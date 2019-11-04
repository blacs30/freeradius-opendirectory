#!/usr/bin/env bash
set -e
# set -x

cp -f /etc/freeradius/mods-available/detail.log.tpl /etc/freeradius/mods-available/detail.log

function samba_config {
    local CONF=/etc/samba/smb.conf
    if [ ! -z $SAMBA_REALM ]; then
        cp -f ${CONF}.tpl ${CONF}
        sed -i "s/SAMBA_REALM/$SAMBA_REALM/g" ${CONF}
    else
        return 0
    fi

    if [ ! -z $SAMBA_SECURITY ]; then
        echo $SAMBA_SECURITY
        sed -i "s/SAMBA_SECURITY/$SAMBA_SECURITY/g" ${CONF}
    fi

    if [ ! -z $SAMBA_WORKGROUP ]; then
        echo $SAMBA_WORKGROUP
        sed -i "s/SAMBA_WORKGROUP/$SAMBA_WORKGROUP/g" ${CONF}
    fi
}

function kerberos_config {
    local CONF=/etc/krb5.conf
    if [ ! -z $KDC_SERVER ]; then
        cp -f ${CONF}.tpl ${CONF}
        echo $KDC_SERVER
        for server in $(echo $KDC_SERVER | tr , " "); do
            sed -i "/MY_REALM =/a \                kdc = ${server}" ${CONF}
        done
    else
        return 0
    fi

    if [ ! -z $MY_REALM ]; then
        echo $MY_REALM
        sed -i "s/MY_REALM/$MY_REALM/g" ${CONF}
    fi


}

function clients_config {
    local CONF=/etc/freeradius/clients.conf
    if [ ! -z $FREERADIUS_CLIENT_HOST ]; then
        cp -f ${CONF}.tpl ${CONF}
        echo $FREERADIUS_CLIENT_HOST
        sed -i "s/FREERADIUS_CLIENT_HOST/$FREERADIUS_CLIENT_HOST/g" ${CONF}
    else
        return 0
    fi

    if [ ! -z $FREERADIUS_CLIENT_SECRET ]; then
        echo $FREERADIUS_CLIENT_SECRET
        sed -i "s/FREERADIUS_CLIENT_SECRET/$FREERADIUS_CLIENT_SECRET/g" ${CONF}
    fi
}

function proxy_config {
    local CONF=/etc/freeradius/proxy.conf
    if [ ! -z $FREERADIUS_PROXY_SECRET ]; then
        cp -f ${CONF}.tpl ${CONF}
        echo $FREERADIUS_PROXY_SECRET
        sed -i "s/FREERADIUS_PROXY_SECRET/$FREERADIUS_PROXY_SECRET/g" ${CONF}
    else
        return 0
    fi

    if [ ! -z $FREERADIUS_ACCOUNT_HOST ]; then
        echo $FREERADIUS_ACCOUNT_HOST
        sed -i "s/FREERADIUS_ACCOUNT_HOST/$FREERADIUS_ACCOUNT_HOST/g" ${CONF}
    fi
}

function eap_config {
    local CONF=/etc/freeradius/mods-available/eap
    if [ ! -z $SSL_PRIV_KEY_PASSWORD ]; then
        cp -f ${CONF}.tpl ${CONF}
        echo $SSL_PRIV_KEY_PASSWORD
        sed -i "s/SSL_PRIV_KEY_PASSWORD/$SSL_PRIV_KEY_PASSWORD/g" ${CONF}
    else
        return 0
    fi
}

function initialize {
    # workaround for winbind to work
    # this seems not to be enough, so adding freerad user to root group:
    # usermod -a -G winbindd_priv freerad
    usermod -a -G root freerad \
    && /etc/init.d/smbd start \
    && /etc/init.d/winbind start \
    && chmod 755 -R /var/run/samba

    if [ -z ${SAMBA_PASSWORD} ]; then
        echo "Missing SAMBA_PASSWORD variable.";
        exit 1;
    else
        set +x
        while true; do
          if echo ${SAMBA_PASSWORD} | kinit administrator@${MY_REALM}; then
            break
          fi
          echo sleep 10 && sleep 10
        done
        set -x
    fi

    if [ -z ${SAMBA_PASSWORD} ]; then
        echo "Missing SAMBA_PASSWORD variable.";
        exit 1;
    else
        net join -U Administrator%${SAMBA_PASSWORD}
    fi

    /etc/init.d/winbind start
    echo test | net ads testjoin | grep 'Join is OK'
}

samba_config
kerberos_config
clients_config
proxy_config
eap_config


# this if will check if the first argument is a flag
# but only works if all arguments require a hyphenated flag
# -v; -SL; -f arg; etc will work, but not arg1 arg2
if [ "$#" -eq 0 ] || [ "${1#-}" != "$1" ]; then
    set -- freeradius "$@"
fi

# check for the expected command
if [ "$1" = 'freeradius' ]; then
    initialize
    shift
    exec freeradius -f "$@"
fi

# many people are likely to call "radiusd" as well, so allow that
if [ "$1" = 'radiusd' ]; then
    initialize
    shift
    exec freeradius -f "$@"
fi

# else default to run whatever the user wanted like "bash" or "sh"
exec "$@"