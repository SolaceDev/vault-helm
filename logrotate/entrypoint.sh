#!/bin/sh

if [ ! -f /etc/logrotate.conf ]; then
    echo "/etc/logrotate.conf not found"
    exit 1
fi
exec tini $@