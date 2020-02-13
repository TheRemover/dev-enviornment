#!/bin/bash

if [ $EUID != 0 ]; then
    sudo "$0" "$@"
    exit $?
fi

read_secret()
{
  # Disable echo.
  /bin/stty -echo

  # Set up trap to ensure echo is enabled before exiting if the script
  # is terminated while echo is disabled.
  trap '/bin/stty echo' EXIT

  # Read secret.
  read "$@"
 
  # Enable echo.
  /bin/stty echo
  trap - EXIT

  # Print a newline because the newline entered by the user after
  # entering the passcode is not echoed. This ensures that the
  # next line of output begins at a new line.
  echo
}

help_menu()
{
  echo "Usage"
  echo "  Flags"
  echo "     --db-user, -u Database User"
  echo "     --directory, -d Directory"
}

args()
{
  OPTS=$(getopt -q -o hd:u: -l help,directory:,user: -- "$@")
  if [ $? != 0 ] ; then help_menu >&2 ; exit 1 ; fi
  echo $OPTS
  eval set -- "$OPTS"
  while true; do
    case "$1" in
      --help | -h)
        help_menu
        exit
        ;;
      --directory | -d)
        shift;
        DIRECTORY=$1
        ;;
      --user | -u)
        shift;
        DB_USER=$1
        ;;
      --)
        shift
        break
        ;;
    esac
    shift
  done
}
      

DIRECTORY=${PWD}

args "$@"

if [ -z "$DB_USER" ]
then
  echo "Please enter DB User"
  read DB_USER
fi

if [ -z "${DB_PASS}"]
then
  echo "Please enter DB Password"
  read_secret DB_PASS
else
  DB_PASS=${DB_PASS}
fi

mkdir $DIRECTORY/guacamole_postgres_database

docker run --rm guacamole/guacamole /opt/guacamole/bin/initdb.sh --postgres > $DIRECTORY/initdb.sql
POSTGRES_ID=$(docker run -d --rm --name pg-docker -e POSTGRES_PASSWORD=docker -v $DIRECTORY/guacamole_postgres_database:/var/lib/postgresql/data -v $DIRECTORY/initdb.sql:/initdb.sql postgres:12)
while [ "`docker inspect -f {{.State.Status}} $POSTGRES_ID`" != "running" ]; do sleep 2; done
docker exec -it pg-docker createdb -U postgres guacamole_db
docker exec -it pg-docker psql -U postgres -d guacamole_db -c "\i /initdb.sql"
docker exec -it pg-docker psql -U postgres -d guacamole_db  -c "CREATE USER "$DB_USER" WITH PASSWORD '"$DB_PASS"';"
docker exec -it pg-docker psql -U postgres -d guacamole_db  -c "GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO "$DB_USER";"
docker exec -it pg-docker psql -U postgres -d guacamole_db -c "GRANT SELECT,USAGE ON ALL SEQUENCES IN SCHEMA public TO "$DB_USER";"