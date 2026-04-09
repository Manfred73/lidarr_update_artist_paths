#!/bin/sh
# lidarr_update_artist_paths.sh - QNAP-compatible version with proper emojis

API_KEY="4bf317d08b6f471eba021790e83d0de2"
LIDARR_URL="http://localhost:8686/api/v1"
HOST_MUSIC_DIR="/share/shares/Audio/Music"
CONTAINER_BASE="/AudioMusic"
PARALLEL=5
MAX_RETRIES=3
DRY_RUN=1
GENRES=""
APPLY=0

usage() {
    echo "Usage: $0 -g <genre1,genre2,...> [-a] [-p <num>] [-r <num>] [-h|--help]"
    echo
    echo "Options:"
    echo "  -g, --genres        Comma-separated list of genres to process"
    echo "  -a, --apply         Actually apply path updates (default is dry-run)"
    echo "  -p, --parallel      Number of parallel updates (default: $PARALLEL)"
    echo "  -r, --retries       Max retries for failed updates (default: $MAX_RETRIES)"
    echo "  -h, --help          Show this help message"
    echo
    echo "Logging:"
    echo "  Logs per genre are stored in ./genres/<genre>/ with timestamped files."
    echo "  Includes found artists, not found artists, and a current run log."
    echo
    echo "Features:"
    echo "  Dry-run is the default unless --apply (-a) is specified."
}

while [ $# -gt 0 ]; do
    case "$1" in
        -g|--genres) GENRES="$2"; shift 2;;
        -a|--apply) APPLY=1; shift;;
        -p|--parallel) PARALLEL="$2"; shift 2;;
        -r|--retries) MAX_RETRIES="$2"; shift 2;;
        -h|--help) usage; exit 0;;
        *) echo "Unknown option: $1"; usage; exit 1;;
    esac
done

if [ -z "$GENRES" ]; then
    echo "Error: At least one genre must be specified."; usage; exit 1
fi

clear
echo "Starting Lidarr artist path update..."

mkdir -p ./genres

OLD_IFS="$IFS"
IFS=','; set -- $GENRES; IFS="$OLD_IFS"
GENRE_LIST="$*"

for GENRE in "$@"; do
    echo "Processing genre: $GENRE"
    LOG_DIR="./genres/$GENRE"
    mkdir -p "$LOG_DIR"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    CURRENT_LOG="$LOG_DIR/${GENRE}_${TIMESTAMP}.log"
    FOUND_LOG="$LOG_DIR/found_artists.log"
    NOTFOUND_LOG="$LOG_DIR/notfound_artists.log"

    echo "Logging to $CURRENT_LOG"

    TMP_FOUND="$FOUND_LOG.tmp"
    TMP_NOTFOUND="$NOTFOUND_LOG.tmp"
    >"$TMP_FOUND"
    >"$TMP_NOTFOUND"

    for ARTIST_DIR in "$HOST_MUSIC_DIR/$GENRE"/*; do
        [ ! -d "$ARTIST_DIR" ] && continue
        ARTIST_NAME=$(basename "$ARTIST_DIR")
        case "$ARTIST_NAME" in
            .*|@*|Thumbs.db) continue;;
        esac

        CONTAINER_PATH="$CONTAINER_BASE/$GENRE/$ARTIST_NAME"

        RETRY=1
        FOUND=0
        while [ $RETRY -le 1 ]; do
            RESPONSE=$(curl -s -G -H "X-Api-Key: $API_KEY" --data-urlencode "name=$ARTIST_NAME" "$LIDARR_URL/artist")
            ARTIST_ID=$(echo "$RESPONSE" | jq -r --arg name "$ARTIST_NAME" '.[] | select(.artistName==$name) | .id' 2>/dev/null)
            #ARTIST_ID=$(echo "$RESPONSE" | jq -r ".[] | select(.artistName==\"$ARTIST_NAME\") | .id" 2>/dev/null)
            if [ -n "$ARTIST_ID" ] && [ "$ARTIST_ID" != "null" ]; then
                FOUND=1
                break
            fi
            RETRY=$((RETRY+1))
        done

        if [ $FOUND -eq 0 ]; then
            echo "❌ Not found: $ARTIST_NAME" | tee -a "$CURRENT_LOG"
            echo "$ARTIST_NAME" >>"$TMP_NOTFOUND"
            continue
        fi

        CURRENT_PATH=$(curl -s -H "X-Api-Key: $API_KEY" "$LIDARR_URL/artist/$ARTIST_ID" | jq -r ".path" 2>/dev/null)
        if [ "$CURRENT_PATH" = "$CONTAINER_PATH" ]; then
            echo "⚠️ Already correct: $ARTIST_NAME -> $CURRENT_PATH" | tee -a "$CURRENT_LOG"
            echo "$ARTIST_NAME" >>"$TMP_FOUND"
            continue
        fi

        if [ $APPLY -eq 0 ]; then
            echo "✅ Would update path: $ARTIST_NAME -> $CONTAINER_PATH" | tee -a "$CURRENT_LOG"
            echo "$ARTIST_NAME" >>"$TMP_FOUND"
        else
            UPDATED_JSON=$(curl -s -H "X-Api-Key: $API_KEY" "$LIDARR_URL/artist/$ARTIST_ID" \
                | jq --arg newPath "$CONTAINER_PATH" '.path=$newPath')

            echo "$UPDATED_JSON" | curl -s -X PUT \
                -H "X-Api-Key: $API_KEY" \
                -H "Content-Type: application/json" \
                -d @- \
                "$LIDARR_URL/artist/$ARTIST_ID" >/dev/null

            echo "✅ Updated path: $ARTIST_NAME -> $CONTAINER_PATH" | tee -a "$CURRENT_LOG"
            echo "$ARTIST_NAME" >>"$TMP_FOUND"
        fi
    done

    mv "$TMP_FOUND" "$FOUND_LOG"
    mv "$TMP_NOTFOUND" "$NOTFOUND_LOG"

    TOTAL=$(ls -1 "$HOST_MUSIC_DIR/$GENRE" 2>/dev/null | wc -l | tr -d ' ')
    FOUND_COUNT=$(wc -l < "$FOUND_LOG" | tr -d ' ')
    NOTFOUND_COUNT=$(wc -l < "$NOTFOUND_LOG" | tr -d ' ')
    ALREADY_CORRECT=$(grep -c "Already correct" "$CURRENT_LOG" || echo 0)

    echo "--------------------" | tee -a "$CURRENT_LOG"
    echo "Artist Path Update Summary for $GENRE" | tee -a "$CURRENT_LOG"
    echo "Total artists scanned: $TOTAL" | tee -a "$CURRENT_LOG"
    echo "Found and updated: $FOUND_COUNT" | tee -a "$CURRENT_LOG"
    echo "Not found: $NOTFOUND_COUNT" | tee -a "$CURRENT_LOG"
    echo "Already correct / skipped: $ALREADY_CORRECT" | tee -a "$CURRENT_LOG"
    echo "Logs:" | tee -a "$CURRENT_LOG"
    echo "Current run log: $CURRENT_LOG" | tee -a "$CURRENT_LOG"
    echo "Found artists log: $FOUND_LOG" | tee -a "$CURRENT_LOG"
    echo "Not found artists log: $NOTFOUND_LOG" | tee -a "$CURRENT_LOG"
done

echo "All done."
