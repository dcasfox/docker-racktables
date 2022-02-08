#!/bin/sh


# This file is part of docker-racktables.
#
# docker-racktables is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# docker-racktables is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Foobar.  If not, see <https://www.gnu.org/licenses/>.


export APACHE_HTTP_PORT=${APACHE_HTTP_PORT:-"8080"}
export SERVER_ADMIN=${SERVER_ADMIN:-"admin@example.com"}

if [ -w /etc/apache2/httpd.conf ]; then
	cat /etc/apache2/httpd.conf.template | envsubst '${APACHE_HTTP_PORT} ${RACKTABLES_PATH} ${SERVER_ADMIN}' > /etc/apache2/httpd.conf
fi

if [ ! -f $RACKTABLES_PATH/wwwroot/inc/secret.php ]; then
	php /make_racktables_secret.php || exit $?
fi

if [ ! -z $RACKTABLES_INIT_DB ]; then
	php /init_racktables_db.php || exit $?
	exit 0
fi

if [ -f /run/apache2/httpd.pid ];then
	rm /run/apache2/httpd.pid
fi

# DB Init
echo "Waiting for mysql"
until mysql -u$RACKTABLES_DB_USERNAME -p$RACKTABLES_DB_PASSWORD -h$RACKTABLES_DB_HOST -P$RACKTABLES_DB_PORT -e "show databases;" &> /dev/null
do
  printf "."
  sleep 1
done
echo -e "\nmysql ready"

if [[ -z "`mysql -u$RACKTABLES_DB_USERNAME -p$RACKTABLES_DB_PASSWORD -h$RACKTABLES_DB_HOST -P$RACKTABLES_DB_PORT -BNe \"SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='${RACKTABLES_DB_NAME}'\" 2>&1`" ]]; then
   sed -i.org -e "s/racktables/$RACKTABLES_DB_NAME/" ${RACKTABLES_PATH}/wwwroot/api/racktables215_init.sql
   mysql -u$RACKTABLES_DB_USERNAME -p$RACKTABLES_DB_PASSWORD -h$RACKTABLES_DB_HOST -P$RACKTABLES_DB_PORT < ${RACKTABLES_PATH}/wwwroot/api/racktables215_init.sql
   mv -f ${RACKTABLES_PATH}/wwwroot/api/racktables215_init.sql.org ${RACKTABLES_PATH}/wwwroot/api/racktables215_init.sql
fi

exec httpd -D FOREGROUND $@
