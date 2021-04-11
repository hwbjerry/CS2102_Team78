
--Functionality 23
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

-- 1. add_employee:
DROP PROCEDURE IF EXISTS add_employee(TEXT, TEXT, TEXT, TEXT, NUMERIC, DATE, TEXT, TEXT ARRAY);
CREATE OR REPLACE PROCEDURE add_employee(ename TEXT, address TEXT, phone TEXT, email TEXT, salary NUMERIC , join_date DATE, employee_category TEXT, course_area TEXT ARRAY)
AS $$
DECLARE
  curr_eid INT;
  number_course_area integer := array_length(course_area, 1);
  course_area_index integer := 1;
BEGIN
  IF employee_category NOT IN ('administrator', 'manager', 'full time instructor', 'part time instructor') THEN
       RAISE EXCEPTION 'Category of employee must be one of the following: administrator, manager, full time instructor, part time instructor';
  END IF;

  INSERT INTO Employees (ename, phone, address, email, join_date)
VALUES (ename, phone, address, email, join_date)
  RETURNING eid INTO curr_eid;
  IF employee_category = 'administrator' THEN
     INSERT INTO Full_Time_Emp VALUES(curr_eid, salary);
       WHILE course_area_index <= number_course_area LOOP
        INSERT INTO Courses_areas VALUES (course_area[course_area_index], curr_eid);
        course_area_index = course_area_index + 1;
     END LOOP;
     INSERT INTO Administrators VALUES (curr_eid);
  ELSEIF employee_category = 'manager' THEN
     INSERT INTO Full_Time_Emp VALUES (curr_eid, salary);
     INSERT INTO Managers VALUES (curr_eid);
     WHILE course_area_index <= number_course_area LOOP
        INSERT INTO Courses_areas VALUES (course_area[course_area_index], curr_eid);
        course_area_index = course_area_index + 1;
     END LOOP;
  ELSEIF employee_category = 'full time instructor' THEN
     INSERT INTO Instructors VALUES (curr_eid);
     INSERT INTO Full_Time_Emp VALUES (curr_eid, salary);
     WHILE course_area_index <= number_course_area LOOP
        INSERT into Specializes VALUES (curr_eid, course_area[course_area_index]);
        course_area_index = course_area_index + 1;
     END LOOP;
  ELSEIF employee_category = 'part time instructor' THEN
     INSERT into Part_Time_Emp VALUES (curr_eid, salary);
     WHILE course_area_index <= number_course_area LOOP
        INSERT into Specializes VALUES (curr_eid, course_area[course_area_index]);
        course_area_index = course_area_index + 1;
     END LOOP;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Testing procedure:
-- CALL add_employee (
--   'Administrator_1',
--   '1 Kent Ridge Drive',
--   '90901111',
--   'admin_1@gmail.com',
--   '3000',
--   '2021-03-31',
--   'administrator',
--   '{}'
-- );
--
-- CALL add_employee (
-- ‘Manager_1’,
-- ‘2 Kent Ridge Drive’,
-- ‘90902222’,
-- ‘manager_1@gmail.com’,
-- ‘3000’,
-- ‘2021-04-30’,
-- ‘Manager’,
-- ‘{“Law”}’
-- );
--
--
-- CALL add_employee (
-- ‘Instructor_1’,
-- ‘3 Kent Ridge Drive’,
-- ‘90903333’,
-- ‘instructor_1@gmail.com’,
-- ‘3000’,
-- ‘2021-03-31’,
-- ‘{“Computer Science”, “Law”}’
-- );
--
-- CALL add_employee (
-- ‘NULL’,
-- ‘2 Kent Ridge Drive’,
-- ‘90902222’,
-- ‘manager_1@gmail.com’,
-- ‘3000’,
-- ‘2021-04-30’,
-- ‘Manager’,
-- ‘{“Law”}’
-- );


-- 3. add_customer:
DROP PROCEDURE IF EXISTS add_customer(TEXT, TEXT, TEXT, TEXT, INT, DATE, INT);
CREATE OR REPLACE PROCEDURE add_customer(cust_name TEXT, address TEXT, phone TEXT, email TEXT, credit_card_num INT, expiry_date DATE, CVV INT)
AS $$
DECLARE
	curr_cust_id INT;
BEGIN
	INSERT INTO Customers (address, phone, cust_name, email) VALUES (address, phone, cust_name, email) RETURNING cust_id INTO curr_cust_id;
	INSERT INTO Credit_cards VALUES (credit_card_num, CVV, expiry_date, CURRENT_DATE, curr_cust_id);
END;
$$ LANGUAGE plpgsql;

-- Testing data:
-- call add_customer (
-- 'Customer1',
-- 'Blk 1 Green Ridge Road',
-- '11111111',
-- 'cust_1@hotmail.com',
-- '1111111111',
-- '2025-04-09',
-- 111
-- );


-- 5. add_course:
DROP PROCEDURE IF EXISTS add_course(TEXT, TEXT, TEXT, INT);
CREATE OR REPLACE PROCEDURE add_course(title TEXT, description TEXT, area_name TEXT, duration INT)
AS $$
	INSERT INTO Courses(title, duration, description, area_name) VALUES (title, duration, description, area_name);
$$ LANGUAGE sql;

-- Testing data:
-- CALL add_course('Additional_course', 'Computing additional course added', 'Computing 01', 4);


--9. get_available_rooms:
DROP FUNCTION IF EXISTS get_available_rooms(start_date DATE, end_date DATE);
CREATE OR REPLACE FUNCTION get_available_rooms(start_date DATE, end_date DATE)
RETURNS TABLE (rid INT, seating_capacity INT, in_day DATE, range_available_hours INT[]) AS $$
DECLARE
  hours_arr INT[];
  curr_hour INT;
  record_room RECORD;
  record_day RECORD;
loop_count INT;
curs_room CURSOR FOR (SELECT * FROM Rooms ORDER BY rid);
curs_day CURSOR FOR (SELECT d.as_of_date::DATE FROM GENERATE_SERIES(start_date -  '1 day '::INTERVAL, end_date,  '1 day '::INTERVAL) d (as_of_date));

BEGIN
  OPEN curs_room;
     OPEN curs_day;
	LOOP
		FETCH curs_room INTO record_room;
		EXIT WHEN NOT FOUND;
		rid := record_room.rid;
		seating_capacity := record_room.seating_capacity;
		MOVE FIRST FROM curs_day;
		LOOP
			FETCH curs_day INTO record_day;
			EXIT WHEN NOT FOUND;
			in_day := record_day.as_of_date::DATE;
			hours_arr := array[9,10,11,14,15,16,17];
			loop_count := 7;
			LOOP
				curr_hour := hours_arr[loop_count];
				IF EXISTS (
				       SELECT 1
				       FROM Sessions
				       WHERE Sessions.session_date = in_day
				       AND Sessions.rid = record_room.rid
				       AND ((curr_hour =date_part('hour',Sessions.start_time)) OR (curr_hour < date_part('hour',Sessions.start_time) AND date_part('hour',Sessions.start_time) < curr_hour + 1) OR (date_part('hour',Sessions.start_time) < curr_hour AND curr_hour < date_part('hour',Sessions.end_time)))
				   )
				   THEN
						SELECT array_remove(hours_arr, curr_hour) INTO hours_arr;
				END IF;
			    loop_count := loop_count - 1;
				EXIT WHEN loop_count = 0;
			END LOOP;
			range_available_hours := hours_arr;
			RETURN NEXT;
		END LOOP;
	END LOOP;
   CLOSE curs_room;
   CLOSE curs_day;
END;
$$ LANGUAGE plpgsql;

-- This will return all rooms free except rid = 1 as there is a session at 0900.
-- Testing data:
-- SELECT * FROM get_available_rooms (
-- '2021-02-09',
-- '2021-02-10'
-- );


-- 11. add_course_package:
DROP PROCEDURE IF EXISTS add_course_package(TEXT, INT, DATE, DATE, NUMERIC);
CREATE OR REPLACE PROCEDURE add_course_package( package_name TEXT, num_free_registrations INT, sale_start_date DATE, sale_end_date DATE, price NUMERIC)
AS $$
	INSERT into Course_packages (sale_start_date, sale_end_date, num_free_registrations, package_name, price)  VALUES (sale_start_date, sale_end_date, num_free_registrations, package_name, price);
$$ LANGUAGE sql;

-- Testing data:
-- CALL add_course_package( 'add_course_packaging_packageName', 1 , '2020-01-01', '2020-02-29', 200.00);


-- 13. buy_course_package:
DROP PROCEDURE IF EXISTS buy_course_package(INT, INT);
CREATE OR REPLACE PROCEDURE buy_course_package (cid INT, pid INT)
AS $$
DECLARE
	num_remaining_redemptions INT;
	credit_card_num TEXT;
BEGIN
	IF cid NOT IN (SELECT Customers.cust_id FROM Customers) THEN
	RAISE EXCEPTION 'Customer ID is not correct. Enter another valid customer_id. ';
	END IF;
	IF pid NOT IN (SELECT Course_packages.package_id FROM Course_packages) THEN
	RAISE EXCEPTION 'Package ID is not correct. Enter another valid package_id.';
	END IF;
	SELECT num_free_registrations FROM Course_packages where Course_packages.package_id = pid INTO num_remaining_redemptions;
	SELECT credit_card_number from Credit_cards WHERE Credit_cards.cust_id = cid ORDER BY Credit_cards.from_date DESC LIMIT 1 INTO credit_card_num;
	INSERT INTO Buys VALUES (CURRENT_DATE, num_remaining_redemptions, pid, credit_card_num, cid);
END;
$$ LANGUAGE plpgsql;

-- Testing data:
-- call add_customer (
-- ‘Customer1’,
-- ‘Blk 1 Green Ridge Road’,
-- ‘11111111’,
-- ‘cust_1@hotmail.com’,
-- ‘1111111111’,
-- ‘2025-04-09’,
-- 111
-- );
--
-- INSERT INTO Course_packages (sale_start_date, sale_end_date, num_free_registrations, package_name,  price) VALUES ('2021-04-01', '2021-05-29', 5, 'Computing 04', 200.00);
--
-- CALL buy_course_package(11, 11);


-- 14. get_my_course_package:
DROP FUNCTION IF EXISTS get_my_course_package (cid INT);
CREATE OR REPLACE FUNCTION get_my_course_package (cid INT)
RETURNS json AS $$
DECLARE
 result JSON;
 buy_date DATE;
 packageId INT;
 credit_card_num TEXT;
 remaining_redemptions INT;
 Cust_has_package INT := 0;
BEGIN
 IF NOT EXISTS (SELECT 1 FROM Customers WHERE Customers.cust_id = cid) THEN
 RAISE EXCEPTION 'Customer ID is not correct. Enter another valid customer_id.';
 END IF;

IF EXISTS (SELECT 1 FROM Buys NATURAL JOIN Credit_cards WHERE cust_id = cid) THEN
 SELECT buys_date, package_id, credit_card_number, num_remaining_redemptions INTO buy_date, packageId, credit_card_num, remaining_redemptions
 FROM Buys NATURAL JOIN Credit_cards WHERE cust_id = cid
 ORDER BY buys_date DESC LIMIT 1;

 IF remaining_redemptions = 0 THEN
    IF EXISTS (
       SELECT 1 FROM Redeems r
       WHERE r.credit_card_number = credit_card_num AND r.package_id = packageId AND r.buys_date = buy_date
       AND EXISTS (SELECT 1 FROM Sessions s WHERE s.course_id = r.course_id AND s.launch_date = r.launch_date AND s.sid = r.sid AND CURRENT_DATE <= s.session_date - 7)) THEN
       Cust_has_package := 1;
    END IF;
 ELSE
    Cust_has_package := 1;
 END IF;
END IF;

IF Cust_has_package = 1 THEN
 WITH cancels_num AS (
    SELECT count(*) AS count1, course_id, launch_date, sid
    FROM Cancels
    WHERE cust_id = cid
    GROUP BY course_id, launch_date, sid
 ), redeems_num AS (
 SELECT count(*) AS count2, course_id, launch_date, sid
 FROM Redeems
 WHERE package_id = packageId AND credit_card_number = credit_card_num AND buys_date = buy_date
 GROUP BY course_id, launch_date, sid
), Sessions_redeemed AS (
 SELECT s.course_id, s.launch_date, s.sid, c.title, s.session_date, s.start_time
 FROM Courses c, Sessions s, Redeems r
 WHERE r.package_id = packageId AND r.credit_card_number = credit_card_num AND r.buys_date = buy_date AND c.course_id = s.course_id
   AND s.course_id = r.course_id AND s.sid = r.sid AND s.launch_date = r.launch_date
 )

SELECT row_to_json(info) INTO result
FROM (
 SELECT package_name, buys_date, price, num_free_registrations, num_remaining_redemptions,
   (SELECT json_agg(Sessions) FROM (SELECT Sessions_redeemed.title, Sessions_redeemed.session_date, Sessions_redeemed.start_time FROM Sessions_redeemed NATURAL LEFT OUTER JOIN cancels_num NATURAL LEFT JOIN redeems_num WHERE COALESCE(count2, 0) - COALESCE(count1, 0) = 1 ORDER BY Sessions_redeemed.session_date, Sessions_redeemed.start_time) Sessions) AS Sessions_redeemed
   FROM Course_packages NATURAL JOIN Buys
   WHERE package_id = packageId AND buys_date = buy_date AND credit_card_number = credit_card_num
   ) info;
END IF;

RETURN result;

END;
$$ LANGUAGE plpgsql;

-- Testing data:
-- SELECT * FROM get_my_course_package(1);
-- will return nothing since the cust_id 1 has no more num_remaining_redemptions
--
-- SELECT * FROM get_my_course_packages(2);



-- 19. update_course_session:
DROP PROCEDURE IF EXISTS update_course_session(INT, INT, INT);
CREATE OR REPLACE PROCEDURE update_course_session (custId INT, courseId INT, new_sid INT)
AS $$
DECLARE
   num_students_within_a_session INT;
   cancel_count INT;
   c1 INT;
   c2 INT;
   c3 INT;
   c4 INT;
   c5 INT;
   c6 INT;

BEGIN
IF NOT EXISTS (SELECT * FROM Sessions s WHERE s.sid=new_sid) THEN
RAISE EXCEPTION 'Session not valid.';


 ELSE
       SELECT COALESCE(count(*), 0) INTO c1
       FROM Redeems
       WHERE Redeems.course_id = courseId AND Redeems.sid = new_sid
       ;
       SELECT COALESCE(count(*), 0) INTO c2
       FROM Registers
       WHERE Registers.course_id = courseId AND Registers.sid = new_sid
       ;
       SELECT COALESCE(count(*), 0) INTO c3
       FROM Cancels
       WHERE Cancels.course_id = courseId AND Cancels.sid = new_sid
       ;

       num_students_within_a_session = c1 + c2 + c3;

       SELECT COALESCE(count(*), 0) INTO c4
       FROM Redeems
       WHERE Redeems.course_id = courseId
       AND Redeems.credit_card_number IN
           (SELECT credit_card_number FROM Credit_cards where Credit_cards.cust_id = custId);

       SELECT COALESCE(count(*), 0) INTO c5
       FROM Registers
       WHERE Registers.course_id = courseId
       AND Registers.credit_card_number IN
           (SELECT credit_card_number FROM Credit_cards where Credit_cards.cust_id = custId);

       SELECT COALESCE(count(*), 0) INTO c6
       FROM Cancels
       WHERE Cancels.course_id = courseId
       AND Cancels.cust_id = custId;

       cancel_count = c4 + c5 + c6;
       IF (cancel_count = 0) THEN
       RAISE EXCEPTION 'Customer is not registered in session';

       ELSIF (num_students_within_a_session+1 > (SELECT seating_capacity FROM (Rooms NATURAL JOIN Sessions) WHERE Rooms.rid = Sessions.rid GROUP BY Rooms.rid LIMIT 1)) THEN
       RAISE EXCEPTION 'Session does not have enough seats.';

       ELSIF EXISTS (SELECT * FROM Registers WHERE Registers.course_id = courseId AND (Registers.credit_card_number IN (SELECT credit_card_number FROM Credit_cards where Credit_cards.cust_id = custId))) THEN
           UPDATE Registers r
           SET sid = new_sid
           WHERE r.course_id = courseId
           AND r.credit_card_number IN (SELECT credit_card_number FROM Credit_cards where Credit_cards.cust_id = custId);

       ELSE
           UPDATE Redeems
           SET sid = new_sid
           WHERE Redeems.course_id = courseId
           AND Redeems.credit_card_number IN (SELECT credit_card_number FROM Credit_cards where Credit_cards.cust_id = custId);
       END IF;
   END IF;
END;
$$ LANGUAGE plpgsql;

-- Testing data:
-- CALL update_course_session(10, 10, 9);