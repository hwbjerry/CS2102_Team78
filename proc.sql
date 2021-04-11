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
                                                                                                        
                                                                                                        

--Procedures

-- Functionality 7
-- Assumption return value of 'array of available hours' means only hour mark is check
-- Thus, hours in range (9, 10, 11, 14, 15, 16, 17)
DROP FUNCTION IF EXISTS get_available_instructors(in_course_id INT, start_date DATE, end_date DATE);
CREATE OR REPLACE FUNCTION get_available_instructors(in_course_id INT, start_date DATE, end_date DATE)
RETURNS TABLE (eid INT, name TEXT, total_hour INT, free_date DATE, free_hours INT[]) 
AS $$
	DECLARE
		curs1 cursor for (select * from instructors);
		curs2 cursor for (select * from sessions);
		r1 record;
		r2 record;
		course_area TEXT;
		weekly_hours_worked FLOAT;
		index_date DATE;
		index_time TIME;
		index_hour INT;
	BEGIN
		OPEN curs1;
		LOOP 
			fetch curs1 INTO r1;
			exit when not found;
			SELECT area_name INTO course_area FROM Courses WHERE Courses.course_id = in_course_id;
			
			IF EXISTS (SELECT 1 FROM Specializes WHERE Specializes.area_name =course_area AND Specializes.eid = r1.eid) THEN
				eid := r1.eid;
				SELECT Employees.ename into name FROM Employees WHERE Employees.eid = r1.eid;

				weekly_hours_worked := EXTRACT(EPOCH FROM(
					SELECT sum(Sessions.end_time - Sessions.start_time) 
					FROM Sessions
					WHERE date_part('month', Sessions.session_date) = date_part('month', start_date)
					AND Sessions.conduct_by = eid
					AND sessions.course_id = in_course_id -- do we need this?
				))/60/60;
				total_hour := weekly_hours_worked;
				--collected all employee data now check free date and free_time
				index_date := start_date;

				LOOP
					exit when index_date > end_date;
					free_date := index_date;
					free_hours := array[9,10,11,14,15,16,17];

					OPEN curs2;
					LOOP
						FETCH curs2 INTO r2;
						exit when not found;

						IF r2.conduct_by = r1.eid AND r2.session_date = index_date THEN
							index_time := r2.start_time;
							
							LOOP
								exit when index_time > r2.end_time;
								index_hour := date_part('hour', index_time);
								select array_remove(free_hours, index_hour) INTO free_hours;
								index_time := index_time + interval '1 hour';
							END LOOP;
						END IF;
					END LOOP;
					CLOSE curs2;
					RETURN NEXT;
					index_date := index_date + interval '1 day';
				END LOOP;
			END IF;
			
		END LOOP;
		CLOSE curs1;
	END
$$ LANGUAGE plpgsql;

--------*******--------

--------*******--------
-- Functionaility 6
-- Assumptions: NIL
-- Check since date provided need to check for all instructor that are free and have not departed during given date
-- Check if instructor is part time exceed 30 hours
DROP FUNCTION IF EXISTS find_instructors(in_course_id INTEGER, in_session_date DATE, session_start_hour TIME);
CREATE OR REPLACE FUNCTION find_instructors(in_course_id INTEGER, in_session_date DATE, session_start_hour TIME)
RETURNS TABLE (eid INT, name TEXT) 
AS $$
	DECLARE
		course_area TEXT;
		course_duration NUMERIC;
		curs1 cursor for (
			SELECT DISTINCT Employees.eid as eid, Employees.ename as name
			FROM Employees NATURAL JOIN Specializes 
			WHERE Employees.depart_date IS NULL OR Employees.depart_date >= in_session_date
			);
		r1 record;
		weekly_hours_worked FLOAT;
		session_end_hour TIME;
	BEGIN
		SELECT area_name, duration INTO course_area, course_duration FROM Courses WHERE Courses.course_id = in_course_id;
		session_end_hour := session_start_hour + INTERVAL '1' minute * FLOOR(course_duration*60);

		IF session_start_hour > '12:00:00'::TIME AND session_start_hour < '14:00:00'::TIME 
		OR session_start_hour < '12:00:00'::TIME AND session_end_hour > '14:00:00'::TIME
		THEN
			RAISE EXCEPTION 'Start Time % and End Time % disallowed.Cannot hold classes between 12pm-2pm', session_start_hour, session_end_hour;
		END IF;

		
		OPEN curs1;
		LOOP
			FETCH curs1 INTO r1;
			EXIT WHEN NOT FOUND;
			
			IF EXISTS (SELECT 1 FROM Specializes WHERE Specializes.area_name = course_area AND Specializes.eid = r1.eid)
			AND 
			NOT EXISTS (
				SELECT 1 
				FROM Sessions 
				WHERE Sessions.conduct_by = r1.eid 
				AND Sessions.session_date = in_session_date 
				AND
				(((Sessions.start_time BETWEEN session_start_hour AND session_end_hour) 
                OR (Sessions.end_time BETWEEN session_start_hour AND session_end_hour)
                OR (session_start_hour BETWEEN Sessions.start_time AND Sessions.end_time)
                OR (session_end_hour BETWEEN Sessions.start_time AND Sessions.end_time))
                OR
                ((Sessions.end_time + INTERVAL '1 hour' > session_start_hour AND Sessions.end_time <= session_start_hour) 
            	OR 
            	(Sessions.start_time < session_end_hour + INTERVAL '1 hour' AND Sessions.start_time >= session_end_hour))))
			THEN
					-- Valid for Part time instructors only
					weekly_hours_worked := EXTRACT(EPOCH FROM(
						SELECT sum(Sessions.end_time - Sessions.start_time) 
						FROM Sessions
						WHERE date_part('month', Sessions.session_date) = date_part('month', in_session_date)
						AND Sessions.conduct_by = r1.eid
						))/60/60;

						
					IF EXISTS (SELECT 1 FROM Full_Time_Emp WHERE Full_Time_Emp.eid = r1.eid) 
					OR weekly_hours_worked + course_duration <= 30 THEN
						eid := r1.eid;
						name := r1.name;
						return NEXT;
					END IF;
				
			END IF;
		END LOOP;
		CLOSE curs1;
	END
$$ LANGUAGE plpgsql;

--EXAMPLE:
-- select * from find_instructors(2, '2021-02-09'::date, '10:30:00'::time);
-- select * from find_instructors(2, '2021-02-09'::date, '14:30:00'::time);

-- Functionality 10
-- Assumption: Add as many valid sessions(instructor, room free) until invalid session
DROP PROCEDURE IF EXISTS add_course_offering(in_course_id INT, course_fees NUMERIC, in_launch_date DATE, in_registration_deadline DATE, in_target_number_registrations INT, in_eid INT, session_info TEXT[][]);
CREATE OR REPLACE PROCEDURE add_course_offering(in_course_id INT, course_fees NUMERIC, in_launch_date DATE, in_registration_deadline DATE, in_target_number_registrations INT, in_eid INT, session_info TEXT[][])
AS $$
	DECLARE
		session TEXT[];

		s_date DATE;
		s_start_time TIME;
		s_capacity INT;
		s_rid INT;
		s_id INT;
		s_conduct_by INT;
		s_duration INT;

		c_start_date DATE;
		c_end_date DATE;
		c_capacity INT;
	BEGIN
	
		IF (array_length(session_info, 1)) <= 0 THEN
			RAISE EXCEPTION 'No sessions info provided';
		END IF;

		-- Initialize varaibles for counter and bookkeeping
		s_id := 1;
		c_capacity := 0;
		c_start_date := session_info[1][1]::DATE;
		c_end_date := session_info[1][1]::DATE;

		INSERT INTO Offerings VALUES (in_launch_date, in_course_id, in_eid, c_start_date, c_end_date, in_registration_deadline, in_target_number_registrations, c_capacity, course_fees);

		FOREACH session SLICE 1 IN ARRAY session_info
		LOOP
			s_date := session[1]::DATE;
			s_start_time := session[2]::TIME;
			s_rid := session[3]::INT;

			RAISE NOTICE '% % %', s_date::DATE, s_start_time::TIME, s_rid::INT;

			IF NOT EXISTS (SELECT 1 FROM find_instructors(in_course_id, s_date, s_start_time)) THEN
				RAISE EXCEPTION 'No instructor avaliable for session on % with start time %', s_date, s_start_time;
			END IF;

			SELECT duration INTO s_duration FROM Courses WHERE Courses.course_id = in_course_id;
			SELECT MAX(FI.eid) INTO s_conduct_by FROM find_instructors(in_course_id, s_date, s_start_time) as FI;
			SELECT seating_capacity INTO s_capacity from Rooms WHERE Rooms.rid = s_rid::INT;


			INSERT INTO Sessions VALUES (s_id, s_start_time, s_start_time + INTERVAL '1' minute * FLOOR(s_duration*60) , s_date, in_launch_date, in_course_id, s_rid, s_conduct_by);
			
			s_id := s_id + 1;
			c_capacity := c_capacity + s_capacity;

			IF s_date < c_start_date THEN
				c_start_date := s_date;
			END IF;

			IF s_date > c_end_date THEN
				c_end_date := s_date;
			END IF;
		END LOOP;
		-- IF in_target_number_registrations >= c_capacity THEN
		-- 	in_target_number_registrations := c_capacity;
		-- END IF;

		RAISE NOTICE '% % %', c_capacity, c_start_date, c_end_date;
		UPDATE Offerings 
		SET
			start_date = c_start_date,
			end_date = c_end_date,
			seating_capacity = c_capacity
		WHERE (Offerings.launch_date = in_launch_date 
			AND Offerings.course_id=in_course_id 
			AND Offerings.eid=in_eid 
			AND Offerings.start_date= session_info[1][1]::DATE
			AND Offerings.end_date=session_info[1][1]::DATE 
			AND Offerings.registration_deadline= in_registration_deadline 
			AND Offerings.target_number_registrations=in_target_number_registrations 
			AND Offerings.seating_capacity = 0 
			AND Offerings.fees=course_fees);
	END
$$ LANGUAGE plpgsql;

--EXAMPLE:
--call add_course_offering(2, 100, '2021-01-06'::DATE,'2021-01-25'::DATE, 10, 3, array[array['2021-02-09', '14:00:00', '3']]);

--Functionality 12
DROP FUNCTION IF EXISTS get_available_course_packages();
CREATE OR REPLACE FUNCTION get_available_course_packages ()
RETURNS TABLE (name TEXT, num_of_free_course INTEGER, end_date_for_promo DATE, price_of_package NUMERIC)
AS $$
	DECLARE
		curs CURSOR FOR (SELECT * FROM Course_packages);
		r RECORD;
		current_date DATE;
	BEGIN
		SELECT CURRENT_DATE INTO current_date;
		-- RAISE NOTICE '%', current_date;
		OPEN curs;
		LOOP
			FETCH curs INTO r;
			-- RAISE NOTICE 'TRYING NOW';
		    EXIT WHEN NOT FOUND;
		    -- RAISE NOTICE 'HELLO % % %', current_date, r.sale_start_date, r.sale_end_date;
			IF (current_date BETWEEN r.sale_start_date AND r.sale_end_date) THEN
	            name := r.package_name;
	            num_of_free_course := r.num_free_registrations;
	            end_date_for_promo := r.sale_end_date;
	            price_of_package := r.price;

	            RETURN NEXT;
	    	END IF;
        END LOOP;
    	CLOSE curs;
	END;
$$ LANGUAGE plpgsql;

-- EXAMPLE : 
--INSERT INTO Course_packages (sale_start_date, sale_end_date, num_free_registrations, package_name,  price) VALUES ('2021-04-01', '2021-05-29', 5, 'Computing 04', 200.00);
-- SELECT * FROM get_available_course_packages();

-- Functionality 15
--This routine is used to retrieve all the available course offerings that could be registered.
DROP FUNCTION IF EXISTS get_available_course_offerings();
CREATE OR REPLACE FUNCTION get_available_course_offerings()
RETURNS TABLE (course_title TEXT, course_area TEXT, start_date date, end_date date, registration_deadline DATE, fees numeric, num_remaining_seats int) 
AS $$
BEGIN
	RETURN QUERY	
	 	WITH course_and_applications AS (
		SELECT Courses.title, Courses.area_name, Offerings.start_date, Offerings.end_date, Offerings.launch_date, Offerings.registration_deadline, Offerings.fees, Offerings.seating_capacity, 
		COALESCE(registers_count, 0) as registers_count, COALESCE(redeems_count, 0) as redeems_count, COALESCE(cancels_count, 0) as cancels_count
		FROM (
			Courses NATURAL JOIN Offerings 
			NATURAL LEFT OUTER JOIN (SELECT course_id, launch_date, count(*) AS registers_count FROM Registers GROUP BY course_id, launch_date) AS Registers_filter
			NATURAL LEFT OUTER JOIN (SELECT course_id, launch_date, count(*) AS redeems_count FROM Redeems GROUP BY course_id, launch_date) AS Redeems_filter
			NATURAL LEFT OUTER JOIN (SELECT course_id, launch_date, count(*) AS cancels_count FROM Cancels GROUP BY course_id, launch_date) AS Cancels_filter
			)
		)
	
		SELECT title, area_name, course_and_applications.start_date, course_and_applications.end_date, course_and_applications.registration_deadline, course_and_applications.fees, (seating_capacity-(registers_count + redeems_count - cancels_count))::INT as num_remaining_seats
		FROM course_and_applications
		WHERE CURRENT_DATE BETWEEN course_and_applications.launch_date AND course_and_applications.registration_deadline
		AND (registers_count + redeems_count - cancels_count) < seating_capacity
		ORDER BY registration_deadline, title;
END;
$$ LANGUAGE plpgsql;

-- EXAMPLE:
-- update offerings set registration_deadline='2021-04-15' where course_id=4;
-- select * from get_available_course_offerings();

-- Functionality 16
DROP FUNCTION IF EXISTS get_available_course_sessions (cid INT);
CREATE OR REPLACE FUNCTION get_available_course_sessions (cid INT)
RETURNS TABLE (session_date DATE, session_start_hour TIME, instructor_name TEXT, num_remaining_seats INT)
AS $$
	BEGIN
		IF NOT EXISTS (SELECT 1 FROM Offerings WHERE Offerings.course_id = cid) THEN
			RAISE EXCEPTION 'Course Offering % is invalid', cid;
		END IF;

		RETURN QUERY
		select available_course_offerings_details.session_date, available_course_offerings_details.start_time, 
		available_course_offerings_details.ename, available_course_offerings_details.num_remaining_seats                
		from (get_available_course_offerings() as available_course_offerings NATURAL JOIN Offerings NATURAL JOIN Sessions NATURAL JOIN Employees) as available_course_offerings_details
		where available_course_offerings_details.course_id=cid;

	END;
$$ LANGUAGE plpgsql;

--EXAMPLE::
-- update offerings set registration_deadline='2021-04-15' where course_id=4;
--update sessions set course_id=4, launch_date='2021-03-28' WHERE course_id=3 AND launch_date='2021-02-26'; 
--select * from get_available_course_sessions(4);

--Functionality 8
DROP FUNCTION IF EXISTS find_rooms (input_session_date DATE, session_start_hour TIME, session_duration NUMERIC);
CREATE OR REPLACE FUNCTION find_rooms (input_session_date DATE, session_start_hour TIME, session_duration NUMERIC)
RETURNS TABLE (rid INTEGER) 
AS $$
DECLARE
	curs CURSOR FOR (SELECT * FROM Rooms);
	r RECORD;
	session_end_hour TIME;
BEGIN
	session_end_hour := session_start_hour + INTERVAL '1' minute * FLOOR(session_duration*60);
	OPEN curs;
	LOOP
		FETCH curs INTO r;
		EXIT WHEN NOT FOUND;
		IF NOT EXISTS (
            SELECT 1 
            FROM Sessions
            WHERE Sessions.rid = r.rid
            AND Sessions.session_date = input_session_date
            AND ((Sessions.start_time BETWEEN session_start_hour AND session_end_hour) 
                OR (Sessions.end_time BETWEEN session_start_hour AND session_end_hour)
                OR (session_start_hour BETWEEN Sessions.start_time AND Sessions.end_time)
                OR (session_end_hour BETWEEN Sessions.start_time AND Sessions.end_time))
        ) THEN 
            rid := r.rid;
      		RETURN NEXT;
		END IF;	
   	END LOOP;
   	CLOSE curs;
END;
$$ LANGUAGE plpgsql;

-- Functionality 21
-- Assumption Functionality 6 is correct
DROP PROCEDURE IF EXISTS update_instructor(cid INT, session_number INT, instructor_id INT);
CREATE OR REPLACE PROCEDURE update_instructor(cid INT, session_number INT, instructor_id INT)
AS $$
DECLARE
	current_date DATE;
	current_time TIME;
	s_date DATE;
	s_start_time TIME;
	s_launch_date DATE;
	s_rid INT;
BEGIN
	IF NOT EXISTS (SELECT 1 FROM Instructors WHERE Instructors.eid=instructor_id) THEN
		RAISE EXCEPTION '% is not an instructor', instructor_id;
	ELSIF NOT EXISTS (SELECT 1 FROM Sessions WHERE Sessions.course_id=cid AND Sessions.sid=session_number) THEN
		RAISE EXCEPTION 'There is no course % with session %', cid, session_number;
	END IF;

	current_date := CURRENT_DATE;
	current_time := CURRENT_TIME;
	

	IF EXISTS (SELECT 1 
		FROM  Sessions AS OS 
		WHERE cid= OS.course_id AND session_number=OS.sid
		AND ((current_date = OS.session_date AND current_time >= OS.start_time) OR current_date > OS.session_date)
		) 
		THEN
		RAISE EXCEPTION 'Course % ,Session % has already started or over', cid, session_number;
	END IF;

	SELECT session_date, start_time , launch_date, rid INTO s_date, s_start_time, s_launch_date, s_rid
	 FROM Sessions WHERE cid= Sessions.course_id AND session_number= Sessions.sid;
	
	IF EXISTS(SELECT 1 FROM find_instructors(cid, s_date, s_start_time) AS FI WHERE FI.eid = instructor_id) THEN
		UPDATE Sessions 
		SET conduct_by=instructor_id 
		WHERE Sessions.course_id=cid AND Sessions.sid=session_number AND Sessions.launch_date=s_launch_date AND Sessions.rid=s_rid;
	ELSE
		RAISE EXCEPTION 'Instructor is not free. Either in class or rest time';
	END IF;


END;
$$ LANGUAGE plpgsql;

-- EXAMPLE: 13 is the new employe eid change accordingly
--INSERT INTO Employees (ename, phone, address, email, join_date, depart_date) VALUES ('W', 9999995, 123455, 'marry@gmail.com', '2020-04-01', null);
--INSERT INTO Full_Time_Emp VALUES (13, 3000);
--INSERT INTO Instructors VALUES (13);
--INSERT INTO Full_Time_instructors VALUES (13);
--INSERT INTO Specializes VALUES (13, 'Computing 04');
--call update_instructor(4,4,13);

-- Functionality 22
-- Assumption Functionality 8 is correct
DROP PROCEDURE IF EXISTS update_room(cid INT, session_number INT, _rid INT);
CREATE OR REPLACE PROCEDURE update_room(cid INT, session_number INT, _rid INT)
AS $$
DECLARE
	current_date DATE;
	current_time TIME;
	s_date DATE;
	s_start_time TIME;
	s_launch_date DATE;
	s_rid INT;
	s_end_time TIME;
	s_duration NUMERIC;
	num_of_applicants INT;
	num_of_seats INT;
BEGIN
	IF NOT EXISTS (SELECT 1 FROM Rooms WHERE Rooms.rid=_rid) THEN
		RAISE EXCEPTION 'There is no room %', _rid;
	ELSIF NOT EXISTS (SELECT 1 FROM Sessions WHERE Sessions.course_id=cid AND Sessions.sid=session_number) THEN
		RAISE EXCEPTION 'There is no course % with session %', cid, session_number;
	END IF;

	current_date := CURRENT_DATE;
	current_time := CURRENT_TIME;
	

	IF EXISTS (SELECT 1 
		FROM  Sessions AS OS 
		WHERE cid= OS.course_id AND session_number=OS.sid
		AND ((current_date = OS.session_date AND current_time >= OS.start_time) OR current_date > OS.session_date)
		) 
		THEN
		RAISE EXCEPTION 'Course % ,Session % has already started or over', cid, session_number;
	END IF;

	-- Extract old data primary key attributions
	SELECT session_date, start_time , launch_date, rid, end_time INTO s_date, s_start_time, s_launch_date, s_rid, s_end_time
	 FROM Sessions WHERE cid= Sessions.course_id AND session_number= Sessions.sid;

	-- CTE FOR NEXT STATEMENT 
	WITH course_and_applications AS (
		SELECT Courses.course_id, 
		COALESCE(registers_count, 0) as registers_count, COALESCE(redeems_count, 0) as redeems_count, COALESCE(cancels_count, 0) as cancels_count
		FROM (
			Courses NATURAL JOIN Offerings 
			NATURAL LEFT OUTER JOIN (SELECT cid, s_launch_date, count(*) AS registers_count FROM Registers GROUP BY cid, s_launch_date) AS Registers_filter
			NATURAL LEFT OUTER JOIN (SELECT cid, s_launch_date, count(*) AS redeems_count FROM Redeems GROUP BY cid, s_launch_date) AS Redeems_filter
			NATURAL LEFT OUTER JOIN (SELECT cid, s_launch_date, count(*) AS cancels_count FROM Cancels GROUP BY cid, s_launch_date) AS Cancels_filter
			)
	)
	-- Get total number of applications for course with given session
	SELECT (registers_count + redeems_count - cancels_count)::INT INTO num_of_applicants FROM course_and_applications WHERE course_and_applications.course_id=cid;	 
	-- Get seating capacity of new room
	SELECT seating_capacity INTO num_of_seats FROM Rooms WHERE Rooms.rid = _rid;

	s_duration := EXTRACT(EPOCH FROM s_end_time - s_start_time)/3600;

	-- If seating capacity > number of applications AND room is free, UPDATE
	IF ((num_of_applicants <= num_of_seats) 
		AND 
	EXISTS(SELECT 1 FROM find_rooms(s_date, s_start_time, s_duration) AS FR WHERE FR.rid = _rid)) 
	THEN
		-- UPDATE Redeems 
		-- SET rid=_rid 
		-- WHERE Redeems.course_id=cid AND Redeems.sid=session_number AND Redeems.launch_date=s_launch_date AND Redeems.rid=s_rid;
		UPDATE Sessions 
		SET rid=_rid 
		WHERE Sessions.course_id=cid AND Sessions.sid=session_number AND Sessions.launch_date=s_launch_date AND Sessions.rid=s_rid;
	ELSE
		RAISE EXCEPTION 'Room % with seating capacity % is too small for % applicants or already occupied', _rid, num_of_seats, num_of_applicants;
	END IF;
END;
$$ LANGUAGE plpgsql;

--EXAMPLE:
--call update_room(4,4,4);
--call update_room(4,4,5);
--------------

-- Functionality 18
-- Assumption:
-- Each course_id and session_id and launch_date and rid is unique
CREATE OR REPLACE FUNCTION get_my_registration (cid INTEGER) 
RETURNS TABLE (course_name TEXT, course_fees NUMERIC, sessionDate DATE, session_start_hour TIME, session_duration INTEGER, instructor_name TEXT)
AS $$
DECLARE  

BEGIN
	RETURN QUERY
	-- CTE FOR NEXT STATEMENT 
	WITH course_and_applications AS (
		SELECT Courses.title, Offerings.fees, Sessions.session_date, Sessions.start_time, Courses.duration, Employees.ename,
		COALESCE(registers_count, 0) as registers_count, COALESCE(redeems_count, 0) as redeems_count, COALESCE(cancels_count, 0) as cancels_count
		FROM (
			Courses NATURAL JOIN Offerings NATURAL JOIN Sessions INNER JOIN Employees ON Sessions.conduct_by = Employees.eid
			NATURAL LEFT OUTER JOIN (SELECT course_id, launch_date, count(*) AS registers_count FROM Registers WHERE cust_id=cid GROUP BY course_id, launch_date) AS Registers_filter
			NATURAL LEFT OUTER JOIN (SELECT course_id, launch_date, count(*) AS redeems_count FROM Redeems WHERE cust_id=cid GROUP BY course_id, launch_date) AS Redeems_filter
			NATURAL LEFT OUTER JOIN (SELECT course_id, launch_date, count(*) AS cancels_count FROM Cancels WHERE cust_id=cid GROUP BY course_id, launch_date) AS Cancels_filter
			)
	)
	-- Get total number of applications for course with given session
	SELECT  title, fees, session_date, start_time, duration, ename
	FROM course_and_applications 
	WHERE (registers_count + redeems_count - cancels_count) > 0
	AND (session_date > CURRENT_DATE OR (session_date = CURRENT_DATE AND start_time > CURRENT_TIME::TIME))
	ORDER BY session_date, start_time;


END;
$$ LANGUAGE plpgsql;

-- EXAMPLE:
-- select * from get_my_registration(4);

-- Functionality 27
DROP FUNCTION IF EXISTS top_packages(N INT);
CREATE OR REPLACE FUNCTION top_packages(N INT)
RETURNS TABLE (package_id INT, num_free_registrations INT, price NUMERIC, sale_start_date DATE, sale_end_date DATE, number_of_packages_sold INT)
AS $$
DECLARE
	curs CURSOR FOR (
		SELECT Course_packages.package_id, Course_packages.num_free_registrations, Course_packages.price, 
		Course_packages.sale_start_date, Course_packages.sale_end_date, count(Buys.buys_date) AS packages_sold
		FROM Course_packages NATURAL JOIN Buys
		WHERE EXTRACT(YEAR FROM Buys.buys_date) = EXTRACT(YEAR FROM CURRENT_DATE)
		GROUP BY Course_packages.package_id
		ORDER BY packages_sold DESC, price DESC
		);
	r1 record;
	r2 record;
	-- To track packages log for 'N'
	count_packages INT;
	-- To track number of packages to log
	packages_sold_counter INT;

BEGIN

	count_packages := 0;
	packages_sold_counter := 0;
	OPEN curs;
	LOOP
		FETCH curs INTO r1;
		EXIT WHEN NOT FOUND OR (packages_sold_counter >= N);
			packages_sold_counter := packages_sold_counter + r1.packages_sold; 
			-- RAISE NOTICE 'HELLO N %', packages_sold_counter;
	END LOOP;
	CLOSE curs;
	OPEN curs;
	LOOP
		FETCH curs INTO r2;
		EXIT WHEN NOT FOUND OR (count_packages >= packages_sold_counter);
			-- RAISE NOTICE 'HELLO';
			package_id := r2.package_id;
	        num_free_registrations := r2.num_free_registrations;
	        price := r2.price;
	        sale_start_date := r2.sale_start_date;
	        sale_end_date := r2.sale_end_date;
	        number_of_packages_sold := r2.packages_sold;
	        RETURN NEXT;
			-- RAISE NOTICE 'HELLO count_pack %', count_packages;
			count_packages := count_packages + r2.packages_sold;
	END LOOP;
	CLOSE curs;
END
$$ LANGUAGE plpgsql;

-- Functionality 26
DROP FUNCTION IF EXISTS promote_courses();
CREATE OR REPLACE FUNCTION promote_courses()
RETURNS TABLE (cust_id INTEGER, name TEXT, course_area TEXT, course_id INT, title TEXT, launch_date DATE, registration_deadline DATE, fees NUMERIC)
AS $$
BEGIN
	RETURN QUERY
	WITH REG_DETAILS AS (
		SELECT * FROM Customers NATURAL LEFT JOIN Registers NATURAL JOIN Redeems
		),
	INACTIVE_REG AS (
		SELECT *
		FROM REG_DETAILS RD1
		WHERE NOT EXISTS (
			SELECT 1 FROM REG_DETAILS RD2 WHERE RD1.cust_id=RD2.cust_id
			AND ((RD2.registers_date BETWEEN (CURRENT_DATE - INTERVAL '6 month'):: DATE AND CURRENT_DATE)
			OR (RD2.redeems_date BETWEEN (CURRENT_DATE - INTERVAL '6 month'):: DATE AND CURRENT_DATE))
		)
	), 
	INACTIVE_REG_RECENT_THREE AS (
        SELECT * FROM INACTIVE_REG IR
        WHERE (SELECT COUNT(*) FROM INACTIVE_REG IR2 WHERE IR2.cust_id = IR.cust_id AND (IR2.registers_date > IR.registers_date OR IR2.redeems_date > IR.redeems_date)) < 3
    ),
    INACTIVE_REG_AREA AS (
        SELECT IRRT.cust_id, IRRT.cust_name, Courses.area_name
        FROM INACTIVE_REG_RECENT_THREE IRRT NATURAL JOIN Courses
    )
    SELECT IRA.cust_id, IRA.cust_name, IRA.area_name, Courses.course_id, Courses.title, Offerings.launch_date, Offerings.registration_deadline, Offerings.fees
    FROM INACTIVE_REG_AREA IRA NATURAL JOIN Courses NATURAL JOIN Offerings
    WHERE Offerings.registration_deadline >= CURRENT_DATE
    ORDER BY IRA.cust_id, Offerings.registration_deadline;

END
$$ LANGUAGE plpgsql;

-- EXAMPLE:
-- select * from promote_courses();




-- DROP FUNCTION IF EXISTS template(in_course_id INT, start_date DATE, end_date DATE);
-- CREATE OR REPLACE FUNCTION template(in_course_id INT, start_date DATE, end_date DATE)
-- RETURNS TABLE (eid INT, name TEXT, total_hour INT, free_date DATE, free_hours INT[]) 
-- AS $$
-- 	DECLARE
-- 	BEGIN
-- 	END
-- $$ LANGUAGE plpgsql;

--2
CREATE OR REPLACE PROCEDURE remove_employee (remove_eid INTEGER, departure_date DATE) 
AS $$
BEGIN
	IF EXISTS (
SELECT 1 FROM Offerings WHERE eid = remove_eid AND
registration_deadline > departure_date)
	THEN RAISE EXCEPTION  'Update operation is rejected: registration deadline of some course offering is after this administrator’s departure date';
	ELSEIF EXISTS (
SELECT 1 FROM Sessions WHERE conduct_by = remove_eid AND
session_date = departure_date)
	THEN RAISE EXCEPTION  'Update operation is rejected: some course session taught by this instructor starts after his/her departure date';
	ELSEIF EXISTS (
SELECT 1 FROM Course_areas WHERE eid = remove_eid)
	THEN RAISE EXCEPTION  'Update operation is rejected: some course area is managed by this manager';
	END IF;
	UPDATE EMPLOYEES
set depart_date = departure_date
	WHERE eid  = remove_eid;
END;
$$ LANGUAGE plpgsql;


--4
CREATE OR REPLACE PROCEDURE update_credit_card (customer_id INTEGER, new_number TEXT, new_CVV INTEGER, new_expiry_date DATE)
AS $$
BEGIN
	INSERT INTO Credit_cards VALUES (new_number, new_cvv, new_expiry_date, current_date, customer_id);
END;
$$ LANGUAGE plpgsql;


--17
CREATE OR REPLACE PROCEDURE register_session(custId INT, courseId INT, launchDate DATE, sessionNumber INT, paymentMethod INT)
AS $$
DECLARE
packageId INT;
cardNumber TEXT;
buyDate DATE;

BEGIN
IF NOT EXISTS (SELECT 1 FROM Customers WHERE Customers.cust_id = custId) THEN
RAISE EXCEPTION 'Customer ID % is not valid', custId;
END IF;
IF NOT EXISTS (SELECT 1 FROM Sessions WHERE course_id = courseId AND launch_date = launchDate AND sid = sessionNumber) THEN
RAISE EXCEPTION 'The session % of course offering of % launched on % is invalid', sessionNumber, courseId, launchDate;
END IF;
IF paymentMethod != 0 AND paymentMethod != 1 THEN
RAISE EXCEPTION 'Payment method must be either INTEGER 0 or 1, which represent using credit card or redemption from active package respectively';
END IF;

IF paymentMethod = 1 THEN
    SELECT B.package_id, B.credit_card_number, B.buys_date INTO packageId, cardNumber, buyDate
    FROM Buys B
    WHERE EXISTS (SELECT 1 FROM Credit_cards C WHERE C.cust_id = custId AND C.credit_card_number = B.credit_card_number)
    AND B.num_remaining_redemptions >= 1
    ORDER BY B.num_remaining_redemptions LIMIT 1;
    IF packageId ISNULL THEN
      RAISE EXCEPTION 'Customer % has no active package', custId;
    END IF;
    INSERT INTO Redeems VALUES(CURRENT_DATE, sessionNumber, launchDate, courseId, sessionNumber, buyDate, packageId, cardNumber, custId);
    RAISE NOTICE 'The session successfully redeemed with package %', packageId;
ELSE
    SELECT C.credit_card_number INTO cardNumber
    FROM Credit_cards C
    WHERE C.cust_id = custId AND C.expiry_date >= CURRENT_DATE
    ORDER BY C.from_date DESC
    LIMIT 1;
    INSERT INTO Registers VALUES(CURRENT_DATE, sessionNumber, launchDate, cardNumber, custId, courseId, sessionNumber);
    RAISE NOTICE 'The session successfully bought by customer %', custId;
END IF;
END;
$$ LANGUAGE plpgsql;


--20
DROP PROCEDURE cancel_registration(integer,integer,date);
CREATE OR REPLACE PROCEDURE cancel_registration (customer_id INTEGER, cid INTEGER, launchDate DATE)
AS $$
DECLARE
  -- check if redeem or refund
  refund CURSOR FOR (select * from Registers natural join Sessions natural join Offerings);
  r1 record;
  redeem CURSOR FOR (select * from Redeems natural join Sessions);
  r2 record;

BEGIN
  open refund;
  LOOP
    fetch refund into r1;
    exit when not found;
    --in the case of credit card payment
    if (r1.cust_id = customer_id AND r1.course_id = cid AND r1.launch_date = launchDate)
    then
      if (current_date + '7 day'::interval <= r1.session_date)
        then  
          insert into Cancels values (current_date,  r1.cust_id, r1.sid,  r1.launch_date, r1.course_id, r1.rid, (0.9*r1.fees), NULL);
	delete from Registers where (r1.cust_id = customer_id AND r1.course_id = cid AND r1.launch_date = launchDate);
        else
          raise exception 'No refund for late cancellation';
      end if;
    end if;
  end loop;
  close refund;

  open redeem;
  LOOP 
    fetch redeem into r2;
    exit when not found;
    --in the case of redemption
    if (r2.cust_id = customer_id AND r2.course_id = cid AND r2.launch_date = launchDate)
    then
      if (current_date + '7 day'::interval <= r2.session_date)
        then 
          insert into Cancels values (current_date, r2.cust_id,  r2.sid, r2.launch_date, r2.course_id, r2.rid, NULL, 1);
	delete from Redeems where (r2.cust_id = customer_id AND r2.course_id = cid AND r2.launch_date = launchDate);
          update Buys
          set num_remaining_redemptions = num_remaining_redemptions + 1
          where cust_id = customer_id;
        else  
          raise exception 'Unable to credit due to late cancellation';
      end if;
    end if;
  end loop;
  close redeem;

END;
$$ LANGUAGE plpgsql;
	       
	       
--28
CREATE OR REPLACE FUNCTION popular_courses()
RETURNS TABLE (course_id INT, course_title TEXT, course_area TEXT, num_offerings INT, num_latest_registrations INT) AS $$
DECLARE
    curs CURSOR FOR (
        WITH W AS (
            SELECT C.course_id, C.title, C.area_name, O.launch_date
            FROM Courses C LEFT OUTER JOIN Offerings O on C.course_id = O.course_id
            WHERE EXTRACT(YEAR FROM O.start_date) = EXTRACT(YEAR FROM CURRENT_DATE)
            AND (
				SELECT count(O1.launch_date) > 2
				FROM Offerings O1
				WHERE C.course_id = O1.course_id
			)
        ),
        X AS (
            SELECT R.course_id, R.launch_date, count(*) AS registers_count
            FROM Registers R
            GROUP BY R.course_id, R.launch_date
        ),
        Y AS (
            SELECT R1.course_id, R1.launch_date, count(*) AS redeems_count
            FROM Redeems R1
            GROUP BY R1.course_id, R1.launch_date
        ),
        Z AS (
            SELECT C1.course_id, C1.launch_date, count(*) AS cancels_count
            FROM Cancels C1
            GROUP BY C1.course_id, C1.launch_date
        )
        SELECT W.course_id, W.title, W.area_name, W.launch_date, COALESCE(X.registers_count, 0) + COALESCE(Y.redeems_count, 0) - COALESCE(Z.cancels_count, 0) AS num_registerations
        FROM W LEFT OUTER JOIN X ON (W.course_id = X.course_id AND W.launch_date = X.launch_date)
                LEFT OUTER JOIN Y ON (W.course_id = Y.course_id AND W.launch_date = Y.launch_date)
                LEFT OUTER JOIN Z ON (W.course_id = Z.course_id AND W.launch_date = Z.launch_date)
        ORDER BY W.course_id, W.launch_date
    );
    curr_r RECORD;
    prev_r RECORD;
    num INT := 1;
    is_popular INT := 1;
BEGIN
    OPEN curs;
    FETCH curs INTO prev_r;
    LOOP
        FETCH curs INTO curr_r;
        EXIT WHEN NOT FOUND;
        IF prev_r.course_id = curr_r.course_id AND prev_r.num_registerations >= curr_r.num_registerations
        THEN
            is_popular := 0;
        ELSIF prev_r.course_id <> curr_r.course_id AND is_popular = 1
        THEN
            course_id := prev_r.course_id;
            course_title := prev_r.title;
            course_area := prev_r.area_name;
            num_offerings := num;
            num_latest_registrations := prev_r.num_registerations;
            RETURN NEXT;
            num := 1;
        ELSIF prev_r.course_id <> curr_r.course_id AND is_popular = 0
        THEN
            is_popular := 1;
            num := 1;
        ELSE
            num := num + 1;
        END IF;
        prev_r := curr_r;
    END LOOP;
	IF is_popular = 1
	THEN
		course_id := prev_r.course_id;
        course_title := prev_r.title;
        course_area := prev_r.area_name;
        num_offerings := num;
        num_latest_registrations := prev_r.num_registerations;
        RETURN NEXT;
	END IF;
    CLOSE curs;
END;
$$ LANGUAGE plpgsql;


--29
CREATE OR REPLACE FUNCTION view_summary_report(n integer)
RETURNS TABLE(
    month_and_year varchar(50),
    total_salary double precision,
    total_packages_sold integer,
    total_paid_fee double precision,
    total_refund double precision,
    total_redeemed_course integer
    ) AS $$
    DECLARE
        iter_date date;
    BEGIN
        iter_date = CURRENT_DATE;
        for counter in 1..n
        LOOP
            month_and_year:= to_char(iter_date, 'YYYY-MM');
            total_salary:= coalesce((SELECT sum(amount) FROM Pay_slips WHERE date_trunc('month', payment_date) = date_trunc('month', iter_date) GROUP BY date_trunc('month', payment_date)), 0);
            total_packages_sold:= coalesce((SELECT count(*) FROM Buys WHERE date_trunc('month', buys_date) = date_trunc('month', iter_date) GROUP BY date_trunc('month', buys_date)), 0);
            total_paid_fee:= coalesce((SELECT sum(fees) FROM (registers R NATURAL JOIN sessions S) INNER JOIN Offerings O ON (S.course_id, S.launch_date) = (O.course_id, O.launch_date)
                            WHERE date_trunc('month', registers_date) = date_trunc('month', iter_date) GROUP BY date_trunc('month', registers_date)
                            ), 0);
            total_refund:= coalesce((SELECT sum(refund_amt) FROM Cancels WHERE date_trunc('month', cancels_date) = date_trunc('month', iter_date) GROUP BY date_trunc('month', cancels_date)), 0);
            total_redeemed_course:= coalesce((SELECT count(*) FROM Buys WHERE date_trunc('month', buys_date) = date_trunc('month', iter_date) GROUP BY date_trunc('month', buys_date)), 0)
                                    - coalesce((SELECT count(*) FROM Cancels WHERE date_trunc('month', cancels_date) = date_trunc('month', iter_date) GROUP BY date_trunc('month', cancels_date)), 0);
            RETURN NEXT;
            iter_date:= iter_date - interval '1 month';
        END LOOP;
    END;
$$ LANGUAGE plpgsql;
	       
	       
	       
	       
	       
	       
	       
	       
	       
	       
	       
	       
	       
