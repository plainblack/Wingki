#!/bin/bash
. /data/Wing/bin/dataapps.sh
cd /data/Wingki/bin
export WING_CONFIG=/data/Wingki/etc/wing.conf
start_server --port 5001 -- starman --workers 2 --user nobody --group nobody --preload-app web.psgi

