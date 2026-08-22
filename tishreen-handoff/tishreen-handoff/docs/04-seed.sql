-- ============================================================================
-- PART A — CORE SEED (every environment)
-- Becomes: api/src/main/resources/db/migration/V2__seed_core_data.sql
-- Contains ONLY reference data the code depends on. No users, no products.
-- ============================================================================

-- ---------- roles ----------
INSERT INTO roles (code, name_ar, name_en) VALUES
 ('ADMIN',    'مدير النظام',  'Administrator'),
 ('EMPLOYEE', 'موظف',         'Employee'),
 ('IT',       'الدعم التقني', 'IT Support'),
 ('DRIVER',   'سائق',         'Driver'),
 ('CUSTOMER', 'عميل',         'Customer');

-- ---------- permissions (the code asks for a permission, never a role) ----------
INSERT INTO permissions (code, description) VALUES
 ('ORDER_VIEW_ALL',          'View all orders'),
 ('ORDER_MANAGE',            'Confirm, start preparing, mark ready, finalize'),
 ('ORDER_WEIGH',             'Enter actual weights (actual_qty)'),
 ('ORDER_ASSIGN_DRIVER',     'Assign driver and dispatch'),
 ('ORDER_CANCEL',            'Cancel an order with a reason'),
 ('DELIVERY_OWN',            'View and complete own deliveries'),
 ('DELIVERY_COLLECT_PAYMENT','Record cash collected on delivery'),
 ('OTP_SEND',                'Generate and send activation / reset codes'),
 ('USER_VIEW',               'Search and view users'),
 ('USER_MANAGE',             'Block, unblock, change role, edit staff notes'),
 ('STAFF_MANAGE',            'Create and edit staff / driver / IT accounts'),
 ('PRODUCT_VIEW_INTERNAL',   'View products with cost and stock'),
 ('PRODUCT_MANAGE',          'Create, edit, deactivate products and images'),
 ('PRODUCT_AVAILABILITY',    'Toggle is_available'),
 ('PRODUCT_PRICE_EDIT',      'Edit product price'),
 ('CATEGORY_MANAGE',         'Manage category tree'),
 ('STOCK_MOVE',              'Record waste / adjustment / return movements'),
 ('PURCHASE_MANAGE',         'Record purchase invoices'),
 ('SUPPLIER_MANAGE',         'Manage suppliers'),
 ('ZONE_MANAGE',             'Manage delivery zones'),
 ('OFFER_MANAGE',            'Create and edit offers'),
 ('POINTS_ADJUST',           'Manual points adjustment'),
 ('CMS_MANAGE',              'Theme and home-page blocks'),
 ('FAQ_MANAGE',              'Chatbot FAQ entries'),
 ('TICKET_VIEW',             'View support tickets'),
 ('TICKET_REPLY',            'Reply to tickets'),
 ('TICKET_ASSIGN',           'Assign tickets'),
 ('REPORT_VIEW',             'View reports'),
 ('AUDIT_VIEW',              'View audit log'),
 ('SETTINGS_BUSINESS',       'Edit BUSINESS settings'),
 ('SETTINGS_TECHNICAL',      'Edit TECHNICAL settings'),
 ('PROVIDER_SWITCH',         'Switch providers'),
 ('LOGS_VIEW',               'View technical logs'),
 ('BACKUP_MANAGE',           'List, run, download backups'),
 ('HEALTH_VIEW',             'View system health');

-- ---------- role → permission matrix ----------
-- ADMIN: everything
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r CROSS JOIN permissions p WHERE r.code = 'ADMIN';

-- EMPLOYEE
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p ON p.code IN (
 'ORDER_VIEW_ALL','ORDER_MANAGE','ORDER_WEIGH','ORDER_ASSIGN_DRIVER','ORDER_CANCEL',
 'OTP_SEND','USER_VIEW','PRODUCT_VIEW_INTERNAL','PRODUCT_AVAILABILITY','PRODUCT_PRICE_EDIT',
 'STOCK_MOVE','TICKET_VIEW','TICKET_REPLY')
WHERE r.code = 'EMPLOYEE';

-- DRIVER
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p ON p.code IN (
 'DELIVERY_OWN','DELIVERY_COLLECT_PAYMENT')
WHERE r.code = 'DRIVER';

-- IT
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r JOIN permissions p ON p.code IN (
 'TICKET_VIEW','TICKET_REPLY','TICKET_ASSIGN','SETTINGS_TECHNICAL','PROVIDER_SWITCH',
 'LOGS_VIEW','BACKUP_MANAGE','HEALTH_VIEW','AUDIT_VIEW')
WHERE r.code = 'IT';

-- CUSTOMER: no permissions; customer endpoints check role + ownership.

-- ---------- settings ----------
INSERT INTO settings (key, value, group_name) VALUES
 -- BUSINESS (admin)
 ('store.name_ar',                    'مجمع تشرين',                'BUSINESS'),
 ('store.name_en',                    'Tishreen Mall',             'BUSINESS'),
 ('store.whatsapp_number',            '+963900000000',             'BUSINESS'), -- replace in prod
 ('store.currency',                   'SYP',                       'BUSINESS'),
 ('store.is_open',                    'true',                      'BUSINESS'),
 ('store.closed_message_ar',          'المتجر مغلق حاليًا، نعود قريبًا.', 'BUSINESS'),
 ('store.closed_message_en',          'The store is closed right now. Back soon.', 'BUSINESS'),
 ('store.hours_open',                 '09:00',                     'BUSINESS'),
 ('store.hours_close',                '22:00',                     'BUSINESS'),
 ('store.timezone',                   'Asia/Damascus',             'BUSINESS'),
 ('store.city_center_lat',            '36.2021',                   'BUSINESS'), -- Aleppo
 ('store.city_center_lng',            '37.1343',                   'BUSINESS'),
 ('orders.weight_step_kg',            '0.250',                     'BUSINESS'),
 ('orders.min_weight_kg',             '0.250',                     'BUSINESS'),
 ('orders.weight_tolerance_pct',      '30',                        'BUSINESS'),
 ('orders.pickup_lead_minutes',       '45',                        'BUSINESS'),
 ('orders.customer_cancel_while',     'NEW',                       'BUSINESS'),
 ('delivery.max_attempts',            '3',                         'BUSINESS'),
 ('loyalty.earn_points_per_amount',   '1',                         'BUSINESS'), -- 1 point ...
 ('loyalty.earn_amount_unit',         '1000',                      'BUSINESS'), -- ... per 1000 SYP of goods
 ('loyalty.redeem_point_value',       '10',                        'BUSINESS'), -- 1 point = 10 SYP
 ('loyalty.min_redeem_points',        '100',                       'BUSINESS'),
 ('loyalty.max_redeem_share',         '0.5',                       'BUSINESS'), -- ≤50% of goods subtotal
 ('loyalty.expiry_days',              '365',                       'BUSINESS'),
 ('otp.ttl_minutes',                  '10',                        'BUSINESS'),
 ('otp.max_attempts',                 '5',                         'BUSINESS'),
 ('bot.match_threshold',              '2',                         'BUSINESS'), -- min keyword hits
 -- TECHNICAL (IT)
 ('auth.access_token_minutes',        '30',                        'TECHNICAL'),
 ('auth.refresh_token_days',          '7',                         'TECHNICAL'),
 ('auth.login_rate_per_minute',       '10',                        'TECHNICAL'),
 ('storage.local.base_path',          '/var/tishreen/media',       'TECHNICAL'),
 ('storage.max_upload_mb',            '5',                         'TECHNICAL'),
 ('backup.schedule_cron',             '0 30 2 * * *',              'TECHNICAL'),
 ('backup.retention_days',            '30',                        'TECHNICAL'),
 ('backup.directory',                 '/var/tishreen/backups',     'TECHNICAL'),
 ('logs.directory',                   '/var/tishreen/logs',        'TECHNICAL'),
 ('logs.retention_days',              '30',                        'TECHNICAL'),
 ('map.tile_url',                     'https://tile.openstreetmap.org/{z}/{x}/{y}.png', 'TECHNICAL'),
 -- PROVIDERS (IT) — the four switches
 ('notification.provider',            'manual-whatsapp',           'PROVIDERS'),
 ('storage.provider',                 'local-disk',                'PROVIDERS'),
 ('payment.provider',                 'cod',                       'PROVIDERS'),
 ('chatbot.provider',                 'faq-rules',                 'PROVIDERS');

-- ---------- theme defaults (admin can change from /admin/cms/theme) ----------
INSERT INTO theme_settings (key, value, type) VALUES
 ('store_name_ar',  'مجمع تشرين',             'TEXT'),
 ('store_name_en',  'Tishreen Mall',          'TEXT'),
 ('slogan_ar',      '',                       'TEXT'),  -- no slogan yet (admin-editable)
 ('slogan_en',      '',                       'TEXT'),
 ('theme_preset',   'rose',                   'TEXT'),  -- rose | orange | sky — the three audited presets (08 §2)
 ('primary_hue',    '',                       'TEXT'),  -- empty = preset hue; else integer 0-360 (hue-only tweak)
 ('logo_key',       '',                       'IMAGE'),
 ('font_display',   'Tufuli Arabic',          'FONT'),  -- licensed files pending; Baloo Bhaijaan 2 is the shipped stand-in/fallback
 ('font_label',     'Cairo',                  'FONT'),
 ('font_body',      'Tajawal',                'FONT');

-- ---------- FAQ starter (bot) ----------
INSERT INTO faq_entries (question_ar, question_en, answer_ar, answer_en, keywords, sort_order) VALUES
 ('ما هي طرق الدفع؟', 'What are the payment methods?',
  'الدفع نقدًا عند الاستلام أو التوصيل فقط.', 'Cash on pickup or delivery only.',
  ARRAY['دفع','نقد','كاش','payment','cash','pay'], 1),
 ('كم تستغرق عملية التوصيل؟', 'How long does delivery take?',
  'عادة خلال ساعة إلى ساعتين حسب المنطقة وضغط الطلبات.', 'Usually 1–2 hours depending on the zone and demand.',
  ARRAY['توصيل','وقت','مدة','متى','delivery','time','long'], 2),
 ('لماذا اختلف سعر طلبي عن السعر المعروض؟', 'Why did my total change?',
  'البضائع الموزونة تُسعَّر حسب الوزن الفعلي بعد الوزن في المتجر.', 'Weighed goods are priced on the actual weight measured at the store.',
  ARRAY['سعر','وزن','فرق','تغير','price','weight','changed'], 3),
 ('كيف أفعّل حسابي؟', 'How do I activate my account?',
  'سيرسل لك موظفنا كود التفعيل عبر واتساب خلال دقائق، أدخله في صفحة التفعيل.', 'Our staff sends the activation code via WhatsApp within minutes; enter it on the activation page.',
  ARRAY['تفعيل','كود','رمز','واتساب','activate','code','otp'], 4);

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
