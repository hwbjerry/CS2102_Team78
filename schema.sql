DROP TABLE IF EXISTS Customers CASCADE;
DROP TABLE IF EXISTS Credit_cards CASCADE;
DROP TABLE IF EXISTS Course_packages CASCADE;
DROP TABLE IF EXISTS Sessions CASCADE;
DROP TABLE IF EXISTS Offerings CASCADE;
DROP TABLE IF EXISTS Courses CASCADE;
DROP TABLE IF EXISTS Rooms CASCADE;
DROP TABLE IF EXISTS Owns CASCADE;
DROP TABLE IF EXISTS Registers CASCADE;
DROP TABLE IF EXISTS Buys CASCADE;
DROP TABLE IF EXISTS Redeems CASCADE;
DROP TABLE IF EXISTS Cancels CASCADE;
DROP TABLE IF EXISTS Specializes CASCADE;
DROP TABLE IF EXISTS Course_areas CASCADE;
DROP TABLE IF EXISTS Pay_slips CASCADE;
DROP TABLE IF EXISTS Employees CASCADE;
DROP TABLE IF EXISTS Part_time_Emp CASCADE;
DROP TABLE IF EXISTS Full_time_Emp CASCADE;
DROP TABLE IF EXISTS Instructors CASCADE;
DROP TABLE IF EXISTS Part_time_instructors CASCADE;
DROP TABLE IF EXISTS Full_time_instructors CASCADE;
DROP TABLE IF EXISTS Managers CASCADE;
DROP TABLE IF EXISTS Administrators CASCADE;

CREATE TABLE Customers (
	cust_id  SERIAL PRIMARY KEY,
	address TEXT NOT NULL,
	phone TEXT NOT NULL,
	cust_name TEXT NOT NULL,
	email TEXT NOT NULL,
  	UNIQUE (address, phone, cust_name, email)
);

CREATE TABLE Credit_cards ( 
	credit_card_number TEXT PRIMARY KEY,
	CVV INTEGER NOT NULL, 
	expiry_date DATE NOT NULL
);

CREATE TABLE Owns (
	from_date DATE NOT NULL,
  	cust_id INTEGER NOT NULL,
  	credit_card_number TEXT,
	foreign key (cust_id) REFERENCES Customers(cust_id),
	foreign key (credit_card_number) REFERENCES Credit_cards(credit_card_number),
	primary key (credit_card_number, cust_id)
);

CREATE TABLE Course_packages (
	package_id SERIAL PRIMARY KEY,
	sale_start_date DATE NOT NULL,
	sale_end_date DATE NOT NULL,
	num_free_registrations INTEGER NOT NULL,
	package_name TEXT NOT NULL,
	price NUMERIC NOT NULL,
	CHECK (
		sale_start_date <= sale_end_date
		and
	num_free_registrations >= 0
)
);

CREATE TABLE Rooms (
	rid INTEGER PRIMARY KEY,
	location TEXT UNIQUE NOT NULL,
	seating_capacity INTEGER NOT NULL
);

CREATE TABLE Employees (
	eid SERIAL PRIMARY KEY,
	ename TEXT NOT NULL, 
	phone TEXT, 
	address TEXT, 
	email TEXT,
	join_date DATE,
	depart_date DATE DEFAULT NULL
);

CREATE TABLE Part_Time_Emp (
	eid INTEGER PRIMARY KEY references Employees(eid) ON DELETE CASCADE,
	hourly_rate NUMERIC NOT NULL
);

CREATE TABLE Full_Time_Emp (
	eid INTEGER PRIMARY KEY references Employees(eid) ON DELETE CASCADE,
	monthly_salary NUMERIC NOT NULL
);

CREATE TABLE Instructors (
	eid INTEGER PRIMARY KEY references Employees(eid) ON DELETE CASCADE
);

CREATE TABLE Part_Time_Instructors (
	eid INTEGER PRIMARY KEY,
  	foreign key (eid) references Part_Time_Emp(eid) ON DELETE CASCADE,
  	foreign key (eid) references Instructors(eid) ON DELETE CASCADE
);

CREATE TABLE Full_Time_Instructors (
	eid INTEGER PRIMARY KEY,
  	foreign key (eid) references Full_Time_Emp(eid) ON DELETE CASCADE,
  	foreign key (eid) references Instructors(eid) ON DELETE CASCADE
);

CREATE TABLE Managers (
	eid INTEGER PRIMARY KEY references Full_Time_Emp(eid) ON DELETE CASCADE
);

CREATE TABLE Administrators (
 	eid INTEGER PRIMARY KEY references Full_Time_Emp(eid) ON DELETE CASCADE
);

-- Integrate with Manages lecture ER page 44
CREATE TABLE Course_areas ( 
	area_name TEXT primary key,
	eid INTEGER NOT NULL,
	foreign key(eid) references Managers(eid) 
);


CREATE TABLE Courses (
	course_id SERIAL PRIMARY KEY,
	title TEXT NOT NULL,
	duration INTEGER NOT NULL,
	description TEXT,
	area_name TEXT NOT NULL,
	foreign key (area_name) REFERENCES Course_areas(area_name), 
	UNIQUE(title)
);



-- integrate with Handles lecture ER page 44
-- integrate with Has
CREATE TABLE Offerings (
	launch_date DATE NOT NULL,
	course_id INTEGER NOT NULL,
	eid INTEGER NOT NULL,
	start_date DATE,
	end_date DATE,
	registration_deadline DATE NOT NULL,
	target_number_registrations INTEGER NOT NULL,
	seating_capacity INTEGER,
	fees NUMERIC NOT NULL,
	primary key (launch_date, course_id),
	foreign key (course_id) REFERENCES Courses(course_id) on delete cascade, 
	foreign key (eid) REFERENCES Administrators(eid), 
CHECK (
AGE(start_date, registration_deadline) >= interval '10 days'
and 
start_date <= end_date 
and 
launch_date <= registration_deadline
)
);

-- integrate with Consist 
-- integrate with Conducts
CREATE TABLE Sessions (
	sid INTEGER,
	start_time TIME,
	end_time TIME,
	session_date DATE,
	launch_date DATE NOT NULL,
	course_id INTEGER NOT NULL,
	rid INTEGER NOT NULL,
	conduct_by INT NOT NULL,
	primary key (sid, launch_date, course_id, rid),
	foreign key (rid) REFERENCES Rooms(rid),
	foreign key (launch_date, course_id) REFERENCES Offerings(launch_date, course_id) on delete cascade,
	foreign key (conduct_by) REFERENCES Instructors(eid),
	CHECK (
		((start_time >= TIME '0900' and end_time <= TIME '1200')
		or
(start_time >= TIME '1400' and end_time <= TIME '1800')) 
and 
start_time < end_time
and 
date_part('dow', session_date) in (1, 2, 3, 4, 5)
)

);

CREATE TABLE Registers ( 
	registers_date DATE DEFAULT CURRENT_DATE,
	sid INTEGER,
	launch_date DATE NOT NULL,
	credit_card_number TEXT,
	cust_id INTEGER,
	course_id INTEGER NOT NULL,
	rid INTEGER NOT NULL,
	primary key (registers_date, sid, credit_card_number, cust_id),
	foreign key (sid, launch_date, course_id, rid) references Sessions (sid, launch_date, course_id, rid),
	foreign key (credit_card_number, cust_id) references Owns(credit_card_number, cust_id)
);

CREATE TABLE Buys (
	buys_date DATE DEFAULT CURRENT_DATE,
	num_remaining_redemptions INTEGER NOT NULL,
	package_id INTEGER,
	credit_card_number TEXT,
	cust_id INTEGER,
	PRIMARY KEY (buys_date, credit_card_number, package_id, cust_id),
	foreign key (credit_card_number, cust_id) references Owns(credit_card_number, cust_id),
  	foreign key (package_id) REFERENCES Course_packages(package_id),
	CHECK (
		num_remaining_redemptions >= 0
	)
);


CREATE TABLE Redeems (
	redeems_date DATE DEFAULT CURRENT_DATE,	
	sid INTEGER,
	launch_date DATE,
	course_id INTEGER,
	rid INTEGER NOT NULL,
	buys_date DATE,
	package_id INTEGER,
	credit_card_number TEXT,
	cust_id INTEGER,
	foreign key (buys_date, credit_card_number, package_id, cust_id) REFERENCES Buys(buys_date, credit_card_number, package_id, cust_id), 
	foreign key (sid, launch_date, course_id, rid) REFERENCES Sessions(sid, launch_date, course_id, rid),
	primary key (redeems_date, buys_date, credit_card_number, package_id, sid, launch_date, course_id),
	CHECK (
		redeems_date >= buys_date
	)
);

CREATE TABLE Cancels (
	cancels_date DATE DEFAULT CURRENT_DATE,
	cust_id INTEGER NOT NULL,
	sid INTEGER NOT NULL,	
	launch_date DATE NOT NULL,
	course_id INTEGER NOT NULL,
	rid INTEGER,
	refund_amt NUMERIC,
	package_credit INTEGER,
	check(package_credit >= 0),
	foreign key (sid, launch_date, course_id, rid) REFERENCES Sessions(sid, launch_date, course_id, rid),
	foreign key (cust_id) REFERENCES Customers(cust_id),
	primary key (cancels_date, cust_id, sid, launch_date, course_id),
	CHECK (
		(refund_amt IS NOT NULL AND package_credit IS NULL)
		or 
		(refund_amt IS NULL AND package_credit IS NOT NULL)
	)
);

CREATE TABLE Specializes (
	eid INTEGER references Instructors(eid), 
	area_name TEXT references Course_areas(area_name),
	primary key(eid, area_name)
); 

CREATE TABLE Pay_slips (
	eid INTEGER NOT NULL,
	payment_date DATE, 
	amount NUMERIC, 
	num_work_hours INTEGER,
	num_work_days INTEGER,
	primary key (payment_date, eid),
	foreign key (eid) references Employees(eid) ON DELETE CASCADE
);

-- Triggers
-- Customer must have a credit to be able to purchase the packages 
CREATE OR REPLACE FUNCTION check_own_credit_card() 
RETURNS TRIGGER 
AS $$
	BEGIN 
		IF ((SELECT COUNT(credit_card_number) FROM Owns WHERE cust_id = NEW.cust_id) = 0) 
THEN RAISE EXCEPTION 'Each customer is required to own at least one credit credit';
			RETURN NULL;
		END IF;
		RETURN NEW;
	END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER check_if_own_credit_card
AFTER UPDATE OR INSERT ON Customers
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_own_credit_card();


-- Each employee can only be one of the following: manager, instructor, administrator
CREATE OR REPLACE FUNCTION check_employee_only_one_role() RETURNS TRIGGER
AS $$
	DECLARE 
		Num_managers INT;
		Num_administrators INT;
		Num_instructors INT;
	BEGIN
		Num_managers := (SELECT 1 FROM Managers WHERE Managers.eid = NEW.eid);
Num_administrators := (SELECT 1 FROM Administrators WHERE Administrators.eid = NEW.eid);
Num_instructors := (SELECT 1 FROM Instructors WHERE Instructors.eid = NEW.eid);

 IF (Num_managers + Num_administrators + Num_instructors > 1) 
THEN RAISE EXCEPTION 'Employee is assigned to multiple roles. Each employee should only be assigned to one of the three roles (ie manager, instructor or administrator) ';
	RETURN NULL;
END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER check_employee_only_one_role
AFTER INSERT OR UPDATE ON Employees
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE PROCEDURE check_employee_only_one_role();



-- If employee with role departs company (checked)
CREATE OR REPLACE FUNCTION check_departing_employee_role_func() RETURNS TRIGGER
AS $$
BEGIN
		IF EXISTS (SELECT 1 FROM Offerings WHERE Offerings.eid = NEW.eid AND Offerings.registration_deadline > NEW.depart_date) THEN
		RAISE EXCEPTION 'Employee is already assigned to offering';
		ELSIF EXISTS (SELECT 1 FROM Sessions WHERE Sessions.conduct_by = NEW.eid AND New.depart_date < Sessions.session_date) THEN
		RAISE EXCEPTION 'Employee is already assigned to offering';
		ELSIF EXISTS (SELECT 1 FROM Course_areas WHERE Course_areas.eid = NEW.eid) THEN
		RAISE EXCEPTION  'Employee is already assigned to course area';
		ELSE RETURN NEW;
		END IF;
		RETURN NULL;
END
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER check_departing_employee_role_trigger
AFTER INSERT OR UPDATE OR DELETE ON Employees
FOR EACH ROW EXECUTE FUNCTION check_departing_employee_role_func();


-- Ensures that all managers and administrators are full time employees 
CREATE OR REPLACE FUNCTION check_if_full_time() RETURNS TRIGGER 
AS $$ 
BEGIN 
IF NOT EXISTS(SELECT Full_TIme_Emp.eid FROM Full_Time_Emp WHERE Full_Time_Emp.eid = NEW.eid)
THEN RAISE EXCEPTION  'Employee who are either administrators or managers needs to be full time. ';
RETURN NULL;
END IF;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER check_if_manager_full_time 
AFTER INSERT ON Managers
FOR EACH ROW EXECUTE FUNCTION check_if_full_time();

CREATE CONSTRAINT TRIGGER check_if_administrator_full_time 
AFTER INSERT ON Administrators
FOR EACH ROW EXECUTE FUNCTION check_if_full_time();

CREATE OR REPLACE FUNCTION check_part_time_full_time_func() RETURNS TRIGGER
AS $$
DECLARE
	part_time INT;
	full_time INT;
	total INT;
BEGIN
	part_time := (SELECT 1 FROM Part_Time_Emp WHERE Part_Time_Emp.eid = NEW.eid);
	full_time := (SELECT 1 FROM Full_Time_Emp WHERE Full_Time_Emp.eid = NEW.eid);
	total := part_time + full_time;
	
	IF (total > 1) THEN
	RAISE EXCEPTION 'Employee cannot be part time and full time';
	ELSIF (total < 1) THEN
	RAISE EXCEPTION 'Employee is neither part time nor full time';
	ELSE RETURN NEW;
	END IF;
	RETURN NULL;
END
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER check_part_time_full_time_trigger
AFTER INSERT ON Employees
FOR EACH ROW EXECUTE FUNCTION check_part_time_full_time_func();

CREATE OR REPLACE FUNCTION check_session_instructor_func() RETURNS TRIGGER
AS $$
DECLARE
	course_area TEXT;
	departed BOOLEAN;
	depart_date DATE;
BEGIN
	depart_date := (SELECT depart_date FROM Employees WHERE Employees.eid = NEW.eid);
	departed := depart_date IS NOT NULL;
	IF departed THEN 
		RAISE EXCEPTION 'Employee is not longer working for the company';
	END IF;
	course_area := (SELECT area_name FROM Courses WHERE Courses.course_id = NEW.course_id);

	IF NOT EXISTS (SELECT 1 FROM Specializes WHERE Specializes.area_name = course_area AND Specializes.eid = NEW.conduct_by) THEN
		RAISE EXCEPTION 'Employee is not specialized in % unable to conduct Session % for % with %', course_area, NEW.sid, NEW.course_id, NEW.launch_date;
	ELSIF (depart_date < NEW.session_date) THEN
		RAISE EXCEPTION 'Employee is departing the company before Session % for % with %', NEW.sid, NEW.course_id, NEW.launch_date;
	END IF;
	RETURN NULL;
END
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER check_session_instructor_trigger
AFTER INSERT OR UPDATE ON Sessions
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_session_instructor_func();

-- Ensures that each instructor should specialize in at least one area
CREATE OR REPLACE FUNCTION check_instructor_specialize() RETURNS TRIGGER
AS $$
	BEGIN 
		IF NOT EXISTS (SELECT eid FROM Specializes WHERE eid = NEW.eid)
		THEN RAISE EXCEPTION 'Instructor does not have any specialization. Instructor should specialize in at least one area';
			RETURN NULL;
		END IF;
		RETURN NEW;
	END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_instructor_specialization 
AFTER INSERT ON Specializes
FOR EACH ROW EXECUTE FUNCTION check_instructor_specialize();

CREATE OR REPLACE FUNCTION	check_part_time_instructor_weekly_hours_func() RETURNS TRIGGER
AS $$
	DECLARE
		weekly_hours_worked FLOAT;
	BEGIN
		weekly_hours_worked := EXTRACT(EPOCH FROM (
			SELECT sum(Sessions.end_time - Sessions.start_time) 
			FROM Sessions
			WHERE date_part('month', Sessions.session_date) = date_part('month', NEW.session_date)
			AND Sessions.conduct_by = NEW.conduct_by
			)/60);
		IF EXISTS (
			SELECT 1 
			FROM Part_Time_Instructors 
			WHERE Part_Time_Instructors.eid = NEW.conduct_by
			AND weekly_hours_worked > 30) THEN
			RAISE EXCEPTION 'Part time Instructor exceeded weekly hour limit of 30';
		END IF;
		RETURN NEW;
	END
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_part_time_instructor_weekly_hours_trigger
AFTER INSERT OR UPDATE ON Sessions	
FOR EACH ROW EXECUTE FUNCTION check_part_time_instructor_weekly_hours_func();

CREATE OR REPLACE FUNCTION	check_interval_between_sessions_for_instructor_func() RETURNS TRIGGER
AS $$
	BEGIN
		IF EXISTS(
			SELECT 1 FROM Sessions
			WHERE 
			((Sessions.start_time = NEW.start_time OR Sessions.start_time = NEW.end_time OR Sessions.end_time = NEW.start_time OR Sessions.end_time = NEW.end_time) 
			OR
			(Sessions.start_time < NEW.start_time AND Sessions.end_time + interval '1 hour' > NEW.start_time)
			OR 
			(Sessions.start_time > NEW.start_time AND NEW.end_time + interval '1 hour' > Sessions.start_time))
			AND Sessions.conduct_by = NEW.conduct_by
			AND Sessions.sid <> NEW.sid
			) THEN
			RAISE EXCEPTION 'Session cannot be held when the instructor is in a session or having rest time';
		END IF;
		RETURN NULL;
	END
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_interval_between_sessions_for_instructor_trigger
AFTER INSERT OR UPDATE ON Sessions	
FOR EACH ROW EXECUTE FUNCTION check_interval_between_sessions_for_instructor_func() ;

CREATE OR REPLACE FUNCTION check_cancellation_policy_func() RETURNS TRIGGER
AS $$
	DECLARE 
		session_date DATE;
		session_fees NUMERIC;
		window_date DATE;
	BEGIN
		IF (NEW.package_credit IS NULL AND NEW.refund_amt IS NULL) THEN
            RAISE EXCEPTION 'Select one mode between package credit and refund amount';
		ELSIF (NEW.package_credit IS NOT NULL AND NEW.refund_amt IS NOT NULL) THEN
            RAISE EXCEPTION 'Only one mode between package credit and refund amount.';
        END IF;

        SELECT Sessions.session_date, Offerings.fees INTO session_date, session_fees
        FROM Sessions NATURAL JOIN Offerings
        WHERE Sessions.sid = NEW.sid AND Sessions.course_id = NEW.course_id AND Sessions.launch_date = NEW.launch_date;

        window_date := session_date - interval '7 day';
        -- Past window: no refund
        IF (window_date < NEW.cancels_date) THEN
        	IF (NEW.refund_amt IS NOT NULL AND NEW.refund_amt <> 0) THEN
        		RAISE EXCEPTION 'Cancellation date(%) is made less then 7 days before session date(%). No refund for amount % due to late Cancellation',
        		NEW.cancels_date, session_date, NEW.refund_amt;
    		ElSIF (NEW.package_credit IS NOT NULL AND NEW.package_credit <> 0) THEN
    			RAISE EXCEPTION 'Cancellation date(%) is made less then 7 days before session date(%). No refund for package credit % due to late Cancellation',
        		NEW.cancels_date, session_date, NEW.package_credit;
        	END IF;
        -- Within window: refund	
        ELSE 
        	IF (NEW.refund_amt IS NOT NULL AND NEW.refund_amt <> (fee * 0.9)) THEN
                RAISE EXCEPTION 'Refund amount is not 90 percent of the fees paid. 
                Refund amount (%), Correct amount (%)', NEW.refund_amt, fee * 0.9;
            ELSIF (NEW.package_credit IS NOT NULL AND NEW.package_credit <> 1) THEN
                RAISE EXCEPTION 'Package credit is invalid (%)', NEW.package_credit;
            END IF;
        END IF;

        RETURN NULL;
	END
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_cancellation_policy_trigger
AFTER INSERT OR UPDATE ON Cancels	
FOR EACH ROW EXECUTE FUNCTION check_cancellation_policy_func();

-- Prevent deletion of an offering that has session
CREATE OR REPLACE FUNCTION check_offering_is_assigned_func()
RETURNS TRIGGER AS $$
    DECLARE
    BEGIN
        IF EXISTS (SELECT 1 FROM Sessions WHERE (Sessions.course_id = OLD.course_id) AND (Sessions.launch_date = OLD.launch_date)) THEN
            RAISE EXCEPTION 'Offering (%) with launch date (%) cannot be deleted as it still has sessions assigned.', NEW.course_id, NEW.launch_date;
        END IF;
        RETURN NULL;
    END;   
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER check_offering_is_assigned_trigger
AFTER DELETE ON Offerings
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION check_offering_is_assigned_func();

