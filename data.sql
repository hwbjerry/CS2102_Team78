--DATA:
INSERT INTO Customers(address, phone, cust_name, email) VALUES ('327 Cottonwood Terrace', '8060000000', 'Nealon OGrady', 'nogrady0@examiner.com');
INSERT INTO Customers(address, phone, cust_name, email) VALUES ('59 Hooker Court', '3030000000', 'Roldan Gilbanks',  'rgilbanks1@webs.com');
INSERT INTO Customers(address, phone, cust_name, email) VALUES ('9 Transport Junction',	'2830000000', 'Trula Laverock',	'tlaverock2@weather.com');
INSERT INTO Customers(address, phone, cust_name, email) VALUES ('99849 Carpenter Alley', '7400000000', 'Khalil Boome',	'kboome3@multiply.com');
INSERT INTO Customers(address, phone, cust_name, email) VALUES ('29 Graceland Street',	'2530000000', 'Stephenie Redwall', 'sredwall4@dagondesign.com');
INSERT INTO Customers(address, phone, cust_name, email) VALUES ('3 Hagan Pass', '2220000000',	'Arvy Ubee', 'aubee5@cyberchimps.com');
INSERT INTO Customers(address, phone, cust_name, email) VALUES ('1 Lillian Center', '4070000000', 'Wyn Blakeden',  'wblakeden6@privacy.gov.au');
INSERT INTO Customers(address, phone, cust_name, email) VALUES ('892 Vera Pass', '1790000000',	'Scarlett Reynoollds',  'sreynoollds7@amazonaws.com');
INSERT INTO Customers(address, phone, cust_name, email) VALUES ('4 Bobwhite Point', '7760000000', 'Kenny Piechnik', 'kpiechnik8@bandcamp.com');
INSERT INTO Customers(address, phone, cust_name, email) VALUES ('28741 Nevada Place', 	'8710000000', 'Mathilde Paladino', 'mpaladino9@acquirethisname.com');
Select * from Customers;

INSERT INTO Credit_cards VALUES ('5140164490919192',683, '2024-10-01', '2021-02-01', 1);
INSERT INTO Credit_cards VALUES  ('5344610134228782',984, '2022-04-01', '2019-04-01', 2);
INSERT INTO Credit_cards VALUES  ('5234352971639424', 807, '2023-05-01', '2020-04-01', 3);
INSERT INTO Credit_cards VALUES  ('5450736293191055', 555, '2025-10-01', '2019-10-01', 4);
INSERT INTO Credit_cards VALUES  ('5297378218777531', 220, '2027-08-01', '2020-08-01', 5);
INSERT INTO Credit_cards VALUES  ('4929855400823578', 691, '2023-11-01', '2020-11-01', 6);
INSERT INTO Credit_cards VALUES  ('4929952829908583', 857, '2022-09-01', '2019-09-01', 7);
INSERT INTO Credit_cards VALUES  ('4556609775025594', 436, '2025-06-01', '2019-06-01', 8);
INSERT INTO Credit_cards VALUES  ('4716087919245161', 626, '2025-05-01', '2020-05-01', 9);
INSERT INTO Credit_cards VALUES  ('4556779474584066', 805, '2027-01-01', '2019-01-01', 10);
Select * from Credit_cards;

INSERT INTO Employees (ename, phone, address, email, join_date, depart_date) VALUES ('Tom', 9999991, 123451, 'tom@gmail.com', '2020-04-01',	null);
INSERT INTO Employees (ename, phone, address, email, join_date, depart_date) VALUES ('Dick', 9999992, 123452, 'dick@gmail.com'	, '2020-04-01',	null);
INSERT INTO Employees (ename, phone, address, email, join_date, depart_date) VALUES ('Harry', 9999993, 123453, 'harry@gmail.com', '2020-04-01', null);
INSERT INTO Employees (ename, phone, address, email, join_date, depart_date) VALUES ('Bell', 9999994, 123454 , 'bell@gmail.com',  '2020-04-01',	null);
INSERT INTO Employees (ename, phone, address, email, join_date, depart_date) VALUES ('Marry', 9999995, 123455, 'marry@gmail.com', '2020-04-01', '2020-04-30');
INSERT INTO Employees (ename, phone, address, email, join_date, depart_date) VALUES ('Terry', 9999996, 123456, 'terry@gmail.com', '2020-04-01', '2021-07-10');
INSERT INTO Employees (ename, phone, address, email, join_date, depart_date) VALUES ('Jane',	9999997, 123457, 'jane@gmail.com', '2020-04-01',	null);
INSERT INTO Employees (ename, phone, address, email, join_date, depart_date) VALUES ('Sally', 9999998, 123458, 'sally@gmail.com', '2020-04-01', null);
INSERT INTO Employees (ename, phone, address, email, join_date, depart_date) VALUES ('Dickson', 9999999,123459, 'dickson@gmail.com',	'2020-04-01', null);
INSERT INTO Employees (ename, phone, address, email, join_date, depart_date) VALUES ('John', 9999990, 123460, 'john@gmail.com',  '2020-04-01', null);

INSERT INTO Part_Time_Emp VALUES (6, 10);
INSERT INTO Part_Time_Emp VALUES (7, 10);
INSERT INTO Part_Time_Emp VALUES (8, 10);
INSERT INTO Part_Time_Emp VALUES (9, 10);
INSERT INTO Part_Time_Emp VALUES (10, 10);

INSERT INTO Full_Time_Emp VALUES (1, 3000);
INSERT INTO Full_Time_Emp VALUES (2, 3000);
INSERT INTO Full_Time_Emp VALUES (3, 3000);
INSERT INTO Full_Time_Emp VALUES (4, 3000);
INSERT INTO Full_Time_Emp VALUES (5, 3000);

INSERT INTO Pay_slips VALUES (1, '2020-04-30', 3000, null, 30);
INSERT INTO Pay_slips VALUES (2, '2020-04-30', 3000, null, 30);
INSERT INTO Pay_slips VALUES (3, '2020-04-30', 2800, null, 28);
INSERT INTO Pay_slips VALUES (4, '2020-04-30', 2800, null, 28);
INSERT INTO Pay_slips VALUES (5, '2020-04-30', 3000, null, 30);
INSERT INTO Pay_slips VALUES (6, '2020-04-30', 100, 10, null);
INSERT INTO Pay_slips VALUES (7, '2020-04-30',300, 30, null);
INSERT INTO Pay_slips VALUES (8, '2020-04-30', 200, 20, null);
INSERT INTO Pay_slips VALUES (9, '2020-04-30', 200, 20, null);
INSERT INTO Pay_slips VALUES (10, '2020-04-30', 200, 30, null);

INSERT INTO Instructors VALUES (2);
INSERT INTO Instructors VALUES (4);
INSERT INTO Instructors VALUES (6);
INSERT INTO Instructors VALUES (7);
INSERT INTO Instructors VALUES (8);
INSERT INTO Instructors VALUES (10);

INSERT INTO Part_Time_instructors VALUES (6);
INSERT INTO Part_Time_instructors VALUES (7);
INSERT INTO Part_Time_instructors VALUES (8);
INSERT INTO Part_Time_instructors VALUES (10);

INSERT INTO Full_Time_instructors VALUES (2);
INSERT INTO Full_Time_instructors VALUES (4);

INSERT INTO Managers VALUES (1);

INSERT INTO Administrators VALUES (3);
INSERT INTO Administrators VALUES (5);

INSERT INTO Course_areas VALUES ('Computing 01', 1);
INSERT INTO Course_areas VALUES ('Computing 02', 1);
INSERT INTO Course_areas VALUES ('Computing 03', 1);
INSERT INTO Course_areas VALUES ('Computing 04', 1);
INSERT INTO Course_areas VALUES ('Computing 05', 1);
INSERT INTO Course_areas VALUES ('Computing 06', 1);
INSERT INTO Course_areas VALUES ('Computing 07', 1);
INSERT INTO Course_areas VALUES ('Computing 08', 1);
INSERT INTO Course_areas VALUES ('Computing 09', 1);
INSERT INTO Course_areas VALUES ('Computing 10', 1);

INSERT INTO Specializes VALUES (2, 'Computing 01');
INSERT INTO Specializes VALUES (2, 'Computing 02');
INSERT INTO Specializes VALUES (4, 'Computing 03');
INSERT INTO Specializes VALUES (4, 'Computing 04');
INSERT INTO Specializes VALUES (6, 'Computing 05');
INSERT INTO Specializes VALUES (6, 'Computing 06');
INSERT INTO Specializes VALUES (7, 'Computing 07');
INSERT INTO Specializes VALUES (8, 'Computing 08');
INSERT INTO Specializes VALUES (10, 'Computing 09');
INSERT INTO Specializes VALUES (10, 'Computing 10');

INSERT INTO Courses (title , duration, description, area_name) VALUES ('CS1010', 4, 'cs1010_01', 'Computing 01');
INSERT INTO Courses (title , duration, description, area_name) VALUES ('CS2010', 4, 'cs2010_02', 'Computing 02');
INSERT INTO Courses (title , duration, description, area_name) VALUES ('CS3010', 4, 'cs3010_03', 'Computing 03');
INSERT INTO Courses (title , duration, description, area_name) VALUES ('CS4010', 4, 'cs4010_04', 'Computing 04');
INSERT INTO Courses (title , duration, description, area_name) VALUES ('CS5010', 4, 'cs5010_05', 'Computing 05');
INSERT INTO Courses (title , duration, description, area_name) VALUES ('CS6010', 4, 'cs6010_06', 'Computing 06');
INSERT INTO Courses (title , duration, description, area_name) VALUES ('CS7010', 4, 'cs7010_07', 'Computing 07');
INSERT INTO Courses (title , duration, description, area_name) VALUES ('CS8010', 4, 'cs8010_08', 'Computing 08');
INSERT INTO Courses (title , duration, description, area_name) VALUES ('CS9010', 4, 'cs9010_09', 'Computing 09');
INSERT INTO Courses (title , duration, description, area_name) VALUES ('CS1234', 4, 'cs1234_10' ,'Computing 10');

INSERT INTO Course_packages (sale_start_date, sale_end_date, num_free_registrations, package_name,  price) VALUES ('2020-01-01', '2020-02-29', 1, 'Computing 01', 100.00);
INSERT INTO Course_packages (sale_start_date, sale_end_date, num_free_registrations, package_name,  price) VALUES ('2020-02-01', '2020-03-29', 1, 'Computing 02', 200.00);
INSERT INTO Course_packages (sale_start_date, sale_end_date, num_free_registrations, package_name,  price) VALUES ('2020-03-01', '2020-04-29', 1, 'Computing 03', 150.00);
INSERT INTO Course_packages (sale_start_date, sale_end_date, num_free_registrations, package_name,  price) VALUES ('2020-04-01', '2020-05-29', 1, 'Computing 04', 200.00);
INSERT INTO Course_packages (sale_start_date, sale_end_date, num_free_registrations, package_name,  price) VALUES ('2020-05-01', '2020-06-29', 1, 'Computing 05', 225.00);
INSERT INTO Course_packages (sale_start_date, sale_end_date, num_free_registrations, package_name,  price) VALUES ('2020-06-01', '2020-07-29', 1, 'Computing 06', 250.00);
INSERT INTO Course_packages (sale_start_date, sale_end_date, num_free_registrations, package_name,  price) VALUES ('2020-07-01', '2020-08-29', 1, 'Computing 07', 275.00);
INSERT INTO Course_packages (sale_start_date, sale_end_date, num_free_registrations, package_name,  price) VALUES ('2020-08-01', '2020-09-29', 1, 'Computing 08', 300.00);
INSERT INTO Course_packages (sale_start_date, sale_end_date, num_free_registrations, package_name,  price) VALUES ('2020-09-01', '2020-10-29', 1, 'Computing 09', 325.00);
INSERT INTO Course_packages (sale_start_date, sale_end_date, num_free_registrations, package_name,  price) VALUES ('2020-10-01', '2020-11-29', 1, 'Computing 10', 350.00);

INSERT INTO Rooms VALUES (1, 'COM1', 5);
INSERT INTO Rooms VALUES (2, 'COM2', 5);
INSERT INTO Rooms VALUES (3, 'COM3', 5);
INSERT INTO Rooms VALUES (4, 'COM4', 5);
INSERT INTO Rooms VALUES (5,'COM5', 5);
INSERT INTO Rooms VALUES (6, 'COM6', 5);
INSERT INTO Rooms VALUES (7, 'COM7', 5);
INSERT INTO Rooms VALUES (8, 'COM8', 5);
INSERT INTO Rooms VALUES (9, 'COM9', 5);
INSERT INTO Rooms VALUES (10,'COM10', 5);

INSERT INTO Offerings VALUES ('2020-12-29', 1, 3, '2021-02-02', '2021-02-23', '2021-01-05', 10, 5, 50.00);
INSERT INTO Offerings VALUES ('2021-01-26', 2, 3, '2021-03-02', '2021-03-23', '2021-02-02', 10, 5, 100.00);
--INSERT INTO Offerings VALUES ('2021-01-02', 2, 3, '2021-02-07', '2021-02-28', '2021-01-05', 10, 5, 115.00);
INSERT INTO Offerings VALUES ('2021-02-26', 3, 3, '2021-04-02', '2021-04-23', '2021-03-05', 10, 5, 75.00);
INSERT INTO Offerings VALUES ('2021-03-26', 4, 3, '2021-04-30', '2021-05-21', '2021-04-02', 10, 5, 80.00);
INSERT INTO Offerings VALUES ('2021-03-27', 4, 3, '2021-05-01', '2021-05-22', '2021-04-03', 10, 5, 65.00);
INSERT INTO Offerings VALUES ('2021-03-28', 4, 3, '2021-05-02', '2021-05-23', '2021-04-04', 10, 5, 100.00);
INSERT INTO Offerings VALUES ('2021-04-28', 5, 3, '2021-06-02', '2021-06-23', '2021-05-05', 10, 5, 110.00);
INSERT INTO Offerings VALUES ('2021-05-28', 6, 5, '2021-07-02', '2021-07-23', '2021-06-04', 10, 5, 125.00);
INSERT INTO Offerings VALUES ('2021-06-28', 7, 5, '2021-08-02', '2021-08-23', '2021-07-05',10, 5, 130.00);
INSERT INTO Offerings VALUES ('2021-07-29' ,8, 5, '2021-09-02', '2021-09-23', '2021-08-05', 10, 5, 150.00);
INSERT INTO Offerings VALUES ('2021-08-28' ,9 ,5, '2021-10-02', '2021-10-23', '2021-09-04', 10, 5, 170.00);
INSERT INTO Offerings VALUES ('2021-09-28', 10, 5, '2021-11-02', '2021-11-23', '2021-10-05', 10, 5, 175.00);

INSERT INTO Sessions VALUES (1, '0900', '1000', '2021-02-09', '2020-12-29', 1, 1, 2);
INSERT INTO Sessions VALUES (2, '0930', '1030', '2021-03-09', '2021-01-26', 2, 2, 2);
INSERT INTO Sessions VALUES (3, '1000', '1100', '2021-04-09', '2021-02-26', 3, 3, 4);
INSERT INTO Sessions VALUES (4, '0900', '1000', '2021-06-09', '2021-03-28', 4, 4, 4);
INSERT INTO Sessions VALUES (5, '1100', '1200', '2021-06-09','2021-04-28', 5, 5, 6);
INSERT INTO Sessions VALUES (6, '1400', '1500', '2021-07-09', '2021-05-28', 6, 6, 6);
INSERT INTO Sessions VALUES (7, '1430', '1530', '2021-08-09', '2021-06-28', 7, 7, 7);
INSERT INTO Sessions VALUES (8, '1500', '1600', '2021-09-09', '2021-07-29', 8, 8, 8);
INSERT INTO Sessions VALUES (9, '1500', '1600', '2021-11-09', '2021-08-28', 9, 9, 10);
INSERT INTO Sessions VALUES (10, '1700', '1800', '2021-11-09', '2021-09-28', 10, 10, 10);

INSERT INTO Registers VALUES ('2021-01-04', 1, '2020-12-29', '5140164490919192', 1, 1, 1);
INSERT INTO Registers VALUES ('2021-01-31', 2, '2021-01-26', '5344610134228782', 2, 2, 2);
INSERT INTO Registers VALUES ('2021-03-01', 3, '2021-02-26', '5234352971639424', 3, 3, 3);
INSERT INTO Registers VALUES ('2021-04-04', 4, '2021-03-28', '5450736293191055', 4, 4, 4);
INSERT INTO Registers VALUES ('2021-05-02', 5, '2021-04-28', '5297378218777531', 5, 5, 5);
INSERT INTO Registers VALUES ('2021-06-02', 6, '2021-05-28', '4929855400823578', 6, 6, 6);
INSERT INTO Registers VALUES ('2021-07-01', 7, '2021-06-28', '4929952829908583', 7, 7, 7);
INSERT INTO Registers VALUES ('2021-08-03', 8, '2021-07-29', '4556609775025594', 8, 8, 8);
INSERT INTO Registers VALUES ('2021-09-04', 9, '2021-08-28', '4716087919245161', 9, 9, 9);
INSERT INTO Registers VALUES ('2021-10-05', 10, '2021-09-28', '4556779474584066', 10, 10, 10);

INSERT INTO Buys VALUES ('2021-01-12',	0, 2, '5140164490919192', 1);
INSERT INTO Buys VALUES ('2021-02-09',	5, 1, '5344610134228782', 2);
INSERT INTO Buys VALUES ('2021-03-12',	5, 3, '5234352971639424', 3);
INSERT INTO Buys VALUES ('2021-04-11',	5, 6, '5450736293191055', 4);
INSERT INTO Buys VALUES ('2021-05-12',	5, 4, '5297378218777531', 5);
INSERT INTO Buys VALUES ('2021-06-11',	5, 8, '4929855400823578', 6);
INSERT INTO Buys VALUES ('2021-07-12',	5, 10, '4929952829908583', 7);
INSERT INTO Buys VALUES ('2021-08-12',	5, 5, '4556609775025594', 8);
INSERT INTO Buys VALUES ('2021-09-11',	5, 9, '4716087919245161', 9);
INSERT INTO Buys VALUES ('2021-10-12',	5, 7, '4556779474584066', 10);

INSERT INTO Redeems VALUES ('2021-01-19', 1,	'2020-12-29', 1, 1,	'2021-01-12', 2, '5140164490919192', 1);
INSERT INTO Redeems VALUES ('2021-02-16',	2,	'2021-01-26', 2, 2,	'2021-02-09', 1, '5344610134228782', 2);
INSERT INTO Redeems VALUES ('2021-03-19',	3,	'2021-02-26', 3, 3,	'2021-03-12', 3, '5234352971639424', 3);
INSERT INTO Redeems VALUES ('2021-04-18',	4,	'2021-03-28', 4, 4,	'2021-04-11', 6, '5450736293191055', 4);
INSERT INTO Redeems VALUES ('2021-05-19',	5,	'2021-04-28', 5, 5,	'2021-05-12', 4, '5297378218777531', 5);
INSERT INTO Redeems VALUES ('2021-06-18',	6,	'2021-05-28', 6, 6,	'2021-06-11', 8, '4929855400823578', 6);
INSERT INTO Redeems VALUES ('2021-07-19',	7,	'2021-06-28', 7, 7,	'2021-07-12', 10, '4929952829908583', 7);
INSERT INTO Redeems VALUES ('2021-08-19',	8,	'2021-07-29', 8, 8,	'2021-08-12', 5, '4556609775025594', 8);
INSERT INTO Redeems VALUES ('2021-09-18',	9,	'2021-08-28', 9, 9,	'2021-09-11', 9, '4716087919245161', 9);
INSERT INTO Redeems VALUES ('2021-10-19',	10,	'2021-09-28', 10, 10, '2021-10-12', 7, '4556779474584066', 10);

INSERT INTO Cancels VALUES ('2021-01-26',	1,	1,	'2020-12-29',	1,	1,	45.0,	NULL);
INSERT INTO Cancels VALUES ('2021-02-23',	2,	2,	'2021-01-26',	2,	2,	90.0,	NULL);
INSERT INTO Cancels VALUES ('2021-03-26',	3,	3,	'2021-02-26',	3,	3,	67.5,	NULL);
INSERT INTO Cancels VALUES ('2021-04-25',	4,	4,	'2021-03-28',	4,	4,	90.0,	NULL);
INSERT INTO Cancels VALUES ('2021-05-26',	5,	5,	'2021-04-28',	5,	5,	99.0,	NULL);
INSERT INTO Cancels VALUES ('2021-06-25',	6,	6,	'2021-05-28',	6,	6,	NULL,	1);
INSERT INTO Cancels VALUES ('2021-07-26',	7,	7,	'2021-06-28',	7,	7,	NULL,	1);
INSERT INTO Cancels VALUES ('2021-08-26', 8, 8, '2021-07-29',	8, 8, NULL, 1);
INSERT INTO Cancels VALUES ('2021-09-25', 9, 9, '2021-08-28',	9, 9, NULL, 1);
INSERT INTO Cancels VALUES ('2021-10-26',	10,	10,	'2021-09-28',	10,	10,	NULL,	1);
