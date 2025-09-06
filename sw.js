// Service Worker for Barcode Manager PWA
const CACHE_NAME = 'barcode-manager-v2';
const urlsToCache = [
  './',
  './index.html',
  './app.js',
  './manifest.json',
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2',
  'https://cdn.jsdelivr.net/npm/jsqr@1.4.0/dist/jsQR.js',
  'https://cdn.jsdelivr.net/npm/xlsx@0.18.5/dist/xlsx.full.min.js'
];

// Install event
self.addEventListener('install', event => {
  console.log('🔧 Service Worker: Installing...');
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => {
        console.log('📦 Service Worker: Caching app shell');
        return cache.addAll(urlsToCache.filter(url => !url.startsWith('https://')));
      })
      .then(() => {
        console.log('✅ Service Worker: Installation complete');
        self.skipWaiting();
      })
      .catch(error => {
        console.error('❌ Service Worker: Installation failed', error);
      })
  );
});

// Fetch event
self.addEventListener('fetch', event => {
  // Skip cross-origin requests and chrome-extension requests
  if (!event.request.url.startsWith(self.location.origin) || 
      event.request.url.includes('chrome-extension://')) {
    return;
  }
  
  event.respondWith(
    caches.match(event.request)
      .then(response => {
        if (response) {
          console.log('📋 Service Worker: Serving from cache:', event.request.url);
          return response;
        }
        
        console.log('🌐 Service Worker: Fetching from network:', event.request.url);
        return fetch(event.request)
          .then(response => {
            // Check if we received a valid response
            if (!response || response.status !== 200 || response.type !== 'basic') {
              return response;
            }
            
            // Clone the response
            const responseToCache = response.clone();
            
            caches.open(CACHE_NAME)
              .then(cache => {
                cache.put(event.request, responseToCache);
              })
              .catch(error => {
                console.warn('Cache put failed:', error);
              });
            
            return response;
          })
          .catch(error => {
            console.error('❌ Service Worker: Fetch failed', error);
            // Return a fallback response for HTML requests
            if (event.request.headers.get('accept') && 
                event.request.headers.get('accept').includes('text/html')) {
              return caches.match('./index.html');
            }
            throw error;
          });
      })
      .catch(error => {
        console.error('❌ Service Worker: Cache match failed', error);
        return fetch(event.request);
      })
  );
});

// Activate event
self.addEventListener('activate', event => {
  console.log('🚀 Service Worker: Activating...');
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.map(cacheName => {
          if (cacheName !== CACHE_NAME) {
            console.log('🗑️ Service Worker: Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    }).then(() => {
      console.log('✅ Service Worker: Activation complete');
      return self.clients.claim();
    })
  );
});

// Message event handler to prevent message channel errors
self.addEventListener('message', event => {
  console.log('📨 Service Worker: Received message:', event.data);
  
  // Handle different message types
  if (event.data && event.data.type) {
    switch (event.data.type) {
      case 'SKIP_WAITING':
        self.skipWaiting();
        event.ports[0]?.postMessage({ success: true });
        break;
      case 'GET_VERSION':
        event.ports[0]?.postMessage({ version: CACHE_NAME });
        break;
      default:
        console.log('Unknown message type:', event.data.type);
        event.ports[0]?.postMessage({ error: 'Unknown message type' });
    }
  } else {
    // Handle messages without specific type
    event.ports[0]?.postMessage({ received: true });
  }
});

// Handle push notifications (if needed in future)
self.addEventListener('push', event => {
  console.log('📱 Service Worker: Push received');
  // Handle push notifications here if needed
});

// Handle notification clicks (if needed in future)
self.addEventListener('notificationclick', event => {
  console.log('🔔 Service Worker: Notification clicked');
  event.notification.close();
});
