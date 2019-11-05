FROM blacs30/freeradius-ubuntu18:v3.0.19
RUN apt update \
  && DEBIAN_FRONTEND=noninteractive apt install -y --no-install-recommends samba samba-dsdb-modules samba-vfs-modules winbind krb5-kdc busybox-static \
    && apt-get autoremove && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/spool/cron/crontabs; \
    echo '* * * * * bash /etc/freeradius/create_acc_request.sh' > /var/spool/cron/crontabs/root

ADD files/freeradius/ /etc/freeradius/
ADD files/krb5.conf.tpl /etc/krb5.conf.tpl
ADD files/smb.conf.tpl /etc/samba/smb.conf.tpl
ADD *.sh /
RUN cd /etc/freeradius/sites-enabled \
    && ln -s ../sites-available/copy-acct-to-home-server ./copy-acct-to-home-server \
    && chmod +x /*.sh

VOLUME /var/log/freeradius

EXPOSE 1812 1813

ENTRYPOINT ["/docker-entrypoint.sh"]

# Need to place certs (ca, cert and cert key) in /etc/freeradius/certs
# needs to place the file authorized_macs in /etc/freeradius
