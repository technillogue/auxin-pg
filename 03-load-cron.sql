CREATE EXTENSION IF NOT EXISTS pg_cron;
ALTER SYSTEM SET cron.database_name = 'postgres';
SELECT cron.unschedule(jobid) FROM cron.job ;
SELECT cron.schedule(job_name:='handle_messages', schedule:='* * * * *', command:='select repeatedly_handle_messages()')
