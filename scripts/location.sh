#!/usr/bin/env bash

# 📍 detect script directory (portable)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 📦 cache (still global, that's fine)
CACHE_FILE="/tmp/location_cache.json"
CACHE_DURATION=3600  # 1 hour

now=$(date +%s)

# 📦 load cache if fresh
if [ -f "$CACHE_FILE" ]; then
    last=$(stat -c %Y "$CACHE_FILE" 2>/dev/null)
    age=$((now - last))
    if [ "$age" -lt "$CACHE_DURATION" ]; then
        loc=$(cat "$CACHE_FILE")
    fi
fi

# 🌍 fetch if no cache
if [ -z "$loc" ]; then
    loc=$(curl -sf "https://ipapi.co/json")

    # fallback (generic, not your personal coords now)
    if [ -z "$loc" ]; then
        loc='{"latitude":0,"longitude":0,"city":"UNK"}'
    fi

    echo "$loc" > "$CACHE_FILE"
fi

# 🎯 interface
case "$1" in
    lat)
        echo "$loc" | jq -r '.latitude'
        ;;
    lon)
        echo "$loc" | jq -r '.longitude'
        ;;
    city)
        echo "$loc" | jq -r '.city // .region // "UNK"'
        ;;
    latlon)
        echo "$loc" | jq -r '"\(.latitude),\(.longitude)"'
        ;;
    json|"")
        echo "$loc"
        ;;
    *)
        echo "Usage: $(basename "$0") [lat|lon|city|latlon|json]"
        exit 1
        ;;
esac
