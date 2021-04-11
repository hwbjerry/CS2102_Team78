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
                                                  
                                                   
DROP FUNCTION IF EXISTS pay_salary();
DROP FUNCTION IF EXISTS get_hour_of_work();
CREATE OR REPLACE FUNCTION pay_salary()
RETURNS TABLE (eid INTEGER, name TEXT, status TEXT, num_of_working_days INTEGER, num_of_working_hours NUMERIC, hourly_rate NUMERIC, monthly_salary NUMERIC, amount NUMERIC)
AS $$
DECLARE
   curs CURSOR FOR (
       SELECT VAR.eid, VAR.ename, VAR.monthly_salary, VAR.hourly_rate, VAR.join_date, VAR.depart_date
       FROM (Employees NATURAL LEFT JOIN Part_Time_Emp NATURAL LEFT JOIN Full_Time_Emp) VAR
       WHERE VAR.depart_date >= DATE_TRUNC('month', CURRENT_DATE)::DATE or VAR.depart_date is NULL
   );
   r RECORD;
   month_first_day DATE;
   month_last_day DATE;
   work_first_day DATE;
   work_last_day DATE;
BEGIN
   OPEN curs;
   LOOP
       FETCH curs INTO r;
       EXIT WHEN NOT FOUND;
       month_first_day := DATE_TRUNC('month', CURRENT_DATE)::DATE;
       month_last_day := (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '1 month - 1 day')::DATE;
       IF r.hourly_rate IS NOT NULL THEN --Part Time
         num_of_working_hours := get_hour_of_work(r.eid);
         eid := r.eid;
         name := r.ename;
         status := 'Part-time';
         num_of_working_days := NULL;
         hourly_rate := r.hourly_rate;
         monthly_salary := NULL;
         amount := TRUNC(hourly_rate * num_of_working_hours, 2);
         INSERT INTO Pay_slips VALUES (eid, CURRENT_DATE, amount, num_of_working_hours, num_of_working_days);
         RETURN NEXT;
       ELSE --Full Time
         IF r.depart_date NOT BETWEEN month_first_day AND month_last_day THEN
           work_last_day := month_last_day;
         ELSE
           work_last_day := r.depart_date;
         END IF;
         IF r.join_date NOT BETWEEN month_first_day AND month_last_day THEN
           work_first_day := month_first_day;
         ELSE
           work_first_day := r.join_date;
         END IF;
         num_of_working_hours := NULL;
         eid := r.eid;
         name := r.ename;
         status := 'Full-time';
         num_of_working_days := work_last_day - work_first_day + 1;
         hourly_rate := NULL;
         monthly_salary := r.monthly_salary;
         amount := TRUNC(monthly_salary * num_of_working_days / (1 + month_last_day - month_first_day), 2);
         INSERT INTO Pay_slips VALUES (eid, CURRENT_DATE, amount, num_of_working_hours, num_of_working_days);
         RETURN NEXT;
       END IF;
   END LOOP;
   CLOSE curs; 
END
$$ LANGUAGE plpgsql;
 

--Helper function to get employee's working hour of the current month
CREATE OR REPLACE FUNCTION get_hour_of_work(IN empId INT,  OUT work_hour numeric)
RETURNS NUMERIC AS $$
BEGIN
 IF empId in (select eid from Part_Time_Emp) THEN
   work_hour := (
   select coalesce(sum(extract(hour from(end_time-start_time))),0)
    from Sessions
    where sid = empId
    and extract(month from session_date)=extract(month from current_date)
    and extract(year from session_date)=extract(year from current_date)
    );
 ELSE work_hour := NULL;
  END IF;
END;
$$ LANGUAGE plpgsql;                                                                                                        
                                                                                                        
                                                                                                        

