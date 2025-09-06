#!/usr/bin/env python3
"""
خادم HTTP محلي بسيط لتشغيل تطبيق الباركود
يحل مشاكل CORS والـ Service Workers
"""

import http.server
import socketserver
import webbrowser
import os
import sys
from urllib.parse import urlparse

class CustomHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # إضافة headers لحل مشاكل CORS وService Workers
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        
        # تحديد Content-Type للملفات المختلفة
        if self.path.endswith('.js'):
            self.send_header('Content-Type', 'application/javascript')
        elif self.path.endswith('.json'):
            self.send_header('Content-Type', 'application/json')
        elif self.path.endswith('.css'):
            self.send_header('Content-Type', 'text/css')
        elif self.path.endswith('.html'):
            self.send_header('Content-Type', 'text/html; charset=utf-8')
        
        super().end_headers()
    
    def do_OPTIONS(self):
        # للتعامل مع طلبات OPTIONS
        self.send_response(200)
        self.end_headers()
    
    def log_message(self, format, *args):
        # تحسين رسائل السجل
        print(f"🌐 {args[0]} - {args[1]} - {args[2]}")

def main():
    # تحديد المنفذ
    PORT = 8000
    
    # التحقق من توفر المنفذ
    try:
        with socketserver.TCPServer(("", PORT), CustomHTTPRequestHandler) as httpd:
            print("🚀 تشغيل خادم تطبيق الباركود...")
            print(f"📡 الخادم يعمل على: http://localhost:{PORT}")
            print(f"📁 مجلد العمل: {os.getcwd()}")
            print("🔗 سيتم فتح التطبيق في المتصفح...")
            print("⏹️  للإيقاف: اضغط Ctrl+C")
            print("-" * 50)
            
            # فتح المتصفح تلقائياً
            webbrowser.open(f'http://localhost:{PORT}')
            
            # تشغيل الخادم
            httpd.serve_forever()
            
    except OSError as e:
        if e.errno == 48 or "already in use" in str(e):
            print(f"❌ المنفذ {PORT} مستخدم بالفعل")
            print("جرب منفذ آخر أو أغلق التطبيق الذي يستخدم هذا المنفذ")
            
            # جرب منفذ آخر
            for new_port in [8001, 8080, 3000, 5000]:
                try:
                    with socketserver.TCPServer(("", new_port), CustomHTTPRequestHandler) as httpd:
                        print(f"✅ تم العثور على منفذ متاح: {new_port}")
                        print(f"🌐 التطبيق متاح على: http://localhost:{new_port}")
                        webbrowser.open(f'http://localhost:{new_port}')
                        httpd.serve_forever()
                        break
                except OSError:
                    continue
            else:
                print("❌ لم يتم العثور على منفذ متاح")
                sys.exit(1)
        else:
            print(f"❌ خطأ في تشغيل الخادم: {e}")
            sys.exit(1)
    
    except KeyboardInterrupt:
        print("\n⏹️  تم إيقاف الخادم بواسطة المستخدم")
        print("👋 شكراً لاستخدام تطبيق الباركود!")

if __name__ == "__main__":
    # التحقق من وجود الملفات المطلوبة
    required_files = ['index.html', 'app.js', 'manifest.json']
    missing_files = [f for f in required_files if not os.path.exists(f)]
    
    if missing_files:
        print("❌ ملفات مفقودة:")
        for file in missing_files:
            print(f"   - {file}")
        print("تأكد من تشغيل الخادم في مجلد التطبيق الصحيح")
        sys.exit(1)
    
    main()
