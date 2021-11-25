## postgres: my favorite signal client

`docker build -t auxpg . && docker run --rm -it --env-file dev_secrets auxpg`

requires auxin-cli, jq, pg\_cron, and either curl or pgxr and then pgxr\_printerfact.fs compiled and placed somewhere.

pgxr seems to require postgres 11

postgresql-11 postgresql-postgresql-11-cron

possibly postgresql-server-dev

you'll need to modify roles and pg\_hba.conf for pg\_cron

## Setting up pg_cron

To start the pg_cron background worker when PostgreSQL starts, you need to add pg_cron to `shared_preload_libraries` in postgresql.conf. Note that pg_cron does not run any jobs as a long a server is in [hot standby](https://www.postgresql.org/docs/current/static/hot-standby.html) mode, but it automatically starts when the server is promoted.

By default, the pg_cron background worker expects its metadata tables to be created in the "postgres" database. However, you can configure this by setting the `cron.database_name` configuration parameter in postgresql.conf.

```
# add to postgresql.conf:
shared_preload_libraries = 'pg_cron'
cron.database_name = 'postgres'
```

After restarting PostgreSQL, you can create the pg_cron functions and metadata tables using `CREATE EXTENSION pg_cron`.

```sql
-- run as superuser:
CREATE EXTENSION pg_cron;

-- optionally, grant usage to regular users:
GRANT USAGE ON SCHEMA cron TO marco;
```

`sudo pg_ctlcluster 11 main restart` for `pg_cron` and stuff

`sudo -u postgres psql -f auxin.sql`

`tail --follow /var/log/postgresql/postgresql-11-main.log`

i also like pgcli. it requires psychopg, which needs `sudo apt install python3.9-dev libpq-dev`

for running locally, stick a symlink to auxin-cli in /var/lib/postgresql/auxin-cli.
