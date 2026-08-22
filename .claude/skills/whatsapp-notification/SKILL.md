---
name: whatsapp-notification
description: Manual WhatsApp channel of Tishreen — wa.me link construction, the exact Arabic/English order and OTP message templates, notification_log semantics (GENERATED → SENT by staff), provider interface NotificationChannel, and what must never be done (no server-side WhatsApp calls). Load for checkout, staff OTP desk, status notifications.
user-invocable: false
---
# Manual WhatsApp notifications (normative: tishreen-handoff/tishreen-handoff/docs/05 §7–§8, tishreen-handoff/tishreen-handoff/docs/06 staff endpoints)

**Principle**: the system *prepares* messages; humans send them from their own WhatsApp. The server never calls WhatsApp. Links are `https://wa.me/<digits>?text=<URL-encoded>` where digits = `store.whatsapp_number` without `+` (order submission, customer → store) or the customer's phone (staff → customer).

**`notification_log`**: `type` ∈ `ORDER_SUBMIT ORDER_CONFIRMED ORDER_READY ORDER_OUT_FOR_DELIVERY ORDER_DELIVERED ORDER_CANCELLED OTP_ACTIVATION OTP_RESET TICKET_REPLY`; `channel` = provider id (`manual-whatsapp`); `status GENERATED` on creation, `SENT` only when a human clicks "تأكيد الإرسال" (`POST /staff/notifications/{id}/mark-sent`, audited `SEND_OTP` for OTP types), `FAILED` if staff marks it. `payload` JSONB keeps `{text, url, language}`. Customer-facing screens never show internal statuses.

**Order message (customer → store), Arabic** — build exactly:
```
طلب جديد {order_number}
الاسم: {full_name} · الهاتف: {phone}
{التسليم: استلام من المتجر · {pickup_time}  |  التوصيل: {zone} · {address details}}
{#}. {name_ar}{ — option_name} × {qty}{ كغ| قطعة} = {line_estimate} ل.س   (one line per item)
المجموع التقديري: {subtotal_estimate} ل.س
{خصم: −{discount} ل.س}
{نقاط: −{points_discount} ل.س}
{رسوم التوصيل: {delivery_fee} ل.س}
الإجمالي التقديري: {final estimate} ل.س
ملاحظة: {customer_note}
* الأسعار تقديرية — البضاعة الموزونة تُحسب على الوزن الفعلي.
```
English variant mirrors it (`New order {number}`…). Numbers Western digits, thousands separator `,`, no decimals for SYP. Lines in braces appear only when non-zero/non-empty. Golden-file tests in `WhatsAppMessageBuilderTest` (ar + en, pickup + delivery, with options and notes).

**OTP message**: ar `مرحبًا {name}، كود تفعيل حسابك في مجمع تشرين هو: {code} — صالح لمدة {ttl} دقائق.` / reset: `كود إعادة تعيين كلمة المرور: {code} — صالح لمدة {ttl} دقائق.` en: `Hi {name}, your مجمع تشرين activation code is {code} — valid for {ttl} minutes.` The code appears once in the `POST /staff/otp/generate` response (`{notificationId, code, text, whatsappUrl, expiresAt}`) and is never logged or re-shown; `otp_codes` keeps only the BCrypt hash.

**Status notifications**: on `CONFIRMED`, `READY_FOR_PICKUP`, `OUT_FOR_DELIVERY`, `DELIVERED`, `CANCELLED` the ordering module emits an event; `NotificationService` creates a GENERATED row with a short template in `customer_language` (`orders.status.<STATUS>` keys in `messages_*.properties`) and the staff queue shows a "send" chip. Nothing is automatic.

**Provider interface** (`platform.providers.NotificationChannel`): `PreparedMessage prepare(NotificationRequest r)`; `void markSent(long notificationId, long actorId)`; `String id()`. `ManualWhatsAppChannel` is the only v1 implementation; a future API-based channel must still write the same `notification_log` rows.
