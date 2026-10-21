-- 1. Вывести английское название модели самолёта, дальность и скорость. 
-- Оставить только самолёты с дальностью от 3000 до 7000 км включительно и отсортировать результат по дальности по убыванию.
SELECT
    model ->> 'en' AS model,
    range,
    speed
FROM bookings.airplanes_data
WHERE range BETWEEN 3000 AND 7000
ORDER BY range DESC;


-- 2. Найти все самолёты, английское название которых начинается с Airbus или Boeing. 
-- Вывести название модели, дальность и скорость. 
-- Реализовать условие с помощью LIKE, OR либо регулярного выражения.

SELECT 
    model ->> 'en' AS model,
    range,
    speed
FROM bookings.airplanes_data
WHERE model ->> 'en' LIKE 'Airbus%' OR model ->> 'en' LIKE 'Boeing%';

-- Тоже самое, но только тут будет регулярка
SELECT
    model ->> 'en' AS model,
    range,
    speed
FROM bookings.airplanes_data
WHERE model ->> 'en' ~ '^(Airbus|Boeing)';

-- 3. Для каждого самолёта вывести название модели, 
-- дальность и вычисляемый столбец type: 
-- до 3000 км — Ближнемагистральный, 
-- от 3000 до 6000 км — Среднемагистральный, 
-- свыше 6000 км — Дальнемагистральный.
SELECT
    model ->> 'en' AS model,
    range,
    CASE
        WHEN range < 3000 THEN 'Ближнемагистральный'
        WHEN range <= 6000 THEN 'Среднемагистральный'
        ELSE 'Дальнемагистральный'
    END AS type
FROM bookings.airplanes_data;

-- 4. Для каждого значения status таблицы flights определить количество рейсов. 
-- Вывести сначала наиболее часто встречающиеся статусы.
-- Требуемый результат:
-- status | flights_count
SELECT
    status,
    COUNT(*) AS flights_count
FROM bookings.flights
GROUP BY status 
ORDER BY flights_count DESC;


-- 5. Для каждого маршрута вывести номер маршрута, аэропорт отправления, 
-- аэропорт назначения, код самолёта и английское название модели самолёта.
-- Использовать таблицы routes и airplanes_data.
SELECT
    r.route_no,
    r.departure_airport,
    r.arrival_airport,
    r.airplane_code,
    a.model ->> 'en' AS model
FROM bookings.routes AS r
JOIN bookings.airplanes_data AS a
    ON a.airplane_code = r.airplane_code;

-- 6. Количество мест различных классов в самолётах. 
-- Для каждой модели самолёта определить количество мест каждого класса обслуживания. 
-- Вывести английское название модели, класс обслуживания и количество мест. 
-- Отсортировать сначала по модели, затем по классу.
-- Требуемый результат:
-- airplane_model | fare_conditions | seats_count
SELECT
    a.model ->> 'en' AS airplane_model,
    s.fare_conditions,
    COUNT(*) AS seats_count
FROM bookings.seats AS s
JOIN bookings.airplanes_data AS a
    ON a.airplane_code = s.airplane_code
GROUP BY a.model ->> 'en', s.fare_conditions
ORDER BY airplane_model, s.fare_conditions;

-- 7. Пассажиры, не прошедшие регистрацию. 
-- Найти пассажиров, которые имели сегмент на рейс, фактически уже вылетевший, но для которых отсутствует посадочный талон. 
-- Вывести имя пассажира, номер билета, flight_id и фактическое время вылета. 
-- Использовать segments, tickets, flights и boarding_passes.
SELECT
    t.passenger_name,
    t.ticket_no,
    f.flight_id,
    f.actual_departure
FROM bookings.tickets AS t
JOIN bookings.segments AS s
    ON s.ticket_no = t.ticket_no
JOIN bookings.flights AS f
    ON f.flight_id = s.flight_id
LEFT JOIN bookings.boarding_passes AS p
    ON p.ticket_no = s.ticket_no
   AND p.flight_id = s.flight_id
WHERE f.actual_departure IS NOT NULL
  AND p.ticket_no IS NULL;

-- 8. Найти случаи, когда класс обслуживания, указанный в segments.fare_conditions, 
-- не совпадает с классом назначенного пассажиру места из seats.fare_conditions. 
-- Вывести пассажира, рейс, модель самолёта, номер места, оплаченный класс и фактический класс места.
SELECT
    t.passenger_name,
    f.flight_id,
    f.route_no,
    ad.model ->> 'en' AS airplane_model,
    bp.seat_no,
    s.fare_conditions AS paid_class,
    st.fare_conditions AS seat_class
FROM bookings.segments AS s
JOIN bookings.tickets AS t
    ON t.ticket_no = s.ticket_no
JOIN bookings.flights AS f
    ON f.flight_id = s.flight_id
JOIN bookings.routes AS r
    ON r.route_no = f.route_no
   AND r.validity @> f.scheduled_departure
JOIN bookings.airplanes_data AS ad
    ON ad.airplane_code = r.airplane_code
JOIN bookings.boarding_passes AS bp
    ON bp.ticket_no = s.ticket_no
   AND bp.flight_id = s.flight_id
JOIN bookings.seats AS st
    ON st.airplane_code = r.airplane_code
   AND st.seat_no = bp.seat_no
WHERE s.fare_conditions <> st.fare_conditions;

-- 9. Для каждого направления departure_airport → arrival_airport определить 
-- количество пассажирских сегментов, минимальную, максимальную и среднюю стоимость сегмента, а также общую сумму продаж. 
-- Вывести только направления, для которых было продано более 100 сегментов.
-- Требуемый результат:
-- departure_airport
-- arrival_airport
-- segments_count
-- min_price
-- max_price
-- avg_price
-- total_revenue
SELECT
    r.departure_airport,
    r.arrival_airport,
    COUNT(*)                AS segments_count,
    MIN(s.price)            AS min_price,
    MAX(s.price)            AS max_price,
    ROUND(AVG(s.price), 2)  AS avg_price,
    SUM(s.price)            AS total_revenue
FROM bookings.segments AS s
JOIN bookings.flights AS f
    ON f.flight_id = s.flight_id
JOIN bookings.routes AS r
    ON r.route_no = f.route_no
   AND r.validity @> f.scheduled_departure
GROUP BY r.departure_airport, r.arrival_airport
HAVING COUNT(*) > 100
ORDER BY total_revenue DESC;



-- 10. Найти пассажиров, у которых встречалось более одного класса обслуживания. 
-- Для каждого такого пассажира вывести passenger_id, имя, количество сегментов и количество различных классов обслуживания. 
-- Результат отсортировать сначала по числу различных классов, затем по числу сегментов.
-- Требуемый результат:
-- passenger_id
-- passenger_name
-- segments_count
-- classes_count
SELECT
    t.passenger_id,
    t.passenger_name,
    COUNT(*) AS segments_count,
    COUNT(DISTINCT s.fare_conditions) AS classes_count
FROM bookings.tickets AS t
JOIN bookings.segments AS s
    ON t.ticket_no = s.ticket_no
GROUP BY t.passenger_id, t.passenger_name
HAVING COUNT(DISTINCT s.fare_conditions) > 1
ORDER BY classes_count, segments_count;