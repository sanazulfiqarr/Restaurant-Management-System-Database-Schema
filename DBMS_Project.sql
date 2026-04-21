Create Database Project;
Use Project;

Create Table Roles (
    Roleid Int Identity(1,1) Primary Key,
    Rolename Nvarchar(50) Not Null Unique);

Create Table Staff (
    Staffid Int Identity(1,1) Primary Key,
    Fullname Nvarchar(100) Not Null,
    Roleid Int Foreign Key References Roles(Roleid) On Delete Set Null,
    Phonenumber Nvarchar(15) Unique Check (Phonenumber Like '[0-9]%' And Len(Phonenumber) Between 10 And 15),
    Email Nvarchar(100) Unique Check (Email Like '%@%.%'),
    Hiredate Date Default Getdate(),
    Salary Decimal(10, 2) Not Null Check (Salary > 0));

Create Table Shifts (
    Shiftid Int Identity(1,1) Primary Key,
    Shiftname Nvarchar(50) Not Null Unique,
    Starttime Time Not Null,
    Endtime Time Not Null,
    Check (Starttime < Endtime));

Create Table Shiftschedule (
    Scheduleid Int Identity(1,1) Primary Key,
    Staffid Int Foreign Key References Staff(Staffid) On Delete Cascade,
    Shiftid Int Foreign Key References Shifts(Shiftid) On Delete Cascade,
    Scheduledate Date Not Null
);

Create Table Customers (
    Customerid Int Identity(1,1) Primary Key,
    Fullname Nvarchar(100) Not Null,
    Phonenumber Nvarchar(15) Unique Check (Phonenumber Like '[0-9]%' And Len(Phonenumber) Between 10 And 15),
    Email Nvarchar(100) Unique Check (Email Like '%@%.%'),
    Joindate Date Default Getdate());

Create Table Restauranttables (
    Tableid Int Identity(1,1) Primary Key,
    Tablenumber Int Not Null Unique,
    Capacity Int Not Null Check (Capacity > 0));

Create Table Reservations (
    Reservationid Int Identity(1,1) Primary Key,
    Customerid Int Foreign Key References Customers(Customerid) On Delete Cascade,
    Tableid Int Foreign Key References Restauranttables(Tableid) On Delete Cascade,
    Reservationdate Date Not Null,
    Starttime Time Not Null,
    Endtime Time Not Null,
    Status Nvarchar(50) Default 'Pending' Check (Status In ('Pending', 'Confirmed', 'Cancelled')),
    Constraint Ck_Reservation_Nooverlap Check (Starttime < Endtime));

Create Table Menucategory (
    Categoryid Int Identity(1,1) Primary Key,
    Categoryname Nvarchar(50) Not Null Unique);

Create Table Menu (
    Menuitemid Int Identity(1,1) Primary Key,
    Itemname Nvarchar(100) Not Null,
    Description Nvarchar(255),
    Price Decimal(10, 2) Not Null Check (Price > 0),
    Categoryid Int Foreign Key References Menucategory(Categoryid) On Delete Cascade);

Create Table Inventory (
    Inventoryid Int Identity(1,1) Primary Key,
    Itemname Nvarchar(100) Not Null,
    Quantity Int Not Null Check (Quantity >= 0),
    Unit Nvarchar(20),
    Lastupdated Datetime Default Getdate());

Create Table Menuingredients (
    Menuingredientid Int Identity(1,1) Primary Key,
    Menuitemid Int Foreign Key References Menu(Menuitemid) On Delete Cascade,
    Inventoryid Int Foreign Key References Inventory(Inventoryid) On Delete Cascade,
    Quantityused Decimal(10, 2) Not Null Check (Quantityused > 0));

Create Table Orders (
    Orderid Int Identity(1,1) Primary Key,
    Tableid Int Foreign Key References Restauranttables(Tableid) On Delete Set Null,
    Waiterid Int Foreign Key References Staff(Staffid) On Delete Set Null,
    Orderdate Datetime Default Getdate(),
    Orderstatus Nvarchar(50) Default 'Pending' Check (Orderstatus In ('Pending', 'Completed', 'Cancelled')));

Create Table Orderdetails (
    Orderdetailid Int Identity(1,1) Primary Key,
    Orderid Int Foreign Key References Orders(Orderid) On Delete Cascade,
    Menuitemid Int Foreign Key References Menu(Menuitemid) On Delete Cascade,
    Quantity Int Not Null Check (Quantity > 0),
    Totalprice Decimal(10, 2) Not Null);

Create Table Billing (
    Billid Int Identity(1,1) Primary Key,
    Orderid Int Foreign Key References Orders(Orderid) On Delete Cascade,
    Totalamount Decimal(10, 2) Not Null,
    Billdate Datetime Default Getdate());

Create Table Feedback (
    Feedbackid Int Identity(1,1) Primary Key,
    Orderid Int Foreign Key References Orders(Orderid) On Delete Cascade,
    Customerid Int Foreign Key References Customers(Customerid) On Delete Set Null,
    Rating Int Check (Rating Between 1 And 5),
    Comments Nvarchar(255),
    Feedbackdate Datetime Default Getdate());

Create Table Auditlog (
    Logid Int Identity(1,1) Primary Key,
    Tablename Nvarchar(50),
	Orderid Int Foreign Key References Orders(Orderid),
    Operation Nvarchar(50),
    Olddata Nvarchar(Max),
    Newdata Nvarchar(Max),
    Changedby Nvarchar(100),
    Changedate Datetime Default Getdate());

Create Trigger Trg_Auditlog_Orders
On Orders
After Insert, Update, Delete
As
Begin
    Declare @Operation Nvarchar(50);
    Set @Operation = Case 
        When Exists (Select * From Inserted) And Exists (Select * From Deleted) Then 'Update'
        When Exists (Select * From Inserted) Then 'Insert'
        Else 'Delete'
    End;
    Insert Into Auditlog (Tablename, Operation, Olddata, Newdata, Changedby)
    Select 
        'Orders',
        @Operation,
        (Select * From Deleted For Json Auto),
        (Select * From Inserted For Json Auto),
        System_User;
End;

Create Trigger Trg_Updateorderstatus
On Billing
After Insert
As
Begin
    Update Orders
    Set Orderstatus = 'Completed'
    Where Orderid In (Select Orderid From Inserted);
    Insert Into Auditlog (Tablename, Operation, Newdata, Changedby)
    Select 'Orders', 'Update', (Select * From Orders Where Orderid In (Select Orderid From Inserted) For Json Auto), System_User;
End;

Create Procedure Placeorder
    @Tableid Int,
    @Waiterid Int,
    @Menuitems Nvarchar(Max)
As
Begin
    Begin Try
        Declare @Orderid Int;
        Insert Into Orders (Tableid, Waiterid)
        Values (@Tableid, @Waiterid);
        Set @Orderid = Scope_Identity();
        Declare @Xml Xml = Cast(@Menuitems As Xml);
        Insert Into Orderdetails (Orderid, Menuitemid, Quantity)
        Select
            @Orderid,
            T.Item.Value('(Menuitemid)[1]', 'Int'),
            T.Item.Value('(Quantity)[1]', 'Int')
        From @Xml.Nodes('/Items/Item') As T(Item);
        Update Inventory
        Set Inventory.Quantity = Inventory.Quantity - (Mi.Quantityused * Od.Quantity)
        From Inventory
        Join Menuingredients Mi On Inventory.Inventoryid = Mi.Inventoryid
        Join Orderdetails Od On Mi.Menuitemid = Od.Menuitemid
        Where Od.Orderid = @Orderid;
    End Try
    Begin Catch
        Declare @Errormessage Nvarchar(4000) = Error_Message();
        Throw 50000, @Errormessage, 1;
    End Catch
End;

Create Procedure Generatebill
    @Orderid Int
As
Begin
    Declare @Totalamount Decimal(10, 2);
    Select @Totalamount = Sum(Totalprice)
    From Orderdetails
    Where Orderid = @Orderid;
    Insert Into Billing (Orderid, Totalamount)
    Values (@Orderid, @Totalamount);
End;

Create Procedure Confirmreservation
    @Reservationid Int
As
Begin
    Update Reservations
    Set Status = 'Confirmed'
    Where Reservationid = @Reservationid;
End;

Insert Into Roles (Rolename)
Values 
('Waiter'),
('Chef'),
('Manager');

Insert Into Staff (Fullname, Roleid, Phonenumber, Email, Salary)
Values 
('Ahmed Khan', 1, '3001234567', 'Ahmed.Khan@Example.Com', 30000),
('Sara Ali', 2, '3007654321', 'Sara.Ali@Example.Com', 40000),
('Fatima Malik', 3, '3012345678', 'Fatima.Malik@Example.Com', 50000),
('Usman Shah', 3, '3023456789', 'Usman.Shah@Example.Com', 35000),
('Hassan Rehman', 1, '3034567890', 'Hassan.Rehman@Example.Com', 29000),
('Ayesha Sadiq', 2, '3045678901', 'Ayesha.Sadiq@Example.Com', 42000),
('Maha Tariq', 3, '3056789012', 'Maha.Tariq@Example.Com', 52000),
('Omer Farooq', 2, '3067890123', 'Omer.Farooq@Example.Com', 33000),
('Zainab Iqbal', 1, '3078901234', 'Zainab.Iqbal@Example.Com', 28000),
('Bilal Javed', 2, '3089012345', 'Bilal.Javed@Example.Com', 41000);

Insert Into Shifts (Shiftname, Starttime, Endtime)
Values 
('Morning', '07:00', '12:00'),
('Evening', '12:00', '17:00'),
('Night', '17:00', '22:00');

Insert Into Shiftschedule (Staffid, Shiftid, Scheduledate)
Values 
(1, 1, '2025-01-03'),
(2, 2, '2025-01-03'),
(3, 3, '2025-01-03'),
(4, 1, '2025-01-03'),
(5, 2, '2025-01-03'),
(6, 3, '2025-01-03'),
(7, 1, '2025-01-03'),
(8, 2, '2025-01-03'),
(9, 3, '2025-01-03'),
(10, 1, '2025-01-03');

Insert Into Customers (Fullname, Phonenumber, Email) 
Values 
('Ali Raza', '3001112233', 'Ali.Raza@Example.Com'),
('Sana Khan', '3002223344', 'Sana.Khan@Example.Com'),
('Imran Abbas', '3012334455', 'Imran.Abbas@Example.Com'),
('Nadia Ahmed', '3023445566', 'Nadia.Ahmed@Example.Com'),
('Fahad Hussain', '3034556677', 'Fahad.Hussain@Example.Com'),
('Rabia Farooq', '3045667788', 'Rabia.Farooq@Example.Com'),
('Kashif Jamil', '3056778899', 'Kashif.Jamil@Example.Com'),
('Mariam Tariq', '3067889900', 'Mariam.Tariq@Example.Com'),
('Bilal Shah', '3078990011', 'Bilal.Shah@Example.Com'),
('Mehak Khan', '3089101122', 'Mehak.Khan@Example.Com');

Insert Into Restauranttables (Tablenumber, Capacity)
Values 
(1, 4),
(2, 4),
(3, 2),
(4, 6),
(5, 4),
(6, 4),
(7, 2),
(8, 6),
(9, 4),
(10, 4);

Insert Into Reservations (Customerid, Tableid, Reservationdate, Starttime, Endtime, Status)
Values 
(1, 1, '2025-01-03', '19:00', '21:00', 'Confirmed'),
(2, 2, '2025-01-03', '18:00', '20:00', 'Pending'),
(3, 3, '2025-01-03', '17:00', '19:00', 'Confirmed'),
(4, 4, '2025-01-03', '20:00', '22:00', 'Cancelled'),
(5, 5, '2025-01-03', '21:00', '22:00', 'Pending'),
(6, 6, '2025-01-03', '19:30', '21:30', 'Confirmed'),
(7, 7, '2025-01-03', '20:30', '22:30', 'Pending'),
(8, 8, '2025-01-03', '18:30', '20:30', 'Confirmed'),
(9, 9, '2025-01-03', '19:00', '21:00', 'Pending'),
(10, 10, '2025-01-03', '21:30', '22:00', 'Confirmed');

Insert Into Menucategory (Categoryname)
Values 
('Starters'),
('Main Course'),
('Desserts'),
('Beverages');

Insert Into Menu (Itemname, Description, Price, Categoryid) 
Values 
('Spring Rolls', 'Crispy Fried Rolls Filled With Vegetables', 150.00, 1),
('Chicken Biryani', 'Spicy Chicken Rice Dish', 500.00, 2),
('Cheesecake', 'Creamy Cheesecake With a Graham Cracker Crust', 250.00, 3),
('Coke', 'Chilled Coca-Cola', 50.00, 4),
('Momos', 'Steamed Dumplings Filled With Vegetables', 180.00, 1),
('Grilled Chicken', 'Tender Grilled Chicken Served With Fries', 600.00, 2),
('Chocolate Brownie', 'Rich Chocolate Brownie Served With Ice Cream', 220.00, 3),
('Water', 'Bottled Water', 30.00, 4),
('French Fries', 'Crispy Golden Fries', 120.00, 1),
('Beef Steak', 'Juicy Beef Steak Served With Vegetables', 700.00, 2);

Insert Into Inventory (Itemname, Quantity, Unit) 
Values 
('Rice', 100, 'Kg'),
('Chicken', 50, 'Kg'),
('Flour', 200, 'Kg'),
('Sugar', 50, 'Kg'),
('Coca-Cola', 100, 'Bottle'),
('Cheese', 30, 'Kg'),
('Chocolate', 20, 'Kg'),
('Vegetables', 200, 'Kg'),
('Butter', 40, 'Kg'),
('Salt', 100, 'Kg');

Insert Into Menuingredients (Menuitemid, Inventoryid, Quantityused)
Values 
(1, 1, 5),
(2, 2, 3),
(3, 3, 2),
(4, 4, 10),
(5, 5, 3),
(6, 6, 4),
(7, 7, 1),
(8, 8, 2),
(9, 9, 4),
(10, 10, 5);

Insert Into Orders (Tableid, Waiterid, Orderstatus)
Values 
(1, 1, 'Pending'),
(2, 2, 'Completed'),
(3, 3, 'Cancelled'),
(4, 4, 'Pending'),
(5, 5, 'Completed'),
(6, 6, 'Pending'),
(7, 7, 'Completed'),
(8, 8, 'Pending'),
(9, 9, 'Completed'),
(10, 10, 'Pending');

Insert Into Orderdetails (Orderid, Menuitemid, Quantity, Totalprice) 
Values 
(1, 1, 2, 300.00),
(1, 2, 1, 500.00),
(2, 3, 1, 250.00),
(2, 4, 2, 100.00),
(3, 5, 3, 540.00),
(3, 6, 1, 600.00),
(4, 7, 2, 440.00),
(5, 8, 1, 50.00),
(6, 9, 1, 120.00),
(7, 10, 2, 60.00);

Insert Into Billing (Orderid, Totalamount) 
Values 
(1, 800.00),
(2, 550.00),
(3, 1140.00),
(4, 740.00),
(5, 170.00),
(6, 720.00),
(7, 120.00),
(8, 400.00),
(9, 240.00),
(10, 370.00);

Insert Into Feedback (Orderid, Customerid, Rating, Comments)
Values 
(1, 1, 5, 'Excellent Food!'),
(2, 2, 4, 'Good Service, But Slow Delivery.'),
(3, 3, 2, 'Disappointed With The Taste.'),
(4, 4, 3, 'Average Experience.'),
(5, 5, 5, 'Perfect! Will Visit Again.'),
(6, 6, 4, 'Great Atmosphere, But The Food Was a Bit Cold.'),
(7, 7, 5, 'Very Happy With The Food And Service.'),
(8, 8, 4, 'Good Food, But The Wait Was Long.'),
(9, 9, 3, 'Okay Experience, Not Great.'),
(10, 10, 5, 'Amazing! Highly Recommend.');

Create View Menupopularity As
Select 
    M.Itemname,
    Count(Od.Orderdetailid) As Timesordered,
    Sum(Od.Quantity) As Totalquantitysold
From Orderdetails Od
Join Menu M On Od.Menuitemid = M.Menuitemid
Group By M.Itemname
Order By Timesordered Desc;

Create View Reservationtrends As
Select 
    Reservationdate,
    Count(Case When Status = 'Confirmed' Then 1 End) As Confirmedreservations,
    Count(Case When Status = 'Pending' Then 1 End) As Pendingreservations,
    Count(Case When Status = 'Cancelled' Then 1 End) As Cancelledreservations
From Reservations
Group By Reservationdate
Order By Reservationdate Desc;
