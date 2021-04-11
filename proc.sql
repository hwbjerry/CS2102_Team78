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
                                                                                                        
--24
--This routine is used to add a new session to a course offering. The inputs to the routine include the following: course offering identifier, new session number, new session day, new session start hour, instructor identifier for new session, and room identifier for new session.
--If the course offering’s registration deadline has not passed and the the addition request is valid, the routine will process the request with the necessary updates.
   --SELECT duration
   --INTO sessionDuration
   --FROM Courses
   --WHERE course_id = course_offering_id;
DROP PROCEDURE IF EXISTS add_session;
CREATE OR REPLACE PROCEDURE add_session(course_offering_id INTEGER, launchDate DATE, new_session_number INTEGER, new_session_day DATE, new_session_start_hour TIME, instructor_id INTEGER, room_id INTEGER) AS $$
DECLARE
 sessionDuration INTEGER;
 regDeadline DATE;
BEGIN
   SELECT registration_deadline
   INTO regDeadline
   FROM Offerings
   WHERE course_id = course_offering_id AND launch_date = launchDate;
   IF NOT EXISTS (SELECT * FROM Offerings WHERE course_id  = course_offering_id AND launch_date = launchDate) THEN
     RAISE EXCEPTION 'Cannot add new session because the course offering does not exist';
   ELSIF (CURRENT_DATE > regDeadline) THEN
     RAISE EXCEPTION 'The registration deadline for course offering has already passed';
   ELSIF (room_id NOT IN (SElECT * FROM find_rooms(new_session_day, new_session_start_hour, interval '1 hour'))) THEN
     RAISE EXCEPTION 'Room is not available';
   ELSE
     INSERT INTO Sessions
     VALUES (new_session_number, new_session_start_hour, (new_session_start_hour + interval '1 hour'), new_session_day, launchDate, course_offering_id, room_id, instructor_id);
   END IF;
END;
$$LANGUAGE plpgsql;
                                                                                                        
                                                                                                        
                                                                                                        

