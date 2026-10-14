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
