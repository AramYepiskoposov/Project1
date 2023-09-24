--Here I am creating an OLAP Database from this raw data: MyShop_RawData




--Lets replace "employee_name" and "employee_address" columns
--with employee_id column, so lets delete one of the 2 columns
ALTER table 
  sales_data 
drop 
  column employee_adress;



--Lets replace the second column with employee_id
Update 
  sales_data 
set 
  employee_name =(
    Select 
      employee_id 
    from 
      Employee 
    where 
      sales_data.employee_name = Employee.name
  );


--Now that column contains employee ids so lets rename that
exec sp_rename 'sales_data.employee_name','emp_id';


--Lets set an appropriate datatype
ALTER Table sales_data Alter column emp_id INT;


--Lets move data about customer adreess and email from sales_data table
--to customer table,so lets add 2 more column in "customer" table
Alter table 
  customer 
add 
  cust_address Varchar(60), 
  cust_email Varchar(60);



--Now we can move the data into new created 2 columns
Update 
  customer 
Set 
  cust_address =(
    Select 
      distinct customer_address 
    from 
      sales_data s 
    where 
      s.customer = customer.customer_name
  ), 
  cust_email =(
    Select 
      distinct customer_email 
    from 
      sales_data s 
    where 
      s.customer = customer.customer_name
  );



--After when we moved 2 column to customers table,
--lets now replace customer_name with customer IDs in sales_data table
Update 
  sales_data 
SET 
  customer =(
    Select 
      customer_id 
    From 
      customer 
    where 
      customer.customer_name = sales_data.customer
  );


--Now that column contains customer ids so lets rename that
exec sp_rename 'sales_data.customer','cust_id';


--Lets set an appropriate dataype as well
ALTER TABLE sales_data ALter column cust_id INT;


--Let's drop 2 unnecessary columns because we now have them in the "customer" table
Alter table sales_data drop column customer_email,customer_address;


--"industry" column also we have in "customer" table, so lets drop that as well
Alter table sales_data drop column industry;


--Lets replace category name with their IDs in products table
Update products set category=(Select category_id 
from category where category.category_name=products.category);


--Let's make the column more understandable.
exec sp_rename 'products.category','cat_id';
exec sp_rename 'products.cat_id','category_id';


--Lets set an appropriate datatype
Alter table products alter column cat_id INT;


--Now we can repalce product names with their ID in sales_data table
Update 
  sales_data 
SET 
  product_name =(
    Select 
      product_id 
    from 
      products as p 
    where 
      p.product_name = sales_data.product_name
  );


--Let's make the column more understandable.
exec sp_rename 'sales_data.product_name','product_id';

--Lets set an appropriate datatype
Alter table 
  sales_data 
drop 
  column product_category, 
  product_cost, 
  product_price;


--Lets move the measure from "market_exp' table to fact table
--so lets add a column where we will keep the data
Alter table sales_data add monthly_mark_exp Float;


--Now we can insert the data about monthly expenses to new added column
With CTE as(
  Select 
    m.month_year_key, 
    m.marketing_expenses, 
    Count(s.month_year_key) as tr_qnt 
  from 
    market_exp as m 
    Join sales_data as s on s.month_year_key = m.Month_year_key 
  Group by 
    m.month_year_key, 
    m.marketing_expenses
) 
Update 
  sales_data 
Set 
  monthly_mark_exp = cast(cte.marketing_expenses as float)/ cast(cte.tr_qnt as float) 
From 
  sales_data 
  join CTE on sales_data.month_year_key = cte.Month_year_key;


--Let's check whether we updated the new column correctly.
Select month_year_key,sum(monthly_mark_exp)
From sales_data
Group by month_year_key
Order by month_year_key;


--The measure has been moved to the fact table, so it 
--doesn't make sense to keep this table.Lets delete that
Drop table market_exp;


--We dont have "market_exp" table anymore, so we dont need to keep
--the 'bridge' between them. Lets drop "month_year_key" column as well
Alter table sales_data drop column month_year_key;


--Lets define Primary Keys for all tables
ALTER Table sales_data ADD Primary Key(tr_id);
Alter table sales_data alter column tr_id INT Not Null;


Alter table employee ALter column employee_id INT Not Null;
Alter table employee Add Primary Key(employee_id);


Alter table customer ALter column customer_id INT Not Null;
Alter table customer Add Primary Key(customer_id);

Alter table products ALter column product_id INT Not Null;
Alter table products Add Primary Key(product_id);


Alter table category ALter column category_id INT Not Null;
Alter table category Add Primary Key(category_id);

Alter table calendar_tab ALter column [date] Date Not Null;
Alter table calendar_tab Add Primary Key([date]);


--When we have primary keys, it's time to establish 
--relationships between the fact and dimensional tables.
Alter table sales_data Add constraint fk_sales_calendar
Foreign Key([transaction_date]) References calendar_tab([date]);

Alter table sales_data Add constraint fk_sales_customer
Foreign Key([cust_id]) References customer(customer_id);

Alter table sales_data Add constraint fk_sales_products
Foreign Key([product_id]) References products(product_id);


Alter table products Add constraint fk_products_category
Foreign Key([category_id]) References category([category_id]);

Alter table sales_data Add constraint fk_sales_employee
Foreign Key([emp_id]) References employee(employee_id);