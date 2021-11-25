#!/bin/bash
cd /var/lib/postgresql/python
/usr/bin/python3.9 datastore.py sync --number +12406171474 &
trap '/usr/bin/python3.9 datastore.py upload && exit' 2
trap '/usr/bin/python3.9 datastore.py upload && exit' 15
