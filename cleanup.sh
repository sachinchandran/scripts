#!/bin/bash

systemctl stop mariadb
systemctl stop httpd

yum erase mariadb
yum erase httpd

rm -rf /var/www/html/*
rm -f /var/www/html/.htaccess
rm -rf /var/lib/mysql/
