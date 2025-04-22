#!/bin/bash

# Conky-Spotify Integration
# Copyright (C) 2014 Madh93
# Modified by @wim66 April 22 2025
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

id_current=$(cat ~/.conky/conky-spotify/current/current.txt 2>/dev/null || echo "")
id_new=$(~/.conky/conky-spotify/scripts/id.sh)
dbus=$(busctl --user list | grep "spotify")

if [ -z "$dbus" ]; then
    cp ~/.conky/conky-spotify/empty.png ~/.conky/conky-spotify/current/current.png
    echo "" > ~/.conky/conky-spotify/current/current.txt
else
    echo "$id_new" > ~/.conky/conky-spotify/current/current.txt
    imgname=$(echo "$id_new" | cut -d '/' -f5)

    cover=$(ls ~/.conky/conky-spotify/covers 2>/dev/null | grep "$id_new" || echo "")

    if grep -q "${imgname}" <<< "$cover"; then
        magick ~/.conky/conky-spotify/covers/"$imgname".jpg ~/.conky/conky-spotify/current/current.png
    else
        imgurl=$(~/.conky/conky-spotify/scripts/imgurl.sh)
        if [ -n "$imgurl" ]; then
            wget -q -O ~/.conky/conky-spotify/covers/"$imgname".jpg "$imgurl" &> /dev/null
            touch ~/.conky/conky-spotify/covers/"$imgname".jpg
            magick ~/.conky/conky-spotify/covers/"$imgname".jpg ~/.conky/conky-spotify/current/current.png
            # Opruimen: houd alleen de nieuwste 10 covers
            rm -f $(ls -t ~/.conky/conky-spotify/covers/* | awk 'NR>10')
            rm -f wget-log
        else
            cp ~/.conky/conky-spotify/empty.png ~/.conky/conky-spotify/current/current.png
        fi
    fi
fi