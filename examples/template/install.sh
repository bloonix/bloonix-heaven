#!/bin/bash

NAME=$1

if test -z "$NAME" ; then
    NAME=webapp
fi

echo "creating /etc/bloonix/$NAME"
echo "creating /srv/bloonix"
mkdir -p /etc/bloonix/$NAME /srv/bloonix

echo "creating /srv/bloonix/$NAME"
cp -a ../template /srv/bloonix/$NAME
echo "creating /etc/bloonix/$NAME/main.conf"
cp etc/bloonix/webapp/main.conf /etc/bloonix/$NAME/main.conf
sed -i "s/@@NAME@@/$NAME/g" /etc/bloonix/$NAME/main.conf

echo "creating /etc/bloonix/$NAME/nginx.conf"
cp etc/bloonix/webapp/nginx.conf /etc/bloonix/$NAME/nginx.conf
sed -i "s/@@NAME@@/$NAME/g" /etc/bloonix/$NAME/nginx.conf

if [ -d "/etc/systemd/system" ] ; then
    R=/etc/systemd/system/bloonix-$NAME.service
    echo "creating /etc/systemd/system/bloonix-$NAME.service"
    cp etc/init/bloonix-webapp.service.in /etc/systemd/system/bloonix-$NAME.service
    sed -i "s/@@NAME@@/$NAME/g" /etc/systemd/system/bloonix-$NAME.service
else
    R=/etc/init.d/bloonix-$NAME
    echo "creating /etc/init.d/bloonix-$NAME"
    cp etc/init/bloonix-webapp.in /etc/init.d/bloonix-$NAME
    sed -i "s/@@NAME@@/$NAME/g" /etc/init.d/bloonix-$NAME
fi

sed -i 's!@@CACHEDIR@@!/var/cache!g' $R
sed -i 's!@@CONFDIR@@!/etc!g' $R
sed -i 's!@@LIBDIR@@!/var/lib!g' $R
sed -i 's!@@LOGDIR@@!/var/log!g' $R
sed -i 's!@@RUNDIR@@!/var/run!g' $R
sed -i 's!@@USRLIBDIR@@!/usr/lib!g' $R

