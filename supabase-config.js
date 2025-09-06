// ملف تكوين Supabase المبسط
// استبدل القيم التالية بقيم مشروعك الخاص

const SUPABASE_CONFIG = {
    // انسخ هذا من Supabase Dashboard > Settings > API
    url: 'https://oowacnfvdvnzwrosfgyy.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9vd2FjbmZ2ZHZuendyb3NmZ3l5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTcwOTkyODgsImV4cCI6MjA3MjY3NTI4OH0.gt48e3zWhMHjrn3SGqYbi_CcasVZkyITY_Dh7KXxttw',
    
    // إعدادات اختيارية
    options: {
        auth: {
            autoRefreshToken: true,
            persistSession: true,
            detectSessionInUrl: false
        }
    }
};

// اختبار الاتصال
async function testSupabaseConnection() {
    if (!window.supabase) {
        console.error('❌ مكتبة Supabase غير محملة');
        return false;
    }
    
    if (SUPABASE_CONFIG.url === 'YOUR_SUPABASE_URL' || 
        SUPABASE_CONFIG.anonKey === 'YOUR_SUPABASE_ANON_KEY') {
        console.warn('⚠️ يرجى تحديث إعدادات Supabase في supabase-config.js');
        return false;
    }
    
    try {
        const client = window.supabase.createClient(
            SUPABASE_CONFIG.url, 
            SUPABASE_CONFIG.anonKey,
            SUPABASE_CONFIG.options
        );
        
        // اختبار بسيط للاتصال
        const { data, error } = await client.from('sessions').select('count').limit(1);
        
        if (error) {
            console.error('❌ خطأ في الاتصال بـ Supabase:', error.message);
            return false;
        }
        
        console.log('✅ تم الاتصال بـ Supabase بنجاح');
        return true;
        
    } catch (error) {
        console.error('❌ خطأ في اختبار Supabase:', error);
        return false;
    }
}

// تصدير التكوين للاستخدام في التطبيق
if (typeof module !== 'undefined' && module.exports) {
    module.exports = SUPABASE_CONFIG;
} else {
    window.SUPABASE_CONFIG = SUPABASE_CONFIG;
    window.testSupabaseConnection = testSupabaseConnection;
}

// تشغيل اختبار تلقائي عند التحميل
if (typeof window !== 'undefined') {
    window.addEventListener('load', () => {
        setTimeout(testSupabaseConnection, 1000);
    });
}
