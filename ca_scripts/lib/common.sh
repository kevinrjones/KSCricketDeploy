#!/bin/sh

# Shared configuration for the CricketArchive fetch/update runners.
# Keep local values in ca_scripts/config.env and credentials.env; both files
# are intentionally ignored by git.

ca_init() {
    CA_COMPONENT_DIR=$1
    CA_ROOT=${2:-$(CDPATH= cd -- "$CA_COMPONENT_DIR/.." && pwd)}

    config_file=${CA_CONFIG_FILE:-$CA_ROOT/config.env}
    if [ -f "$config_file" ]; then
        # shellcheck disable=SC1090
        . "$config_file"
    fi

    credentials_file=${CA_CREDENTIALS_FILE:-$CA_ROOT/credentials.env}
    if [ -f "$credentials_file" ]; then
        # shellcheck disable=SC1090
        . "$credentials_file"
    fi

    CA_ARCHIVE_DIR=${CA_ARCHIVE_DIR:-$HOME/CricketArchive/Archive}
    CA_DB_HOST=${CA_DB_HOST:-127.0.0.1}
    CA_DB_PORT=${CA_DB_PORT:-3306}
    CA_DB_NAME=${CA_DB_NAME:-cricketarchive}
    CA_DB_USER=${CA_DB_USER:-}
    CA_DUMP_DIR=${CA_DUMP_DIR:-$HOME/sql}
    CA_DUMP_FILE=${CA_DUMP_FILE:-$CA_DUMP_DIR/cricketarchive-upload.sql.gz}

    if [ -n "${CA_DB_USER_FILE:-}" ] && [ -z "${CA_DB_USER:-}" ]; then
        CA_DB_USER=$(cat "$(ca_resolve_path "$CA_DB_USER_FILE")")
    fi
    if [ -n "${CA_DB_PASSWORD_FILE:-}" ] && [ -z "${CA_DB_PASSWORD:-}" ]; then
        CA_DB_PASSWORD=$(cat "$(ca_resolve_path "$CA_DB_PASSWORD_FILE")")
    fi
    CA_DB_USER=${CA_DB_USER:-cricketarchive}
    CA_JDBC_URL=${CA_JDBC_URL:-jdbc:mariadb://$CA_DB_HOST:$CA_DB_PORT/$CA_DB_NAME}

    export CA_ROOT CA_COMPONENT_DIR CA_ARCHIVE_DIR CA_DB_HOST CA_DB_PORT
    export CA_DB_NAME CA_DB_USER CA_JDBC_URL CA_DUMP_DIR CA_DUMP_FILE
    export CRICKETARCHIVE_EMAIL CRICKETARCHIVE_PASSWORD
    export CRICKETARCHIVE_PROXY_HOST CRICKETARCHIVE_PROXY_PORT
    export CRICKETARCHIVE_PROXY_USER CRICKETARCHIVE_PROXY_PASSWORD
    export GMAIL_ACCT_PASSWORD
}

ca_resolve_path() {
    case "$1" in
        /*) printf '%s\n' "$1" ;;
        *) printf '%s/%s\n' "$CA_ROOT" "$1" ;;
    esac
}

ca_require_archive() {
    if [ ! -d "$CA_ARCHIVE_DIR" ]; then
        printf 'ERROR: CricketArchive directory does not exist: %s\n' "$CA_ARCHIVE_DIR" >&2
        printf 'Set CA_ARCHIVE_DIR in %s.\n' "${CA_CONFIG_FILE:-$CA_ROOT/config.env}" >&2
        exit 1
    fi
}

ca_require_fetch_credentials() {
    if [ -z "${CRICKETARCHIVE_EMAIL:-}" ] || [ -z "${CRICKETARCHIVE_PASSWORD:-}" ]; then
        printf 'ERROR: CRICKETARCHIVE_EMAIL and CRICKETARCHIVE_PASSWORD must be set.\n' >&2
        printf 'Use an ignored credentials.env file or export them in the environment.\n' >&2
        exit 1
    fi
}

ca_require_db_credentials() {
    if [ -z "${CA_DB_PASSWORD:-}" ]; then
        printf 'ERROR: CA_DB_PASSWORD or CA_DB_PASSWORD_FILE must be set.\n' >&2
        printf 'For Beta, point CA_DB_PASSWORD_FILE at ../private/beta/jdbc.password.\n' >&2
        exit 1
    fi
}

ca_run() {
    component=$1
    shift
    (cd "$CA_ROOT/$component" && "./run" "$@")
}