#!/bin/bash

PLAYERCTL="/usr/bin/playerctl"

# Find active player
player=$($PLAYERCTL --list-all 2>/dev/null | while read -r p; do
    status=$($PLAYERCTL --player="$p" status 2>/dev/null)
    if [ "$status" = "Playing" ] || [ "$status" = "Paused" ]; then
        echo "$p"
        exit 0
    fi
done)

# Nothing active → show nothing
[ -z "$player" ] && exit 0

status=$($PLAYERCTL --player="$player" status 2>/dev/null)

# Metadata
title=$($PLAYERCTL --player="$player" metadata title 2>/dev/null)
[ -z "$title" ] && title="Unknown Track"

# Truncate safely
truncate() {
    local max=$1
    local text="$2"
    if [ ${#text} -gt $max ]; then
        echo "${text:0:$((max - 1))}…"
    else
        echo "$text"
    fi
}

title=$(truncate 38 "$title")

# If paused → no progress bar
if [ "$status" = "Paused" ]; then
    echo "  $title"
    exit 0
fi

# Position & length
pos_sec=$($PLAYERCTL --player="$player" position 2>/dev/null | cut -d'.' -f1)
length_us=$($PLAYERCTL --player="$player" metadata mpris:length 2>/dev/null)

[ -z "$pos_sec" ] || [ -z "$length_us" ] || [ "$length_us" -eq 0 ] && {
    echo "  $title"
    exit 0
}

length_sec=$(( length_us / 1000000 ))

# Progress bar
bar_length=18
progress=$(( pos_sec * bar_length / length_sec ))

bar=$(printf '▓%.0s' $(seq 1 "$progress"))
bar+=$(printf '─%.0s' $(seq 1 $((bar_length - progress))))

format_time() {
    printf "%02d:%02d" $(( $1 / 60 )) $(( $1 % 60 ))
}

current=$(format_time "$pos_sec")
total=$(format_time "$length_sec")

# Output (2-line Apple stack, smaller font for second line in Hyprlock)
echo "[ $bar ] $current / $total"
echo "  $title"
