 -- ilk bakışta genel bir bilgi için bu sorguyu yazdım
 SELECT od.order_id, od.product_id, od.unit_price, od.quantity, od.discount, o.order_date, e.title, 
                r.region_description, s.company_name, o.freight
                FROM orders o
                JOIN order_details od
                ON od.order_id = o.order_id
                JOIN employees e
                ON o.employee_id = e.employee_id
                JOIN employee_territories as et
                ON e.employee_id = et.employee_id
                JOIN territories as t
                ON et.territory_id = t.territory_id
                JOIN region as r
                ON t.region_id = r.region_id
                JOIN shippers s
                ON o.ship_via = s.shipper_id
                GROUP BY od.order_id, od.product_id,o.order_date,e.title,r.region_description,s.company_name, o.freight
---1.ANALİZ python 1: 
--Şirketin fiyat belirleme yöntemi için belirli bir fiyat aralığında ( $20 ila $50) sunulan ürünlerin analizi:
(---ortalama unit_price :
SELECT AVG(unit_price) AS average_price
FROM products;)
--
SELECT
	product_name,
	unit_price
FROM products
WHERE unit_price BETWEEN 20 AND 50
AND discontinued = 0
ORDER BY unit_price DESC;

--2.ANALİZ python2:
--Her kategorinin fiyat aralığına göre nasıl performans gösterdiğinin analizi:
SELECT
	c.category_name,
	CASE 
		WHEN p.unit_price < 20 THEN '$20 altında'
		WHEN p.unit_price >= 20 AND p.unit_price <= 50 THEN '$20 - $50'
		WHEN p.unit_price > 50 THEN '$50 üstünde'
		END AS price_range,
	ROUND(SUM(d.unit_price * d.quantity)) AS total_amount,
	COUNT(DISTINCT d.order_id) AS total_number_orders
FROM categories AS c
INNER JOIN products AS p
ON c.category_id =  p.category_id
INNER JOIN order_details AS d
ON d.product_id =  p.product_id
GROUP BY 
	c.category_name,
	price_range
ORDER BY 
	total_amount DESC;
---
--3.ANALİZ python 3:
-- Her ürünün birim fiyatını, aynı kategorideki ürünlerin ortalama birim fiyatı ile karşılaştırmak için:
WITH tablo AS (
	SELECT 
		c.category_name,
		p.product_name,
		p.unit_price,
		ROUND(AVG(d.unit_price)::NUMERIC, 2) AS average_unit_price
	FROM categories AS c
	INNER JOIN products AS p ON c.category_id = p.category_id
	INNER JOIN order_details AS d ON p.product_id = d.product_id
	WHERE p.discontinued = 0  -- Sadece aktif ürünler
	GROUP BY 
		c.category_name,
		p.product_name,
		p.unit_price
)
SELECT
	category_name,
	product_name,
	unit_price,
	average_unit_price,
	CASE
		WHEN unit_price > average_unit_price THEN 'Ortalamanın Üstünde'
		WHEN unit_price = average_unit_price THEN 'Ortalamaya Eşit'
		WHEN unit_price < average_unit_price THEN 'Ortalamanın Altında'
	END AS average_unit_price_position
FROM tablo
ORDER BY 
	category_name,
	product_name;
---sql sorgular--
--lojistik için ortalama sevkiyat süresi:
SELECT 
    ROUND(AVG(shipped_date - order_date)::NUMERIC, 2) AS average_shipping_time_in_days
FROM orders
WHERE shipped_date IS NOT NULL;  

--ülkelere göre ortalama sevkiyat süresi:
SELECT 
    ship_country,
    ROUND(AVG(shipped_date - order_date)::NUMERIC, 2) AS average_shipping_time_in_days
FROM orders
WHERE shipped_date IS NOT NULL  
GROUP BY ship_country
ORDER BY average_shipping_time_in_days DESC;  
--
--4.ANALİZ 1998 yılında siparişlerin sevkiyatında en az 5 gün gecikme yaşayan ve en az 10 sipariş almış olan ülkeler:
WITH tablo AS (
SELECT
    ship_country,
    ROUND(AVG(shipped_date - order_date)::NUMERIC, 2) AS siparis_sevkiyat_ort_gün_sayisi,  
    COUNT(*) AS toplam_siparis_sayisi  
FROM orders
WHERE EXTRACT(YEAR FROM order_date) = 1998  
GROUP BY
    ship_country
ORDER BY ship_country)
SELECT * FROM tablo
WHERE siparis_sevkiyat_ort_gün_sayisi >= 5  
AND toplam_siparis_sayisi > 10;  
---
--toplam siparis sayisi
select count (*) as toplam_siparis from orders
--geciken sipariş sayısı
SELECT COUNT(*) AS geciken_siparis
FROM orders
WHERE shipped_date > required_date
AND shipped_date IS NOT NULL;  -- Sadece sevk edilen siparişler
--
--teslim edilmeyen sipariş sayısı
SELECT COUNT(*) AS teslim_edilmeyen
FROM orders WHERE shipped_date IS NULL;

--5.ANALİZ : Lojistik için 1997-1998 dönemi aylara göre analiz:
WITH tablo AS (
	SELECT
		CONCAT(EXTRACT(YEAR FROM order_date), 
			   '-', 
			   EXTRACT(MONTH FROM order_date), 
			   '-01'
			  ) AS year_month,
		COUNT(*) AS toplam_siparis,
		ROUND(
			SUM(freight)
			)::INT AS toplam_navlun
	FROM orders
	WHERE order_date >= '1997-01-01' AND order_date < '1998-01-31'
	GROUP BY 
		CONCAT(EXTRACT(YEAR FROM order_date), 
			   '-', 
			   EXTRACT(MONTH FROM order_date), 
			   '-01'
			  )
)
SELECT * FROM tablo
ORDER BY toplam_navlun DESC;
---
--6.ANALİZ: Lojistik: Her ürün kategorisi için bölgesel tedarikçilerin stoklarının mevcut durumu :
SELECT
	c.category_name,
	CASE
		WHEN s.country IN ('Australia', 'Singapore', 'Japan' ) THEN 'Asia'
		WHEN s.country IN ('US', 'Brazil', 'Canada') THEN 'America'
		ELSE 'Europe'
	END AS tedarikci_bölgesi,
	p.units_in_stock AS stok_adedi,
	p.units_on_order AS siparis_edilebilecek_adet,
	p.reorder_level AS yeniden_siparis_seviyesi
FROM suppliers AS s
INNER JOIN products AS p
ON s.supplier_id = p.supplier_id
INNER JOIN categories AS c
ON p.category_id = c.category_id
WHERE s.region IS NOT NULL
ORDER BY 
	tedarikci_bölgesi,
	c.category_name,
	p.unit_price;
----
--7.ANALİZ: Çalışanların Analizi:
SELECT
    CONCAT(e.first_name, ' ', e.last_name) AS calisan_isim_soyisim,
	e.title AS calisan_unvan,
	EXTRACT(YEAR FROM AGE(e.hire_date, e.birth_date))::INT AS yas,
	CONCAT(m.first_name, ' ', m.last_name) AS yönetici_isim_soyisim,
	m.title AS yonetici_unvan
FROM
    employees AS e
INNER JOIN employees AS m 
ON m.employee_id = e.reports_to
ORDER BY
    yas,
	calisan_isim_soyisim;
	
---8.ANALİZ: Çalışanların genel performansı:
WITH kpi AS (
    SELECT
        CONCAT(e.first_name, ' ', e.last_name) AS personel_tam_adı,
        e.title AS personel_unvanı,
        ROUND(
            SUM(d.quantity * d.unit_price)::NUMERIC,
            2) AS kdv_hariç_toplam_satış_tutarı,
        COUNT(DISTINCT d.order_id) AS toplam_sipariş_sayısı,
        COUNT(d.*) AS toplam_satış_kalemi_sayısı,
        ROUND(
            SUM(d.discount*(d.quantity * d.unit_price))::NUMERIC,
            2) AS toplam_indirim_tutarı,
        ROUND(
            SUM((1 - d.discount)*(d.quantity * d.unit_price))::NUMERIC,
            2) AS kdv_dahil_toplam_satış_tutarı
    FROM orders AS o
    INNER JOIN employees AS e
    ON o.employee_id = e.employee_id
    INNER JOIN order_details AS d
    ON d.order_id = o.order_id
    INNER JOIN products AS p
    ON d.product_id = p.product_id
    GROUP BY
        personel_tam_adı,
        personel_unvanı
)
SELECT
    personel_tam_adı,
    personel_unvanı,
    kdv_hariç_toplam_satış_tutarı,
    toplam_sipariş_sayısı,
    toplam_satış_kalemi_sayısı,
    ROUND(
        SUM(kdv_hariç_toplam_satış_tutarı/toplam_satış_kalemi_sayısı),
        2) AS ortalama_satış_kalemi_tutarı,
    ROUND(
        SUM(kdv_hariç_toplam_satış_tutarı/toplam_sipariş_sayısı),
        2) AS ortalama_sipariş_tutarı,
    toplam_indirim_tutarı,
    kdv_dahil_toplam_satış_tutarı,
    SUM(ROUND(
        (kdv_hariç_toplam_satış_tutarı - kdv_dahil_toplam_satış_tutarı) /
        kdv_hariç_toplam_satış_tutarı * 100,
        2)) AS toplam_indirim_yüzdesi
FROM kpi
GROUP BY
    personel_tam_adı,
    personel_unvanı,
    kdv_hariç_toplam_satış_tutarı,
    toplam_sipariş_sayısı,
    toplam_satış_kalemi_sayısı,
    toplam_indirim_tutarı,
    kdv_dahil_toplam_satış_tutarı
ORDER BY kdv_dahil_toplam_satış_tutarı DESC;
--