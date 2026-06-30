/* Проект: Анализ проекта DonorSearch
 * Цель: выявить факторы, влияющие на активность доноров и стратегии для их мотивации.
 * Автор: Федорова Марина Вячеславовна
 */


-- Задачи:
-- 1. Oпределить регионы с наибольшим количеством зарегистрированных доноров.
SELECT region,
       COUNT (DISTINCT id) AS id_count
FROM donorsearch.user_anon_data
GROUP BY region 
ORDER BY id_count DESC
LIMIT 10;

-- 2. Изучить динамику общего количества донаций в месяц за 2022 и 2023 годы.
SELECT DATE_TRUNC ('month', donation_date) AS month,
       COUNT (id) AS donation_count
FROM donorsearch.donation_anon
WHERE donation_date BETWEEN '2022-01-01' AND '2023-12-31'
GROUP BY month
ORDER BY month;

-- 3. Определить наиболее активных доноров в системе, учитывая только данные о зарегистрированных и подтвержденных донациях.
SELECT id,
       SUM (confirmed_donations) AS total_donations
FROM donorsearch.user_anon_data
GROUP BY id 
ORDER BY total_donations DESC 
LIMIT 20;

-- 4. Оценить, как система бонусов влияет на зарегистрированные в системе донации.
WITH active_donor AS(
    SELECT id,
           donation_count,
           COALESCE (user_bonus_count, 0) AS bonus
    FROM donorsearch.user_anon_bonus
)
SELECT CASE 
	       WHEN bonus > 0 THEN 'recip_bonus'
	       ELSE 'not_recip_bonus'
       END AS bonus_category,
       COUNT (id) AS id_cnt,
       AVG (donation_count) AS avg_donation
FROM active_donor 
GROUP BY bonus_category;

-- 5. Исследовать вовлечение новых доноров через социальные сети. 
--Узнать, сколько по каким каналам пришло доноров, и среднее количество донаций по каждому каналу.
SELECT CASE 
	       WHEN autho_vk THEN 'VK'
	       WHEN autho_ok THEN 'OK'
	       WHEN autho_tg THEN 'TG'
	       WHEN autho_yandex THEN 'Yandex'
	       WHEN autho_google THEN 'Google'
	       ELSE 'other'
       END AS channel,
       COUNT (id) AS id_cnt,
       AVG (confirmed_donations) AS avg_donations
FROM donorsearch.user_anon_data
GROUP BY channel
ORDER BY id_cnt DESC;

-- 6. Сравнить активность однократных доноров со средней активностью повторных доноров.
WITH activity_donors AS (
    SELECT user_id,
       COUNT (*) AS cnt_donations,
       EXTRACT (YEAR FROM MIN (donation_date)) AS year_first_donations,
       EXTRACT (YEAR FROM AGE (CURRENT_DATE, MIN (donation_date))) AS time_of_first_donations
    FROM donorsearch.donation_anon 
    GROUP BY user_id
    HAVING COUNT (*) > 1
)
SELECT year_first_donations,
       CASE 
	       WHEN cnt_donations BETWEEN 2 AND 3 THEN '2-3 donations'
	       WHEN cnt_donations BETWEEN 4 AND 5 THEN '4-5 donations'
	       WHEN cnt_donations > 6 THEN 'more than 6'
       END AS category,
       COUNT (user_id) AS cnt_users,
       ROUND (AVG (time_of_first_donations), 2) AS average_times_of_first_donations
FROM activity_donors
GROUP BY year_first_donations, cnt_donations  
ORDER BY year_first_donations;
        
-- 7. Сравнить данные о планируемых донациях с фактическими данными, чтобы оценить эффективность планирования.
WITH planned_donations AS (
    SELECT user_id,
           donation_date,
           donation_type
    FROM donorsearch.donation_plan
),
actual_donations AS (
    SELECT user_id,
           donation_date
    FROM donorsearch.donation_anon
),
planned_and_actual_donations AS (
    SELECT pd.user_id,
           pd.donation_date AS planned_data,
           ad.donation_date AS actual_date,
           pd.donation_type,
           CASE
           	WHEN ad.donation_date IS NOT NULL THEN 1
           	ELSE 0
           END AS cnt_actual_donations
    FROM planned_donations AS pd
    LEFT JOIN actual_donations AS ad ON pd.user_id = ad.user_id AND pd.donation_date = ad.donation_date
)
SELECT donation_type,
       COUNT (user_id) AS cnt_users,
       SUM (cnt_actual_donations) AS total_actual_donations,
       ROUND (SUM (cnt_actual_donations)::numeric*100/COUNT (planned_data)::numeric, 2) AS perc_of_completion
FROM planned_and_actual_donations
GROUP BY donation_type;



