
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
