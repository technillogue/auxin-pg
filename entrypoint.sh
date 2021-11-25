#!/bin/bash
set -o xtrace
DATASTORE='/var/lib/postgresql/python/datastore.py'
python3.9 $DATASTORE sync --number +12406171474 &
trap 'python3.9 $DATASTORE upload --path /tmp/local-signal && exit' 2
trap 'python3.9 $DATASTORE upload --path /tmp/local-signal && exit' 15
/usr/local/bin/docker-entrypoint.sh postgres
