#!/bin/bash

## Error handler
_error() {
  echo >&2 ":: $*"
}

########
# This script is tested on CentOS 7 and Debian 9
#######

## Detect OS Type
os_type_detect() {

        [[ -x "/usr/bin/apt-get" ]]          && _OSTYPE="DPKG" && return
        [[ -x "/usr/bin/yum" ]]              && _OSTYPE="YUM" && return

        if [[ -z "$_OSTYPE" ]]
        then
                _error "No supported package manager installed on system"
        fi

}

_os_is() {
  [[ "$_OSTYPE" = "$*" ]]
}

_exec_() {
        local _type="$1"
        shift
        if _os_is $_type
        then
                eval "$*"
        fi
}

update_packages() {
        echo "Running updates..."
        _exec_ DPKG     "apt-get update && apt-get -y upgrade"
        _exec_ YUM      "yum check-update && yum update -y"
}

install_a_package() {
        local _pkg="$1"
        echo "Installing $_pkg..."
        _exec_ DPKG     "apt-get install -y $_pkg"
        _exec_ YUM      "yum install -y $_pkg"
}

initialize() {
        os_type_detect
        echo $_OSTYPE

        update_packages
        install_a_package "telnet"
        install_a_package "expect"
        install_a_package "curl"
        install_a_package "wget"
        is_initialized=1
}

initialize_os_packages() {
	_exec_ YUM 	"yum install -y gcc"
	_exec_ YUM	"yum install -y glibc"
	_exec_ YUM	"yum install -y glibc-common"
	_exec_ YUM	"yum install -y gd"
	_exec_ YUM	"yum install -y gd-devel"
	_exec_ YUM 	"yum install -y make"
	_exec_ YUM	"yum install -y net-snmp"
	_exec_ YUM	"yum install -y unzip"

	_exec_ DPKG	"apt-get install -y build-essential"
	_exec_ DPKG	"apt-get install -y libgd-dev"
	_exec_ DPKG	"apt-get install -y unzip"
}

install_apache() {
        echo "Installing apache..."
        _exec_ YUM      "yum install -y httpd"
        _exec_ DPKG     "apt-get install -y apache2"
}

install_php() {
        echo "Installing php..."
        _exec_ YUM      "yum install -y php php-mysql"
        _exec_ DPKG     "apt-get install -y php7.0 libapache2-mod-php7.0 php7.0-mysql php7.0-gd php7.0-opcache"
        _exec_ YUM      "systemctl stop httpd"
        _exec_ YUM      "systemctl start httpd"
        _exec_ DPKG     "systemctl stop apache2"
        _exec_ DPKG     "systemctl start apache2"
}

download_nagios() {
	cd /tmp
	wget http://prdownloads.sourceforge.net/sourceforge/nagios/nagios-4.2.0.tar.gz
	wget http://nagios-plugins.org/download/nagios-plugins-2.1.2.tar.gz
}

setup_nagios_user() {
	useradd nagios
	groupadd nagcmd
	usermod -a -G nagcmd nagios

	_exec_ DPKG	"usermod -a -G nagios,nagcmd apache"
	_exec_ YUM	"usermod -a -G nagios,nagcmd www-data"
}

install_nagios() {
	cd /tmp
	tar zxvf nagios-4.2.0.tar.gz
	tar zxvf nagios-plugins-2.1.2.tar.gz

	cd nagios-4.2.0
	_exec_ YUM 	"./configure --with-command-group=nagcmd"
	_exec_ DPKG	"./configure --with-command-group=nagcmd --with-httpd-conf=/etc/apache2/"

	make all
	make install
	make install-init
	make install-config
	make install-commandmode
	make install-webconf 

	cp -R contrib/eventhandlers/ /usr/local/nagios/libexec/
	
	chown -R nagios:nagios /usr/local/nagios/libexec/eventhandlers

	/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg

	_exec_ DPKG	"a2ensite nagios"
	_exec_ DPKG	"a2enmod rewrite cgi"

	_exec_ YUM	"/etc/init.d/nagios start"
	_exec_ YUM	"systemctl stop httpd"	
	_exec_ YUM	"systemctl start httpd"	

#	_exec_ DPKG	"cp /etc/init.d/skeleton /etc/init.d/nagios"
#	_exec_ DPKG	"echo 'DESC=\"Nagios\"' >> /etc/init.d/nagios"
#	_exec_ DPKG	"echo 'NAME=nagios' >> /etc/init.d/nagios"
#	_exec_ DPKG	"echo \"DAEMON=/usr/local/nagios/bin/$NAME\" >> /etc/init.d/nagios"
#	_exec_ DPKG	"echo 'DAEMON_ARGS=\"-d /usr/local/nagios/etc/nagios.cfg\"' >> /etc/init.d/nagios"
#	_exec_ DPKG	"echo \"PIDFILE=/usr/local/nagios/var/$NAME.lock\" >> /etc/init.d/nagios"
	_exec_ DPKG	"systemctl reload apache2"
	_exec_ DPKG	"systemctl restart apache2"
	_exec_ DPKG	"/etc/init.d/nagios restart"

	htpasswd -cb /usr/local/nagios/etc/htpasswd.users nagiosadmin nagiosadmin

	cd /tmp/nagios-plugins-2.1.2
	./configure --with-nagios-user=nagios --with-nagios-group=nagios
	make
	make install
}

main() {
## Download and install requirements
	initialize
	initialize_os_packages
	install_apache
	install_php

## Download & install Nagios packages
	download_nagios
	setup_nagios_user
	install_nagios
}

main "$@"
