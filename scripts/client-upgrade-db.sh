#!/bin/bash

# Usage: ./scripts/client-upgrade-db.sh <module> <hostname> <user> <password> <db>
# Example: ./scripts/client-upgrade-db.sh Monarc\BackOffice localhost root derp monarc_backoffice

MODULE=$1
SQLHOST=$2
SQLUSER=$3
SQLPASS=$4
SQLBASE=$5

path=""
case $MODULE in
    "Monarc/Core"|"core")
        path="module/MonarcCore"
        if [ ! -d $path ]; then
            path="vendor/monarc/core"
        fi
        ;;
    "Monarc/BackOffice"|"backoffice")
        path="module/Monarc/BackOffice"
        if [ ! -d $path ]; then
            path="vendor/monarc/backoffice"
        fi
        ;;
    *)
        echo "Unknow module"
        exit 1
        ;;
esac

cat <<EOF >/tmp/conf.tmp.php
<?php
return array(
    'paths' => array(
        'migrations' => '$path/migrations/db',
        'seeds' => '$path/migrations/seeds',
    ),
    'environments' => array(
        'default_migration_table' => 'phinxlog',
        'default_database' => 'cli',
        'cli' => array(
            'adapter' => 'mysql',
            'host' => '$SQLHOST',
            'name' => '$SQLBASE',
            'user' => '$SQLUSER',
            'pass' => '$SQLPASS',
            'port' => 3306,
            'charset' => 'utf8',
        ),
    ),
);

EOF


php ./vendor/robmorgan/phinx/bin/phinx migrate -c /tmp/conf.tmp.php
rm /tmp/conf.tmp.php
