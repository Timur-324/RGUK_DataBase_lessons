-- 1. Отбор самолётов по характеристикам
-- Вывести английское название модели самолёта, дальность и скорость. 
-- Оставить только самолёты с дальностью от 3000 до 7000 км включительно. 
-- Результат отсортировать по дальности по убыванию.
-- Результат должен содержать: model, range, speed
-- Использовать: BETWEEN, ORDER BY, ->>
SELECT
	model ->> 'en' AS model,
	range,
	speed
FROM bookings.airplanes_data
WHERE RANGE BETWEEN 3000 AND 7000
ORDER BY RANGE DESC;


-- 2. Поиск моделей по названию
-- Найти самолёты, английское название которых начинается с Airbus или Boeing. 
-- Вывести название модели, дальность и скорость. 
-- Реализовать условие с помощью LIKE и логического оператора OR.
-- Результат должен содержать: model, range, speed
-- Использовать: LIKE, OR
SELECT 
    model ->> 'en' AS model,
    range,
    speed
FROM bookings.airplanes_data
WHERE model ->> 'en' LIKE 'Airbus%' OR model ->> 'en' LIKE 'Boeing%';

-- 3. Классификация самолётов
-- Для каждого самолёта сформировать вычисляемый столбец type: 
-- дальность менее 3000 км — «Ближнемагистральный», 
-- от 3000 до 6000 км включительно — «Среднемагистральный», 
-- свыше 6000 км — «Дальнемагистральный».
-- Результат должен содержать: model, range, type
-- Использовать: CASE WHEN ... THEN ... ELSE ... END
SELECT
    model ->> 'en' AS model,
    range,
    CASE
        WHEN range < 3000 THEN 'Ближнемагистральный'
        WHEN range <= 6000 THEN 'Среднемагистральный'
        ELSE 'Дальнемагистральный'
    END AS type
FROM bookings.airplanes_data;

-- 4. Рейсы, которые ещё не завершены
-- Вывести рейсы, у которых фактическое время вылета уже известно, но фактическое время прибытия ещё отсутствует. 
-- Отсортировать по фактическому времени вылета.
-- Результат должен содержать: flight_id, route_no, status, actual_departure, actual_arrival
-- Использовать: IS NOT NULL, IS NULL, ORDER BY

SELECT 
	flight_id,
    route_no,
    status,
    actual_departure,
    actual_arrival
FROM flights
WHERE actual_departure IS NOT NULL
  AND actual_arrival IS NULL
ORDER BY actual_departure;

-- 5. Самолёты с дальностью выше средней
-- Найти все модели самолётов, дальность которых превышает среднюю дальность по таблице airplanes_data. 
-- Результат вывести от самолёта с наибольшей дальностью к наименьшей.
-- Результат должен содержать: model, range
-- Использовать: скалярный подзапрос, AVG
select model, airplanes_data.range
from airplanes_data
where range > (
	select avg(range) from airplanes_data 
)
order by range DESC;


-- 6. Уникальный список используемых аэропортов
-- Получить единый список кодов аэропортов, 
-- которые встречаются в routes либо как departure_airport, 
-- либо как arrival_airport. 
-- Повторяющиеся коды в итоговом наборе не должны встречаться.
-- Результат должен содержать: airport_code
-- Использовать: UNION

SELECT 
	departure_airport AS airport_code
FROM routes
UNION
SELECT arrival_airport
FROM routes;

-- 2. Агрегатные функции и группировка
-- В этом блоке необходимо осознанно использовать COUNT, SUM, AVG, MIN, MAX, GROUP BY, HAVING и COUNT(DISTINCT ...). 

-- 7. Общая статистика по бронированиям
-- Для таблицы bookings определить количество бронирований, минимальную, максимальную и среднюю стоимость бронирования, 
-- а также общую сумму всех бронирований. Среднюю стоимость округлить до двух знаков после запятой.
-- Результат должен содержать: bookings_count, min_amount, max_amount, avg_amount, total_amount
-- Использовать: COUNT, MIN, MAX, AVG, SUM, ROUND

SELECT 
	COUNT(*)                     AS bookings_count,
    MIN(total_amount)            AS min_amount,
    MAX(total_amount)            AS max_amount,
    ROUND(AVG(total_amount), 2)  AS avg_amount,
    SUM(total_amount)            AS total_amount
FROM bookings;

-- 8. Количество рейсов по статусам
-- Для каждого значения status в таблице flights определить количество рейсов. 
-- Наиболее распространённые статусы вывести первыми.
-- Результат должен содержать: status, flights_count
-- Использовать: COUNT, GROUP BY, ORDER BY

SELECT 
	status,
    COUNT(*) AS flights_count
FROM flights
GROUP BY status
ORDER BY flights_count DESC;

-- 9. Количество мест по классам обслуживания
-- Для каждого самолёта определить количество мест каждого класса обслуживания. 
-- Вывести код самолёта, fare_conditions и количество мест. 
-- Результат отсортировать сначала по самолёту, затем по классу.
-- Результат должен содержать: airplane_code, fare_conditions, seats_count
-- Использовать: COUNT, GROUP BY

select
	airplane_code,
	fare_conditions,
	count(seat_no) AS seats_count
from seats AS s
group by airplane_code, fare_conditions
order by seats_count asc;

-- 10. Статистика стоимости сегментов
-- Для каждого класса обслуживания из segments определить количество сегментов, 
-- минимальную, максимальную и среднюю цену, а также суммарную стоимость. 
-- Среднюю цену округлить до двух знаков.
-- Результат должен содержать: fare_conditions, segments_count, min_price, max_price, avg_price, total_price
-- Использовать: COUNT, MIN, MAX, AVG, SUM, GROUP BY

SELECT 
	fare_conditions,
    COUNT(*)                AS segments_count,
    MIN(price)              AS min_price,
    MAX(price)              AS max_price,
    ROUND(AVG(price), 2)    AS avg_price,
    SUM(price)              AS total_price
FROM segments
GROUP BY fare_conditions
ORDER BY fare_conditions;








select 
	count(*) as bookings_count,
	min(total_amount) as min_amount,
	max(total_amount) as max_amount,
	round(avg(total_amount),2) as avg_amount,
	sum(total_amount) as total_amount
from bookings;


select 
	status,
	count(flight_id) as flight_count
from flights f 
group by status
order by flight_count desc;
 

-- 11
select 
 	flight_id,
 	COUNT(*) as segments_count
 from segments
 group by flight_id 
 having count(*) > 100
 order by segments_count desc;

-- 12
select
	passenger_id,
	passenger_name,
	count(*) as seg_count,
	count(distinct fare_conditions) as cond_count
from tickets as t
join segments as s on t.ticket_no = s.ticket_no
group by passenger_id, passenger_name having count(distinct fare_conditions) > 1;

