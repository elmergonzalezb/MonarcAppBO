#! /usr/bin/env bash

PATH_TO_MONARC='/home/ubuntu/monarc'

APPENV='local'
ENVIRONMENT='development'

DBHOST='localhost'
DBNAME_COMMON='monarc_common'
DBNAME_MASTER='monarc_master'
DBUSER_ADMIN='root'
DBPASSWORD_ADMIN='root'
DBUSER_MONARC='sqlmonarcuser'
DBPASSWORD_MONARC='sqlmonarcuser'

upload_max_filesize=200M
post_max_size=50M
max_execution_time=100
max_input_time=223
memory_limit=512M
PHP_INI=/etc/php/7.2/apache2/php.ini
X_DEBUG_CFG=/etc/php/7.2/apache2/conf.d/20-xdebug.ini
MARIA_DB_CFG=/etc/mysql/mariadb.conf.d/50-server.cnf

export DEBIAN_FRONTEND=noninteractive
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
locale-gen en_US.UTF-8
dpkg-reconfigure locales


echo -e "\n--- Installing now… ---\n"

echo -e "\n--- Updating packages list ---\n"
apt-get update && apt-get -y upgrade

echo -e "\n--- Install base packages… ---\n"
apt-get -y install vim zip unzip git gettext > /dev/null


echo -e "\n--- Install MariaDB specific packages and settings… ---\n"
apt-get -y install mariadb-server mariadb-client > /dev/null
# Secure the MariaDB installation (especially by setting a strong root password)
systemctl restart mariadb.service > /dev/null
sleep 5
apt-get -y install expect > /dev/null
## do we need to spawn mysql_secure_install with sudo in future?
expect -f - <<-EOF
  set timeout 10
  spawn mysql_secure_installation
  expect "Enter current password for root (enter for none):"
  send -- "\r"
  expect "Set root password?"
  send -- "y\r"
  expect "New password:"
  send -- "${DBPASSWORD_ADMIN}\r"
  expect "Re-enter new password:"
  send -- "${DBPASSWORD_ADMIN}\r"
  expect "Remove anonymous users?"
  send -- "y\r"
  expect "Disallow root login remotely?"
  send -- "y\r"
  expect "Remove test database and access to it?"
  send -- "y\r"
  expect "Reload privilege tables now?"
  send -- "y\r"
  expect eof
EOF
sudo apt-get purge -y expect php-xdebug > /dev/null 2>&1

echo -e "\n--- Configuring… ---\n"
sed -i "s/skip-external-locking/#skip-external-locking/g" $MARIA_DB_CFG
sed -i "s/.*bind-address.*/bind-address = 0.0.0.0/" $MARIA_DB_CFG

echo -e "\n--- Setting up our MariaDB user for MONARC… ---\n"
mysql -u root -p$DBPASSWORD_ADMIN -e "CREATE USER '$DBUSER_MONARC'@'%' IDENTIFIED BY '$DBPASSWORD_MONARC';"
mysql -u root -p$DBPASSWORD_ADMIN -e "GRANT ALL PRIVILEGES ON * . * TO '$DBUSER_MONARC'@'%';"
mysql -u root -p$DBPASSWORD_ADMIN -e "FLUSH PRIVILEGES;"
systemctl restart mariadb.service > /dev/null

echo -e "\n--- Installing PHP-specific packages… ---\n"
apt-get -y install php apache2 libapache2-mod-php php-curl php-gd php-mysql php-pear php-apcu php-xml php-mbstring php-intl php-imagick php-zip php-xdebug > /dev/null

echo -e "\n--- Configuring PHP… ---\n"
for key in upload_max_filesize post_max_size max_execution_time max_input_time memory_limit
do
 sed -i "s/^\($key\).*/\1 = $(eval echo \${$key})/" $PHP_INI
done

echo -e "\n--- Configuring Xdebug for development ---\n"
cat > $X_DEBUG_CFG <<EOF
zend_extension=xdebug.so
xdebug.remote_enable=1
xdebug.remote_connect_back=1
xdebug.idekey=IDEKEY
EOF

echo -e "\n--- Enabling mod-rewrite and ssl… ---\n"
a2enmod rewrite > /dev/null
a2enmod ssl > /dev/null

echo -e "\n--- Allowing Apache override to all ---\n"
sed -i "s/AllowOverride None/AllowOverride All/g" /etc/apache2/apache2.conf


echo -e "\n--- Installing composer… ---\n"
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer > /dev/null
if [ $? -ne 0 ]; then
    echo "\nERROR: unable to install composer\n"
    exit 1;
fi
composer self-update

echo -e "\n--- Installing MONARC… ---\n"
cd $PATH_TO_MONARC
git config core.fileMode false

echo -e "\n--- Retrieving MONARC libraries… ---\n"
composer install -o


# Make modules symlinks.
mkdir -p module/Monarc
cd module/Monarc
ln -s ./../../vendor/monarc/core Core
ln -s ./../../vendor/monarc/backoffice BackOffice
cd $PATH_TO_MONARC


mkdir -p $PATH_TO_MONARC/data/cache
mkdir -p $PATH_TO_MONARC/data/LazyServices/Proxy
mkdir -p $PATH_TO_MONARC/data/DoctrineORMModule/Proxy
chown -R www-data data
chmod -R 777 data


# Front-end
mkdir node_modules
cd node_modules
git clone --config core.filemode=false https://github.com/monarc-project/ng-backoffice.git ng_backoffice > /dev/null
if [ $? -ne 0 ]; then
    echo "\nERROR: unable to clone the ng-backoffice repository\n"
    exit 1;
fi
git clone --config core.filemode=false https://github.com/monarc-project/ng-anr.git ng_anr > /dev/null
if [ $? -ne 0 ]; then
    echo "\nERROR: unable to clone the ng-anr repository\n"
    exit 1;
fi
cd ..


chown -R www-data $PATH_TO_MONARC
chgrp -R www-data $PATH_TO_MONARC
chmod -R 700 $PATH_TO_MONARC


echo -e "\n--- Add a VirtualHost for MONARC ---\n"
cat > /etc/apache2/sites-enabled/000-default.conf <<EOF
<VirtualHost *:80>
    ServerName localhost
    DocumentRoot $PATH_TO_MONARC/public

    <Directory $PATH_TO_MONARC/public>
        DirectoryIndex index.php
        AllowOverride All
        Require all granted
    </Directory>

    SetEnv APP_ENV $APPENV
    SetEnv APP_DIR $PATH_TO_MONARC

    SetEnv DB_HOST $DBHOST
    SetEnv DB_NAME $DBNAME
    SetEnv DB_USER $DBUSER
    SetEnv DB_PASS $DBPASSWD
</VirtualHost>
EOF
echo -e "\n--- Restarting Apache… ---\n"
systemctl restart apache2.service > /dev/null


echo -e "\n--- Configuration of MONARC database connection ---\n"
cat > config/autoload/local.php <<EOF
<?php
return array(
    'doctrine' => array(
        'connection' => array(
            'orm_default' => array(
                'params' => array(
                    'host' => '$DBHOST',
                    'user' => '$DBUSER_MONARC',
                    'password' => '$DBPASSWORD_MONARC',
                    'dbname' => '$DBNAME_COMMON',
                ),
            ),
            'orm_cli' => array(
                'params' => array(
                    'host' => '$DBHOST',
                    'user' => '$DBUSER_MONARC',
                    'password' => '$DBPASSWORD_MONARC',
                    'dbname' => '$DBNAME_MASTER',
                    ),
                ),
            ),
        ),

    /* Link with (ModuleCore)
    config['languages'] = [
        'fr' => array(
            'index' => 1,
            'label' => 'Français'
        ),
        'en' => array(
            'index' => 2,
            'label' => 'English'
        ),
        'de' => array(
            'index' => 3,
            'label' => 'Deutsch'
        ),
    ]
    */
    'activeLanguages' => array('fr','en','de','nl'),

    'monarc' => array(
        'ttl' => 60, // timeout
        'salt' => '', // salt privé pour chiffrement pwd
    ),
);
EOF


echo -e "\n--- Creation of the data bases… ---\n"
mysql -u $DBUSER_MONARC -p$DBPASSWORD_MONARC -e "CREATE DATABASE monarc_master DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;" > /dev/null
mysql -u $DBUSER_MONARC -p$DBPASSWORD_MONARC -e "CREATE DATABASE monarc_common DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;" > /dev/null
echo -e "\n--- Populating MONARC DB… ---\n"
mysql -u $DBUSER_MONARC -p$DBPASSWORD_MONARC monarc_common < db-bootstrap/monarc_structure.sql > /dev/null
mysql -u $DBUSER_MONARC -p$DBPASSWORD_MONARC monarc_common < db-bootstrap/monarc_data.sql > /dev/null


echo -e "\n--- Installation of Grunt… ---\n"
curl -sL https://deb.nodesource.com/setup_13.x | sudo bash -
sudo apt-get install -y nodejs
sudo npm install -g grunt-cli


echo -e "\n--- Update the project… ---\n"
/bin/bash ./scripts/update-all.sh > /dev/null


echo -e "\n--- Create initial user and client ---\n"
php ./vendor/robmorgan/phinx/bin/phinx seed:run -c ./module/Monarc/BackOffice/migrations/phinx.php > /dev/null


echo -e "\n--- Restarting Apache… ---\n"
systemctl restart apache2.service > /dev/null



echo -e "\n--- MONARC is ready! Point your Web browser to http://127.0.0.1:5000 ---\n"
