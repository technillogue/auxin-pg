DROP TABLE IF EXISTS pastes;
CREATE TABLE pastes (id SERIAL PRIMARY KEY, content TEXT, url TEXT);

CREATE OR REPLACE FUNCTION trigger_upload()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $BODY$
DECLARE
    text TEXT;
    program TEXT;
    tmp TEXT;
    content TEXT;
BEGIN 
    text := quote_ident(NEW.content);
    program := 'echo ' || text || '| curl --data-binary @/dev/stdin https://public.getpost.workers.dev|grep share';
    tmp := 'temp';
    EXECUTE 'CREATE TEMP TABLE ' || tmp || ' (content text)';
    EXECUTE 'COPY ' || tmp || E' FROM PROGRAM \'' || program||E'\'';
    EXECUTE 'SELECT content FROM ' || tmp INTO content;
    EXECUTE 'DROP TABLE ' || tmp;
    NEW.url := substring(content, 'https://.*?raw');
    RETURN NEW;
END;
$BODY$;

drop trigger if exists whatever on pastes;
create trigger whatever before insert on pastes for each row execute procedure trigger_upload();
