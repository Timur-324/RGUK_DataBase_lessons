CREATE TABLE customers (
    customer_id integer PRIMARY KEY,
    full_name text NOT NULL,
    email text NOT NULL UNIQUE,
    region text NOT NULL,
    registered_on date NOT NULL,
    comment text NOT NULL
);

CREATE TABLE products (
    product_id integer PRIMARY KEY,
    sku text NOT NULL UNIQUE,
    title text NOT NULL,
    category text NOT NULL,
    price numeric(10,2) NOT NULL CHECK (price > 0),
    attributes jsonb NOT NULL
);

CREATE TABLE orders (
    order_id integer PRIMARY KEY,
    customer_id integer NOT NULL REFERENCES customers(customer_id),
    order_number text NOT NULL UNIQUE,
    created_at timestamp NOT NULL,
    status text NOT NULL CHECK (status IN ('delivered', 'paid', 'shipped', 'cancelled')),
    total_amount numeric(12,2) NOT NULL CHECK (total_amount >= 0),
    delivery_city text NOT NULL,
    metadata jsonb NOT NULL,
    comment text NOT NULL
);

CREATE TABLE order_items (
    order_item_id integer PRIMARY KEY,
    order_id integer NOT NULL REFERENCES orders(order_id),
    product_id integer NOT NULL REFERENCES products(product_id),
    quantity integer NOT NULL CHECK (quantity > 0),
    unit_price numeric(10,2) NOT NULL CHECK (unit_price > 0),
    UNIQUE (order_id, product_id)
);


INSERT INTO customers (customer_id, full_name, email, region, registered_on, comment)
SELECT g,
       'Покупатель ' || lpad(g::text, 5, '0'),
       'buyer' || lpad(g::text, 5, '0') || '@shop.example',
       (ARRAY['Москва', 'Санкт-Петербург', 'Казань', 'Екатеринбург', 'Новосибирск'])[1 + (g % 5)],
       date '2023-01-01' + (g % 550),
       repeat('Карточка клиента интернет-магазина. ', 4)
FROM generate_series(1, 2000) AS s(g);


INSERT INTO products (product_id, sku, title, category, price, attributes)
SELECT g,
       'SKU-' || lpad(g::text, 5, '0'),
       'Товар ' || lpad(g::text, 4, '0'),
       (ARRAY['Электроника', 'Книги', 'Одежда', 'Спорт', 'Дом'])[1 + (g % 5)],
       (100 + ((g * 19) % 200) * 10)::numeric(10,2),
       jsonb_build_object(
          'color', (ARRAY['black','white','red','blue'])[1+(g%4)],
          'brand', 'Brand-' || (1+(g%12)),
          'fragile', (g % 11 = 0)
       )
FROM generate_series(1, 200) AS s(g);


INSERT INTO orders
    (order_id, customer_id, order_number, created_at, status,
     total_amount, delivery_city, metadata, comment)
SELECT g,
       1 + ((g * 37) % 2000),
       'WEB-' || lpad(g::text, 7, '0'),
       timestamp '2024-01-01 00:00:00' + g * interval '2 hours',
       CASE WHEN g % 100 < 2 THEN 'cancelled'
            WHEN g % 100 < 12 THEN 'shipped'
            WHEN g % 100 < 30 THEN 'paid'
            ELSE 'delivered' END,
       (SELECT SUM(p.price * (1 + ((g + j.i) % 3)))
        FROM generate_series(1, 3) AS j(i)
        JOIN products AS p
          ON p.product_id = 1 + ((g * 17 + j.i * 31) % 200)),
       (ARRAY['Москва','Казань','Санкт-Петербург','Новосибирск','Екатеринбург','Самара'])[1+(g%6)],
       jsonb_build_object(
          'campaign', CASE WHEN g % 97 = 0 THEN 'VIP' ELSE 'regular' END,
          'channel', (ARRAY['site','app','partner'])[1+(g%3)],
          'gift', (g%43=0)
       ),
       repeat('Сведения о сборке и доставке заказа. ', 6)
FROM generate_series(1, 1000000) AS s(g);


INSERT INTO order_items (order_item_id, order_id, product_id, quantity, unit_price)
SELECT (o.order_id - 1)*3 + j.i,
       o.order_id,
       p.product_id,
       1 + ((o.order_id + j.i) % 3),
       p.price
FROM orders AS o
CROSS JOIN generate_series(1, 3) AS j(i)
JOIN products AS p ON p.product_id = 1 + ((o.order_id*17 + j.i*31)%200);


SELECT 'customers' AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL SELECT 'products', COUNT(*) FROM products
UNION ALL SELECT 'orders', COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items;


-- Должно получиться 0.
SELECT COUNT(*) AS mismatched_orders
FROM orders AS o
JOIN (SELECT order_id, SUM(quantity * unit_price) AS amount
      FROM order_items GROUP BY order_id) AS x USING (order_id)
WHERE o.total_amount <> x.amount;

