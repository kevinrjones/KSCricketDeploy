#!/usr/bin/env bash
# =============================================================================
# Import Cricket / Ball-by-Ball Database - Seed / Restore Data in MariaDB
# =============================================================================
# Imports SQL or gzipped dump files into MariaDB on the VM or VPS.
# Supports both 'cricketarchive' (for acs-api) and 'acs_ball_by_ball' (for bbb-api).
# Can be executed directly inside the VM, or executed from the laptop
# targeting the VM or VPS over SSH.
#
# Usage:
#   ./scripts/import-cricket-data.sh [path-to-sql-file] [environment] [options]
#
# Arguments:
#   path-to-sql-file: Path to SQL or .sql.gz dump (optional, auto-detected if omitted)
#   environment:      local-vm or beta (defaults to local-vm)
#
# Options:
#   --database <name>     Target database name (cricketarchive or acs_ball_by_ball)
#   --remote <user@host>  Target remote host over SSH (e.g. parallels@10.211.55.7)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SCRIPT_NAME="${IMPORT_SCRIPT_NAME:-$(basename "${BASH_SOURCE[0]}")}"

INPUT_FILE=""
ENV="local-vm"
TARGET_DB=""
DB_EXPLICIT=0
REMOTE_TARGET="${SSH_TARGET:-}"

# If invoked as import-ball-by-ball-data.sh, default target db is acs_ball_by_ball
if [[ "$SCRIPT_NAME" =~ ball-by-ball ]]; then
    TARGET_DB="acs_ball_by_ball"
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --database)
            TARGET_DB="$2"
            DB_EXPLICIT=1
            shift 2
            ;;
        --remote)
            REMOTE_TARGET="$2"
            shift 2
            ;;
        -*)
            echo "Unknown option: $1"
            echo "Usage: ./scripts/$SCRIPT_NAME [path-to-sql-file] [environment] [--database <name>] [--remote <user@host>]"
            exit 1
            ;;
        *)
            if [ "$1" = "local-vm" ] || [ "$1" = "beta" ]; then
                ENV="$1"
            elif [ -z "$INPUT_FILE" ]; then
                INPUT_FILE="$1"
            else
                ENV="$1"
            fi
            shift
            ;;
    esac
done

# If database not explicitly set, determine from input file or default
if [ "$DB_EXPLICIT" -eq 0 ]; then
    if [ -n "$INPUT_FILE" ] && [[ "$INPUT_FILE" =~ ball-by-ball ]]; then
        TARGET_DB="acs_ball_by_ball"
    elif [ -n "$INPUT_FILE" ] && [[ "$INPUT_FILE" =~ cricketarchive ]]; then
        TARGET_DB="cricketarchive"
    elif [ -z "$TARGET_DB" ]; then
        TARGET_DB="cricketarchive"
    fi
fi

ENV_DIR="$PROJECT_ROOT/environments/$ENV"
PRIVATE_DIR="$PROJECT_ROOT/private/$ENV"

# Search for default input file if not provided
if [ -z "$INPUT_FILE" ]; then
    if [ "$TARGET_DB" = "acs_ball_by_ball" ]; then
        CANDIDATES=(
            "/media/psf/Dropbox/dumps/mysql/ball-by-ball-upload.sql"
            "/media/psf/Dropbox/dumps/mysql/ball-by-ball-upload.sql.gz"
            "$HOME/sql/ball-by-ball-upload.sql"
            "$HOME/sql/ball-by-ball-upload.sql.gz"
            "$HOME/Dropbox/dumps/mysql/ball-by-ball-upload.sql"
            "$HOME/Dropbox/dumps/mysql/ball-by-ball-upload.sql.gz"
            "$HOME/ball-by-ball-upload.sql"
            "$HOME/ball-by-ball-upload.sql.gz"
            "$PROJECT_ROOT/ball-by-ball-upload.sql"
            "$PROJECT_ROOT/ball-by-ball-upload.sql.gz"
        )
    else
        CANDIDATES=(
            "/media/psf/Dropbox/dumps/mysql/cricketarchive-upload.sql"
            "/media/psf/Dropbox/dumps/mysql/cricketarchive-upload.sql.gz"
            "$HOME/sql/cricketarchive-upload.sql"
            "$HOME/sql/cricketarchive-upload.sql.gz"
            "/media/psf/Dropbox/dumps/mysql/CricketArchive/DatabaseBackup/cricketarchive-upload.sql"
            "/media/psf/Dropbox/dumps/mysql/CricketArchive/DatabaseBackup/cricketarchive-upload.sql.gz"
            "$HOME/Dropbox/dumps/mysql/cricketarchive-upload.sql"
            "$HOME/Dropbox/dumps/mysql/cricketarchive-upload.sql.gz"
            "$HOME/Dropbox/dumps/mysql/CricketArchive/DatabaseBackup/cricketarchive-upload.sql"
            "$HOME/Dropbox/dumps/mysql/CricketArchive/DatabaseBackup/cricketarchive-upload.sql.gz"
            "/media/psf/Dropbox/projects/cricket/CricketArchive/DatabaseBackup/cricketarchive-upload.sql"
            "/media/psf/Dropbox/projects/cricket/CricketArchive/DatabaseBackup/cricketarchive-upload.sql.gz"
            "$HOME/Dropbox/projects/cricket/CricketArchive/DatabaseBackup/cricketarchive-upload.sql"
            "$HOME/Dropbox/projects/cricket/CricketArchive/DatabaseBackup/cricketarchive-upload.sql.gz"
            "$HOME/cricketarchive-upload.sql"
            "$HOME/cricketarchive-upload.sql.gz"
            "$PROJECT_ROOT/cricketarchive-upload.sql"
            "$PROJECT_ROOT/cricketarchive-upload.sql.gz"
        )
    fi
    for c in "${CANDIDATES[@]}"; do
        if [ -f "$c" ]; then
            INPUT_FILE="$c"
            break
        fi
    done
fi

if [ -n "$INPUT_FILE" ] && [ ! -f "$INPUT_FILE" ]; then
    echo "ERROR: Data file not found: $INPUT_FILE"
    echo "The path is checked on the machine where this script is running."
    if [ "$ENV" = "beta" ]; then
        echo "For a dump on the VPS, run this from ~/acs-deploy on the VPS:"
        if [ "$TARGET_DB" = "acs_ball_by_ball" ]; then
            echo "  ./scripts/$SCRIPT_NAME ~/sql/ball-by-ball-upload.sql.gz beta"
        else
            echo "  ./scripts/$SCRIPT_NAME ~/sql/cricketarchive-upload.sql.gz beta"
        fi
        echo "For a dump on your laptop, use --remote to stream it to the VPS."
    fi
    exit 1
fi

if [ -z "$INPUT_FILE" ]; then
    echo "ERROR: Data file not found for database '$TARGET_DB'."
    echo "No supported dump was found in the automatic search paths."
    echo "Please provide the file path as an argument, e.g.:"
    if [ "$TARGET_DB" = "acs_ball_by_ball" ]; then
        echo "  ./scripts/$SCRIPT_NAME ~/sql/ball-by-ball-upload.sql.gz [environment]"
    else
        echo "  ./scripts/$SCRIPT_NAME ~/sql/cricketarchive-upload.sql.gz [environment]"
    fi
    exit 1
fi

echo "=========================================="
if [ "$TARGET_DB" = "acs_ball_by_ball" ]; then
    echo "Importing Ball-by-Ball Cricket Data"
else
    echo "Importing CricketArchive Data"
fi
echo "Source:      $INPUT_FILE"
echo "Environment: $ENV"
echo "Database:    $TARGET_DB"
echo "=========================================="

# Check file compression
IS_GZIP=0
if [[ "$INPUT_FILE" =~ \.gz$ ]] || (command -v file >/dev/null 2>&1 && file "$INPUT_FILE" | grep -qi "gzip compressed"); then
    IS_GZIP=1
    echo "→ Detected gzip-compressed file."
fi

# Detect local container
LOCAL_CONTAINER=$(docker compose -f "$ENV_DIR/compose.yaml" ps -q mariadb 2>/dev/null || true)

if [ -n "$LOCAL_CONTAINER" ]; then
    echo "→ Found local MariaDB container ($LOCAL_CONTAINER)"
    
    # Increase buffer pool / packet limits dynamically if possible
    docker exec "$LOCAL_CONTAINER" sh -c '
        ROOT_PW=$(cat /run/secrets/mariadb_root_password 2>/dev/null || echo "")
        mariadb -u root -p"$ROOT_PW" -e "SET GLOBAL max_allowed_packet = 1073741824; SET GLOBAL innodb_buffer_pool_size = 1073741824;" 2>/dev/null || true
    '

    echo "→ Starting data import into database '$TARGET_DB' (this may take some time for large dumps)..."
    if [ "$IS_GZIP" -eq 1 ]; then
        gunzip -c "$INPUT_FILE" | docker exec -i "$LOCAL_CONTAINER" sh -c \
            "mariadb --verbose -u root -p\"\$(cat /run/secrets/mariadb_root_password)\" --max-allowed-packet=1G --default-character-set=utf8mb4 $TARGET_DB"
    else
        docker exec -i "$LOCAL_CONTAINER" sh -c \
            "mariadb --verbose -u root -p\"\$(cat /run/secrets/mariadb_root_password)\" --max-allowed-packet=1G --default-character-set=utf8mb4 $TARGET_DB" < "$INPUT_FILE"
    fi

    echo "✓ Import finished! Verifying database tables..."
    if [ "$TARGET_DB" = "acs_ball_by_ball" ]; then
        docker exec "$LOCAL_CONTAINER" sh -c "
            ROOT_PW=\$(cat /run/secrets/mariadb_root_password 2>/dev/null || echo \"\")
            mariadb -u root -p\"\$ROOT_PW\" -e \"
                SELECT count(*) AS total_tables FROM information_schema.tables WHERE table_schema='$TARGET_DB';
                SELECT 'dim_match' AS tbl, count(*) AS total_rows FROM $TARGET_DB.dim_match UNION ALL
                SELECT 'dim_person', count(*) FROM $TARGET_DB.dim_person UNION ALL
                SELECT 'dim_team', count(*) FROM $TARGET_DB.dim_team UNION ALL
                SELECT 'fact_delivery', count(*) FROM $TARGET_DB.fact_delivery;
            \"
        "
    elif [ "$TARGET_DB" = "cricketarchive" ]; then
        docker exec "$LOCAL_CONTAINER" sh -c "
            ROOT_PW=\$(cat /run/secrets/mariadb_root_password 2>/dev/null || echo \"\")
            mariadb -u root -p\"\$ROOT_PW\" -e \"
                SELECT count(*) AS total_tables FROM information_schema.tables WHERE table_schema='$TARGET_DB';
                SELECT 'Matches' AS tbl, count(*) AS total_rows FROM $TARGET_DB.Matches UNION ALL
                SELECT 'Players', count(*) FROM $TARGET_DB.Players UNION ALL
                SELECT 'Teams', count(*) FROM $TARGET_DB.Teams;
            \"
        "
    else
        docker exec "$LOCAL_CONTAINER" sh -c "
            ROOT_PW=\$(cat /run/secrets/mariadb_root_password 2>/dev/null || echo \"\")
            mariadb -u root -p\"\$ROOT_PW\" -e \"
                SELECT count(*) AS total_tables FROM information_schema.tables WHERE table_schema='$TARGET_DB';
            \"
        "
    fi
    exit 0
fi

# If no local container, check remote target or auto-detect for local-vm
if [ -z "$REMOTE_TARGET" ] && [ "$ENV" = "local-vm" ]; then
    IDS_HOST="ids-vm.knowledgespike.cricket"
    VM_IP=$(getent hosts "$IDS_HOST" 2>/dev/null | awk '{print $1}' || true)
    if [ -z "$VM_IP" ]; then
        VM_IP=$(dscacheutil -q host -a name "$IDS_HOST" 2>/dev/null | awk '/^ip_address:/ {print $2}' || true)
    fi
    if [ -n "$VM_IP" ]; then
        if ssh -o BatchMode=yes -o ConnectTimeout=2 "parallels@$VM_IP" "true" 2>/dev/null; then
            REMOTE_TARGET="parallels@$VM_IP"
        fi
    fi
fi

if [ -n "$REMOTE_TARGET" ]; then
    echo "→ Connecting to remote host: $REMOTE_TARGET"
    REMOTE_COMPOSE="~/acs-deploy/environments/$ENV/compose.yaml"
    REMOTE_CONTAINER=$(ssh "$REMOTE_TARGET" "docker compose -f $REMOTE_COMPOSE ps -q mariadb 2>/dev/null || true")

    if [ -z "$REMOTE_CONTAINER" ]; then
        echo "ERROR: MariaDB container not running on $REMOTE_TARGET"
        exit 1
    fi

    echo "→ Found remote MariaDB container ($REMOTE_CONTAINER)"
    echo "→ Streaming cricket data into remote database '$TARGET_DB'..."
    if [ "$IS_GZIP" -eq 1 ]; then
        gunzip -c "$INPUT_FILE" | ssh "$REMOTE_TARGET" "docker exec -i $REMOTE_CONTAINER sh -c 'mariadb --verbose -u root -p\"\$(cat /run/secrets/mariadb_root_password)\" --max-allowed-packet=1G --default-character-set=utf8mb4 $TARGET_DB'"
    else
        ssh "$REMOTE_TARGET" "docker exec -i $REMOTE_CONTAINER sh -c 'mariadb --verbose -u root -p\"\$(cat /run/secrets/mariadb_root_password)\" --max-allowed-packet=1G --default-character-set=utf8mb4 $TARGET_DB'" < "$INPUT_FILE"
    fi

    echo "✓ Import finished on remote host! Verifying database tables..."
    if [ "$TARGET_DB" = "acs_ball_by_ball" ]; then
        ssh "$REMOTE_TARGET" "docker exec $REMOTE_CONTAINER sh -c \"
            ROOT_PW=\\\$(cat /run/secrets/mariadb_root_password 2>/dev/null || echo \\\"\\\")
            mariadb -u root -p\\\"\\\$ROOT_PW\\\" -e \\\"
                SELECT count(*) AS total_tables FROM information_schema.tables WHERE table_schema='$TARGET_DB';
                SELECT 'dim_match' AS tbl, count(*) AS total_rows FROM $TARGET_DB.dim_match UNION ALL
                SELECT 'dim_person', count(*) FROM $TARGET_DB.dim_person UNION ALL
                SELECT 'dim_team', count(*) FROM $TARGET_DB.dim_team UNION ALL
                SELECT 'fact_delivery', count(*) FROM $TARGET_DB.fact_delivery;
            \\\"
        \""
    elif [ "$TARGET_DB" = "cricketarchive" ]; then
        ssh "$REMOTE_TARGET" "docker exec $REMOTE_CONTAINER sh -c \"
            ROOT_PW=\\\$(cat /run/secrets/mariadb_root_password 2>/dev/null || echo \\\"\\\")
            mariadb -u root -p\\\"\\\$ROOT_PW\\\" -e \\\"
                SELECT count(*) AS total_tables FROM information_schema.tables WHERE table_schema='$TARGET_DB';
                SELECT 'Matches' AS tbl, count(*) AS total_rows FROM $TARGET_DB.Matches UNION ALL
                SELECT 'Players', count(*) FROM $TARGET_DB.Players UNION ALL
                SELECT 'Teams', count(*) FROM $TARGET_DB.Teams;
            \\\"
        \""
    else
        ssh "$REMOTE_TARGET" "docker exec $REMOTE_CONTAINER sh -c \"
            ROOT_PW=\\\$(cat /run/secrets/mariadb_root_password 2>/dev/null || echo \\\"\\\")
            mariadb -u root -p\\\"\\\$ROOT_PW\\\" -e \\\"
                SELECT count(*) AS total_tables FROM information_schema.tables WHERE table_schema='$TARGET_DB';
            \\\"
        \""
    fi
    exit 0
fi

echo "ERROR: Could not find a running MariaDB container locally, and no --remote target specified."
echo "Provide a remote target with: --remote <user@host>"
exit 1
