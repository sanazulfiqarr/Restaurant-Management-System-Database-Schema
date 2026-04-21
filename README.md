# Restaurant-Management-System-Database-Schema


This SQL script creates a complete **Restaurant Management System** database. It manages staff, shifts, customers, table reservations, menu items, inventory, orders, billing, feedback, and audit logging. The schema includes tables, relationships, constraints, triggers, stored procedures, and views.

## Table of Contents
- [Overview](#overview)
- [Database Schema](#database-schema)
- [Tables](#tables)
- [Relationships](#relationships)
- [Stored Procedures](#stored-procedures)
- [Triggers](#triggers)
- [Views](#views)
- [Sample Data](#sample-data)
- [Installation & Usage](#installation--usage)
- [License](#license)

## Overview
This database is designed for a restaurant to:
- Manage staff, roles, and shift schedules.
- Handle customer information and table reservations.
- Track menu items by category and their ingredient requirements.
- Maintain inventory levels.
- Process orders, order details, and billing.
- Collect customer feedback.
- Automatically log changes to orders via an audit trail.
- Generate views for menu popularity and reservation trends.

## Database Schema

**Database Name:** `Project`

Run the script in SQL Server (T-SQL). It creates all tables, constraints, procedures, triggers, and inserts sample data.

## Tables

| Table | Description |
|-------|-------------|
| `Roles` | Staff roles (Waiter, Chef, Manager) |
| `Staff` | Employee details, linked to Roles |
| `Shifts` | Shift names and time ranges |
| `ShiftSchedule` | Assigns staff to shifts on specific dates |
| `Customers` | Customer details |
| `RestaurantTables` | Table numbers and seating capacity |
| `Reservations` | Table reservations by customers |
| `MenuCategory` | Categories (Starters, Main Course, etc.) |
| `Menu` | Menu items with price and category |
| `Inventory` | Stock items (rice, chicken, etc.) |
| `MenuIngredients` | Links menu items to inventory items with quantity used |
| `Orders` | Customer orders linked to a table and waiter |
| `OrderDetails` | Line items of an order (menu item, quantity, total price) |
| `Billing` | Final bill for an order |
| `Feedback` | Customer ratings and comments per order |
| `AuditLog` | Automatic log of changes to Orders table |

## Relationships

- **Staff → Roles** (many-to-one)
- **Staff → ShiftSchedule → Shifts** (many-to-many via junction table)
- **Customers → Reservations → RestaurantTables** (customers reserve tables)
- **Menu → MenuCategory** (many-to-one)
- **Menu ← MenuIngredients → Inventory** (many-to-many with quantity used)
- **Orders → RestaurantTables, Staff (waiter)** 
- **Orders → OrderDetails → Menu** (order lines)
- **Orders → Billing** (one-to-one)
- **Orders → Feedback** (one-to-one)

All foreign keys use appropriate `ON DELETE` actions (CASCADE, SET NULL, etc.).

## Stored Procedures

### `PlaceOrder`
```sql
EXEC PlaceOrder @Tableid, @Waiterid, @Menuitems
```
- Creates a new order.
- Accepts XML parameter for multiple menu items: `<Items><Item><Menuitemid>1</Menuitemid><Quantity>2</Quantity></Item>...</Items>`
- Automatically reduces inventory based on recipe quantities.

### `GenerateBill`
```sql
EXEC GenerateBill @Orderid
```
- Calculates total from `OrderDetails` and inserts a record into `Billing`.

### `ConfirmReservation`
```sql
EXEC ConfirmReservation @Reservationid
```
- Updates reservation status to `'Confirmed'`.

## Triggers

### `Trg_Auditlog_Orders`
- Logs `INSERT`, `UPDATE`, `DELETE` operations on the `Orders` table into `AuditLog`.
- Stores old and new data as JSON (using `FOR JSON AUTO`).

### `Trg_Updateorderstatus`
- After inserting a bill, automatically updates the corresponding order’s status to `'Completed'`.
- Also logs the status change in the audit log.

## Views

### `MenuPopularity`
Shows menu items ranked by number of times ordered and total quantity sold.

### `ReservationTrends`
Daily summary of confirmed, pending, and cancelled reservations.

## Sample Data
The script inserts:
- 3 roles (Waiter, Chef, Manager)
- 10 staff members
- 3 shifts (Morning, Evening, Night)
- 10 customers
- 10 restaurant tables (capacities 2,4,6)
- 10 reservations with different statuses
- 4 menu categories, 10 menu items
- 10 inventory items
- 10 orders and order details
- 10 billing records
- 10 feedback entries

## Installation & Usage

1. **Run the script** in Microsoft SQL Server Management Studio (SSMS) or any T-SQL compatible environment.
2. The database `Project` will be created and populated with sample data.
3. Test stored procedures:
   ```sql
   -- Place an order (XML format)
   EXEC PlaceOrder 1, 1, '<Items><Item><Menuitemid>1</Menuitemid><Quantity>2</Quantity></Item></Items>';

   -- Generate bill for order 11
   EXEC GenerateBill 11;

   -- Confirm a reservation
   EXEC ConfirmReservation 2;
   ```
4. Query views:
   ```sql
   SELECT * FROM MenuPopularity;
   SELECT * FROM ReservationTrends;
   ```


