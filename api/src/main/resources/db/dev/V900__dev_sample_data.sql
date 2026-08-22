-- ============================================================================
-- PART B — DEV SEED (local development only)
-- Becomes: api/src/main/resources/db/dev/V900__dev_sample_data.sql
-- Enabled only with: spring.flyway.locations=classpath:db/migration,classpath:db/dev (profile dev)
-- Passwords: all dev accounts use  Tishreen!Dev1
-- ============================================================================

INSERT INTO users (full_name, phone, password_hash, role_id, status, preferred_language)
SELECT v.full_name, v.phone, '$2b$12$nKgwQp2v3mY.VnI3eUqCZOuZM6zejWIVSD96rPa40Ad477YCyo11C', r.id, v.status, 'ar'
FROM (VALUES
  ('مدير النظام',  '+963911000001', 'ADMIN',    'ACTIVE'),
  ('موظف المتجر',  '+963911000002', 'EMPLOYEE', 'ACTIVE'),
  ('سائق أول',     '+963911000003', 'DRIVER',   'ACTIVE'),
  ('الدعم التقني', '+963911000004', 'IT',       'ACTIVE'),
  ('عميل فعّال',   '+963911000005', 'CUSTOMER', 'ACTIVE'),
  ('عميل جديد',    '+963911000006', 'CUSTOMER', 'PENDING')
) AS v(full_name, phone, role_code, status)
JOIN roles r ON r.code = v.role_code;

INSERT INTO employee_profiles (user_id, job_title, hired_at)
SELECT id, 'أمين صندوق', CURRENT_DATE FROM users WHERE phone = '+963911000002';
INSERT INTO driver_profiles (user_id, vehicle_type, vehicle_plate, is_available)
SELECT id, 'دراجة نارية', 'حلب 12345', true FROM users WHERE phone = '+963911000003';
INSERT INTO customer_profiles (user_id)
SELECT id FROM users WHERE phone IN ('+963911000005','+963911000006');

INSERT INTO delivery_zones (name_ar, name_en, fee, min_order, sort_order) VALUES
 ('الفرقان',    'Al-Furqan',    5000, 50000, 1),
 ('الجميلية',   'Al-Jamiliyah', 7000, 50000, 2),
 ('الحمدانية',  'Al-Hamdaniyah',8000, 60000, 3),
 ('السريان',    'Al-Suryan',    6000, 50000, 4);

INSERT INTO addresses (user_id, label, zone_id, details, latitude, longitude, is_default)
SELECT u.id, 'البيت', z.id, 'شارع الفرقان، بناء الحكيم، الطابق الثالث', 36.2105, 37.1202, true
FROM users u, delivery_zones z WHERE u.phone = '+963911000005' AND z.name_ar = 'الفرقان';

INSERT INTO categories (name_ar, name_en, slug, sort_order) VALUES
 ('خضار وفواكه', 'Fruits & Vegetables', 'fruits-vegetables', 1),
 ('ألبان وأجبان','Dairy',               'dairy',             2),
 ('مكسرات',      'Nuts',                'nuts',              3),
 ('معلبات',      'Canned goods',        'canned',            4);
INSERT INTO categories (parent_id, name_ar, name_en, slug, sort_order)
SELECT id, 'ورقيات', 'Leafy greens', 'leafy-greens', 1 FROM categories WHERE slug = 'fruits-vegetables';

INSERT INTO products (category_id, name_ar, name_en, slug, unit, price, cost_price, stock_cached, low_stock_threshold)
SELECT c.id, v.name_ar, v.name_en, v.slug, v.unit, v.price, v.cost, v.stock, v.low
FROM (VALUES
  ('fruits-vegetables','بندورة',        'Tomatoes',      'tomatoes',       'KG',    9000,  6500, 120.000, 20.000),
  ('fruits-vegetables','خيار',          'Cucumbers',     'cucumbers',      'KG',    7000,  5000,  80.000, 20.000),
  ('leafy-greens',     'بقدونس',        'Parsley',       'parsley',        'PIECE', 2000,  1200, 40.000, 10.000),
  ('dairy',            'جبنة بيضاء',    'White cheese',  'white-cheese',   'KG',   60000, 48000,  25.000,  5.000),
  ('dairy',            'لبن رائب',      'Yogurt 1 kg',   'yogurt-1kg',     'PIECE',15000, 12000,  30.000,  5.000),
  ('nuts',             'فستق حلبي',     'Aleppo pistachio','aleppo-pistachio','KG', 250000,210000,  10.000,  2.000),
  ('canned',           'تونة 160غ',     'Tuna 160g',     'tuna-160g',      'PIECE',18000, 15000,  60.000, 10.000)
) AS v(cat_slug, name_ar, name_en, slug, unit, price, cost, stock, low)
JOIN categories c ON c.slug = v.cat_slug;

INSERT INTO product_options (product_id, name_ar, name_en, price_delta, sort_order)
SELECT p.id, o.name_ar, o.name_en, o.delta, o.ord FROM products p
JOIN (VALUES
  ('white-cheese', 'قطعة واحدة', 'Whole piece', 0, 1),
  ('white-cheese', 'تقطيع شرائح', 'Sliced',     2000, 2),
  ('aleppo-pistachio', 'بقشر', 'In shell',     0, 1),
  ('aleppo-pistachio', 'مقشّر', 'Shelled',     40000, 2)
) AS o(slug, name_ar, name_en, delta, ord) ON o.slug = p.slug;

-- opening stock as ledger rows (so SUM(stock_movements) == stock_cached)
INSERT INTO stock_movements (product_id, type, qty, reason)
SELECT id, 'ADJUSTMENT', stock_cached, 'Opening stock (dev seed)' FROM products;

INSERT INTO content_blocks (block_type, title, payload, sort_order) VALUES
 ('HERO_BANNER', 'Hero', '{"title":{"ar":"خضار وفواكه طازجة كل صباح","en":"Fresh fruit and vegetables every morning"},"subtitle":{"ar":"من المزرعة إلى بيتك — اطلب الآن","en":"From the farm to your home — order now"},"imageKey":"","cta":{"label":{"ar":"تسوّق الآن","en":"Shop now"},"href":"/categories"}}', 1),
 ('FEATURED_CATEGORIES', 'Featured categories', '{"title":{"ar":"تصفّح الأقسام","en":"Browse categories"},"categoryIds":[1,2,3,4]}', 2),
 ('FEATURED_PRODUCTS', 'Featured products', '{"title":{"ar":"مختارات اليوم","en":"Today''s picks"},"productIds":[1,4,6]}', 3);

INSERT INTO offers (name_ar, name_en, scope, conditions, benefit_type, benefit_value, applies_to, usage_limit_per_customer)
VALUES
 ('توصيل مجاني فوق 150 ألف', 'Free delivery over 150k', 'PUBLIC',
  '{"all":[{"type":"MIN_CART_TOTAL","value":150000},{"type":"FULFILLMENT","value":"DELIVERY"}]}',
  'FREE_DELIVERY', 0, 'CART', NULL),
 ('خصم 10% على أول طلب', '10% off first order', 'PUBLIC',
  '{"all":[{"type":"FIRST_ORDER"}]}',
  'PERCENT', 10, 'CART', 1);
