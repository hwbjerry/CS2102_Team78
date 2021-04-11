--23
--This routine is used to remove a course session. The inputs to the routine include the following: course offering identifier and session number.
--If the course session has not yet started and the request is valid, the routine will process the request with the necessary updates.
--The request must not be performed if there is at least one registration for the session.
--Note that the resultant seating capacity of the course offering could fall below the course offering’s target number of registrations, which is allowed.
DROP Procedure if exists remove_session;
CREATE OR REPLACE Procedure remove_session(cid INTEGER, launchDate DATE, session_number INTEGER) AS $$
DECLARE
   num_of_registrations int;
   num_of_redeems int;
   num_of_cancellations int;
   condition text;
   --num_of_active_registrations int;
 
BEGIN
   num_of_registrations :=
          ( SELECT count(*)
           FROM Sessions S, Registers R
           WHERE (S.sid = session_number) and (S.course_id = cid) and (S.launch_date = launchDate) and (R.sid = S.sid));
   num_of_redeems :=
           (SELECT count(*)
           FROM Sessions S, Redeems R
           WHERE (S.sid = session_number) and (S.course_id = cid) and (S.launch_date = launchDate) and (R.sid = S.sid));
   num_of_cancellations :=
           (SELECT count(*)
           FROM Sessions S, Cancels C
           WHERE (S.sid = session_number) and (S.course_id = cid) and (S.launch_date = launchDate) and (C.sid = S.sid));
   IF (num_of_registrations + num_of_redeems - num_of_cancellations = 0) AND (CURRENT_DATE - (select launch_date from Offerings as so where so.course_id = cid and so.launch_date = launchDate )::date < 0 ) THEN
   DELETE FROM SESSIONS WHERE course_id = cid AND launch_date = launchDate AND sid = session_number;
   END IF;
END;
$$ LANGUAGE plpgsql;

