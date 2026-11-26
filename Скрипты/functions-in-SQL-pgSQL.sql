-- Блок 1. Основы создания функций на SQL

-- Задание 1. get_airports_count(): общее количество аэропортов, без параметров.
-- COUNT(*) возвращает bigint, это же значение возвращает функция.
CREATE OR REPLACE FUNCTION get_airports_count()
RETURNS int
LANGUAGE SQL
AS $$
	SELECT COUNT(*) FROM airports_data;
$$;

SELECT get_airports_count();
SELECT COUNT(*) FROM bookings.airports;

-- Задание 2. get_bookings_amount(p_book_ref): стоимость брони по её номеру.
-- Если брони нет, возвращается NULL, а не 0.
create or replace function get_bookings_amount(
p_book_ref text)
returns numeric
language sql
as $$
	select total_amount from bookings
	where (bookings.book_ref::text = p_book_ref);
$$;

select get_bookings_amount('3ZY3O5');

select book_ref, get_bookings_amount(book_ref) from bookings;


-- Задание 3. count_flights(p_status): число рейсов с указанным статусом.
-- При отсутствии таких рейсов COUNT(*) вернёт 0.
CREATE OR REPLACE FUNCTION count_flights(
p_status text
)
RETURNS int
LANGUAGE SQL
AS $$
SELECT count(*)
FROM bookings.flights AS f
WHERE f.status = p_status;
$$;
SELECT count_flights('Arrived');


-- Задание 5. count_flight_passengers(p_flight_id): число уникальных пассажиров рейса.
-- Уникальность считается по passenger_id через segments JOIN tickets.
create or replace function count_flight_passengers(p_flight_id int)
returns int 
language sql
as $$ 
	select count(distinct passenger_id) 
	from segments s
	join tickets t ON s.ticket_no = t.ticket_no
	where s.flight_id = p_flight_id;
$$;

SELECT count_flight_passengers(
(SELECT flight_id FROM bookings.segments LIMIT 1)
);

-- Задание 6. get_airports_by_country(p_country): аэропорты указанной страны.
-- Табличная функция возвращает код аэропорта, название и город.
create or replace function get_airports_by_country(p_country text)
RETURNS TABLE (
airport_code text,
airport_name text,
city text
)
language sql
as $$
	select airport_code,airport_name ->> 'en', city  ->> 'en'
	from airports_data a
	where a.country ->> 'en' = p_country;
$$;

SELECT * FROM get_airports_by_country(
(SELECT country FROM bookings.airports LIMIT 1)
);

-- Блок 2. Функции, возвращающие наборы данных

-- Задание 7.1. get_booking_tickets(p_book_ref): все билеты бронирования.
-- Возвращает полные записи bookings.tickets (RETURNS SETOF).
CREATE OR REPLACE FUNCTION get_booking_tickets(
p_book_ref text)
RETURNS SETOF 
bookings.tickets
LANGUAGE SQL
AS $$
	SELECT *
	FROM tickets AS t
	WHERE t.book_ref::text = p_book_ref;
$$;
-- Проверка:
SELECT get_booking_tickets('RBUUIQ');

-- Задание 7.2. get_booking_passengers(p_book_ref): пассажиры бронирования.
-- Возвращает только ticket_no, passenger_id, passenger_name (RETURNS TABLE).
CREATE OR REPLACE FUNCTION get_booking_passengers(
p_book_ref text)
RETURNS TABLE (
ticket_no text,
passenger_id text,
passenger_name text
)
LANGUAGE SQL
AS $$
	SELECT ticket_no, passenger_id, passenger_name
	FROM tickets AS t
	WHERE t.book_ref::text = p_book_ref;
$$;
-- Проверка:
SELECT get_booking_tickets('RBUUIQ');

-- Задание 8. get_departures(p_airport, p_start, p_end): вылеты за период.
-- Интервал: p_start включительно, p_end не включается.
CREATE OR REPLACE FUNCTION get_departures(
	p_airport text,
	p_start timestamptz,
	p_end timestamptz
)
RETURNS TABLE (
	flight_id integer,
	route_no text,
	arrival_airport text,
	departure_time timestamptz,
	flight_status text
)
LANGUAGE SQL
AS $$
	SELECT flight_id, route_no, arrival_airport, scheduled_departure, status
	FROM bookings.timetable AS t
	WHERE t.departure_airport::text = p_airport
	AND t.scheduled_arrival >= p_start
	AND t.scheduled_departure < p_end;
$$;

SELECT * FROM get_departures(
(SELECT departure_airport
FROM bookings.timetable LIMIT 1),
'2025-09-01 00:00:00+00',
'2025-11-01 00:00:00+00'
)
ORDER BY departure_time;

