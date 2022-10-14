#!/bin/bash
NOMBRE=$1 # Nombre que debe tener el equipo.
apt install -y libsasl2-modules postfix-pcre
echo "
/^From:.root/ REPLACE From: Notificacion Sistema $NOMBRE <pxmx@mail.nubodata.com>
/^From:.vzdump/ REPLACE From: BACKUP $NOMBRE <pxmx@mail.nubodata.com>
/^Subject:.vzdump.*successful/ REPLACE Subject: BACKUP $NOMBRE EXITOSO
/^Subject:.vzdump.*failed/ REPLACE Subject: BACKUP $NOMBRE FALLIDO
" > /etc/postfix/smtp_header_checks

echo "
relayhost = [mail.nubodata.com]:465
smtp_use_tls = yes
smtp_sasl_auth_enable = yes
smtp_sasl_security_options = noanonymous
smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd
smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt
myhostname=$NOMBRE
smtpd_banner = $myhostname ESMTP $mail_name (Debian/GNU) NBDT
biff = no
# appending .domain is the MUA's job.
append_dot_mydomain = no
# Uncomment the next line to generate "delayed mail" warnings
delay_warning_time = 4h
alias_maps = hash:/etc/aliases
alias_database = hash:/etc/aliases
mydestination = $myhostname, localhost.$mydomain, localhost
mynetworks = 127.0.0.0/8
inet_interfaces = loopback-only
recipient_delimiter = +
compatibility_level = 2
smtp_header_checks = pcre:/etc/postfix/smtp_header_checks
smtp_tls_wrappermode = yes
smtp_tls_security_level = encrypt
" > /etc/postfix/main.cf

echo "mail.nubodata.com bckp@mail.nubodata.com:z9ws9u47oucxuzrujqg33s7jdubtkpxw" > /etc/postfix/sasl_passwd
chmod 600 /etc/postfix/sasl_passwd
chmod 600 /etc/postfix/smtp_header_checks

postmap /etc/postfix/sasl_passwd
postmap /etc/postfix/smtp_header_checks

postfix reload

echo "
[Definition]
failregex = pvedaemon\[.*authentication failure; rhost=<HOST> user=.* msg=.*
ignoreregex =
" > /etc/fail2ban/filter.d/pxmx.conf

echo "
[DEFAULT]
ignoreip = 127.0.0.0
bantime  = 31556952s
findtime  = 120s
destemail = sgrd@mail.nubodata.com
sender = pxmx@mail.nubodata.com
sendername = Fail2ban-$NOMBRE
mta = sendmail
action = %(action_mwl)s

[pxmx]
enabled = true
port = https,http,8006,8007
filter = pxmx
logpath = /var/log/daemon.log
maxretry = 3
# 1 anho
bantime = 31556952

[sshd]
enabled = true

" > /etc/fail2ban/jail.d/nubodata.conf

sed -i '/user:root.*:::/c\user:root@pam:1:0:::sist@mail.nubodata.com:::' user.cfg #Asigna el email sistemas a root.

sed -i '/email_from:/c\email_from: pxmx@mail.nubodata.com' /etc/pve/datacenter.cfg #Susituye el email de envio por defecto. 
grep -qxF 'email_from: pxmx@mail.nubodata.com' /etc/pve/datacenter.cfg || echo 'email_from: pxmx@mail.nubodata.com' >> /etc/pve/datacenter.cfg #Añade linea si no existe.
 
FILE=/etc/pxmx-backup/node.cfg # Comprobamos si este servidor ejecuta PBS
if test -f "$FILE"; then
    echo "Ejecuta PBS se procede a configurar"
    grep -qxF 'email-from: pxmx@mail.nubodata.com' $FILE || echo 'email-from: pxmx@mail.nubodata.com' >> $FILE #Añade linea si no existe.
else
    echo "Ignorar PBS"
fi
