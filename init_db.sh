#!/bin/bash

read_secret()
{
    # Disable echo.
    stty -echo

    # Set up trap to ensure echo is enabled before exiting if the script
    # is terminated while echo is disabled.
    trap 'stty echo' EXIT

    # Read secret.
    read "$@"

    # Enable echo.
    stty echo
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
   echo "     --db-user, -u=Database User"
   echo "     --path, -p=Path"
}

while [ ! $# -eq 0 ]
do
        case "$1" in
                --help | -h)
                        help_menu
                        exit
                        ;;
                --user | -u)
                        secretopt
                        exit
                        ;;
        esac
        shift
done

PATH=${BASEDIR}
echo "Please enter DB User"
read DB_USER
echo "Please enter DB Password"
read_secret DB_PASS

mkdir $PATH/guacamole_postgres_database

docker run --rm guacamole/guacamole /opt/guacamole/bin/initdb.sh --postgres > $PATH/initdb.sql
POSTGRES_ID=docker run --rm --name pg-docker -e POSTGRES_PASSWORD=docker -v $PATH/guacamole_postgres_database:/var/lib/postgresql/data -v $PATH/initdb.sql:/initdb.sql postgres:12
while [ "`docker inspect -f {{.State.Health.Status}} $POSTGRES_ID`" != "healthy" ]; do sleep 2; done
docker exec -it pg-docker createdb -U postgres guacamole_db
docker exec -it pg-docker psql -U postgres -d guacamole_db \i /initdb.sql
docker exec -it pg-docker psql -U postgres -d guacamole_db  CREATE USER $DB_USER WITH PASSWORD "'"$DB_PASS"'";
docker exec -it pg-docker psql -U postgres -d guacamole_db  GRANT SELECT,INSERT,UPDATE,DELETE ON ALL TABLES IN SCHEMA public TO $DB_USER;
docker exec -it pg-docker psql -U postgres -d guacamole_db GRANT SELECT,USAGE ON ALL SEQUENCES IN SCHEMA public TO $DB_USER;