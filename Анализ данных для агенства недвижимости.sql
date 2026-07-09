/* Анализ данных для агентства недвижимости
 * 
 * Автор: Федорова Марина Вячеславовна
 * Дата: 30.10.2025
*/



-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),
-- Выделяем категории объявлений по времени активности объявления
category_advertisement AS (
   SELECT fi.id,
           CASE
           	   WHEN c.city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
           	   ELSE 'ЛенОбл'
           END AS region,
           CASE
           	   WHEN a.days_exposition <= 30 THEN 'около одного месяца'
           	   WHEN a.days_exposition <= 90 THEN 'от одного до трех месяцев'
           	   WHEN a.days_exposition <= 180 THEN 'от трех месяцев до полугода'
           	   WHEN a.days_exposition > 180 THEN 'более полугода'
           	   ELSE 'non_category'
           END AS active_category,
           ROUND (last_price::numeric/total_area::numeric, 2) AS price_1m, -- Находим стоимость 1 кв.метра
           total_area,
           rooms,
           balcony,
           floor,
           ceiling_height,
           open_plan,
           is_apartment,
           airports_nearest,
           parks_around3000,
           ponds_around3000
     FROM filtered_id AS fi
     LEFT JOIN real_estate.advertisement AS a ON fi.id = a.id
     LEFT JOIN real_estate.flats AS f ON a.id = f.id
     LEFT JOIN real_estate.city AS c ON c.city_id = f.city_id
     LEFT JOIN real_estate.type AS t ON t.type_id = f.type_id
     WHERE t.type = 'город' 
       AND a.first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31'
)
-- Находим статистику для каждой категории объявления в каждом регионе
SELECT region,
       active_category,
       COUNT (DISTINCT id) AS id_count,
       ROUND (COUNT (id)::numeric*100/SUM (COUNT (id)) OVER (PARTITION BY region)::numeric, 2) AS perc_by_category,
       ROUND (AVG (price_1m)::numeric, 2) AS avg_price_1m, 
       ROUND (AVG (total_area)::numeric, 2) AS avg_total_area,
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS median_cnt_room,
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS median_cnt_balcony,
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor) AS median_floor,
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY ceiling_height) AS median_ceiling_height,
       SUM (open_plan) AS open_plan_cnt,
       SUM (is_apartment) AS apartment_cnt,
       ROUND (SUM (open_plan)::numeric*100/COUNT (id)::numeric, 2) AS perc_open_plan,
       ROUND (AVG (airports_nearest)::numeric, 2) AS avg_airports_distance,
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY parks_around3000) AS median_parks,
       PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY ponds_around3000) AS median_ponds,
       ROUND ((SELECT SUM (COUNT (id)) OVER ()
             FROM category_advertisement
             WHERE region = 'ЛенОбл')*100/SUM (COUNT (id)) OVER (), 2) AS perc_cnt_id_len_obl,
       ROUND ((SELECT SUM (COUNT (id)) OVER ()
             FROM category_advertisement
             WHERE region = 'Санкт-Петербург')*100/SUM (COUNT (id)) OVER (), 2) AS perc_cnt_id_saint_p
FROM category_advertisement
GROUP BY region, active_category;
           

-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS (
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
division_by_month AS (
     SELECT EXTRACT (MONTH FROM a.first_day_exposition) AS month_of_publication,
-- Выделяем из даты месяц и с помощью конкаста добавляем 'day', чтобы перевести в интервал для правильного подсчёта
            EXTRACT (MONTH FROM (a.first_day_exposition + (a.days_exposition || ' days')::interval)) AS month_of_withdrawal, 
            fi.id,
            t.type,
            a.first_day_exposition,
            ROUND (last_price::numeric/total_area::numeric, 2) AS price_1m, -- Стоимость 1 кв.метра
            total_area
     FROM filtered_id AS fi
     LEFT JOIN real_estate.advertisement AS a ON fi.id = a.id
     LEFT JOIN real_estate.flats AS f ON a.id = f.id
     LEFT JOIN real_estate.type AS t ON t.type_id = f.type_id
     WHERE t.type = 'город'
       AND a.first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31'
),
-- Считаем статистику для Месяца публикации объявления
statistics_by_month_publication AS (
     SELECT 
            month_of_publication,
            ROUND (COUNT (id)::numeric, 2) AS id_cnt_publication,
            ROUND (AVG (price_1m)::numeric, 2) AS avg_price_1m_publication,
            ROUND (AVG (total_area)::numeric, 2) AS avg_total_area_publication
     FROM division_by_month 
     GROUP BY month_of_publication
),
-- Считаем статистику для Месяца снятия объявления с публикации
statistics_of_month_withdrawal AS (
     SELECT 
            month_of_withdrawal,
            ROUND (COUNT (id)::numeric, 2) AS id_cnt_withdrawal,
            ROUND (AVG (price_1m)::numeric, 2) AS avg_price_1m_withdrawal,
            ROUND (AVG (total_area)::numeric, 2) AS avg_total_area_withdrawal
     FROM division_by_month 
     GROUP BY month_of_withdrawal
)
SELECT RANK () OVER (ORDER BY mp.id_cnt_publication DESC),
       mp.month_of_publication,
       mp.id_cnt_publication,
       ROUND (mp.id_cnt_publication*100/(
          SELECT COUNT (id)
          FROM division_by_month)::numeric, 2) AS perc_id_publication,
       mp.avg_price_1m_publication,
       mp.avg_total_area_publication,
       RANK () OVER (ORDER BY mw.id_cnt_withdrawal DESC),
       mw.month_of_withdrawal,
       mw.id_cnt_withdrawal,
       ROUND (mw.id_cnt_withdrawal*100/(
          SELECT COUNT (id)
          FROM division_by_month)::numeric, 2) AS perc_id_withdrawal,
       mw.avg_price_1m_withdrawal,
       mw.avg_total_area_withdrawal
FROM statistics_by_month_publication mp
JOIN statistics_of_month_withdrawal mw ON mp.month_of_publication = mw.month_of_withdrawal
ORDER BY month_of_publication, month_of_withdrawal;
