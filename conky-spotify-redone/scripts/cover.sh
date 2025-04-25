#!/bin/bash

# Conky-Spotify Integration
# Copyright (C) 2014 Madh93
# Modified by @wim66 April 25, 2025
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Determine the script's directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CURRENT_DIR="$SCRIPT_DIR/../current"
COVERS_DIR="$SCRIPT_DIR/../covers"
TEMP_FILE=$(mktemp /tmp/conky-spotify-cover.XXXXXX)

# Ensure covers directory exists
mkdir -p "$COVERS_DIR"

# Read current track ID and fetch new ID
id_current=$(cat "$CURRENT_DIR/current.txt" 2>/dev/null || echo "")
id_new=$("$SCRIPT_DIR/id.sh")
dbus=$(busctl --user list | grep "spotify")

if [ -z "$dbus" ]; then
    cp "$CURRENT_DIR/empty.png" "$CURRENT_DIR/current.png"
    echo "" > "$CURRENT_DIR/current.txt"
else
    echo "$id_new" > "$CURRENT_DIR/current.txt"
    imgname=$(echo "$id_new" | cut -d '/' -f5)

    # Check if cover exists in covers directory
    if [ -f "$COVERS_DIR/${imgname}.png" ]; then
        cp "$COVERS_DIR/${imgname}.png" "$CURRENT_DIR/current.png"
    else
        imgurl=$("$SCRIPT_DIR/imgurl.sh")
        if [ -n "$imgurl" ]; then
            # Download to temp file and convert to PNG
            if timeout 1 wget -q -O "$TEMP_FILE" "$imgurl"; then
                magick "$TEMP_FILE" "$CURRENT_DIR/current.png"
                # Validate PNG
                if ! file "$CURRENT_DIR/current.png" | grep -q "PNG image data"; then
                    cp "$CURRENT_DIR/empty.png" "$CURRENT_DIR/current.png"
                else
                    # Cache PNG in covers directory
                    cp "$CURRENT_DIR/current.png" "$COVERS_DIR/${imgname}.png"
                fi
            else
                cp "$CURRENT_DIR/empty.png" "$CURRENT_DIR/current.png"
            fi
        else
            cp "$CURRENT_DIR/empty.png" "$CURRENT_DIR/current.png"
        fi
    fi
    # Clean up temporary file
    rm -f "$TEMP_FILE"
fi

# Clean up: keep only the newest 10 PNGs in covers/
find "$COVERS_DIR/" -maxdepth 1 -type f -name "*.png" -printf "%T@ %p\n" | sort -nr | awk 'NR>10 {print $2}' | xargs -r rm -f