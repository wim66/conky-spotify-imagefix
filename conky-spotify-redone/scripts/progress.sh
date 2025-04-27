#!/bin/bash

# progress.sh: Fetch Spotify track progress, elapsed, and remaining time

# Check if Spotify is running
if ! busctl --user list | grep -q "spotify"; then
    echo "0|0:00|0:00"
    exit 0
fi

# Get track length (mpris:length in microseconds) from Metadata
length=$(dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify \
    /org/mpris/MediaPlayer2 org.freedesktop.DBus.Properties.Get \
    string:'org.mpris.MediaPlayer2.Player' string:'Metadata' | \
    grep -A 1 "mpris:length" | grep variant | awk '{print $3}')

# Get current position (in microseconds)
position=$(dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify \
    /org/mpris/MediaPlayer2 org.freedesktop.DBus.Properties.Get \
    string:'org.mpris.MediaPlayer2.Player' string:'Position' | \
    grep variant | awk '{print $3}')

# If no length or position, return defaults
if [ -z "$length" ] || [ -z "$position" ] || [ "$length" -eq 0 ]; then
    echo "0|0:00|0:00"
    exit 0
fi

# Calculate progress percentage
percent=$(echo "scale=2; $position * 100 / $length" | bc | cut -d. -f1)

# Convert to seconds
pos_secs=$((position / 1000000))
len_secs=$((length / 1000000))

# Format elapsed time (MM:SS)
pos_min=$((pos_secs / 60))
pos_sec=$((pos_secs % 60))
elapsed=$(printf "%d:%02d" $pos_min $pos_sec)

# Format remaining time (MM:SS)
rem_secs=$((len_secs - pos_secs))
rem_min=$((rem_secs / 60))
rem_sec=$((rem_secs % 60))
remaining=$(printf "%d:%02d" $rem_min $rem_sec)

# Output: percentage|elapsed|remaining
echo "$percent|$elapsed|$remaining"