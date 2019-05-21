#!/bin/bash
# docker-entrypoint.sh

set -e

while ! nc -z $DB_HOST $DB_PORT;
   do
      echo PostgreSQL server $DB_HOST is not ready on $DB_PORT;
      sleep 1;
done;

echo PostgreSQL server $DB_HOST is ready on $DB_PORT - starting wildfly /opt/jboss/wildfly/bin/standalone.sh;

exec sh /opt/jboss/wildfly/bin/standalone.sh "$@"
