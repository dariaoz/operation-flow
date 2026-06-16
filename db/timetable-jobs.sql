SELECT timetable.add_job(
               job_name => 'update-transaction-state-every-3-seconds',
               job_schedule => '@every 3 seconds',
               job_command =>'CALL update_transaction_states()'
       );


SELECT timetable.add_job(
               job_name => 'insert-every-5-seconds',
               job_schedule => '@every 5 seconds',
               job_command => 'CALL insert_pending_transaction()'
       );
       
SELECT timetable.add_job(
    job_name     => 'create-next-month-partition',
    job_schedule => '0 0 1 * *',
    job_command  => 'CALL create_next_month_partition()'
);
