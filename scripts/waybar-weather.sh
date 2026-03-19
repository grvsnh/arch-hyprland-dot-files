#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CACHE_FILE="/tmp/waybar_weather_cache.json"
CACHE_DURATION=600

API_WEATHER="https://api.open-meteo.com/v1/forecast"
API_AQI="https://air-quality-api.open-meteo.com/v1/air-quality"

now=$(date +%s)

# 🧠 cache
if [ -f "$CACHE_FILE" ]; then
    last=$(stat -c %Y "$CACHE_FILE" 2>/dev/null)
    age=$((now - last))
    if [ "$age" -lt "$CACHE_DURATION" ]; then
        cat "$CACHE_FILE"
        exit
    fi
fi

loc=$("$SCRIPT_DIR/location.sh" json)

lat=$(echo "$loc" | jq -r '.latitude')
lon=$(echo "$loc" | jq -r '.longitude')
city=$(echo "$loc" | jq -r '.city // .region // "UNK"')

# 🌤 weather
weather=$(curl -sf "$API_WEATHER?latitude=$lat&longitude=$lon&current=temperature_2m,apparent_temperature,weather_code,is_day,wind_speed_10m,wind_direction_10m,relative_humidity_2m,precipitation,uv_index&daily=sunrise,sunset&timezone=auto")

aqi_data=$(curl -sf "$API_AQI?latitude=$lat&longitude=$lon&current=us_aqi")

[ -z "$weather" ] && printf '{"text":"N/A","tooltip":"Weather unavailable"}\n' && exit

# 🌡 values
temp=$(echo "$weather" | jq '.current.temperature_2m' | cut -d. -f1)
feels=$(echo "$weather" | jq '.current.apparent_temperature' | cut -d. -f1)
wind=$(echo "$weather" | jq '.current.wind_speed_10m')
wind_dir_deg=$(echo "$weather" | jq '.current.wind_direction_10m')
humidity=$(echo "$weather" | jq '.current.relative_humidity_2m')
precip=$(echo "$weather" | jq '.current.precipitation')
uv=$(echo "$weather" | jq '.current.uv_index')
code=$(echo "$weather" | jq '.current.weather_code')
is_day=$(echo "$weather" | jq '.current.is_day')

sunrise=$(echo "$weather" | jq -r '.daily.sunrise[0]' | cut -dT -f2 | cut -c1-5)
sunset=$(echo "$weather" | jq -r '.daily.sunset[0]' | cut -dT -f2 | cut -c1-5)

aqi=$(echo "$aqi_data" | jq '.current.us_aqi' 2>/dev/null)
[ -z "$aqi" ] && aqi=0

# 🧭 wind direction
dirs=("N" "NE" "E" "SE" "S" "SW" "W" "NW")
idx=$(( (wind_dir_deg + 22) / 45 % 8 ))
wind_dir=${dirs[$idx]}

# 🌤 icon mapping
case $code in
    0) [ "$is_day" -eq 1 ] && icon="󰖙" || icon="󰖔"; desc="clear";;
    1|2|3) icon="󰖕"; desc="cloudy";;
    45|48) icon="󰖑"; desc="fog";;
    51|53|55|61|63|65|80|81|82) icon="󰖗"; desc="rain";;
    71|73|75|77|85|86) icon="󰖘"; desc="snow";;
    95|96|99) icon="󰖓"; desc="storm";;
    *) icon="󰖐"; desc="unk";;
esac

# 🧾 tooltip
tooltip="$city | $desc

󰔏 ${temp}° (${feels}°)
󰖝 ${wind} km/h 󰩖 $wind_dir
󰖨 $sunrise  󰖩 $sunset
󰒑 AQI $aqi
󰋩 ${humidity}%
󰔄 UV $uv
󰖗 ${precip}%"

tooltip_escaped=$(printf '%s' "$tooltip" | jq -Rs .)

output=$(printf '{"text":"%s %s°","tooltip":%s}\n' "$icon" "$temp" "$tooltip_escaped")

echo "$output" > "$CACHE_FILE"
echo "$output"
