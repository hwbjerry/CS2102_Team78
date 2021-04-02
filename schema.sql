/* Clean Tables If Already Present */
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
	cust_id  INTEGER PRIMARY KEY,
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
	package_id INTEGER PRIMARY KEY,
	sale_start_date DATE NOT NULL,
	sale_end_date DATE NOT NULL,
	num_free_registrations INTEGER,
	name TEXT NOT NULL,
	price DECIMAL NOT NULL
);

CREATE TABLE Sessions (
	sid INTEGER,
start_time DATETIME,
	end_time DATETIME,
	date DATE,
	launch_date DATE NOT NULL,
	course_id INTEGER NOT NULL,
	rid INTEGER NOT NULL,
primary key (sid, launch_date, course_id, rid),
	foreign key (rid) REFERENCES Rooms,
	foreign key (launch_date) DATE REFERENCES Offerings on delete cascade,
	foreign key (course_id) REFERENCES Courses on delete cascade
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
	foreign key (course_id) REFERENCES Courses on delete cascade, 
	foreign key (eid) REFERENCES Administrators 
);
	
CREATE TABLE Courses (
	course_id INTEGER PRIMARY KEY,
	title TEXT NOT NULL,
	duration INTEGER NOT NULL,
	description TEXT,
	name VARCHAR(50) NOT NULL,
	foreign key (name) REFERENCES Course_areas
);

CREATE TABLE Rooms (
	rid INTEGER PRIMARY KEY,
	location VARCHAR(50) NOT NULL,
	seating_capacity INTEGER NOT NULL
);

CREATE TABLE Owns (
	from_date DATE NOT NULL,
	foreign key (cust_id) INTEGER REFERENCES Customers,
	foreign key (number)  INTEGER REFERENCES Credit_cards,
	primary key (number)
);

CREATE TABLE Registers ( 
date DATE,
sid INTEGER references Sessions,
number INTEGER,
cust_id INTEGER,
primary key (date, sid, number, cust_id),
foreign key (number, cust_id) references Owns (number, cust_id)
);

CREATE TABLE Buys (
date DATE,
num_remaining_redemptions INTEGER,
package_id INTEGER REFERENCES Course_packages,
number INTEGER,
cust_id INTEGER,
PRIMARY KEY (date, package_id, number, cust_id),
foreign key (number, cust_id) references Owns (number, cust_id)
);

CREATE TABLE Redeems (
	date DATE PRIMARY KEY,
	buys_date DATE,
	package_id INTEGER,
sid INTEGER,
	launch_date DATE,
course_id INTEGER,
foreign key (buys_date, package_id, number, cust_id) REFERENCES Buys, 
foreign key (sid, launch_date, course_id) REFERENCES Sessions,
primary key (date, buys_date, package_id, sid, launch_date, course_id)
);

CREATE TABLE Cancels (
	date DATE PRIMARY KEY,
	cust_id INTEGER NOT NULL,
	sid INTEGER NOT NULL,
	launch_date DATE NOT NULL,
	course_id INTEGER NOT NULL,
	refund_amt numeric,
	package_credit integer
check(package_credit >= 0),
	foreign key (sid, launch_date, course_id) REFERENCES Sessions,
	foreign key (cust_id) REFERENCES Customers,
primary key (date, cust_id, sid, launch_dae, course_id)
);

CREATE TABLE Conducts (
	rid INTEGER NOT NULL,
	eid INTEGER NOT NULL,
	sid INTEGER NOT NULL,
	launch_date DATE NOT NULL,
	course_id INTEGER NOT NULL,
	foreign key (eid)  INTEGER REFERENCES Employees,
foreign key (sid, rid, launch_date, course_id) REFERENCES Sessions,
primary key (course_id, launch_date, sid) 
);


CREATE TABLE Specializes (
	eid INTEGER references Instructors, 
	name VARCHAR(50) references Course_areas,
primary key(eid, name)
); 


-- Integrate with Manages lecture ER page 44
CREATE TABLE Course_areas ( 
	name VARCHAR(50) primary key,
eid INTEGER NOT NULL,
foreign key(eid) references Managers 
);


CREATE TABLE Pay_slips (
	payment_date DATE, 
	amount float, 
	num_work_hours INTEGER,
	num_work_days INTEGER,
	primary key (payment_date, eid),
	foreign key (eid) references Employees on delete cascade
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
	eid INTEGER PRIMARY KEY references Employees on delete cascade,
	hourly_rate NUMERIC NOT NULL
);
CREATE TABLE Full_time_Emp (
	eid INTEGER PRIMARY KEY references Employees on delete cascade,
	monthly_salary NUMERIC NOT NULL
);

CREATE TABLE Instructors (
	eid INTEGER PRIMARY KEY references Employees references Part_time_instructors on delete cascade
);

CREATE TABLE Part_time_instructors (
	eid INTEGER PRIMARY KEY references Part_time_Emp references Instructors on delete cascade
);

CREATE TABLE Full_time_instructors (
	eid INTEGER PRIMARY KEY references Full_time_Emp references Instructors on delete cascade
);

CREATE TABLE Managers (
	eid INTEGER PRIMARY KEY references Full_time_Emp on delete cascade
);

CREATE TABLE Administrators (
 	eid INTEGER PRIMARY KEY references Full_time_Emp on delete cascade
);
