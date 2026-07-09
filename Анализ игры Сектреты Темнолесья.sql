/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Федорова Марина Вячеславовна
 * Дата: 11.10.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
SELECT COUNT (id) AS users_count,
       SUM (payer) AS paying_users,
       SUM (payer)::float/COUNT (id)::float AS perc_paying_users
FROM fantasy.users; 

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT r.race,
       COUNT (u.id) AS users_count,
       SUM (u.payer) AS paying_users,
       SUM (u.payer)::float/COUNT (u.id)::float AS perc_paying_users
FROM fantasy.race AS r 
JOIN fantasy.users AS u ON r.race_id = u.race_id
GROUP BY r.race;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT COUNT(amount) AS count_purchase,
       SUM(amount) AS total_amount,
       MIN(amount) AS min_amount,
       MAX(amount) AS max_amount,
       AVG(amount) AS avg_amount,
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY amount) AS median,
       STDDEV (amount) AS stddev
FROM fantasy.events;

-- 2.2: Аномальные нулевые покупки:
WITH cost AS (
    SELECT COUNT (amount) AS count_cost
    FROM fantasy.events
)
SELECT count_cost,
       (
    SELECT COUNT (amount) AS count_zero_cost
    FROM fantasy.events
    WHERE amount = 0)::float/count_cost AS perc_cost
FROM cost;

-- 2.3: Популярные эпические предметы:
--кол-во покупок для каждого эпического предмета
WITH item_count AS (
     SELECT item_code,
            COUNT (transaction_id) AS transaction_count, 
            COUNT (DISTINCT id) AS id_count
     FROM fantasy.events
     WHERE amount != 0
     GROUP BY item_code
)
-- общее кол-во покупок
SELECT ic.item_code,
       i.game_items,
       ic.transaction_count,
       transaction_count::float/(
          SELECT COUNT (transaction_id)
          FROM fantasy.events)::float AS perc_transactions,
       id_count::float/(
          SELECT COUNT (DISTINCT id)
          FROM fantasy.events)::float AS perc_users
FROM item_count AS ic 
JOIN fantasy.items AS i ON ic.item_code = i.item_code
ORDER BY ic.transaction_count DESC, perc_transactions DESC, perc_users DESC;

-- Задача: Зависимость активности игроков от расы персонажа:
WITH count_users_race AS (
    SELECT race_id,
           COUNT (id) AS users_count -- подсчет общего кол-ва зарегистрированных игроков
    FROM fantasy.users
    GROUP BY race_id
),
paying_users AS (
    SELECT u.race_id,
       COUNT (DISTINCT u.id) AS users_paying, -- игроки, совершившие покупки
       COUNT (DISTINCT u.id)::float/cur.users_count::float AS perc_paying, -- доля от общего кол-ва игроков
       AVG (u.payer) AS payers_share -- доля платящих игроков
FROM fantasy.users AS u
JOIN fantasy.events AS e ON u.id = e.id
JOIN count_users_race AS cur ON u.race_id = cur.race_id 
WHERE e.amount != 0
GROUP BY u.race_id, cur.users_count 
),
avg_paying_users AS (
    SELECT u.race_id,
           COUNT (e.amount)::float/pu.users_paying::float AS avg_total_payer, --среднее кол-во покупок на одного игрока
           SUM (e.amount)::float/pu.users_paying::float AS avg_amount, -- средняя стоимость одной покупки на одного игрока
           AVG (e.amount) AS avg_total_amount -- средняя стоимость
    FROM fantasy.users AS u 
    JOIN fantasy.events AS e ON u.id = e.id
    JOIN paying_users AS pu ON pu.race_id = u.race_id 
    WHERE amount != 0
    GROUP BY u.race_id, pu.users_paying 
)
SELECT r.race_id,
       r.race,
       cur.users_count,
       pu.users_paying,
       pu.perc_paying,
       pu.payers_share,
       apu.avg_total_payer,
       apu.avg_amount,
       apu.avg_total_amount
FROM fantasy.race AS r
LEFT JOIN count_users_race AS cur ON r.race_id = cur.race_id 
LEFT JOIN paying_users AS pu ON cur.race_id = pu.race_id 
LEFT JOIN avg_paying_users AS apu ON pu.race_id = apu.race_id;
