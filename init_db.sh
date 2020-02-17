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

verbose=0

args()
{
  OPTS=$(getopt -q -o vhd:u: -l verbose,help,directory:,user: -- "$@")
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
        directory=$1
        ;;
      --user | -u)
        shift;
        db_user=$1
        ;;
      --verbose | -v)
        shift;
        verbose=1
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
  read db_user
fi

if [ -z "${DB_PASS}"]
then
  echo "Please enter DB Password"
  read_secret db_pass
else
  db_pass=${DB_PASS}
fi

echo "Creating Postgress Database folder in $directory"
mkdir $directory/guacamole_postgres_database

docker run --rm guacamole/guacamole /opt/guacamole/bin/initdb.sh --postgres > $directory/initdb.sql
echo "Starting Postgress in Docker"
if [[ -z "$verbose" ]] ; then
    exec 2>&1 >/dev/null
fi
postgress_id=$(docker run -d --rm --name pg-docker -e POSTGRES_PASSWORD=docker -v $directory/guacamole_postgres_database:/var/lib/postgresql/data -v $directory/initdb.sql:/initdb.sql postgres:12)
trap "docker stop $postgress_id" EXIT
exec > /dev/stdout
echo "Initializing database"
if [[ -z "$verbose" ]] ; then
    exec 2>&1 >/dev/null
fi
while [ "`docker inspect -f {{.State.Status}} $postgress_id`" != "running" ]; do sleep 2; done
docker exec -it pg-docker createdb -U postgres guacamole_db
docker exec -it pg-docker psql -U postgres -d guacamole_db -c "\i /initdb.sql"
docker exec -it pg-docker psql -U postgres -d guacamole_db  -c "CREATE USER "$db_user" WITH PASSWORD '"$db_pass"';"
docker exec -it pg-docker psql -U postgres -d guacamole_db  -c "GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO "$db_user";"
docker exec -it pg-docker psql -U postgres -d guacamole_db -c "GRANT SELECT,USAGE ON ALL SEQUENCES IN SCHEMA public TO "$db_user";"
docker stop $postgress_id