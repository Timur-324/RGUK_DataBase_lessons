-- =============================================================================
-- 1. Поиск заказов конкретного клиента
-- =============================================================================

--- ДО индекса ---
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE customer_id = 777;

EXPLAIN (ANALYZE)
SELECT * FROM orders WHERE customer_id = 777;


--- вариант A — B-tree + план ---
DROP INDEX IF EXISTS idx_orders_customer_btree;
DROP INDEX IF EXISTS idx_orders_customer_hash;
CREATE INDEX idx_orders_customer_btree ON orders (customer_id);
ANALYZE orders;

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE customer_id = 777;


--- вариант B — Hash + план ---
DROP INDEX idx_orders_customer_btree;
CREATE INDEX idx_orders_customer_hash ON orders USING HASH (customer_id);
ANALYZE orders;

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE customer_id = 777;


--- финальный выбор — оставляем B-tree ---
DROP INDEX IF EXISTS idx_orders_customer_hash;
CREATE INDEX idx_orders_customer_btree ON orders (customer_id);
ANALYZE orders;

SELECT 'B-tree восстановлен, Hash удалён' AS result;


-- =============================================================================
-- 2. Поиск по номеру заказа - индекс уже есть
-- =============================================================================

---2.1: список существующих индексов на orders ---
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public' AND tablename = 'orders'
ORDER BY indexname;


--- 2.2: список ограничений (PK/UNIQUE) на orders ---
SELECT conname, contype, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid = 'orders'::regclass
ORDER BY contype, conname;


--- 2.3: план запроса по order_number ---
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, order_number, status, total_amount
FROM orders
WHERE order_number = 'WEB-00500000';


-- =============================================================================
-- 3. Индекс по статусу при массовой выборке
-- =============================================================================

--- 3.1: доля status='delivered' ---
SELECT
    COUNT(*) FILTER (WHERE status = 'delivered') AS delivered_count,
    COUNT(*) AS total_count,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE status = 'delivered') / COUNT(*), 2
    ) AS delivered_share_pct
FROM orders;


--- 3.2: план БЕЗ индекса по status ---
DROP INDEX IF EXISTS idx_orders_status;

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE status = 'delivered';


--- 3.3: план С индексом по status ---
CREATE INDEX idx_orders_status ON orders (status);
ANALYZE orders;

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM orders WHERE status = 'delivered';


--- 3.4: убираем индекс - он не оправдан ---
DROP INDEX IF EXISTS idx_orders_status;
SELECT 'Индекс по status удалён' AS result;


-- =============================================================================
-- 4. Витрина самых дорогих заказов (топ-20)
-- =============================================================================

--- 4.1: план ДО индекса (будет Sort) ---
DROP INDEX IF EXISTS idx_orders_amount_id_desc;

EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, total_amount
FROM orders
ORDER BY total_amount DESC, order_id DESC
LIMIT 20;


--- 4.2: план ПОСЛЕ индекса (Sort должен исчезнуть) ---
CREATE INDEX idx_orders_amount_id_desc
    ON orders (total_amount DESC, order_id DESC);
ANALYZE orders;

EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, total_amount
FROM orders
ORDER BY total_amount DESC, order_id DESC
LIMIT 20;


-- =============================================================================
-- 5. Медленный поиск по календарной дате
-- =============================================================================

--- 5.1: исходный запрос с created_at::date ---
DROP INDEX IF EXISTS idx_orders_created_at;
DROP INDEX IF EXISTS idx_orders_created_date;
CREATE INDEX idx_orders_created_at ON orders (created_at);
ANALYZE orders;

EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, created_at, total_amount
FROM orders
WHERE created_at::date = DATE '2025-05-10';


--- 5.2: способ 1 - переписать в диапазон ---
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, created_at, total_amount
FROM orders
WHERE created_at >= DATE '2025-05-10'
  AND created_at <  DATE '2025-05-10' + INTERVAL '1 day';


--- 5.3: способ 2 - индекс по выражению (created_at::date) ---
CREATE INDEX idx_orders_created_date ON orders ((created_at::date));
ANALYZE orders;

EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, created_at, total_amount
FROM orders
WHERE created_at::date = DATE '2025-05-10';


--- 5.4: убираем лишний индекс ---
DROP INDEX IF EXISTS idx_orders_created_date;
SELECT 'Оставлен только idx_orders_created_at' AS result;


-- =============================================================================
-- 6. История заказов клиента (20 последних)
-- =============================================================================

--- 6.1: стратегия A - обычный составной индекс ---
DROP INDEX IF EXISTS idx_orders_customer_created;
DROP INDEX IF EXISTS idx_orders_customer_created_covering;

CREATE INDEX idx_orders_customer_created
    ON orders (customer_id, created_at DESC, order_id DESC);
ANALYZE orders;

EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, customer_id, created_at, total_amount
FROM orders
WHERE customer_id = 777
ORDER BY created_at DESC, order_id DESC
LIMIT 20;


--- 6.2: стратегия B - покрывающий индекс (INCLUDE) ---
DROP INDEX idx_orders_customer_created;
CREATE INDEX idx_orders_customer_created_covering
    ON orders (customer_id, created_at DESC, order_id DESC)
    INCLUDE (total_amount);
ANALYZE orders;

EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, customer_id, created_at, total_amount
FROM orders
WHERE customer_id = 777
ORDER BY created_at DESC, order_id DESC
LIMIT 20;


-- =============================================================================
-- 7. Очередь отменённых заказов - частичный индекс
-- =============================================================================

--- 7.1: создаём полный и частичный индексы ---
DROP INDEX IF EXISTS idx_orders_status_created_full;
DROP INDEX IF EXISTS idx_orders_cancelled_created_partial;

CREATE INDEX idx_orders_status_created_full
    ON orders (status, created_at DESC, order_id DESC);

CREATE INDEX idx_orders_cancelled_created_partial
    ON orders (created_at DESC, order_id DESC)
    WHERE status = 'cancelled';

ANALYZE orders;
SELECT 'Оба индекса созданы' AS result;


--- 7.2: план с частичным индексом ---
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, created_at, total_amount
FROM orders
WHERE status = 'cancelled'
ORDER BY created_at DESC, order_id DESC
LIMIT 50;


--- 7.3: сравнение размеров индексов ---
SELECT
    indexrelname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS size
FROM pg_stat_user_indexes
WHERE relname = 'orders'
  AND indexrelname IN (
      'idx_orders_status_created_full',
      'idx_orders_cancelled_created_partial'
  )
ORDER BY pg_relation_size(indexrelid);


--- 7.4: удаляем полный индекс, частичный оставляем ---
DROP INDEX IF EXISTS idx_orders_status_created_full;
SELECT 'Оставлен только частичный индекс' AS result;


-- =============================================================================
-- 8. Поиск города без учёта регистра
-- =============================================================================

--- 8.1: создаём оба индекса (точный и lower) ---
DROP INDEX IF EXISTS idx_orders_city;
DROP INDEX IF EXISTS idx_orders_city_lower;

CREATE INDEX idx_orders_city        ON orders (delivery_city);
CREATE INDEX idx_orders_city_lower  ON orders (lower(delivery_city));

ANALYZE orders;
SELECT 'Созданы idx_orders_city и idx_orders_city_lower' AS result;


--- 8.2: план с lower() ---
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, delivery_city, created_at
FROM orders
WHERE lower(delivery_city) = 'владивосток';


--- 8.3: план с точным сравнением ---
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, delivery_city, created_at
FROM orders
WHERE delivery_city = 'Владивосток';


--- 8.4: убираем «простой» индекс, оставляем lower ---
DROP INDEX IF EXISTS idx_orders_city;
SELECT 'Оставлен только idx_orders_city_lower' AS result;


-- =============================================================================
-- 9. Поиск замечаний о возврате (ILIKE '%...%')
-- =============================================================================

--- 9.1: включаем pg_trgm и создаём B-tree для демонстрации ---
CREATE EXTENSION IF NOT EXISTS pg_trgm;

DROP INDEX IF EXISTS idx_orders_comment_trgm;
DROP INDEX IF EXISTS idx_orders_comment_btree;

CREATE INDEX idx_orders_comment_btree ON orders (comment);
ANALYZE orders;
SELECT 'pg_trgm подключён, создан B-tree по comment' AS result;


--- 9.2: план с B-tree - бесполезно для ILIKE %...% ---
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, comment
FROM orders
WHERE comment ILIKE '%возврат%';


--- 9.3: план с GIN trgm - работает ---
DROP INDEX idx_orders_comment_btree;
CREATE INDEX idx_orders_comment_trgm
    ON orders USING GIN (comment gin_trgm_ops);
ANALYZE orders;

EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, comment
FROM orders
WHERE comment ILIKE '%возврат%';


-- =============================================================================
-- 10. JSONB containment через GIN jsonb_path_ops
-- =============================================================================

--- 10.1: план БЕЗ индекса ---
DROP INDEX IF EXISTS idx_orders_metadata_gin_path;

EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, metadata, total_amount
FROM orders
WHERE metadata @> '{"campaign":"VIP"}'::jsonb;


--- 10.2: план С GIN jsonb_path_ops ---
CREATE INDEX idx_orders_metadata_gin_path
    ON orders USING GIN (metadata jsonb_path_ops);
ANALYZE orders;

EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, metadata, total_amount
FROM orders
WHERE metadata @> '{"campaign":"VIP"}'::jsonb;


-- =============================================================================
-- 11. Index Only Scan + Heap Fetches + VACUUM
-- =============================================================================

--- 11.1: покрывающий индекс, план ДО VACUUM ---
DROP INDEX IF EXISTS idx_orders_customer_covering;

CREATE INDEX idx_orders_customer_covering
    ON orders (customer_id) INCLUDE (created_at);
ANALYZE orders;

EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id, created_at
FROM orders
WHERE customer_id = 777;


--- 11.2: VACUUM (выполнять ОТДЕЛЬНО, не в транзакции) ---
VACUUM (VERBOSE, ANALYZE) orders;


--- 11.3: план ПОСЛЕ VACUUM ---
EXPLAIN (ANALYZE, BUFFERS)
SELECT customer_id, created_at
FROM orders
WHERE customer_id = 777;


-- =============================================================================
-- 12. Глубокая пагинация - keyset вместо OFFSET
-- =============================================================================

--- 12.1: исходный запрос с OFFSET ---
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, order_number
FROM orders
ORDER BY order_id
LIMIT 20 OFFSET 500000;


--- 12.2: keyset-пагинация (те же 20 строк) ---
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, order_number
FROM orders
WHERE order_id > 500000
ORDER BY order_id
LIMIT 20;


-- =============================================================================
-- 13. JOIN с фильтром по клиентам - индекс на внешнем ключе
-- =============================================================================

--- 13.1: план JOIN БЕЗ индекса на orders.customer_id ---
DROP INDEX IF EXISTS idx_orders_customer_btree;

EXPLAIN (ANALYZE, BUFFERS)
SELECT o.order_id, o.customer_id, o.total_amount
FROM customers AS c
JOIN orders AS o ON o.customer_id = c.customer_id
WHERE c.customer_id IN (101, 202, 303, 404, 505);


--- 13.2: план JOIN С индексом на orders.customer_id ---
CREATE INDEX idx_orders_customer_btree ON orders (customer_id);
ANALYZE orders;

EXPLAIN (ANALYZE, BUFFERS)
SELECT o.order_id, o.customer_id, o.total_amount
FROM customers AS c
JOIN orders AS o ON o.customer_id = c.customer_id
WHERE c.customer_id IN (101, 202, 303, 404, 505);


-- =============================================================================
-- 14. Цена индексов при массовой вставке
-- =============================================================================

--- 14.1: создаём две одинаковые целевые таблицы ---
DROP TABLE IF EXISTS write_target_no_idx;
DROP TABLE IF EXISTS write_target_multi_idx;

CREATE TABLE write_target_no_idx
    (LIKE orders INCLUDING DEFAULTS INCLUDING CONSTRAINTS);

CREATE TABLE write_target_multi_idx
    (LIKE orders INCLUDING DEFAULTS INCLUDING CONSTRAINTS);

CREATE INDEX idx_wt_customer ON write_target_multi_idx (customer_id);
CREATE INDEX idx_wt_status   ON write_target_multi_idx (status);
CREATE INDEX idx_wt_created  ON write_target_multi_idx (created_at);
CREATE INDEX idx_wt_metadata ON write_target_multi_idx
    USING GIN (metadata jsonb_path_ops);

ANALYZE write_target_no_idx;
ANALYZE write_target_multi_idx;

SELECT 'Обе таблицы готовы' AS result;


--- 14.2: INSERT 5000 строк БЕЗ индексов ---
EXPLAIN (ANALYZE, BUFFERS)
INSERT INTO write_target_no_idx
SELECT * FROM orders
WHERE order_id BETWEEN 50001 AND 55000;


--- 14.3: INSERT 5000 строк С индексами ---
EXPLAIN (ANALYZE, BUFFERS)
INSERT INTO write_target_multi_idx
SELECT * FROM orders
WHERE order_id BETWEEN 50001 AND 55000;


--- 14.4: сравнение размеров таблиц и индексов ---
SELECT
    c.relname,
    pg_size_pretty(pg_total_relation_size(c.oid)) AS total_size,
    pg_size_pretty(pg_relation_size(c.oid))       AS table_size,
    pg_size_pretty(pg_indexes_size(c.oid))        AS indexes_size
FROM pg_class c
WHERE c.relname IN ('write_target_no_idx', 'write_target_multi_idx')
ORDER BY c.relname;


--- 14.5: убираем временные таблицы ---
DROP TABLE IF EXISTS write_target_no_idx;
DROP TABLE IF EXISTS write_target_multi_idx;
SELECT 'Временные таблицы удалены' AS result;
