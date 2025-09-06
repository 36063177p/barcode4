-- إعداد قاعدة البيانات لتطبيق إدارة جلسات الباركود
-- استخدم هذا الملف في Supabase SQL Editor

-- إنشاء جدول الجلسات
CREATE TABLE IF NOT EXISTS sessions (
    id BIGSERIAL PRIMARY KEY,
    user_id TEXT NOT NULL DEFAULT 'anonymous',
    client_name TEXT NOT NULL DEFAULT 'عميل غير محدد',
    start_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    end_time TIMESTAMPTZ,
    total_barcodes INTEGER DEFAULT 0,
    success_count INTEGER DEFAULT 0,
    error_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- إنشاء جدول الباركودات
CREATE TABLE IF NOT EXISTS barcodes (
    id BIGSERIAL PRIMARY KEY,
    session_id BIGINT REFERENCES sessions(id) ON DELETE CASCADE,
    barcode_value TEXT NOT NULL,
    scan_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_valid BOOLEAN NOT NULL DEFAULT TRUE,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- إنشاء فهارس لتحسين الأداء
CREATE INDEX IF NOT EXISTS idx_barcodes_session_id ON barcodes(session_id);
CREATE INDEX IF NOT EXISTS idx_barcodes_scan_time ON barcodes(scan_time DESC);
CREATE INDEX IF NOT EXISTS idx_sessions_start_time ON sessions(start_time DESC);
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_barcodes_is_valid ON barcodes(is_valid);

-- إنشاء دالة لتحديث إحصائيات الجلسة تلقائياً
CREATE OR REPLACE FUNCTION update_session_stats()
RETURNS TRIGGER AS $$
BEGIN
    -- تحديث إحصائيات الجلسة عند إضافة باركود جديد
    UPDATE sessions 
    SET 
        total_barcodes = (
            SELECT COUNT(*) 
            FROM barcodes 
            WHERE session_id = NEW.session_id
        ),
        success_count = (
            SELECT COUNT(*) 
            FROM barcodes 
            WHERE session_id = NEW.session_id AND is_valid = TRUE
        ),
        error_count = (
            SELECT COUNT(*) 
            FROM barcodes 
            WHERE session_id = NEW.session_id AND is_valid = FALSE
        ),
        updated_at = NOW()
    WHERE id = NEW.session_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- إنشاء مشغل لتحديث الإحصائيات تلقائياً
DROP TRIGGER IF EXISTS trigger_update_session_stats ON barcodes;
CREATE TRIGGER trigger_update_session_stats
    AFTER INSERT OR UPDATE OR DELETE ON barcodes
    FOR EACH ROW EXECUTE FUNCTION update_session_stats();

-- إنشاء دالة لتحديث updated_at تلقائياً
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- إنشاء مشغل لتحديث updated_at في جدول sessions
DROP TRIGGER IF EXISTS trigger_update_sessions_updated_at ON sessions;
CREATE TRIGGER trigger_update_sessions_updated_at
    BEFORE UPDATE ON sessions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- إنشاء عرض (View) للإحصائيات العامة
CREATE OR REPLACE VIEW session_statistics AS
SELECT 
    s.id,
    s.user_id,
    s.start_time,
    s.end_time,
    s.total_barcodes,
    s.success_count,
    s.error_count,
    CASE 
        WHEN s.total_barcodes > 0 
        THEN ROUND((s.success_count::DECIMAL / s.total_barcodes) * 100, 2)
        ELSE 0 
    END as success_rate,
    CASE 
        WHEN s.end_time IS NOT NULL 
        THEN EXTRACT(EPOCH FROM (s.end_time - s.start_time))/60 
        ELSE EXTRACT(EPOCH FROM (NOW() - s.start_time))/60 
    END as duration_minutes
FROM sessions s
ORDER BY s.start_time DESC;

-- تحديث الجداول الموجودة لإضافة حقل اسم العميل
ALTER TABLE sessions ADD COLUMN IF NOT EXISTS client_name TEXT NOT NULL DEFAULT 'عميل غير محدد';

-- إنشاء عرض للباركودات مع معلومات الجلسة
CREATE OR REPLACE VIEW barcode_details AS
SELECT 
    b.id,
    b.barcode_value,
    b.scan_time,
    b.is_valid,
    b.error_message,
    s.id as session_id,
    s.client_name,
    s.start_time as session_start_time,
    s.user_id
FROM barcodes b
JOIN sessions s ON b.session_id = s.id
ORDER BY b.scan_time DESC;

-- إدراج بيانات تجريبية (اختيارية)
-- يمكنك حذف هذا القسم إذا كنت لا تريد بيانات تجريبية

-- INSERT INTO sessions (user_id, start_time) VALUES 
-- ('demo_user', NOW() - INTERVAL '1 day'),
-- ('demo_user', NOW() - INTERVAL '2 hours');

-- INSERT INTO barcodes (session_id, barcode_value, is_valid, scan_time) VALUES 
-- (1, '1234567890123', TRUE, NOW() - INTERVAL '1 day' + INTERVAL '5 minutes'),
-- (1, '9876543210987', TRUE, NOW() - INTERVAL '1 day' + INTERVAL '10 minutes'),
-- (1, 'INVALID123', FALSE, NOW() - INTERVAL '1 day' + INTERVAL '15 minutes'),
-- (2, '5555666677778888', TRUE, NOW() - INTERVAL '1 hour'),
-- (2, '1111222233334444', TRUE, NOW() - INTERVAL '30 minutes');

-- تفعيل Row Level Security (RLS) للأمان
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE barcodes ENABLE ROW LEVEL SECURITY;

-- إنشاء سياسات الأمان (يمكن تخصيصها حسب الحاجة)
-- هذه السياسات تسمح للجميع بالقراءة والكتابة (للاستخدام العام)
-- يمكنك تعديلها لتقييد الوصول حسب المستخدم

CREATE POLICY "Enable read access for all users" ON sessions
    FOR SELECT USING (true);

CREATE POLICY "Enable insert access for all users" ON sessions
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Enable update access for all users" ON sessions
    FOR UPDATE USING (true);

CREATE POLICY "Enable read access for all users" ON barcodes
    FOR SELECT USING (true);

CREATE POLICY "Enable insert access for all users" ON barcodes
    FOR INSERT WITH CHECK (true);

CREATE POLICY "Enable update access for all users" ON barcodes
    FOR UPDATE USING (true);

-- إنشاء دالة للحصول على إحصائيات سريعة
CREATE OR REPLACE FUNCTION get_quick_stats()
RETURNS JSON AS $$
DECLARE
    result JSON;
BEGIN
    SELECT json_build_object(
        'total_sessions', (SELECT COUNT(*) FROM sessions),
        'total_barcodes', (SELECT COUNT(*) FROM barcodes),
        'valid_barcodes', (SELECT COUNT(*) FROM barcodes WHERE is_valid = TRUE),
        'invalid_barcodes', (SELECT COUNT(*) FROM barcodes WHERE is_valid = FALSE),
        'today_sessions', (SELECT COUNT(*) FROM sessions WHERE DATE(start_time) = CURRENT_DATE),
        'today_barcodes', (SELECT COUNT(*) FROM barcodes WHERE DATE(scan_time) = CURRENT_DATE)
    ) INTO result;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql;

-- تعليق: لاستخدام الدالة، استخدم: SELECT get_quick_stats();

COMMIT;
