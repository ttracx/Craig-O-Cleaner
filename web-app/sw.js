/**
 * Craig-O-Clean Service Worker
 * Provides offline support and caching for the PWA
 */

const CACHE_NAME = 'craig-o-clean-v1';
const STATIC_CACHE = 'craig-o-clean-static-v1';
const DYNAMIC_CACHE = 'craig-o-clean-dynamic-v1';

// Assets to cache immediately on install
const STATIC_ASSETS = [
    '/',
    '/index.html',
    '/css/styles.css',
    '/js/app.js',
    '/manifest.json',
    '/icons/icon-192.png',
    '/icons/icon-512.png'
];

// Install event - cache static assets
self.addEventListener('install', (event) => {
    console.log('[ServiceWorker] Install');

    event.waitUntil(
        caches.open(STATIC_CACHE)
            .then((cache) => {
                console.log('[ServiceWorker] Pre-caching static assets');
                return cache.addAll(STATIC_ASSETS);
            })
            .then(() => {
                console.log('[ServiceWorker] Skip waiting');
                return self.skipWaiting();
            })
            .catch((error) => {
                console.error('[ServiceWorker] Pre-cache failed:', error);
            })
    );
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
    console.log('[ServiceWorker] Activate');

    event.waitUntil(
        caches.keys()
            .then((cacheNames) => {
                return Promise.all(
                    cacheNames
                        .filter((cacheName) => {
                            return cacheName !== STATIC_CACHE &&
                                   cacheName !== DYNAMIC_CACHE;
                        })
                        .map((cacheName) => {
                            console.log('[ServiceWorker] Deleting old cache:', cacheName);
                            return caches.delete(cacheName);
                        })
                );
            })
            .then(() => {
                console.log('[ServiceWorker] Claiming clients');
                return self.clients.claim();
            })
    );
});

// Fetch event - serve from cache, fallback to network
self.addEventListener('fetch', (event) => {
    const { request } = event;
    const url = new URL(request.url);

    // Skip non-GET requests
    if (request.method !== 'GET') {
        return;
    }

    // Skip chrome-extension and other non-http(s) requests
    if (!url.protocol.startsWith('http')) {
        return;
    }

    // Handle navigation requests (HTML pages)
    if (request.mode === 'navigate') {
        event.respondWith(
            fetch(request)
                .then((response) => {
                    // Clone and cache the response
                    const responseClone = response.clone();
                    caches.open(DYNAMIC_CACHE)
                        .then((cache) => cache.put(request, responseClone));
                    return response;
                })
                .catch(() => {
                    // Return cached version or offline page
                    return caches.match(request)
                        .then((cachedResponse) => {
                            if (cachedResponse) {
                                return cachedResponse;
                            }
                            return caches.match('/index.html');
                        });
                })
        );
        return;
    }

    // Handle static assets (CSS, JS, images)
    if (isStaticAsset(url.pathname)) {
        event.respondWith(
            caches.match(request)
                .then((cachedResponse) => {
                    if (cachedResponse) {
                        // Return cached version and update in background
                        fetchAndCache(request, STATIC_CACHE);
                        return cachedResponse;
                    }
                    return fetchAndCache(request, STATIC_CACHE);
                })
        );
        return;
    }

    // Handle other requests with network-first strategy
    event.respondWith(
        fetch(request)
            .then((response) => {
                // Clone and cache the response
                const responseClone = response.clone();
                caches.open(DYNAMIC_CACHE)
                    .then((cache) => cache.put(request, responseClone));
                return response;
            })
            .catch(() => {
                return caches.match(request);
            })
    );
});

// Helper function to check if request is for a static asset
function isStaticAsset(pathname) {
    const staticExtensions = ['.css', '.js', '.png', '.jpg', '.jpeg', '.gif', '.svg', '.woff', '.woff2', '.ttf', '.ico'];
    return staticExtensions.some((ext) => pathname.endsWith(ext));
}

// Helper function to fetch and cache
function fetchAndCache(request, cacheName) {
    return fetch(request)
        .then((response) => {
            if (!response || response.status !== 200) {
                return response;
            }

            const responseClone = response.clone();
            caches.open(cacheName)
                .then((cache) => cache.put(request, responseClone));

            return response;
        })
        .catch((error) => {
            console.error('[ServiceWorker] Fetch failed:', error);
            throw error;
        });
}

// Handle push notifications
self.addEventListener('push', (event) => {
    console.log('[ServiceWorker] Push received');

    let notificationData = {
        title: 'Craig-O-Clean',
        body: 'Time to clean your device!',
        icon: '/icons/icon-192.png',
        badge: '/icons/icon-72.png',
        tag: 'craig-o-clean-notification',
        requireInteraction: false,
        actions: [
            {
                action: 'clean',
                title: 'Clean Now'
            },
            {
                action: 'dismiss',
                title: 'Later'
            }
        ]
    };

    if (event.data) {
        try {
            const data = event.data.json();
            notificationData = { ...notificationData, ...data };
        } catch (e) {
            notificationData.body = event.data.text();
        }
    }

    event.waitUntil(
        self.registration.showNotification(notificationData.title, notificationData)
    );
});

// Handle notification clicks
self.addEventListener('notificationclick', (event) => {
    console.log('[ServiceWorker] Notification clicked:', event.action);

    event.notification.close();

    let url = '/';
    if (event.action === 'clean') {
        url = '/?action=quick-clean';
    }

    event.waitUntil(
        clients.matchAll({ type: 'window', includeUncontrolled: true })
            .then((clientList) => {
                // Focus existing window if available
                for (const client of clientList) {
                    if (client.url.includes(self.location.origin) && 'focus' in client) {
                        client.navigate(url);
                        return client.focus();
                    }
                }
                // Open new window
                if (clients.openWindow) {
                    return clients.openWindow(url);
                }
            })
    );
});

// Handle background sync
self.addEventListener('sync', (event) => {
    console.log('[ServiceWorker] Sync event:', event.tag);

    if (event.tag === 'sync-cleaning-history') {
        event.waitUntil(syncCleaningHistory());
    }
});

// Sync cleaning history (placeholder for future implementation)
async function syncCleaningHistory() {
    console.log('[ServiceWorker] Syncing cleaning history');
    // This would sync with a backend in a real implementation
    return Promise.resolve();
}

// Periodic background sync (if supported)
self.addEventListener('periodicsync', (event) => {
    console.log('[ServiceWorker] Periodic sync:', event.tag);

    if (event.tag === 'check-device-health') {
        event.waitUntil(checkDeviceHealth());
    }
});

async function checkDeviceHealth() {
    console.log('[ServiceWorker] Checking device health');
    // This would check device health and notify if needed
    return Promise.resolve();
}

// Message handling for communication with main app
self.addEventListener('message', (event) => {
    console.log('[ServiceWorker] Message received:', event.data);

    if (event.data && event.data.type === 'SKIP_WAITING') {
        self.skipWaiting();
    }

    if (event.data && event.data.type === 'CACHE_URLS') {
        event.waitUntil(
            caches.open(DYNAMIC_CACHE)
                .then((cache) => cache.addAll(event.data.urls))
        );
    }
});

console.log('[ServiceWorker] Script loaded');
