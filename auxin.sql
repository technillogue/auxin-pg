--COPY (select datastore from signal_accounts where id='<number>') TO PROGRAM 'tax x';
--COPY signal_accounts FROM PROGRAM 'tar xf data'

DROP TABLE IF EXISTS outbox;
CREATE TABLE outbox (id SERIAL PRIMARY KEY, msg TEXT, dest TEXT, ts TEXT);


CREATE OR REPLACE FUNCTION get_output(program TEXT)
RETURNS text AS $$ 
    DECLARE 
        output TEXT;
    BEGIN
        CREATE TEMP TABLE tmp (content text);
        EXECUTE format('COPY tmp FROM PROGRAM %s;', quote_literal(program));
        SELECT content FROM tmp INTO output;
        DROP TABLE tmp;
        RETURN output;
    END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION curl_printerfact() RETURNS text AS $$
    select get_output('curl https://colbyolson.com/printers');
$$ LANGUAGE SQL

CREATE OR REPLACE FUNCTION curl_intelfact() RETURNS text AS $$
    select get_output('curl https://intelligence.sometimes.workers.dev');
$$ LANGUAGE SQL

CREATE OR REPLACE FUNCTION trigger_send()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $BODY$
BEGIN 
    NEW.ts := get_output(
        format(
            $$/home/sylv/.local/bin/auxin-cli -c . -u +447927948360 send -m '%s' %s$$,
            NEW.msg, 
            quote_ident(NEW.dest)
        )
    );
    RETURN NEW;
END;
$BODY$;

DROP TRIGGER IF EXISTS send ON outbox;
CREATE TRIGGER send BEFORE INSERT ON outbox FOR EACH ROW EXECUTE PROCEDURE trigger_send();

DROP TABLE IF EXISTS inbox;
CREATE TABLE inbox (id SERIAL PRIMARY KEY, msg TEXT, sender TEXT, ts TEXT, unread BOOLEAN DEFAULT TRUE);

CREATE OR REPLACE FUNCTION receive()
RETURNS table (id integer, msg TEXT, sender TEXT, ts TEXT, unread BOOLEAN) AS $$ 
    COPY inbox (sender, msg, ts) 
    FROM PROGRAM '/home/sylv/.local/bin/auxin-cli -c . -u +447927948360 receive | jq -r ".[] | [.remote_address.address.Both[0], .content.text_message, .timestamp] | select(.[1] != null) | @tsv"';
    UPDATE inbox SET unread=FALSE WHERE inbox.unread=TRUE RETURNING *;
$$ LANGUAGE SQL;


CREATE TABLE IF NOT EXISTS commands (name TEXT, fn TEXT)

CREATE OR REPLACE FUNCTION call_fn_with_arg(query TEXT, arg TEXT) 
RETURNS text AS $$ 
    DECLARE 
        output TEXT;
    BEGIN
        CREATE TEMP TABLE tmp_call (result text);
        EXECUTE format('INSERT INTO tmp_call select %s(%s)', query, arg);
        SELECT result FROM tmp_call INTO output;
        DROP TABLE tmp_call;
        RETURN output;
    END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION dispatch_message(message TEXT) RETURNS TEXT as $$
    BEGIN
        match := select fn from commands where message ilike '%' || name || '%' limit 1
        return cas 
CREATE OR REPLACE FUNCTION handle_messages() RETURNS void AS $$
    INSERT INTO outbox (dest, msg) 
    SELECT 
        sender,
        CASE
            WHEN msg ILIKE '%printerfact%' THEN pgxr_printerfact()
            WHEN msg ILIKE '%ping%' THEN msg
            ELSE 'valid commands are printerfact and ping'
        END
    FROM receive()
--    RETURNING *;
$$ LANGUAGE SQL; 

CREATE EXTENSION IF NOT EXISTS pg_cron;
SELECT cron.unschedule(jobid) FROM cron.job ;
SELECT cron.schedule(job_name:='handle_messages', schedule:='* * * * *', command:='select handle_messages()')
