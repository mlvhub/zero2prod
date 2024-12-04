#!/usr/bin/env bash

set -x
set -eo pipefail

DB_PORT=${POSTGRES_PORT:-5432}
SUPERUSER=${SUPERUSER:-postgres}
SUPERUSER_PWD="${SUPERUSER_PWD:-password}"
APP_USER="${APP_USER:-app}"
APP_USER_PWD="${APP_USER_PWD:-secret}"
APP_DB_NAME="${APP_DB_NAME:-newsletter}"

CONTAINER_NAME="postgres"
if [[ -z "${SKIP_DOCKER}" ]] 
then
    docker run \
        --env POSTGRES_USER=${SUPERUSER} \
        --env POSTGRES_PASSWORD=${SUPERUSER_PWD} \
        --health-cmd="pg_isready -U ${SUPERUSER} || exit 1" \
        --health-interval=1s \
        --health-timeout=5s \
        --health-retries=5 \
        --publish "${DB_PORT}:5432" \
        --detach \
        --rm \
        --name "${CONTAINER_NAME}" \
        postgres -N 1000

    until [ \
        "$(docker inspect -f "{{.State.Health.Status}}" ${CONTAINER_NAME})" = "healthy"
    ]; do
        >&2 echo "Postgres is still unavailable - sleeping"
        sleep 1
    done

    echo "Postgres is up and running on port ${DB_PORT}!"

    CREATE_QUERY="CREATE USER ${APP_USER} WITH PASSWORD '${APP_USER_PWD}';"
    docker exec -it "${CONTAINER_NAME}" psql -U "${SUPERUSER}" -c "${CREATE_QUERY}"

    GRANT_QUERY="ALTER USER ${APP_USER} CREATEDB;"
    docker exec -it "${CONTAINER_NAME}" psql -U "${SUPERUSER}" -c "${GRANT_QUERY}"
fi

DATABASE_URL="postgres://${APP_USER}:${APP_USER_PWD}@localhost:${DB_PORT}/${APP_DB_NAME}"
export DATABASE_URL
sqlx database create
sqlx migrate run

echo "Postgres has been migrated, ready to go!"
