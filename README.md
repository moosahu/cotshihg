# تطبيق الصحة النفسية

تطبيق شامل للصحة النفسية مشابه لتطبيق لبيه، يدعم iOS و Android.

## المكونات

- **Backend**: Node.js + Express + PostgreSQL + Redis + Socket.io
- **Mobile**: Flutter (iOS + Android)
- **Admin**: React Web Dashboard (قريباً)

## البدء السريع

### Backend
```bash
cd backend
npm install
cp .env.example .env
# عدّل .env بالإعدادات الخاصة بك
npm run dev
```

### قاعدة البيانات
```bash
# تشغيل PostgreSQL و Redis باستخدام Docker
docker-compose up -d

# تهيئة الجداول
psql -U postgres -d mental_health_db -f src/database/schema.sql
```

### Flutter
```bash
cd mobile/client_app
flutter pub get
flutter run
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /api/v1/auth/send-otp | إرسال OTP |
| POST | /api/v1/auth/verify-otp | التحقق من OTP |
| GET | /api/v1/therapists | قائمة المعالجين |
| GET | /api/v1/therapists/:id | تفاصيل معالج |
| POST | /api/v1/bookings | إنشاء حجز |
| GET | /api/v1/bookings | حجوزاتي |
| POST | /api/v1/sessions/:bookingId/start | بدء جلسة |
| GET | /api/v1/chat/:bookingId/messages | رسائل المحادثة |
| POST | /api/v1/mood | تسجيل المزاج |

## الميزات

- تسجيل بالجوال (OTP)
- اكتشاف المعالجين مع فلترة
- حجز المواعيد (فوري / مجدول)
- جلسات (نصية / صوتية / فيديو)
- دردشة مباشرة (Socket.io)
- مكالمات فيديو (Agora)
- تتبع المزاج اليومي
- محتوى تثقيفي
- إشعارات Push
- بوابة دفع (Moyasar)
