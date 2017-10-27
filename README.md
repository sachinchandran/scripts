
## install_wordpress.sh

 * Git clone the repo -> git clone https://github.com/sachinchandran/scripts.git
 * Inside scripts directory -> cd scripts
 * Run as root user on a fresh CentOS 7 or Debian 9 machine.
 * Installs httpd/apache2, mariadb, php and wordpress.
 * ./install_wordpress.sh --mysql --apache --php --mysqlrootpassword=foobar123 --wpdbpassword=foobar345
 * Going to http://<ip of your machine/vm> , should give you the Wordpress initialization page.
 * Go to admin by logging in using grab/Gr@bpass001

## install_nagios.sh

 * Git clone the repo -> git clone https://github.com/sachinchandran/script.git
 * Inside scripts directory -> cd scripts
 * Run as root user on a CentOS 7 or Debian 9 machine
 * ./install_nagios.sh
 * Go to http://<ip of your machine/vm>/nagios. Login using nagiosadmin/nagiosadmin
