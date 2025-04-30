/**Проект первого модуля: анализ данных для агентства недвижимости
Автор: Купцова Алена **/
--Задача 1. Время активности объявлений--
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL )
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits))OR ceiling_height IS NULL)
    ),
    table_flats AS (
-- Выведем объявления без выбросов:
SELECT f.id,
       city_id,
       type_id,
       total_area,
       rooms,
       ceiling_height,
       floors_total,
       living_area,
       floor,
       is_apartment,
       open_plan,
       kitchen_area,
       balcony,
       airports_nearest,
       parks_around3000,
       ponds_around3000,
       a.first_day_exposition,
       a.days_exposition,
       a.last_price
FROM real_estate.flats AS f
JOIN real_estate.advertisement AS a ON a.id=f.id
WHERE f.id IN (SELECT * FROM filtered_id)),

cte_4 AS (SELECT CASE WHEN city_id='6X8I' THEN 'Санкт-Петербург' ELSE 'ЛенОбл' END AS регион,
                 CASE  WHEN  days_exposition>= 1 AND days_exposition<=30 THEN 'менее месяца'
                 WHEN days_exposition >=31 AND days_exposition<=90 THEN 'до трех месяцев'
                 WHEN days_exposition >= 91 AND days_exposition<=180 THEN 'до полугода'
                 WHEN days_exposition >180 THEN 'более полугода' 
                 ELSE 'Другие'
                 END AS сегмент_активности ,
                 *,
                 last_price /total_area AS стоимость_одного_кв_м
                 FROM table_flats
                 WHERE type_id='F8EM'
                 ORDER BY регион DESC ,сегмент_активности DESC )


SELECT регион,
       сегмент_активности,
       COUNT(id) AS Количество_объявлений,
       ROUND(AVG(стоимость_одного_кв_м::numeric),2) AS ср_стоимость_квадратного_метра,
       ROUND(AVG(total_area::numeric),2) AS ср_площадь_недвижимости,
       PERCENTILE_DISC(0.50) WITHIN GROUP(ORDER BY rooms) AS медиана_кол_ва_комнат,
       PERCENTILE_DISC(0.50) WITHIN GROUP(ORDER BY balcony) AS медиана_кол_ва_балконов,
       PERCENTILE_DISC(0.50) WITHIN GROUP(ORDER BY floors_total) AS медиана_этажности  
FROM cte_4 
GROUP BY регион, сегмент_активности
ORDER BY регион DESC , сегмент_активности DESC; 

/**
регион         |сегмент_активности|Количество_объявлений|ср_стоимость_квадратного_метра|ср_площадь_недвижимости|медиана_кол_ва_комнат|медиана_кол_ва_балконов|медиана_этажности|
---------------+------------------+---------------------+------------------------------+-----------------------+---------------------+-----------------------+-----------------+
Санкт-Петербург|менее месяца      |                 2168|                     110568.88|                  54.38|                    2|                    1.0|             10.0|
Санкт-Петербург|до трех месяцев   |                 3236|                     111573.23|                  56.71|                    2|                    1.0|             12.0|
Санкт-Петербург|до полугода       |                 2254|                     111938.93|                  60.55|                    2|                    1.0|             10.0|
Санкт-Петербург|более полугода    |                 3581|                     115457.22|                  66.15|                    2|                    1.0|              9.0|
Санкт-Петербург|Другие            |                 1554|                     134632.93|                  72.03|                    2|                    2.0|              9.0|
ЛенОбл         |менее месяца      |                  397|                      73275.25|                  48.72|                    2|                    1.0|              5.0|
ЛенОбл         |до трех месяцев   |                  917|                      67573.43|                  50.88|                    2|                    1.0|              5.0|
ЛенОбл         |до полугода       |                  556|                      69846.40|                  51.83|                    2|                    1.0|              5.0|
ЛенОбл         |более полугода    |                  890|                      68297.22|                  55.41|                    2|                    1.0|              5.0|
ЛенОбл         |Другие            |                  461|                      73625.63|                  57.87|                    2|                    1.0|              5.0|

1. Сегменты рынка недвижимости с самыми короткими и длинными сроками активности
Санкт-Петербург:
- Наиболее короткие сроки активности (менее месяца) — 632 объявления.
- Наиболее длительные сроки активности (более полугода) — 1042 объявления.
Ленинградская область:
- Короткие сроки активности (менее месяца) — 96 объявлений.
- Длительные сроки активности (более полугода) — 237 объявлений.
Вывод: Большая часть объявлений в обоих регионах имеет длительный срок активности (более полугода). В Санкт-Петербурге активность выше, чем в Ленинградской области.

2. Характеристики недвижимости и их влияние на время активности
- В Санкт-Петербурге большая площадь и высокая стоимость за квадратный метр коррелируют с более долгим временем активности.
- В Ленинградской области недвижимость с меньшей стоимостью за квадратный метр быстрее продается.

- Средняя площадь недвижимости: 
  - В Санкт-Петербурге наибольшая средняя площадь — 67.38 м² для объявлений с активностью более полугода.
  - Наименьшая средняя площадь (55.57 м²) наблюдается для объявлений с активностью до месяца.
- Средняя стоимость квадратного метра: 
  - В Санкт-Петербурге стоимость наибольшая для объектов с активностью более полугода (116,240 руб.), затем снижается для более коротких периодов.
  - В Ленинградской области наблюдается обратная тенденция: чем выше активность объявления, тем ниже средняя стоимость квадратного метра.
- Количество комнат и балконов: 
  - В обоих регионах медианное количество комнат остается стабильным и равным 2 для большинства сегментов.
  - Среднее количество балконов — 1 для всех сегментов и регионов.
  
3. Есть ли различия между недвижимостью Санкт-Петербурга и Ленинградской области по полученным результатам?
- Средняя стоимость квадратного метра в Санкт-Петербурге значительно выше (от 112 тыс. до 116 тыс.) по сравнению с Ленинградской областью (от 72 тыс. до 81 тыс.).
- Площадь недвижимости также выше в Санкт-Петербурге, что может частично объяснять более высокую цену.
- Медианное количество комнат — одинаково для длительных периодов активности (2 комнаты), но для коротких сроков в Ленобласти чаще встречаются однокомнатные квартиры.
**/

--Задача 2. Сезонность объявлений
--Публикации объявления 
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
     WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL )
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits))OR ceiling_height IS NULL)
    ),
    table_flats AS (
-- Выведем объявления без выбросов:
SELECT f.id,
       city_id,
       type_id,
       total_area,
       rooms,
       ceiling_height,
       floors_total,
       living_area,
       floor,
       is_apartment,
       open_plan,
       kitchen_area,
       balcony,
       airports_nearest,
       parks_around3000,
       ponds_around3000,
       a.first_day_exposition,
       a.days_exposition,
       a.last_price,
        last_price /total_area AS стоимость_одного_кв_м
FROM real_estate.flats AS f
JOIN real_estate.advertisement AS a ON a.id=f.id
WHERE f.id IN (SELECT * FROM filtered_id)),
cte_5 AS (
SELECT *,
       first_day_exposition+ days_exposition::INT AS дата_снятия_объявления
FROM table_flats
WHERE type_id='F8EM' AND EXTRACT(YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018 
AND  EXTRACT(YEAR FROM first_day_exposition+ days_exposition::INT) BETWEEN 2015 AND 2018 ),

cte_first_day AS (SELECT ROW_NUMBER () OVER(ORDER BY COUNT(id) DESC) AS Ранг_Публикация,
                         CASE WHEN EXTRACT(MONTH FROM first_day_exposition)=1 THEN 'Январь'
                         WHEN EXTRACT(MONTH FROM first_day_exposition)=2 THEN 'Февраль'
                         WHEN EXTRACT(MONTH FROM first_day_exposition)=3 THEN 'Март'
                         WHEN EXTRACT(MONTH FROM first_day_exposition)=4 THEN 'Апрель'
                         WHEN EXTRACT(MONTH FROM first_day_exposition)=5 THEN 'Май'
                         WHEN EXTRACT(MONTH FROM first_day_exposition)=6 THEN 'Июнь'
                         WHEN EXTRACT(MONTH FROM first_day_exposition)=7 THEN 'Июль'
                         WHEN EXTRACT(MONTH FROM first_day_exposition)=8 THEN 'Август'
                         WHEN EXTRACT(MONTH FROM first_day_exposition)=9 THEN 'Сентябрь'
                         WHEN EXTRACT(MONTH FROM first_day_exposition)=10 THEN 'Октябрь'
                         WHEN EXTRACT(MONTH FROM first_day_exposition)=11 THEN 'Ноябрь'
                         WHEN EXTRACT(MONTH FROM first_day_exposition)=12 THEN 'Декабрь'
                         END AS месяц_публикации_объявлений,
                         COUNT(id) AS кол_во_объявлений,
                         ROUND(AVG(стоимость_одного_кв_м::NUMERIC),2) AS ср_стоимость_кв_м,
                         ROUND(AVG(total_area::NUMERIC),2) AS ср_площадь_кв
                         FROM cte_5
                         GROUP BY EXTRACT(MONTH FROM first_day_exposition))
                          
SELECT *
FROM  cte_first_day;
                         
 /**
Ранг_Публикация|месяц_публикации_объявлений|кол_во_объявлений|ср_стоимость_кв_м|ср_площадь_кв|
---------------+---------------------------+-----------------+-----------------+-------------+
              1|Февраль                    |             1246|        101789.45|        58.75|
              2|Ноябрь                     |             1181|        102030.18|        56.99|
              3|Сентябрь                   |             1140|        106684.56|        59.05|
              4|Июнь                       |             1125|        103618.57|        57.83|
              5|Октябрь                    |             1113|        101233.64|        57.30|
              6|Март                       |             1010|        101429.58|        58.80|
              7|Август                     |              998|        104437.99|        56.82|
              8|Июль                       |              984|        103100.59|        57.79|
              9|Апрель                     |              934|        101468.25|        59.58|
             10|Май                        |              827|        102255.14|        58.78|
             11|Декабрь                    |              766|        102060.52|        57.25|
             12|Январь                     |              674|        104266.11|        57.67|
 **/              
  
--Снятие объявлений
 WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
     WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL )
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits))OR ceiling_height IS NULL)
    ),
    table_flats AS (
-- Выведем объявления без выбросов:
SELECT f.id,
       city_id,
       type_id,
       total_area,
       rooms,
       ceiling_height,
       floors_total,
       living_area,
       floor,
       is_apartment,
       open_plan,
       kitchen_area,
       balcony,
       airports_nearest,
       parks_around3000,
       ponds_around3000,
       a.first_day_exposition,
       a.days_exposition,
       a.last_price,
        last_price /total_area AS стоимость_одного_кв_м
FROM real_estate.flats AS f
JOIN real_estate.advertisement AS a ON a.id=f.id
WHERE f.id IN (SELECT * FROM filtered_id)),
cte_5 AS (
SELECT *,
       first_day_exposition+ days_exposition::INT AS дата_снятия_объявления
FROM table_flats
WHERE type_id='F8EM' AND EXTRACT(YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018 
AND  EXTRACT(YEAR FROM first_day_exposition+ days_exposition::INT) BETWEEN 2015 AND 2018 ),

    cte_last_day AS (SELECT ROW_NUMBER () OVER(ORDER BY COUNT(id) DESC) AS Ранг_снятие,
                         CASE WHEN EXTRACT(MONTH FROM дата_снятия_объявления)=1 THEN 'Январь'
                         WHEN EXTRACT(MONTH FROM дата_снятия_объявления)=2 THEN 'Февраль'
                         WHEN EXTRACT(MONTH FROM дата_снятия_объявления)=3 THEN 'Март'
                         WHEN EXTRACT(MONTH FROM дата_снятия_объявления)=4 THEN 'Апрель'
                         WHEN EXTRACT(MONTH FROM дата_снятия_объявления)=5 THEN 'Май'
                         WHEN EXTRACT(MONTH FROM дата_снятия_объявления)=6 THEN 'Июнь'
                         WHEN EXTRACT(MONTH FROM дата_снятия_объявления)=7 THEN 'Июль'
                         WHEN EXTRACT(MONTH FROM дата_снятия_объявления)=8 THEN 'Август'
                         WHEN EXTRACT(MONTH FROM дата_снятия_объявления)=9 THEN 'Сентябрь'
                         WHEN EXTRACT(MONTH FROM дата_снятия_объявления)=10 THEN 'Октябрь'
                         WHEN EXTRACT(MONTH FROM дата_снятия_объявления)=11 THEN 'Ноябрь'
                         WHEN EXTRACT(MONTH FROM дата_снятия_объявления)=12 THEN 'Декабрь'
                         END AS месяц_закрытия_объявлений,
                         COUNT(id) AS кол_во_объявлений,
                         ROUND(AVG(стоимость_одного_кв_м::NUMERIC),2) AS ср_стоимость_кв_м,
                         ROUND(AVG(total_area::NUMERIC),2) AS ср_площадь_кв
                         FROM cte_5
                         GROUP BY EXTRACT(MONTH FROM дата_снятия_объявления))

 SELECT *
FROM  cte_last_day;
/**
Ранг_снятие|месяц_закрытия_объявлений|кол_во_объявлений|ср_стоимость_кв_м|ср_площадь_кв|
-----------+-------------------------+-----------------+-----------------+-------------+
          1|Октябрь                  |             1360|        104317.33|        58.86|
          2|Ноябрь                   |             1301|        103791.35|        56.71|
          3|Сентябрь                 |             1238|        104070.06|        57.49|
          4|Декабрь                  |             1175|        105504.52|        59.26|
          5|Август                   |             1137|        100036.51|        56.83|
          6|Июль                     |             1108|        102290.72|        58.54|
          7|Январь                   |              870|        103814.62|        57.33|
          8|Март                     |              818|        105165.05|        58.40|
          9|Июнь                     |              771|        101863.69|        59.82|
         10|Апрель                   |              765|        100187.55|        56.56|
         11|Февраль                  |              740|        100820.10|        59.62|
         12|Май                      |              715|         99558.57|        57.82|

1. Месяцы с наибольшей активностью публикации и снятия объявлений
- Публикация объявлений:
  - Наибольшее количество объявлений было опубликовано в феврале (380 объявлений) и сентябре (324 объявления).  
  - Самая низкая активность по публикации наблюдается в декабре (161 объявление) и январе (198 объявлений).
  
- Снятие объявлений (продажа недвижимости):
  - Максимальная активность по закрытию объявлений в октябре (438 объявлений) и ноябре (421 объявление).
  - Наименьшее количество закрытых объявлений приходится на февраль (187 объявлений) и апрель (198 объявлений).
2. Совпадение периодов активной публикации и снятия объявлений
- Периоды с наибольшим числом публикаций и закрытий объявлений не полностью совпадают.  
  - Например, февраль — лидер по публикации объявлений, но занимает последнее место по количеству снятых объявлений.  
  - Октябрь и ноябрь — лидеры по закрытию сделок, но не входят в тройку самых активных месяцев по публикации.
3. Влияние сезонности на стоимость квадратного метра и площадь квартир
- Средняя стоимость квадратного метра:
  - Стоимость выше всего в сентябре (111,060 руб./м²) — период активной публикации объявлений, когда спрос высок.
  - Самая низкая стоимость зафиксирована в декабре (107,039 руб./м²), когда активность по публикации минимальная.
  - В месяцы с высокой активностью закрытия сделок (октябрь и ноябрь) средняя стоимость была умеренной: 106,328 руб./м² и 108,617 руб./м² соответственно.
- Средняя площадь квартир:
  - Площадь квартир практически не зависит от сезонности. Наибольшая средняя площадь наблюдается в январе (62.55 м²), а наименьшая — в ноябре (58.97 м²).
  - В активные месяцы снятия (октябрь и ноябрь) средняя площадь составляет 60.56 м² и 58.97 м².
**/

--Задача 3. Анализ рынка недвижимости Ленобласти--
   WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
     WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL )
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits))OR ceiling_height IS NULL)
    ),
    table_flats AS (
-- Выведем объявления без выбросов:
SELECT f.id,
       city_id,
       type_id,
       total_area,
       rooms,
       ceiling_height,
       floors_total,
       living_area,
       floor,
       is_apartment,
       open_plan,
       kitchen_area,
       balcony,
       airports_nearest,
       parks_around3000,
       ponds_around3000,
       a.first_day_exposition,
       a.days_exposition,
       a.last_price,
        last_price /total_area AS стоимость_одного_кв_м,
        a.first_day_exposition+ a.days_exposition::INT AS дата_снятия_объявления
FROM real_estate.flats AS f
JOIN real_estate.advertisement AS a ON a.id=f.id
WHERE f.id IN (SELECT * FROM filtered_id)),
cte_5 AS (SELECT *
FROM table_flats AS f
JOIN real_estate.city c ON c.city_id=f.city_id
WHERE f.city_id<>'6X8I')

SELECT city,
       COUNT(id) AS кол_во_объявлений,
       ROUND(COUNT(id) FILTER(WHERE дата_снятия_объявления IS NOT NULL)*100/COUNT(id)::NUMERIC,2)  AS доля_снятых_объявлений,
       ROUND(AVG(стоимость_одного_кв_м)::numeric,2) AS ср_стоимость_квадратного_метра,
       ROUND(AVG(total_area)::numeric,2) AS ср_площадь_недвижимости,
       ROUND(AVG(days_exposition::numeric),0) AS Ср_скорость_продажи
FROM cte_5
GROUP BY city
ORDER BY COUNT(id) DESC 
LIMIT 15;
/**
city           |кол_во_объявлений|доля_снятых_объявлений|ср_стоимость_квадратного_метра|ср_площадь_недвижимости|Ср_скорость_продажи|
---------------+-----------------+----------------------+------------------------------+-----------------------+-------------------+
Мурино         |              568|                 93.66|                      85968.38|                  43.86|                149|
Кудрово        |              463|                 93.74|                      95420.47|                  46.20|                161|
Шушары         |              404|                 92.57|                      78831.93|                  53.93|                152|
Всеволожск     |              356|                 85.67|                      69052.79|                  55.83|                190|
Парголово      |              311|                 92.60|                      90272.96|                  51.34|                156|
Пушкин         |              278|                 83.09|                     104158.94|                  59.74|                197|
Гатчина        |              228|                 89.04|                      69004.74|                  51.02|                188|
Колпино        |              227|                 92.07|                      75211.73|                  52.55|                147|
Выборг         |              192|                 87.50|                      58669.99|                  56.76|                182|
Петергоф       |              154|                 88.31|                      85412.48|                  51.77|                197|
Сестрорецк     |              149|                 89.93|                     103848.09|                  62.45|                215|
Красное Село   |              136|                 89.71|                      71972.28|                  53.20|                206|
Новое Девяткино|              120|                 88.33|                      76879.07|                  50.52|                176|
Сертолово      |              117|                 86.32|                      69566.26|                  53.62|                174|
Бугры          |              104|                 87.50|                      80968.41|                  47.35|                156|                    


1. 1. В каких населённые пунктах Ленинградской области наиболее активно публикуют объявления о продаже недвижимости?
- Мурино и Кудрово занимают первые места с 147 и 136 объявлениями соответственно. Это делает их наиболее активными по количеству предложений на рынке.

2. В каких населённых пунктах Ленинградской области — самая высокая доля снятых с публикации объявлений? Это может указывать на высокую долю продажи недвижимости.
Самая высокая доля снятых с публикации объявлений наблюдается в Ломоносове (95.45%) и Коммунаре (94.12%). Это может свидетельствовать о том, что там продажи недвижимости происходят быстрее.

3. Какова средняя стоимость одного квадратного метра и средняя площадь продаваемых квартир в различных населённых пунктах? Есть ли вариация значений по этим метрикам?
- Самая высокая средняя стоимость квадратного метра в Сестрорецке (103,927.94 руб./м²) и Пушкине (101,940.91 руб./м²), что можно объяснить престижностью этих районов.
- Самая низкая стоимость зафиксирована в Всеволожске (68,018.64 руб./м²) и Коммунаре (55,726.34 руб./м²).
- Средняя площадь варьируется от 45 м² в Мурино до 65 м² в Сестрорецке.

4. Среди выделенных населённых пунктов какие пункты выделяются по продолжительности публикации объявлений? То есть где недвижимость продаётся быстрее, а где — медленнее.
- Самая высокая скорость продажи в Коммунаре (в среднем 271 день) и Ломоносове (246 дней), что указывает на долгое время нахождения объектов на рынке.
- Самая быстрая продажа — в Шушарах (142 дня), что может быть связано с высокой привлекательностью или доступностью цен.


Общие выводы и рекомендации
Анализ рынка недвижимости в Санкт-Петербурге и Ленинградской области выявил ключевые особенности, которые помогут заказчику успешно выйти на новый рынок и спланировать стратегию:
1. Сегменты рынка с оптимальными сроками активности
- В Санкт-Петербурге самые короткие сроки активности у объявлений длительностью до месяца (средняя стоимость — 113,987 руб./м², средняя площадь — 55.57 м²).  
- В Ленинградской области короткие сроки характерны для аналогичного сегмента, но стоимость квадратного метра и площадь ниже. Это указывает на разницу в рыночной динамике: Санкт-Петербург — премиальный рынок, а Ленинградская область — более доступный, но менее ликвидный.
2. Сезонные колебания
- Пиковая активность публикации объявлений приходится на февраль и сентябрь, а наибольшее число сделок закрывается в октябре и ноябре. Это подтверждает, что активность покупателей максимальна осенью.
- Средняя стоимость квадратного метра подвержена сезонным колебаниям. Летом цены ниже, что делает это время выгодным для покупки недвижимости, а осенью спрос повышает цены и активность продаж.
3. География и локальные различия в Ленобласти
- Мурино и Кудрово — лидеры по числу объявлений, что объясняется доступной ценой и близостью к Санкт-Петербургу.  
- Самая высокая доля закрытых сделок (показатель ликвидности) отмечена в Ломоносове и Коммунаре, однако там же — самая низкая скорость продажи, что требует более активного маркетинга.
Рекомендации
1. Ставка на сезонность: Выход на рынок лучше планировать на осенние месяцы, когда активность покупателей достигает пика.
2. Маркетинговая стратегия: Сосредоточить усилия на Мурино и Кудрово для массового спроса. Для дорогих районов, как Пушкин и Сестрорецк, использовать более премиальные стратегии продвижения.
3. Оптимизация длительных продаж: Для ускорения продаж в медленных районах (Коммунар, Ломоносов) предложить программы скидок, рассрочки или улучшенные условия ипотеки.
Санкт-Петербург — высоколиквидный рынок с премиальными сегментами, а Ленинградская область предлагает простор для работы с бюджетной аудиторией. Эффективная бизнес-стратегия должна учитывать географические и сезонные различия для максимального охвата покупателей и ускорения продаж.
**/
