--COPY (select datastore from signal_accounts where id='<number>') TO PROGRAM 'tax x';
--COPY signal_accounts FROM PROGRAM 'tar xf data'

DROP TABLE IF EXISTS inbox;
CREATE TABLE inbox (id SERIAL PRIMARY KEY, msg TEXT, sender TEXT, ts TEXT, unread BOOLEAN DEFAULT TRUE);

CREATE OR REPLACE FUNCTION receive()
RETURNS table (id integer, msg TEXT, sender TEXT, ts TEXT, unread BOOLEAN) AS $$ 
    COPY inbox (sender, msg, ts) 
    FROM PROGRAM '/home/sylv/.local/bin/auxin-cli -c . -u +447927948360 receive | jq -r ".[] | [.remote_address.address.Both[0], .content.text_message, .timestamp] | select(.[1] != null) | @tsv"';
    UPDATE inbox SET unread=FALSE WHERE inbox.unread=TRUE 
    RETURNING *;
$$ LANGUAGE SQL;


CREATE OR REPLACE FUNCTION get_output(program TEXT)
RETURNS text AS $$ 
    DECLARE 
        output TEXT;
    BEGIN
        -- COPY requires a table, so let's make a temporary one
        CREATE TEMP TABLE tmp (content text);
        EXECUTE format('COPY tmp FROM PROGRAM %s;', quote_literal(program));
        SELECT content FROM tmp INTO output;
        DROP TABLE tmp;
        RETURN output;
    END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION curl_printerfact(msg text) RETURNS text AS $$
    select get_output('curl https://colbyolson.com/printers');
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION curl_intelfact(msg text) RETURNS text AS $$
    select get_output('curl https://intelligence.sometimes.workers.dev');
$$ LANGUAGE SQL;

CREATE OR REPLACE FUNCTION echo(msg text) RETURNS text AS 'BEGIN RETURN msg; END;'
LANGUAGE plpgsql; 

DROP TABLE IF EXISTS commands;
CREATE TABLE commands (name TEXT, fn TEXT);
-- name is the message string to match; fn is the name of the function
INSERT INTO commands VALUES 
    ('printerfact', 'curl_printerfact'),
    ('intelfact', 'curl_intelfact'),
    ('ping', 'echo');

CREATE OR REPLACE FUNCTION dispatch_message(message TEXT) 
RETURNS text AS $$ 
    DECLARE 
        output TEXT;
        fn TEXT;
        error_text TEXT;
        error_context TEXT;
    BEGIN
        SELECT commands.fn
        FROM commands 
        WHERE message ILIKE '%' || name || '%' 
        LIMIT 1
        INTO fn;
        IF NOT FOUND THEN
            RAISE NOTICE 'no command found for message %', message;
            SELECT format('Sorry, valid commands are: %s', string_agg(commands.name, ', '))
            FROM commands
            INTO output;
        ELSE 
            RAISE NOTICE 'found command for message %: %', message, fn;
            BEGIN 
                EXECUTE format('select %s(%s)', fn, quote_literal(message)) INTO output;
            EXCEPTION WHEN OTHERS THEN
                -- something went wrong! 
                GET STACKED DIAGNOSTICS 
                    error_text = MESSAGE_TEXT,
                    error_context = PG_EXCEPTION_CONTEXT;
                RAISE NOTICE 'error in message dispatch: %, %', error_text, error_context;
                -- send error to admin
                INSERT INTO outbox (msg, dest) 
                VALUES (format('error: %s, %s', error_text, error_context), '+16176088864');
                output := 'Sorry, something went wrong';
            END; 
        END IF;
        RETURN output;
    END;
$$ LANGUAGE plpgsql;

DROP TABLE IF EXISTS outbox;
CREATE TABLE outbox (id SERIAL PRIMARY KEY, msg TEXT, dest TEXT, ts TEXT);

CREATE OR REPLACE FUNCTION trigger_send()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $BODY$
BEGIN 
    NEW.ts := get_output(
        -- compose an auxin-cli invocation to send a message, escaping '
        format(
            $$/home/sylv/.local/bin/auxin-cli -c . -u +447927948360 send -m '%s' %s$$,
            regexp_replace(NEW.msg, $$'$$, $$\'$$),  -- my poor syntax highlighter'
            quote_ident(NEW.dest)
        )
    ); -- this ought to strip 'Successfully sent Signal message with timestamp: '
    RETURN NEW;
END;
$BODY$;

DROP TRIGGER IF EXISTS send ON outbox;
CREATE TRIGGER send BEFORE INSERT ON outbox FOR EACH ROW EXECUTE PROCEDURE trigger_send();

CREATE OR REPLACE FUNCTION handle_messages() RETURNS void AS $$
    -- reply to each received message with the results of dispatch_message
    INSERT INTO outbox (dest, msg) 
    SELECT 
        inbox.sender,
        dispatch_message(inbox.msg)
    FROM receive() AS inbox
    RETURNING *;
$$ LANGUAGE SQL; 

CREATE OR REPLACE FUNCTION repeatedly_handle_messages() RETURNS void AS $$
    BEGIN 
        -- i was hoping to handle_messages() four times a second, 
        -- but it seems to actually be executed after finishing every sleep? :(
        FOR i IN 1..4 LOOP
            PERFORM handle_messages();
            RAISE NOTICE '% : handled messages', clock_timestamp();
            PERFORM pg_sleep(0.2);
        END LOOP;
    END;
$$ LANGUAGE plpgsql;
        
CREATE EXTENSION IF NOT EXISTS pg_cron;
SELECT cron.unschedule(jobid) FROM cron.job ;
SELECT cron.schedule(job_name:='handle_messages', schedule:='* * * * *', command:='select repeatedly_handle_messages()')
