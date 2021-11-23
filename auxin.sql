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
$$ LANGUAGE plpgsql VOLATILE;


CREATE OR REPLACE FUNCTION trigger_send()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $BODY$
BEGIN 
    NEW.ts := get_output(
        format(
            '/home/sylv/.local/bin/auxin-cli -c . -u +447927948360 send -m "%s" %s',
            NEW.msg, 
            quote_ident(NEW.dest)
        )
    );
    RETURN NEW;
END;
$BODY$;

drop trigger if exists send on outbox;
create trigger send before insert on outbox for each row execute procedure trigger_send();

DROP TABLE IF EXISTS inbox;
CREATE TABLE inbox (id SERIAL PRIMARY KEY, msg TEXT, sender TEXT, ts TEXT, unread BOOLEAN DEFAULT TRUE);


DROP TABLE IF EXISTS inbox;
CREATE TABLE inbox (id SERIAL PRIMARY KEY, msg TEXT, sender TEXT, ts TEXT, unread BOOLEAN DEFAULT TRUE);

CREATE OR REPLACE FUNCTION receive()
RETURNS table (id integer, msg TEXT, sender TEXT, ts TEXT, unread BOOLEAN) AS $$ 
        COPY inbox (sender, msg, ts) 
        FROM PROGRAM '/home/sylv/.local/bin/auxin-cli -c . -u +447927948360 receive | jq -r ".[] | [.remote_address.address.Both[0], .content.text_message, .timestamp] | select(.[1] != null) | @tsv"';
        UPDATE inbox SET unread=FALSE WHERE inbox.unread=TRUE RETURNING *;
$$ LANGUAGE SQL;

