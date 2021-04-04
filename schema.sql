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
DROP TABLE IF EXISTS Conducts CASCADE;
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
	cust_id  INTEGER PRIMARY KEY AUTO_INCREMENT,
	address VARCHAR(250),
	phone VARCHAR(15),
	name VARCHAR(100),
	email VARCHAR(100),
  	UNIQUE (address, phone, name, email)
);

CREATE TABLE Credit_cards ( 
	number INTEGER PRIMARY KEY,
	CVV INTEGER NOT NULL, 
	expiry_date DATE NOT NULL
);

CREATE TABLE Course_packages (
	package_id INTEGER PRIMARY KEY AUTO_INCREMENT,
	sale_start_date DATE NOT NULL,
	sale_end_date DATE NOT NULL,
	num_free_registrations INTEGER,
	name VARCHAR(100) NOT NULL,
	price DECIMAL NOT NULL
);

CREATE TABLE Rooms (
	rid INTEGER PRIMARY KEY,
	location VARCHAR(50) NOT NULL,
	seating_capacity INTEGER NOT NULL
);

CREATE TABLE Employees (
	eid INTEGER PRIMARY KEY,
	name VARCHAR(30) NOT NULL, 
	phone INTEGER, 
	address VARCHAR(30), 
	email VARCHAR(50),
	join_date DATE,
	depart_date DATE
);

CREATE TABLE Part_time_Emp (
	eid INTEGER PRIMARY KEY references Employees(eid) on delete cascade,
	hourly_rate NUMERIC NOT NULL
);

CREATE TABLE Full_time_Emp (
	eid INTEGER PRIMARY KEY references Employees(eid) on delete cascade,
	monthly_salary NUMERIC NOT NULL
);

CREATE TABLE Instructors (
	eid INTEGER PRIMARY KEY, 
  	foreign key (eid) references Employees(eid) on delete cascade
);

CREATE TABLE Part_time_instructors (
	eid INTEGER PRIMARY KEY,
  	foreign key (eid) references Part_time_Emp(eid) on delete cascade,
  	foreign key (eid) references Instructors(eid) on delete cascade
);

CREATE TABLE Full_time_instructors (
	eid INTEGER PRIMARY KEY,
  	foreign key (eid) references Full_time_Emp(eid) on delete cascade,
  	foreign key (eid) references Instructors(eid) on delete cascade
);

CREATE TABLE Managers (
	eid INTEGER PRIMARY KEY references Full_time_Emp(eid) on delete cascade
);

CREATE TABLE Administrators (
 	eid INTEGER PRIMARY KEY references Full_time_Emp(eid) on delete cascade
);

-- Integrate with Manages lecture ER page 44
CREATE TABLE Course_areas ( 
	name VARCHAR(50) primary key,
	eid INTEGER NOT NULL,
	foreign key(eid) references Managers(eid) 
);

CREATE TABLE Courses (
	course_id INTEGER PRIMARY KEY AUTO_INCREMENT,
	title VARCHAR(50) NOT NULL,
	duration INTEGER NOT NULL,
	description VARCHAR(250),
	name VARCHAR(50) NOT NULL,
	foreign key (name) REFERENCES Course_areas(name)
);

-- integrate with Handles lecture ER page 44
CREATE TABLE Offerings (
	launch_date DATE NOT NULL,
	course_id INTEGER NOT NULL,
	eid INTEGER NOT NULL,
	end_date DATE,
	start_date DATE,
	registration_deadline TIMESTAMP,
	target_number_registrations INTEGER,
	seating_capacity INTEGER,
	fees NUMERIC NOT NULL,
	primary key (launch_date, course_id),
	foreign key (course_id) REFERENCES Courses(course_id) on delete cascade, 
	foreign key (eid) REFERENCES Administrators(eid) 
);

CREATE TABLE Sessions (
	sid INTEGER,
	start_time TIME,
	end_time TIME,
	session_date DATE,
	launch_date DATE NOT NULL,
	course_id INTEGER NOT NULL,
	rid INTEGER NOT NULL,
	primary key (sid, launch_date, course_id, rid),
	foreign key (rid) REFERENCES Rooms(rid),
	foreign key (launch_date) REFERENCES Offerings(launch_date) on delete cascade,
	foreign key (course_id) REFERENCES Courses(course_id) on delete cascade
);

CREATE TABLE Owns (
	from_date DATE NOT NULL,
  	cust_id INTEGER NOT NULL,
  	number INTEGER,
	foreign key (cust_id) REFERENCES Customers(cust_id),
	foreign key (number) REFERENCES Credit_cards(number),
	primary key (number)
);

CREATE TABLE Registers ( 
	registers_date DATE,
	sid INTEGER references Sessions(sid),
	number INTEGER,
	cust_id INTEGER,
	primary key (registers_date, sid, number, cust_id),
	foreign key (number) references Owns(number),
  	foreign key (cust_id) references Customers(cust_id)
);

CREATE TABLE Buys (
	buys_date DATE,
	num_remaining_redemptions INTEGER,
	number INTEGER,
  	package_id INTEGER,
	cust_id INTEGER,
	PRIMARY KEY (buys_date, number, package_id, cust_id),
	foreign key (number) references Owns(number),
  	foreign key (cust_id) references Customers(cust_id),
  	foreign key (package_id) REFERENCES Course_packages(package_id)
);

CREATE TABLE Redeems (
	redeems_date DATE,
	buys_date DATE,
	number INTEGER,
	package_id INTEGER,
	sid INTEGER,
	launch_date DATE,
	course_id INTEGER,
	foreign key (buys_date, number, package_id) REFERENCES Buys(buys_date, number, package_id), 
	foreign key (sid, launch_date, course_id) REFERENCES Sessions(sid, launch_date, course_id),
	primary key (redeems_date, buys_date, number, package_id, sid, launch_date, course_id)
);

CREATE TABLE Cancels (
	cancels_date DATE,
	cust_id INTEGER NOT NULL,
	sid INTEGER NOT NULL,
	launch_date DATE NOT NULL,
	course_id INTEGER NOT NULL,
	refund_amt numeric,
	package_credit integer
	check(package_credit >= 0),
	foreign key (sid, launch_date, course_id) REFERENCES Sessions(sid, launch_date, course_id),
	foreign key (cust_id) REFERENCES Customers(cust_id),
	primary key (cancels_date, cust_id, sid, launch_date, course_id)
);

CREATE TABLE Conducts (
	rid INTEGER NOT NULL,
	eid INTEGER NOT NULL,
	sid INTEGER NOT NULL,
	launch_date DATE NOT NULL,
	course_id INTEGER NOT NULL,
	foreign key (eid) REFERENCES Employees(eid),
	foreign key (sid, launch_date, course_id, rid) REFERENCES Sessions(sid, launch_date, course_id, rid),
	primary key (sid, launch_date, course_id, rid) 
);

CREATE TABLE Specializes (
	eid INTEGER references Instructors(eid), 
	name VARCHAR(50) references Course_areas(name),
	primary key(eid, name)
); 

CREATE TABLE Pay_slips (
	eid INTEGER,
	payment_date DATE, 
	amount float, 
	num_work_hours INTEGER,
	num_work_days INTEGER,
	primary key (payment_date, eid),
	foreign key (eid) references Employees(eid) on delete cascade
);

