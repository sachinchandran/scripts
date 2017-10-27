#!/bin/bash

## Error handler
_error() {
  echo >&2 ":: $*"
}

########
# This script is tested on CentOS 7
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
	_exec_ DPKG	"apt-get update && apt-get -y upgrade"
	_exec_ YUM	"yum check-update && yum update -y"
}

install_a_package() {
	local _pkg="$1"
	echo "Installing $_pkg..."
	_exec_ DPKG     "apt-get install -y $_pkg"
	_exec_ YUM      "yum install -y $_pkg"
}

install_db() {
	echo "Install DB..."
	_exec_ YUM	"yum install -y mariadb-server"
	_exec_ DPKG	"apt-get install -y software-properties-common"
	_exec_ DPKG	"apt-get install -y dirmngr"
#	_exec_ DPKG	"apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xF1656F24C74CD1D8"
#	_exec_ DPKG	"add-apt-repository 'deb [arch=amd64] http://www.ftp.saix.net/DB/mariadb/repo/10.1/debian stretch main'"
#	_exec_ DPKG	"apt-get update"
	_exec_ DPKG	"DEBIAN_FRONTEND=noninteractive && apt-get install -y mariadb-server mariadb-client"

	_exec_ DPKG	"systemctl start mariadb"
	_exec_ YUM	"systemctl start mariadb"
	_exec_ DPKG	"systemctl status mariadb"
	_exec_ YUM	"systemctl status mariadb"
	_exec_ DPKG	"systemctl enable mariadb"
	_exec_ YUM	"systemctl enable mariadb"
}

install_apache() {
	echo "Installing apache..."
	_exec_ YUM 	"yum install -y httpd"
	_exec_ DPKG	"apt-get install -y apache2"
}

install_php() {
	echo "Installing php..."
	_exec_ YUM	"yum install -y php php-mysql"
	_exec_ DPKG	"apt-get install -y php5-curl"
}

setup_wp_mysql_user() {
	echo "Initializing WordPress Database..."
        MYSQL_PASS=$1
        WP_DB_PASS=$2

        echo 'CREATE DATABASE wordpress;' | mysql -u root -p${MYSQL_PASS}
        echo "GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'localhost' IDENTIFIED BY '${WP_DB_PASS}';" | mysql -u root -p${MYSQL_PASS}
        echo "FLUSH PRIVILEGES;" | mysql -u root -p${MYSQL_PASS}
}

download_install_wp() {
	curl -O https://wordpress.org/latest.tar.gz
	mkdir -p /var/www/html
	tar -C /var/www/html/ --strip-components=1 -zxvf latest.tar.gz && rm -f latest.tar.gz
	cd /var/www/html
	mkdir wp-content/{uploads,cache}
	chown apache:apache wp-content/{uploads,cache}
}

configure_wp() {
	WP_DB_PASS=$1
	cd /var/www/html
	cp wp-config-sample.php wp-config.php
	sed -i 's@database_name_here@wordpress@' wp-config.php
	sed -i 's@username_here@wordpress@' wp-config.php
	sed -i "s@password_here@${WP_DB_PASS}@" wp-config.php
	curl https://api.wordpress.org/secret-key/1.1/salt/ >> wp-config.php	
}

setup_htaccess() {
	cd /var/www/html
	echo "# BEGIN WordPress
<IfModule mod_rewrite.c> 
   RewriteEngine On 
   RewriteBase / 
   RewriteRule ^index\.php$ - [L] 
   RewriteCond %{REQUEST_FILENAME} !-f 
   RewriteCond %{REQUEST_FILENAME} !-d 
   RewriteRule . /index.php [L] 
</IfModule> 
# END WordPress" >> .htaccess
	chmod 666 /var/www/html/.htaccess
}

open_firewall() {
	_exec_ YUM	"firewall-cmd --permanent --zone=public --add-service=http"
	_exec_ YUM 	"firewall-cmd --reload"
}

startup_apache() {
	open_firewall
	sed -i "/^<Directory \"\/var\/www\/html\">/,/^<\/Directory>/{s/AllowOverride None/AllowOverride All/g}" /etc/httpd/conf/httpd.conf
	_exec_ YUM 	"systemctl enable httpd.service"
	_exec_ YUM	"systemctl start httpd.service"
	_exec_ DPKG	"systemctl enable apache2"
	_exec_ DPKG	"systemctl start apache2"
}

initialize_wp() {
	current_ip=`ip route get 8.8.8.8 | awk 'NR==1 {print $NF}'`
	curl --data "user_name=grab&admin_password=Gr@bpass001&admin_password2=Gr@bpass001&admin_email=test@noemail.com&blog_public=checked&Submit=submit" "http://${current_ip}/wp-admin/install.php?step=2"
}

install_wordpress() {
	echo "Starting WordPress Installation..."
	MYSQL_PASS=$1
	WP_DB_PASS=$2
	
	setup_wp_mysql_user $MYSQL_PASS $WP_DB_PASS
	download_install_wp
	configure_wp $WP_DB_PASS
	setup_htaccess
	startup_apache
	initialize_wp
}

mysql_secure() {

	MYSQL_PASS=$1
	
	SECURE_MYSQL=$(expect -c "

	set timeout 10
	spawn mysql_secure_installation

	expect \"Enter current password for root (enter for none):\"
	send \"\r\"

	expect \"Set root password?\"
	send \"y\r\"

	expect \"New password:\"
  	send \"${MYSQL_PASS}\r\"

	expect \"Re-enter new password:\"
  	send \"${MYSQL_PASS}\r\"

	expect \"Remove anonymous users?\"
	send \"y\r\"

	expect \"Disallow root login remotely?\"
	send \"y\r\"
	
	expect \"Remove test database and access to it?\"
	send \"y\r\"
	
	expect \"Reload privilege tables now?\"
	send \"y\r\"
	
	expect eof
")

echo "$SECURE_MYSQL"	
}

###
### Main
###

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

usage() {
	echo "Usage:"
	echo "	./install_wordpress.sh"
	echo "		-m|--mysql 	Install Mysql"
	echo " 		-a|--apache	Install Apache"
	echo " 		-p|--php      	Install PHP"
	echo "		-h|--help 	Print this message"
	echo "		--mysqlrootpassword	MySQL root password(mandatory)"
	echo "		--wpdbpassword		MySQL DB password for Wordpress"
}

main() {
	
	if [ "$#" -eq 0 ]
	then
		usage
		exit 1
	fi
	echo "$@"

	is_initialized=0
	inst_mysql=0
	inst_apache=0
	inst_php=0

	while :;
	do
		case $1 in 
			-h|-\?|--help)
				usage
				exit 0
				;;
			-m|--mysql)
				inst_mysql=1
				shift
				;;
			-a|--apache)
				inst_apache=1
				shift
				;;
			-p|--php)
				inst_php=1
				shift
				;;
			--mysqlrootpassword=?*)
				mysqlrootpassword=${1#*=}
				shift
				;;
			--mysqlrootpassword=)
				printf '%s\n' 'ERROR: --mysqlrootpassword should have a value!' >&2
				usage
				exit 1
				;;
			--mysqlrootpassword)
				printf '%s\n' 'ERROR: --mysqlrootpassword should have a value!' >&2
				usage
				exit 1
				;;
			--wpdbpassword=?*)
				wpdbpassword=${1#*=}
				shift
				;;
			--wpdbpassword=)
				printf '%s\n' 'ERROR: --wpdbpassword should have a value!' >&2
				usage
				exit 1
				;;
			--wpdbpassword)
				printf '%s\n' 'ERROR: --wpdbpassword should have a value!' >&2
                                usage
                                exit 1
                                ;;
			--)
            			shift
            			break
            			;;
        		-?*)
            			printf '%s\n' 'WARN: Unknown option (ignored): %s\n' >&2
				usage
				exit 1
            			;;
        		*)
            			break
    		esac

    		#shift
	done

#	while getopts 'mysql,apache,php,help' flag; do
#		case "${flag}" in
#			mysql)	if [ ${is_initialized} -eq 0 ]
#				then
#					initialize
#				fi
#				install_db
#				mysql_password="$1"
#				mysql_secure $mysql_password
#				;;
#			apache)	if [ ${is_initialized} -eq 0 ]
#                                then
#                                        initialize
#                                fi
#				install_apache
#				;;
#			php) 	if [ ${is_initialized} -eq 0 ]
#                                then
#                                        initialize
#                                fi
#				install_php
#				;;
#			help)	usage
#				exit 0
#				;;
#			*)	usage
#				exit 1
#				;;
#		esac
#	done
#	install_db

#	mysql_password="$1"

	if [ -z ${mysqlrootpassword} ]
	then
		printf '%s\n' 'ERROR: mysqlrootpassword is not defined!' >&2
		usage
		exit 1
	fi

	if [ -z ${wpdbpassword} ]
	then
		printf '%s\n' 'ERROR: wpdbpassword is not defined!' >&2
		usage
		exit 1
	fi

	if [ ${is_initialized} -eq 0 ]
        then
       		initialize
        fi

	if [ ${inst_mysql} -eq 1 ]
	then
		install_db
		mysql_secure $mysqlrootpassword
	fi
	
	if [ ${inst_apache} -eq 1 ]
	then
		install_apache
	fi
	
	if [ ${inst_php} -eq 1 ]
	then
		install_php
	fi


#	wordpress_db_password="$2"

#	mysql_secure $mysql_password

#	install_apache
#	install_php

	install_wordpress $mysqlrootpassword $wpdbpassword
}

main "$@"
