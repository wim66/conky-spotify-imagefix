#!/bin/bash

CONKY_DIR=$(dirname "$(readlink -f "$0")")



if pidof conky > /dev/null; then
    killall conky
fi

cd $CONKY_DIR
conky -c ./conky-spotify &

exit 0
