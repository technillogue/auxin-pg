CREATE TABLE IF NOT EXISTS get_fact (id SERIAL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS facts (fact TEXT);

CREATE OR REPLACE FUNCTION trigger_printerfact()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $BODY$
BEGIN 
    --insert into urls (content_id, url) values (NEW.id, char_length(NEW.content)); -- 
	COPY facts (fact) FROM PROGRAM 'curl https://colbyolson.com/printers';
    RETURN NEW;
END;
$BODY$;


create trigger whatever before insert on get_fact for each row execute procedure trigger_printerfact();


