select * from goldusers_signup
select * from product
select * from sales
select * from users

-- 1. what is the amount purchased by each customer

select s.userid,sum(p.price)
from sales s
join product p
on s.product_id = p.product_id
group by s.userid
order by s.userid

-- 2. how many days each custommer visited zomato

select 
	userid,
	count(distinct created_date)
from sales
group by userid

-- 3. what was the first product purchased by each product

with cte as (
	select s.userid,s.created_date,s.product_id,
		row_number() over(partition by s.userid order by s.created_date) as id
	from sales s
	join product p 
	on s.product_id = p.product_id
)

select userid,created_date,product_id
from cte 
where id = 1

-- 4. what is the most purchased item in the menu and how many times it was purchased

with cte as (
	select product_id,count(product_id) as no_of_times_bought
	from sales
	group by product_id
	order by no_of_times_bought desc
	limit 1
)

select *
from sales
where product_id in (select product_id from cte)

-- 5. which item is most popular for each customer

with cte as (
	select s.userid,p.product_id,count(p.product_id) as no_of_times_bought,
		row_number() over(partition by s.userid order by count(p.product_id) desc) as id
	from sales s
	join product p
	on s.product_id = p.product_id
	group by s.userid,p.product_id
)

select userid,product_id,no_of_times_bought
from cte 
where id = 1

-- 6. which item was purchased first by customer after they became a member

with cte as (
	select s.userid,s.product_id,s.created_date,g.gold_signup_date,
		row_number() over(partition by s.userid order by created_date) as next_date_id
	from sales s
	inner join goldusers_signup g
	on s.userid = g.userid and s.created_date>=g.gold_signup_date 
)

select userid,created_date,product_id,gold_signup_date
from cte
where next_date_id = 1

-- 7. which item was purchased before became a member

with cte as (
	select s.userid,s.product_id,s.created_date,g.gold_signup_date,
		row_number() over(partition by s.userid order by created_date desc) as next_date_id
	from sales s
	inner join goldusers_signup g
	on s.userid = g.userid and s.created_date<=g.gold_signup_date 
)

select userid,created_date,product_id,gold_signup_date
from cte
where next_date_id = 1

-- 8. what is the total orders and amount spent for each member before they become member

with cte as (
	select s.userid,s.product_id,s.created_date,g.gold_signup_date,p.price
	from sales s
	inner join goldusers_signup g
	on s.userid = g.userid and s.created_date<=g.gold_signup_date 
	inner join product p
	on p.product_id = s.product_id
)

select userid,count(product_id) no_of_products_purchased,sum(price) total_price_spent
from cte
group by userid

/*  if buying each product generates points for eg 5rs=2 point and each product has different purchasing points 
	for eg for p1 5rs=1 zomato point, for p2 10rs=5 zomato points and p3 5rs=1 zomato point
	
calculate points collected by each customers and for which product most points have been given till now. */

with cte as (
	select s.userid,p.product_name,sum(p.price) money_spent,
		case when product_name = 'p1' then sum(price/5)*2.5
			 when product_name = 'p2' then (sum(price/10)*5)*2.5
			 when product_name = 'p3' then sum(price/5)*2.5
		end as points_obtained
	from sales s 
	inner join product p
	on s.product_id = p.product_id
	group by s.userid,p.product_name
	order by s.userid,p.product_name
)

select userid,sum(points_obtained) as total_points
from cte
group by userid
order by userid

-- product has more points

with cte as (
	select p.product_id,p.product_name,sum(p.price) money_spent,
		case when product_name = 'p1' then sum(price/5)
			 when product_name = 'p2' then (sum(price/10)*5)
			 when product_name = 'p3' then sum(price/5)
		end as points_obtained
	from sales s 
	inner join product p
	on s.product_id = p.product_id
	group by p.product_id,p.product_name
	order by p.product_id,p.product_name
)

select product_id,sum(points_obtained) as total_points
from cte
group by product_id
order by product_id

/* In the first one year after a customer join the gold program(including their join date) irrespective of 
   what they have purchased they earn 5 zomato points for every 10 rs spent who earned more 1 or 3 and what 
   was their points earning in the first year */

select s.userid,
	(sum(p.price/10)*5) as points_earned
from sales s
inner join goldusers_signup g
on s.userid = g.userid and  s.created_date >= g.gold_signup_date and (s.created_date<=365+g.gold_signup_date)
inner join product p
on p.product_id = s.product_id
group by s.userid
order by s.userid

/* rank all the transactions for each member whenever they are a zomato gold member for every non gold member 
transaction mark as na */

with cte as (
	select *,
		cast ((case when created_date > gold_signup_date then rank() 
			  				over(partition by s.userid order by s.created_date desc)
				else 0
				end) as varchar)
		as id
	from sales s
	left join goldusers_signup g
	on s.userid = g.userid 
)

select *,
	case when id = '0' then 'na' else id
	end as final_id
from cte