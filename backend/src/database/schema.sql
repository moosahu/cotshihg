-- Users table
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone VARCHAR(20) UNIQUE NOT NULL,
  email VARCHAR(255) UNIQUE,
  name VARCHAR(255),
  avatar_url TEXT,
  gender VARCHAR(10),
  date_of_birth DATE,
  role VARCHAR(20) DEFAULT 'client' CHECK (role IN ('client', 'therapist', 'coach', 'admin')),
  is_active BOOLEAN DEFAULT true,
  fcm_token TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Therapists profile
CREATE TABLE therapists (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  bio TEXT,
  specializations TEXT[],
  languages TEXT[] DEFAULT '{"ar", "en"}',
  years_experience INTEGER DEFAULT 0,
  education TEXT,
  license_number VARCHAR(100),
  license_verified BOOLEAN DEFAULT false,
  session_price_chat DECIMAL(10,2),
  session_price_voice DECIMAL(10,2),
  session_price_video DECIMAL(10,2),
  rating DECIMAL(3,2) DEFAULT 0,
  total_sessions INTEGER DEFAULT 0,
  total_reviews INTEGER DEFAULT 0,
  is_available_instant BOOLEAN DEFAULT false,
  is_approved BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Therapist availability
CREATE TABLE therapist_availability (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  therapist_id UUID REFERENCES therapists(id) ON DELETE CASCADE,
  day_of_week INTEGER CHECK (day_of_week BETWEEN 0 AND 6),
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  is_active BOOLEAN DEFAULT true
);

-- Bookings
CREATE TABLE bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID REFERENCES users(id),
  therapist_id UUID REFERENCES therapists(id),
  session_type VARCHAR(20) CHECK (session_type IN ('chat', 'voice', 'video')),
  booking_type VARCHAR(20) DEFAULT 'scheduled' CHECK (booking_type IN ('scheduled', 'instant')),
  scheduled_at TIMESTAMP,
  duration_minutes INTEGER DEFAULT 60,
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'in_progress', 'completed', 'cancelled')),
  price DECIMAL(10,2),
  payment_status VARCHAR(20) DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'refunded')),
  payment_id TEXT,
  notes TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Sessions (actual sessions)
CREATE TABLE sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID REFERENCES bookings(id),
  room_id VARCHAR(255) UNIQUE,
  started_at TIMESTAMP,
  ended_at TIMESTAMP,
  duration_actual INTEGER,
  status VARCHAR(20) DEFAULT 'waiting' CHECK (status IN ('waiting', 'active', 'ended')),
  agora_token TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Chat messages
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID REFERENCES bookings(id),
  sender_id UUID REFERENCES users(id),
  content TEXT,
  message_type VARCHAR(20) DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'voice', 'file')),
  media_url TEXT,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Reviews
CREATE TABLE reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID REFERENCES bookings(id),
  client_id UUID REFERENCES users(id),
  therapist_id UUID REFERENCES therapists(id),
  rating INTEGER CHECK (rating BETWEEN 1 AND 5),
  comment TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Mood tracking
CREATE TABLE mood_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  mood_score INTEGER CHECK (mood_score BETWEEN 1 AND 10),
  mood_label VARCHAR(50),
  note TEXT,
  logged_at TIMESTAMP DEFAULT NOW()
);

-- Content (articles/programs)
CREATE TABLE content (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title_ar TEXT NOT NULL,
  title_en TEXT,
  body_ar TEXT,
  body_en TEXT,
  content_type VARCHAR(30) CHECK (content_type IN ('article', 'program', 'exercise', 'webinar')),
  category VARCHAR(50),
  thumbnail_url TEXT,
  duration_minutes INTEGER,
  is_free BOOLEAN DEFAULT true,
  is_published BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Assessments
CREATE TABLE assessments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  assessment_type VARCHAR(50),
  score INTEGER,
  answers JSONB,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Notifications
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  title TEXT,
  body TEXT,
  type VARCHAR(50),
  data JSONB,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Payments
CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID REFERENCES bookings(id),
  user_id UUID REFERENCES users(id),
  amount DECIMAL(10,2),
  currency VARCHAR(10) DEFAULT 'SAR',
  provider VARCHAR(30),
  provider_payment_id TEXT,
  status VARCHAR(20) DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT NOW()
);

-- Questionnaire (admin-managed questions, client one-time response)
CREATE TABLE questionnaire_questions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  question_text TEXT NOT NULL,
  question_type VARCHAR(20) DEFAULT 'text' CHECK (question_type IN ('text', 'rating', 'choice')),
  options JSONB,
  specialization TEXT, -- NULL = عام لكل التخصصات
  order_index INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE TABLE questionnaire_responses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  client_id UUID REFERENCES users(id) ON DELETE CASCADE,
  question_id UUID REFERENCES questionnaire_questions(id) ON DELETE CASCADE,
  answer TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(client_id, question_id)
);

-- Indexes
CREATE INDEX idx_bookings_client ON bookings(client_id);
CREATE INDEX idx_bookings_therapist ON bookings(therapist_id);
CREATE INDEX idx_messages_booking ON messages(booking_id);
CREATE INDEX idx_mood_user ON mood_logs(user_id);
CREATE INDEX idx_notifications_user ON notifications(user_id);
