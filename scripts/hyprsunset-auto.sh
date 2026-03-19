#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONFIG="$HOME/.config/hypr/hyprsunset.conf"
CACHE_FILE="/tmp/waybar_weather_cache.json"

API_WEATHER="https://api.open-meteo.com/v1/forecast"

# 🌍 location (ONE CALL)
loc=$("$SCRIPT_DIR/location.sh" json)

lat=$(echo "$loc" | jq -r '.latitude')
lon=$(echo "$loc" | jq -r '.longitude')

# fallback
[ "$lat" = "null" ] && lat=12.97
[ "$lon" = "null" ] && lon=77.59

# 🌅 try to reuse weather cache first (INSANE optimization)
if [ -f "$CACHE_FILE" ]; then
    sunrise=$(jq -r '.tooltip' "$CACHE_FILE" | grep -oP '󰖨 \K[0-9:]+')
    sunset=$(jq -r '.tooltip' "$CACHE_FILE" | grep -oP '󰖩 \K[0-9:]+' )
fi

# 🌤 fallback → API call if cache failed
if [ -z "$sunrise" ] || [ -z "$sunset" ]; then
    weather=$(curl -sf "$API_WEATHER?latitude=$lat&longitude=$lon&daily=sunrise,sunset&timezone=auto")

    if [ -z "$weather" ]; then
        echo "Failed to fetch weather data"
        exit 1
    fi

    sunrise=$(echo "$weather" | jq -r '.daily.sunrise[0]' | cut -dT -f2 | cut -c1-5)
    sunset=$(echo "$weather" | jq -r '.daily.sunset[0]' | cut -dT -f2 | cut -c1-5)
fi

# fallback safety
[ -z "$sunrise" ] && sunrise="06:00"
[ -z "$sunset" ] && sunset="18:00"

# 📝 write config
cat > "$CONFIG" <<EOF
profile {
    time = $sunrise
    identity = true
}

profile {
    time = $sunset
    temperature = 4000
}
EOF

echo "Hyprsunset config updated:"
echo "  Sunrise: $sunrise"
echo "  Sunset : $sunset"

# 🔁 restart hyprsunset cleanly
if pgrep -x hyprsunset >/dev/null; then
    pkill hyprsunset
    sleep 0.5
fi

hyprsunset &
