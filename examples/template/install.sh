#!/bin/bash

NAME=$1

if test -z "$NAME" ; then
    NAME=webapp
fi

mkdir -p /etc/bloonix/$NAME /srv/bloonix

cp -a ../template /srv/bloonix/$NAME
cp etc/bloonix/webapp/main.conf /etc/bloonix/$NAME/main.conf
sed -i "s/@@NAME@@/$NAME/g" /etc/bloonix/$NAME/main.conf

cp etc/bloonix/webapp/nginx.conf /etc/bloonix/$NAME/nginx.conf
sed -i "s/@@NAME@@/$NAME/g" /etc/bloonix/$NAME/nginx.conf

if [ -d "/etc/systemd/system" ] ; then
    cp etc/init/bloonix-webapp.service.in /etc/systemd/system/bloonix-$NAME.service
    sed -i "s/@@NAME@@/$NAME/g" /etc/systemd/system/bloonix-$NAME.service
else
    cp etc/init/bloonix-webapp.in /etc/init.d/bloonix-$NAME
    sed -i "s/@@NAME@@/$NAME/g" /etc/init.d/bloonix-$NAME
fi

