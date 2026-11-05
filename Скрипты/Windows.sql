/*function_name(arguments) OVER (
    PARTITION BY column1, column2
    ORDER BY column3 ASC
    ROWS BETWEEN ...
)*/


SELECT
    flight_id,
    ROUND(AVG(price), 2) AS avg_price
FROM segments
GROUP BY flight_id
ORDER BY flight_id;

SELECT
    ticket_no,
    flight_id,
    price,
    ROUND(
        AVG(price) OVER (
            PARTITION BY flight_id
        ), 2
    ) AS avg_price
FROM segments
ORDER BY flight_id, ticket_no;


SELECT COUNT(*) FROM segments;

SELECT
    COUNT(*) OVER () AS total_segments
FROM segments
LIMIT 10;


SELECT
    flight_id,
    ticket_no,
    price,
    COUNT(*) OVER (
        PARTITION BY flight_id
    ) AS tickets_count
FROM segments
ORDER BY flight_id, ticket_no;


SELECT
    flight_id,
    ticket_no,
    price,
    ROW_NUMBER() OVER (
        PARTITION BY flight_id
        ORDER BY price DESC, ticket_no
    ) AS row_num
FROM segments
ORDER BY flight_id, row_num;


SELECT
    flight_id,
    ticket_no,
    fare_conditions,
    COUNT(*) OVER (
        PARTITION BY flight_id
    ) AS segments_count
FROM segments
ORDER BY flight_id, ticket_no;

SELECT
    flight_id,
    ticket_no,
    fare_conditions,
    COUNT(*) OVER (
        PARTITION BY flight_id
    ) AS total_count,
    COUNT(*) FILTER (
        WHERE fare_conditions = 'Business'
    ) OVER (
        PARTITION BY flight_id
    ) AS business_count
FROM segments
ORDER BY flight_id, ticket_no;


SELECT
    flight_id,
    ticket_no,
    price,
    SUM(price) OVER (
        PARTITION BY flight_id
    ) AS total_price
FROM segments
ORDER BY flight_id, ticket_no;


SELECT
    flight_id,
    ticket_no,
    price,
    SUM(price) OVER (
        PARTITION BY flight_id
    ) AS total_price,
    ROUND(
        100.0 * price /
        NULLIF(
            SUM(price) OVER (
                PARTITION BY flight_id
            ), 0
        ),
        2
    ) AS price_percent
FROM segments
ORDER BY flight_id, ticket_no;


SELECT
    flight_id,
    ticket_no,
    price,
    ROUND(
        AVG(price) OVER (
            PARTITION BY flight_id
        ), 2
    ) AS avg_price,
    ROUND(
        price - AVG(price) OVER (
            PARTITION BY flight_id
        ), 2
    ) AS price_difference
FROM segments
ORDER BY flight_id, ticket_no;

SELECT
    flight_id,
    ticket_no,
    price,
    MIN(price) OVER (
        PARTITION BY flight_id
    ) AS min_price,
    MAX(price) OVER (
        PARTITION BY flight_id
    ) AS max_price,
    MAX(price) OVER (
        PARTITION BY flight_id
    )
    -
    MIN(price) OVER (
        PARTITION BY flight_id
    ) AS price_range
FROM segments
ORDER BY flight_id, ticket_no;


SELECT
    flight_id,
    ticket_no,
    price,
    COUNT(*) OVER (
        PARTITION BY flight_id
    ) AS cnt,
    SUM(price) OVER (
        PARTITION BY flight_id
    ) AS total,
    ROUND(
        AVG(price) OVER (
            PARTITION BY flight_id
        ), 2
    ) AS average,
    MIN(price) OVER (
        PARTITION BY flight_id
    ) AS minimum,
    MAX(price) OVER (
        PARTITION BY flight_id
    ) AS maximum
FROM segments
ORDER BY flight_id, ticket_no
LIMIT 30;


SELECT
    flight_id,
    ticket_no,
    price,
    ROW_NUMBER() OVER (
        PARTITION BY flight_id
        ORDER BY price DESC, ticket_no
    ) AS row_num
FROM segments
ORDER BY flight_id, row_num;


SELECT
    flight_id,
    ticket_no,
    price,
    RANK() OVER (
        PARTITION BY flight_id
        ORDER BY price DESC
    ) AS price_rank
FROM segments
ORDER BY flight_id, price_rank, ticket_no;


--определить время предыдущего запланированного вылета для каждого маршрута.
SELECT
    flight_id,
    route_no,
    scheduled_departure,
    LAG(scheduled_departure) OVER (
        PARTITION BY route_no
        ORDER BY scheduled_departure, flight_id
    ) AS previous_departure
FROM flights
ORDER BY route_no, scheduled_departure, flight_id;

SELECT
    flight_id,
    route_no,
    scheduled_departure,
    scheduled_departure
    -
    LAG(scheduled_departure) OVER (
        PARTITION BY route_no
        ORDER BY scheduled_departure, flight_id
    ) AS departure_interval
FROM flights
ORDER BY route_no, scheduled_departure, flight_id;


SELECT
    flight_id,
    route_no,
    scheduled_departure,
    LEAD(scheduled_departure) OVER (
        PARTITION BY route_no
        ORDER BY scheduled_departure, flight_id
    ) AS next_departure
FROM flights
ORDER BY route_no, scheduled_departure, flight_id;


SELECT
    flight_id,
    route_no,
    scheduled_departure,
    LAG(flight_id) OVER (
        PARTITION BY route_no
        ORDER BY scheduled_departure, flight_id
    ) AS previous_flight_id,
    LEAD(flight_id) OVER (
        PARTITION BY route_no
        ORDER BY scheduled_departure, flight_id
    ) AS next_flight_id
FROM flights
ORDER BY route_no, scheduled_departure, flight_id;


SELECT
    book_ref,
    book_date,
    total_amount,
    SUM(total_amount) OVER (
        ORDER BY book_date, book_ref
        ROWS BETWEEN UNBOUNDED PRECEDING
                 AND CURRENT ROW
    ) AS cumulative_amount
FROM bookings
ORDER BY book_date, book_ref;


SELECT
    book_ref,
    book_date,
    total_amount,
    ROUND(
        AVG(total_amount) OVER (
            ORDER BY book_date, book_ref
            ROWS BETWEEN 2 PRECEDING
                     AND CURRENT ROW
        ), 2
    ) AS moving_avg
FROM bookings
ORDER BY book_date, book_ref;


SELECT
    book_ref,
    book_date,
    total_amount,
    ROUND(
        AVG(total_amount) OVER (
            ORDER BY book_date, book_ref
            ROWS BETWEEN 1 PRECEDING
                     AND 1 FOLLOWING
        ), 2
    ) AS centered_avg
FROM bookings
ORDER BY book_date, book_ref;



WITH daily AS (
    SELECT
        book_date::date AS day,
        SUM(total_amount) AS revenue
    FROM bookings
    GROUP BY book_date::date
)
SELECT
    day,
    revenue,
    SUM(revenue) OVER (
        ORDER BY day
        RANGE BETWEEN INTERVAL '6 days' PRECEDING
                  AND CURRENT ROW
    ) AS revenue_7_days
FROM daily
ORDER BY day;


SELECT
    flight_id,
    ticket_no,
    price,
    SUM(price) OVER (
        PARTITION BY flight_id
        ORDER BY price
        ROWS BETWEEN UNBOUNDED PRECEDING
                 AND CURRENT ROW
    ) AS rows_sum,
    SUM(price) OVER (
        PARTITION BY flight_id
        ORDER BY price
        RANGE BETWEEN UNBOUNDED PRECEDING
                  AND CURRENT ROW
    ) AS range_sum
FROM segments
ORDER BY flight_id, price, ticket_no;


SELECT
    flight_id,
    ticket_no,
    price,
    SUM(price) OVER (
        PARTITION BY flight_id
        ORDER BY price, ticket_no
        ROWS BETWEEN UNBOUNDED PRECEDING
                 AND CURRENT ROW
    ) AS rows_sum,
    SUM(price) OVER (
        PARTITION BY flight_id
        ORDER BY price
        RANGE BETWEEN UNBOUNDED PRECEDING
                  AND CURRENT ROW
    ) AS range_sum
FROM segments
ORDER BY flight_id, price, ticket_no;