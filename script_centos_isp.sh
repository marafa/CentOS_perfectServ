#!/bin/bash
clear
echo "   _____           _    ____   _____                    __          _    _____                 "
echo "  / ____|         | |  / __ \ / ____|                  / _|        | |  / ____|                "
echo " | |     ___ _ __ | |_| |  | | (___    _ __   ___ _ __| |_ ___  ___| |_| (___   ___ _ ____   __"
echo " | |    / _ \ '_ \| __| |  | |\___ \  | '_ \ / _ \ '__|  _/ _ \/ __| __|\___ \ / _ \ '__\ \ / /"
echo " | |___|  __/ | | | |_| |__| |____) | | |_) |  __/ |  | ||  __/ (__| |_ ____) |  __/ |   \ V / "
echo "  \_____\___|_| |_|\__|\____/|_____/  | .__/ \___|_|  |_| \___|\___|\__|_____/ \___|_|    \_/  "
echo "                                      | |  v0.1beta"
echo "                                      |_|  for auto hosting simply & easily"
echo ""
echo "To view details: \"tail -f log_script.log\""
echo ""
echo -e "\033[31mThis script will modify your configuration server.\033[0m"
echo -e "\033[31mIt works with NO guarantees\033[0m"
echo -e "\033[31mDo you want to continue? (type YES in UPPERCASE)\033[0m"
read areyousure
if [ $areyousure != "YES" ]
then exit 1
else echo -e "\033[31mStarting script `basename $0` ...\033[0m"
fi

LOG=/root/log_script.log

configure_zeroconf() {
echo "NOZEROCONF=yes" >> /etc/sysconfig/network
}

# Configuration of repository for CentOS
configure_repo() {
  yum -y install wget >> $LOG 2>&1

  echo -e "[\033[33m*\033[0m] Installing & configuring epel, rpmforge repos..."
  rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY* >> $LOG 2>&1 || echo -e "[\033[31mX\033[0m] Error importing key /etc/pki/rpm-gpg/RPM-GPG-KEY*"
  rpm --import http://dag.wieers.com/rpm/packages/RPM-GPG-KEY.dag.txt >> $LOG 2>&1 || echo -e "[\033[31mX\033[0m] Error importing key RPM-GPG-KEY.dag"
  cd /tmp
  wget http://pkgs.repoforge.org/rpmforge-release/rpmforge-release-0.5.2-2.el6.rf.x86_64.rpm >> $LOG 2>&1 || echo -e "[\033[31mX\033[0m] Error downloading RPMForge rpm"
  rpm -ivh rpmforge-release-0.5.2-2.el6.rf.x86_64.rpm >> $LOG 2>&1 || echo -e "[\033[31mX\033[0m] Error installing rpmforge rpm"

  rpm --import https://fedoraproject.org/static/0608B895.txt >> $LOG 2>&1  || echo -e "[\033[31mX\033[0m] Error importing epel key"
  wget http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm >> $LOG 2>&1  || echo -e "[\033[31mX\033[0m] Error downloading epel repo rpm"
  rpm -ivh epel-release-6-8.noarch.rpm >> $LOG 2>&1  || echo -e "[\033[31mX\033[0m] Error installing epel repo rpm"

  #rpm --import http://rpms.famillecollet.com/RPM-GPG-KEY-remi >> $LOG 2>&1  || echo -e "[\033[31mX\033[0m] Error import key remi"
  #rpm -ivh http://rpms.famillecollet.com/enterprise/remi-release-6.rpm >> $LOG 2>&1  || echo -e "[\033[31mX\033[0m] Error installing rpm remi"

  yum install yum-priorities -y >> $LOG 2>&1 echo -e "[\033[31mX\033[0m] Error installing yum-priorites"
  awk 'NR== 2 { print "priority=10" } { print }' /etc/yum.repos.d/epel.repo > /tmp/epel.repo
  rm /etc/yum.repos.d/epel.repo -f
  mv /tmp/epel.repo /etc/yum.repos.d

  #sed -i -e "0,/5/s/enabled=0/enabled=1/" /etc/yum.repos.d/remi.repo
}

update_system() {
  echo -e "[\033[33m*\033[0m] Updating full system (it can take some minutes...)"
  yum update -y >> $LOG 2>&1 ||  echo -e "[\033[31mX\033[0m] Error in yum update"
}

install_required_packages() {
  echo -e "[\033[33m*\033[0m] Installing required packages"
  yum install -y vim htop iftop nmap screen git expect >> $LOG 2>&1 || echo -e "[\033[31mX\033[0m] Error installing base packages"
  echo -e "[\033[33m*\033[0m] Installing Development Tools"
  yum groupinstall -y 'Development Tools'  >> $LOG 2>&1 || echo -e "[\033[31mX\033[0m] Error installing Dev Tools metapackage"
}

install_ntpd() {
  echo -e "[\033[33m*\033[0m] Installing and configure NTPD"
  yum install -y ntp  >> $LOG 2>&1
  chkconfig ntpd on >> $LOG 2>&1
}

disable_fw() {
  echo -e "[\033[33m*\033[0m] Disabling Firewall (for installation time)"
  service iptables save >> $LOG 2>&1
  service iptables stop >> $LOG 2>&1
  chkconfig iptables off >> $LOG 2>&1
}

disable_selinux() {
  echo -e "[\033[33m*\033[0m] Disabling SELinux"
  sed -i -e 's/SELINUX=enforcing/SELINUX=disabled' /etc/selinux/config >> $LOG 2>&1
  setenforce 0 >> $LOG 2>&1
}


install_mysql() {
  echo -e "[\033[33m*\033[0m] Installing MYSQL Server"
  yum install mysql mysql-server -y >> $LOG 2>&1
  chkconfig --levels 235 mysqld on >> $LOG 2>&1
  /etc/init.d/mysqld start >> $LOG 2>&1

  echo "Type the MySQL root password you want to set: "
  read -s mysqlrootpw

  SECURE_MYSQL=$(expect -c "
  
  set timeout 10
  spawn mysql_secure_installation
  
  expect \"Enter current password for root (enter for none):\"
  send \"\r\"
  
  expect \"Set root password?\"
  send \"y\r\"

  expect \"New password:\"
  send \"$mysqlrootpw\r\"

  expect \"Re-enter new password:\"
  send \"$mysqlrootpw\r\"
  
  expect \"Remove anonymous users?\"
  send \"y\r\"
  
  expect \"Disallow root login remotely?\"
  send \"y\r\"
  
  expect \"Remove test database and access to it?\"
  send \"y\r\"
  
  expect \"Reload privilege tables now?\"
  send \"y\r\"
  
  expect eof
  " >> $LOG)

  echo "$SECURE_MYSQL" >> $LOG 2>&1 || echo -e "[\033[31mX\033[0m] Error configuring MySQL"
}
  
install_dovecot() {
  echo -e "[\033[33m*\033[0m] Installing DOVECOT Server"
  yum install dovecot dovecot-mysql -y >> $LOG 2>&1
  chkconfig --levels 235 dovecot on >> $LOG 2>&1
  /etc/init.d/dovecot start >> $LOG 2>&1
}
  
install_postfix() {  
  echo -e "[\033[33m*\033[0m] Installing Postfix Server"
  yum install postfix -y >> $LOG 2>&1
  chkconfig --levels 235 postfix on >> $LOG 2>&1
  /etc/init.d/postfix restart >> $LOG 2>&1
}
  
install_getmail() {
  echo -e "[\033[33m*\033[0m] Installing getmail"
  yum install getmail -y >> $LOG 2>&1
}

install_clamav() {
  echo -e "[\033[33m*\033[0m] Installing Antivirus/Antispam Layer (it can take some times downloading AV databases)"
  yum install -y amavisd-new spamassassin clamav clamd unzip bzip2 unrar perl-DBD-mysql --disablerepo=epel >> $LOG 2>&1
  sa-update >> $LOG 2>&1
  chkconfig --levels 235 amavisd on >> $LOG 2>&1
  /usr/bin/freshclam >> $LOG 2>&1
  /etc/init.d/amavisd start >> $LOG 2>&1
}

install_httpd(){
  echo -e "[\033[33m*\033[0m] Installing & Configuring Apache Webserver"
  yum install httpd mod_ssl --enablerepo=epel -y >> $LOG 2>&1	
}

install_nginx() {
  echo -e "[\033[33m*\033[0m] Installing & Configuring NGINX Webserver"
  yum install nginx --enablerepo=epel -y >> $LOG 2>&1

  awk 'NR== 21 { print "map $scheme $https {" ; print "default off;" ; print "https on;"; print "}"} { print }' /etc/nginx/nginx.conf > /tmp/nginx.conf
  rm -f /etc/nginx/nginx.conf
  mv /tmp/nginx.conf /etc/nginx


  chkconfig --del httpd >> $LOG 2>&1
  /etc/init.d/httpd stop >> $LOG 2>&1
  chkconfig --levels 235 nginx on >> $LOG 2>&1
  /etc/init.d/nginx start >> $LOG 2>&1
  yum install php php-fpm php-cli php-mysql php-gd php-imap php-ldap php-odbc php-pear php-xml php-xmlrpc php-pecl-apc php-magickwand php-magpierss php-mbstring php-mcrypt php-mssql php-shout php-snmp php-soap php-tidy -y >> $LOG 2>&1
  sed -i -e 's/; cgi.fix_pathinfo=0/cgi.fix_pathinfo=0/' /etc/php.ini >> $LOG 2>&1
  chkconfig --levels 235 php-fpm on >> $LOG 2>&1
  /etc/init.d/php-fpm start >> $LOG 2>&1
  yum install -y fcgi-devel >> $LOG 2>&1

  echo -e "  [\033[33m*\033[0m] Compil fcgiwrap (cause it don't exist in rpm for CentOS)"
  cd /usr/local/src/
  git clone git://github.com/gnosek/fcgiwrap.git >> $LOG 2>&1
  echo -e "  [\033[32m*\033[0m] Gitting sources done"
  cd fcgiwrap
  autoreconf -i >> $LOG 2>&1
  ./configure >> $LOG 2>&1
  make >> $LOG 2>&1
  make install >> $LOG 2>&1
  echo -e "  [\033[32m*\033[0m] fcgiwrap done"

  yum install spawn-fcgi -y >> $LOG 2>&1
  echo -e "[\033[33m*\033[0m] Setting /etc/sysconfig/spawn-fcgi configuration file"
  cat <<EOF > /etc/sysconfig/spawn-fcgi
  # You must set some working options before the "spawn-fcgi" service will work.
  # If SOCKET points to a file, then this file is cleaned up by the init script.
  #
  # See spawn-fcgi(1) for all possible options.
  #
  # Example :
  #SOCKET=/var/run/php-fcgi.sock
  #OPTIONS="-u apache -g apache -s $SOCKET -S -M 0600 -C 32 -F 1 -P /var/run/spawn-fcgi.pid -- /usr/bin/php-cgi"

  FCGI_SOCKET=/var/run/fcgiwrap.socket
  FCGI_PROGRAM=/usr/local/sbin/fcgiwrap
  FCGI_USER=apache
  FCGI_GROUP=apache
  FCGI_EXTRA_OPTIONS="-M 0770"
  OPTIONS="-u $FCGI_USER -g $FCGI_GROUP -s $FCGI_SOCKET -S $FCGI_EXTRA_OPTIONS -F 1 -P /var/run/spawn-fcgi.pid -- $FCGI_PROGRAM"
EOF

  usermod -a -G apache nginx >> $LOG 2>&1
  chkconfig --levels 235 spawn-fcgi on >> $LOG 2>&1
  /etc/init.d/spawn-fcgi start >> $LOG 2>&1
}

install_pma() {
  echo -e "[\033[33m*\033[0m] Setting PHPmyAdmin"
  yum install phpmyadmin -y >> $LOG 2>&1
  sed -i -e "s/$cfg['Servers'][$i]['auth_type'] = 'cookie';/$cfg['Servers'][$i]['auth_type'] = 'http';/" /usr/share/phpmyadmin/config.inc.php 2>&1
  }

install_mailman() {
  echo -e "[\033[33m*\033[0m] Setting Mailman"
  yum install mailman -y >> $LOG 2>&1
  /usr/lib/mailman/bin/newlist mailman

  cat <<EOF >> /etc/aliases
  mailman:              "|/usr/lib/mailman/mail/mailman post mailman"
  mailman-admin:        "|/usr/lib/mailman/mail/mailman admin mailman"
  mailman-bounces:      "|/usr/lib/mailman/mail/mailman bounces mailman"
  mailman-confirm:      "|/usr/lib/mailman/mail/mailman confirm mailman"
  mailman-join:         "|/usr/lib/mailman/mail/mailman join mailman"
  mailman-leave:        "|/usr/lib/mailman/mail/mailman leave mailman"
  mailman-owner:        "|/usr/lib/mailman/mail/mailman owner mailman"
  mailman-request:      "|/usr/lib/mailman/mail/mailman request mailman"
  mailman-subscribe:    "|/usr/lib/mailman/mail/mailman subscribe mailman"
  mailman-unsubscribe:  "|/usr/lib/mailman/mail/mailman unsubscribe mailman"
EOF

  newaliases >> $LOG
  /etc/init.d/postfix restart >> $LOG 2>&1
  chkconfig --levels 235 mailman on >> $LOG 2>&1
  /etc/init.d/mailman start >> $LOG 2>&1
  cd /usr/lib/mailman/cgi-bin/
  ln -s ./ mailman
}

install_ftpd() {
  echo -e "[\033[33m*\033[0m] Setting PureFTPD"
  yum install pure-ftpd -y >> $LOG 2>&1
  chkconfig --levels 235 pure-ftpd on >> $LOG 2>&1
  /etc/init.d/pure-ftpd start >> $LOG 2>&1
  yum install openssl >> $LOG 2>&1
}

install_bind() {
  echo -e "[\033[33m*\033[0m] Setting Bind"
  yum install bind bind-utils -y >> $LOG 2>&1

  cp /etc/named.conf /etc/named.conf_bak
  cat <<EOF > /etc/named.conf
  //
  // named.conf
  //
  // Provided by Red Hat bind package to configure the ISC BIND named(8) DNS
  // server as a caching only nameserver (as a localhost DNS resolver only).
  //
  // See /usr/share/doc/bind*/sample/ for example named configuration files.
  //
  options {
	  listen-on port 53 { any; };
	  listen-on-v6 port 53 { any; };
	  directory       "/var/named";
	  dump-file       "/var/named/data/cache_dump.db";
	  statistics-file "/var/named/data/named_stats.txt";
	  memstatistics-file "/var/named/data/named_mem_stats.txt";
	  allow-query     { any; };
	  recursion yes;
	  };
  logging {
	  channel default_debug {
		  file "data/named.run";
		  severity dynamic;
	};
  };

  zone "." IN {
	  type hint;
	  file "named.ca";
  };

  include "/etc/named.conf.local";

EOF

  touch /etc/named.conf.local

  chkconfig --levels 235 named on >> $LOG 2>&1
  /etc/init.d/named start >> $LOG 2>&1
}

install_awstat() {
  echo -e "[\033[33m*\033[0m] Setting statistics stuffs"
  yum install webalizer awstats perl-DateTime-Format-HTTP perl-DateTime-Format-Builder -y >> $LOG 2>&1
}

install_jailkit() {
  echo -e "[\033[33m*\033[0m] Setting Jailkit"
  #Jailkit
  cd /tmp
  wget http://olivier.sessink.nl/jailkit/jailkit-2.16.tar.gz >> $LOG 2>&1
  tar xvfz jailkit-2.16.tar.gz >> $LOG 2>&1
  cd jailkit-2.16
  ./configure >> $LOG 2>&1
  make >> $LOG 2>&1
  make install >> $LOG 2>&1
  cd ..
  rm -rf jailkit-2.16* >> $LOG 2>&1
}

install_fail2ban() {
  echo -e "[\033[33m*\033[0m] Setting fail2ban & RootkitHunter"
  yum install fail2ban -y >> $LOG 2>&1
  chkconfig --levels 235 fail2ban on >> $LOG 2>&1
  /etc/init.d/fail2ban start >> $LOG 2>&1
}

install_rkhunter() {
  yum install rkhunter -y >> $LOG 2>&1
}

configure_zeroconf
configure_repo
update_system
install_required_packages
install_ntpd
disable_fw
disable_selinux
install_mysql
install_dovecot
install_postfix
install_getmail
install_clamav
install_nginx
#install_httpd
install_pma
install_mailman
install_ftpd
install_bind
install_awstat
install_jailkit
install_fail2ban
install_rkhunter

#ISPConfig
echo -e "[\033[33m*\033[0m] Installing ISPConfig Stable version"
cd /tmp
wget http://www.ispconfig.org/downloads/ISPConfig-3-stable.tar.gz >> $LOG 2>&1
tar xfz ISPConfig-3-stable.tar.gz >> $LOG 2>&1
cd ispconfig3_install/install/
php install.php
