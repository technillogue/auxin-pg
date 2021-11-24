## postgres: my favorite signal client

requires auxin-cli, jq, pg\_cron, and either curl or pgxr and then pgxr\_printerfact.fs compiled and placed somewhere.

pgxr seems to require postgres 11

postgresql-11 postgresql-postgresql-11-cron

possibly postgresql-server-dev

you'll need to modify roles and pg\_hba.conf for pg\_cron

`sudo pg_ctlcluster 11 main restart` for `pg_cron` and stuff

`sudo -u postgres psql -f auxin.sql`

`tail --follow /var/log/postgresql/postgresql-11-main.log`

i also like pgcli. it requires psychopg, which needs `sudo apt install python3.9-dev libpq-dev`


