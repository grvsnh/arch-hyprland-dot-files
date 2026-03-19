#!/bin/bash

PLAYERCTL="/usr/bin/playerctl"

# Find currently playing player
playing_player=$($PLAYERCTL --list-all 2>/dev/null | while read -r p; do
    status=$($PLAYERCTL --player="$p" status 2>/dev/null)
    if [ "$status" = "Playing" ]; then
        echo "$p"
        exit 0
    fi
done)

if [ -n "$playing_player" ]; then
    # Metadata
    song=$($PLAYERCTL --player="$playing_player" metadata title 2>/dev/null || echo "Unknown")
    artist=$($PLAYERCTL --player="$playing_player" metadata artist 2>/dev/null)

    # Determine icon
    if echo "$playing_player" | grep -qiE "spotify|ncspot"; then
        icon=""   # Spotify
    else
        icon=""   # Other player
    fi

    # Output
    if [ -n "$artist" ]; then
        echo "$icon $artist — $song"
    else
        echo "$icon $song"
    fi
else
    # No music playing → greet based on time
    hour=$(date +"%H")
    if [ "$hour" -ge 5 ] && [ "$hour" -lt 12 ]; then
        echo "Good morning, $USER"
    elif [ "$hour" -ge 12 ] && [ "$hour" -lt 17 ]; then
        echo "Good afternoon, $USER"
    else
        echo "Good evening, $USER"
    fi
fi
