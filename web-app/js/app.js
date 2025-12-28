/**
 * Craig-O-Clean - Device Optimizer Web App
 * Main Application JavaScript
 */

// App State
const AppState = {
    deviceHealth: 0,
    cacheSize: 0,
    memoryUsage: 0,
    storageUsed: 0,
    storageTotal: 0,
    cpuUsage: 0,
    ramUsage: 0,
    batteryLevel: 100,
    isOnline: navigator.onLine,
    settings: {
        darkMode: true,
        notifications: true,
        autoClean: false,
        cleanImages: true,
        cleanTemp: true
    },
    cleaningHistory: []
};

// DOM Elements
const elements = {
    splashScreen: document.getElementById('splash-screen'),
    app: document.getElementById('app'),
    statusRingProgress: document.getElementById('status-ring-progress'),
    statusPercentage: document.getElementById('status-percentage'),
    statusLabel: document.getElementById('status-label'),
    deviceHealthTitle: document.getElementById('device-health-title'),
    deviceHealthDesc: document.getElementById('device-health-desc'),
    cacheSize: document.getElementById('cache-size'),
    memoryUsage: document.getElementById('memory-usage'),
    speedStatus: document.getElementById('speed-status'),
    batteryLevel: document.getElementById('battery-level'),
    storageUsed: document.getElementById('storage-used'),
    storageTotal: document.getElementById('storage-total'),
    storagePercent: document.getElementById('storage-percent'),
    storageBarFill: document.getElementById('storage-bar-fill'),
    storageApps: document.getElementById('storage-apps'),
    storageMedia: document.getElementById('storage-media'),
    storageCache: document.getElementById('storage-cache'),
    storageOther: document.getElementById('storage-other'),
    cpuUsage: document.getElementById('cpu-usage'),
    ramUsage: document.getElementById('ram-usage'),
    deviceTemp: document.getElementById('device-temp'),
    networkStatus: document.getElementById('network-status'),
    settingsBtn: document.getElementById('settings-btn'),
    settingsModal: document.getElementById('settings-modal'),
    closeSettings: document.getElementById('close-settings'),
    processingModal: document.getElementById('processing-modal'),
    processingTitle: document.getElementById('processing-title'),
    processingStatus: document.getElementById('processing-status'),
    processingBar: document.getElementById('processing-bar'),
    processingPercent: document.getElementById('processing-percent'),
    resultModal: document.getElementById('result-modal'),
    resultTitle: document.getElementById('result-title'),
    resultMessage: document.getElementById('result-message'),
    filesCleaned: document.getElementById('files-cleaned'),
    spaceFreed: document.getElementById('space-freed'),
    resultCloseBtn: document.getElementById('result-close-btn'),
    toastContainer: document.getElementById('toast-container'),
    cleanCacheBtn: document.getElementById('clean-cache-btn'),
    optimizeMemoryBtn: document.getElementById('optimize-memory-btn'),
    boostSpeedBtn: document.getElementById('boost-speed-btn'),
    batterySaverBtn: document.getElementById('battery-saver-btn'),
    deepCleanBtn: document.getElementById('deep-clean-btn'),
    navItems: document.querySelectorAll('.nav-item'),
    darkModeToggle: document.getElementById('dark-mode-toggle'),
    notificationsToggle: document.getElementById('notifications-toggle'),
    autoCleanToggle: document.getElementById('auto-clean-toggle'),
    cleanImagesToggle: document.getElementById('clean-images-toggle'),
    cleanTempToggle: document.getElementById('clean-temp-toggle')
};

// Utility Functions
const Utils = {
    formatBytes(bytes, decimals = 1) {
        if (bytes === 0) return '0 B';
        const k = 1024;
        const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(decimals)) + ' ' + sizes[i];
    },

    randomBetween(min, max) {
        return Math.floor(Math.random() * (max - min + 1) + min);
    },

    delay(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    },

    animateValue(element, start, end, duration, suffix = '') {
        const startTime = performance.now();
        const update = (currentTime) => {
            const elapsed = currentTime - startTime;
            const progress = Math.min(elapsed / duration, 1);
            const easeOut = 1 - Math.pow(1 - progress, 3);
            const current = Math.round(start + (end - start) * easeOut);
            element.textContent = current + suffix;
            if (progress < 1) {
                requestAnimationFrame(update);
            }
        };
        requestAnimationFrame(update);
    },

    setRingProgress(element, percentage) {
        const circumference = 2 * Math.PI * 85;
        const offset = circumference - (percentage / 100) * circumference;
        element.style.strokeDashoffset = offset;
    }
};

// Toast Notifications
const Toast = {
    show(message, type = 'info', duration = 3000) {
        const toast = document.createElement('div');
        toast.className = `toast ${type}`;

        const iconSvg = this.getIcon(type);
        toast.innerHTML = `
            <svg class="toast-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                ${iconSvg}
            </svg>
            <span class="toast-message">${message}</span>
        `;

        elements.toastContainer.appendChild(toast);

        setTimeout(() => {
            toast.classList.add('fade-out');
            setTimeout(() => toast.remove(), 300);
        }, duration);
    },

    getIcon(type) {
        const icons = {
            success: '<path d="M22 11.08V12a10 10 0 11-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/>',
            warning: '<path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>',
            error: '<circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/>',
            info: '<circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/>'
        };
        return icons[type] || icons.info;
    }
};

// Simulated Device Metrics
const DeviceMetrics = {
    async scan() {
        // Simulate scanning device
        await Utils.delay(500);

        // Generate simulated metrics
        AppState.cacheSize = Utils.randomBetween(200, 800) * 1024 * 1024; // 200-800 MB
        AppState.memoryUsage = Utils.randomBetween(40, 75);
        AppState.cpuUsage = Utils.randomBetween(15, 45);
        AppState.ramUsage = Utils.randomBetween(50, 80);

        // Storage simulation
        AppState.storageTotal = 64 * 1024 * 1024 * 1024; // 64 GB
        AppState.storageUsed = Utils.randomBetween(30, 55) * 1024 * 1024 * 1024;

        // Calculate health score based on metrics
        const cacheScore = Math.max(0, 100 - (AppState.cacheSize / (1024 * 1024 * 1024)) * 100);
        const memoryScore = 100 - AppState.memoryUsage;
        const storageScore = Math.max(0, 100 - ((AppState.storageUsed / AppState.storageTotal) * 100));

        AppState.deviceHealth = Math.round((cacheScore + memoryScore + storageScore) / 3);

        return AppState;
    },

    async getBatteryInfo() {
        if ('getBattery' in navigator) {
            try {
                const battery = await navigator.getBattery();
                AppState.batteryLevel = Math.round(battery.level * 100);
                return {
                    level: AppState.batteryLevel,
                    charging: battery.charging
                };
            } catch (e) {
                return { level: 'N/A', charging: false };
            }
        }
        return { level: Utils.randomBetween(20, 95), charging: false };
    },

    getNetworkInfo() {
        if ('connection' in navigator) {
            const conn = navigator.connection;
            return {
                type: conn.effectiveType || 'Unknown',
                downlink: conn.downlink || 'N/A'
            };
        }
        return { type: navigator.onLine ? '4G' : 'Offline', downlink: 'N/A' };
    }
};

// Cleaning Operations
const Cleaner = {
    async cleanCache() {
        elements.processingTitle.textContent = 'Cleaning Cache';
        showModal(elements.processingModal);

        const steps = [
            { status: 'Scanning cached files...', progress: 10 },
            { status: 'Analyzing browser cache...', progress: 25 },
            { status: 'Removing temporary files...', progress: 45 },
            { status: 'Clearing image cache...', progress: 65 },
            { status: 'Optimizing storage...', progress: 85 },
            { status: 'Finalizing...', progress: 100 }
        ];

        for (const step of steps) {
            elements.processingStatus.textContent = step.status;
            elements.processingBar.style.width = step.progress + '%';
            elements.processingPercent.textContent = step.progress + '%';
            await Utils.delay(Utils.randomBetween(400, 700));
        }

        const freedSpace = Utils.randomBetween(100, 400) * 1024 * 1024;
        const filesCount = Utils.randomBetween(50, 200);

        await Utils.delay(300);
        hideModal(elements.processingModal);

        AppState.cacheSize = Math.max(0, AppState.cacheSize - freedSpace);
        this.showResult('Cache Cleaned!', `Removed ${filesCount} temporary files`, filesCount, freedSpace);
        this.addToHistory('Cache Clean', freedSpace, filesCount);
    },

    async optimizeMemory() {
        elements.processingTitle.textContent = 'Optimizing Memory';
        showModal(elements.processingModal);

        const steps = [
            { status: 'Analyzing memory usage...', progress: 15 },
            { status: 'Identifying idle processes...', progress: 35 },
            { status: 'Freeing unused memory...', progress: 55 },
            { status: 'Compacting RAM...', progress: 75 },
            { status: 'Optimizing allocations...', progress: 95 },
            { status: 'Complete!', progress: 100 }
        ];

        for (const step of steps) {
            elements.processingStatus.textContent = step.status;
            elements.processingBar.style.width = step.progress + '%';
            elements.processingPercent.textContent = step.progress + '%';
            await Utils.delay(Utils.randomBetween(300, 600));
        }

        const freedMemory = Utils.randomBetween(200, 500) * 1024 * 1024;
        const processesOptimized = Utils.randomBetween(10, 30);

        await Utils.delay(300);
        hideModal(elements.processingModal);

        AppState.memoryUsage = Math.max(30, AppState.memoryUsage - Utils.randomBetween(10, 25));
        this.showResult('Memory Optimized!', `Freed ${Utils.formatBytes(freedMemory)} of RAM`, processesOptimized, freedMemory);
        this.addToHistory('Memory Optimization', freedMemory, processesOptimized);
    },

    async boostSpeed() {
        elements.processingTitle.textContent = 'Boosting Speed';
        showModal(elements.processingModal);

        const steps = [
            { status: 'Analyzing system performance...', progress: 10 },
            { status: 'Stopping background tasks...', progress: 30 },
            { status: 'Optimizing CPU priority...', progress: 50 },
            { status: 'Clearing system buffers...', progress: 70 },
            { status: 'Applying optimizations...', progress: 90 },
            { status: 'Speed boost applied!', progress: 100 }
        ];

        for (const step of steps) {
            elements.processingStatus.textContent = step.status;
            elements.processingBar.style.width = step.progress + '%';
            elements.processingPercent.textContent = step.progress + '%';
            await Utils.delay(Utils.randomBetween(350, 550));
        }

        await Utils.delay(300);
        hideModal(elements.processingModal);

        AppState.cpuUsage = Math.max(10, AppState.cpuUsage - Utils.randomBetween(5, 15));
        this.showResult('Speed Boosted!', 'Your device is now running faster', 0, 0, true);
        this.addToHistory('Speed Boost', 0, 0);
    },

    async saveBattery() {
        elements.processingTitle.textContent = 'Enabling Battery Saver';
        showModal(elements.processingModal);

        const steps = [
            { status: 'Scanning power usage...', progress: 20 },
            { status: 'Reducing background activity...', progress: 40 },
            { status: 'Optimizing screen settings...', progress: 60 },
            { status: 'Limiting sync frequency...', progress: 80 },
            { status: 'Battery saver enabled!', progress: 100 }
        ];

        for (const step of steps) {
            elements.processingStatus.textContent = step.status;
            elements.processingBar.style.width = step.progress + '%';
            elements.processingPercent.textContent = step.progress + '%';
            await Utils.delay(Utils.randomBetween(300, 500));
        }

        await Utils.delay(300);
        hideModal(elements.processingModal);

        this.showResult('Battery Saver Active!', 'Extended battery life enabled', 0, 0, true);
        this.addToHistory('Battery Saver', 0, 0);
    },

    async deepClean() {
        elements.processingTitle.textContent = 'Deep Cleaning';
        showModal(elements.processingModal);

        const steps = [
            { status: 'Starting deep scan...', progress: 5 },
            { status: 'Analyzing system files...', progress: 15 },
            { status: 'Scanning app data...', progress: 25 },
            { status: 'Checking for residual files...', progress: 35 },
            { status: 'Cleaning browser cache...', progress: 45 },
            { status: 'Removing temp files...', progress: 55 },
            { status: 'Optimizing databases...', progress: 65 },
            { status: 'Cleaning thumbnails...', progress: 75 },
            { status: 'Freeing memory...', progress: 85 },
            { status: 'Final optimization...', progress: 95 },
            { status: 'Deep clean complete!', progress: 100 }
        ];

        for (const step of steps) {
            elements.processingStatus.textContent = step.status;
            elements.processingBar.style.width = step.progress + '%';
            elements.processingPercent.textContent = step.progress + '%';
            await Utils.delay(Utils.randomBetween(400, 800));
        }

        const freedSpace = Utils.randomBetween(500, 1200) * 1024 * 1024;
        const filesCount = Utils.randomBetween(200, 500);

        await Utils.delay(300);
        hideModal(elements.processingModal);

        AppState.cacheSize = Math.max(0, AppState.cacheSize - freedSpace);
        AppState.memoryUsage = Math.max(30, AppState.memoryUsage - Utils.randomBetween(15, 30));
        AppState.deviceHealth = Math.min(100, AppState.deviceHealth + Utils.randomBetween(15, 30));

        this.showResult('Deep Clean Complete!', `Your device is now optimized`, filesCount, freedSpace);
        this.addToHistory('Deep Clean', freedSpace, filesCount);
    },

    showResult(title, message, files, space, isSpeedBoost = false) {
        elements.resultTitle.textContent = title;
        elements.resultMessage.textContent = message;

        if (isSpeedBoost) {
            elements.filesCleaned.textContent = '15%';
            document.querySelector('.result-stats .result-stat:first-child .stat-label').textContent = 'Speed Increase';
            elements.spaceFreed.textContent = 'Active';
            document.querySelector('.result-stats .result-stat:last-child .stat-label').textContent = 'Status';
        } else {
            elements.filesCleaned.textContent = files;
            document.querySelector('.result-stats .result-stat:first-child .stat-label').textContent = 'Files Cleaned';
            elements.spaceFreed.textContent = Utils.formatBytes(space);
            document.querySelector('.result-stats .result-stat:last-child .stat-label').textContent = 'Space Freed';
        }

        showModal(elements.resultModal);
        updateUI();
    },

    addToHistory(action, space, files) {
        AppState.cleaningHistory.unshift({
            action,
            space,
            files,
            timestamp: new Date().toISOString()
        });

        // Keep only last 50 entries
        if (AppState.cleaningHistory.length > 50) {
            AppState.cleaningHistory.pop();
        }

        // Save to localStorage
        localStorage.setItem('cleaningHistory', JSON.stringify(AppState.cleaningHistory));
    }
};

// Modal Functions
function showModal(modal) {
    modal.classList.remove('hidden');
}

function hideModal(modal) {
    modal.classList.add('hidden');
}

// Update UI
function updateUI() {
    // Update status ring
    Utils.setRingProgress(elements.statusRingProgress, AppState.deviceHealth);
    Utils.animateValue(elements.statusPercentage, 0, AppState.deviceHealth, 1000, '%');

    // Update status label
    let healthStatus, healthDesc;
    if (AppState.deviceHealth >= 80) {
        healthStatus = 'Excellent';
        healthDesc = 'Your device is running great!';
        elements.statusLabel.textContent = 'Excellent';
    } else if (AppState.deviceHealth >= 60) {
        healthStatus = 'Good';
        healthDesc = 'Your device is performing well';
        elements.statusLabel.textContent = 'Good';
    } else if (AppState.deviceHealth >= 40) {
        healthStatus = 'Fair';
        healthDesc = 'Consider cleaning your device';
        elements.statusLabel.textContent = 'Fair';
    } else {
        healthStatus = 'Needs Attention';
        healthDesc = 'Your device needs optimization';
        elements.statusLabel.textContent = 'Poor';
    }

    elements.deviceHealthTitle.textContent = `Device Health: ${healthStatus}`;
    elements.deviceHealthDesc.textContent = healthDesc;

    // Update cache size
    elements.cacheSize.textContent = Utils.formatBytes(AppState.cacheSize);

    // Update memory
    elements.memoryUsage.textContent = `${AppState.memoryUsage}% used`;

    // Update storage
    const storagePercent = Math.round((AppState.storageUsed / AppState.storageTotal) * 100);
    elements.storageUsed.textContent = Utils.formatBytes(AppState.storageUsed);
    elements.storageTotal.textContent = Utils.formatBytes(AppState.storageTotal);
    elements.storagePercent.textContent = storagePercent + '%';
    elements.storageBarFill.style.width = storagePercent + '%';

    // Storage breakdown (simulated)
    const appsSize = AppState.storageUsed * 0.35;
    const mediaSize = AppState.storageUsed * 0.40;
    const cacheSize = AppState.cacheSize;
    const otherSize = AppState.storageUsed - appsSize - mediaSize - cacheSize;

    elements.storageApps.textContent = Utils.formatBytes(appsSize);
    elements.storageMedia.textContent = Utils.formatBytes(mediaSize);
    elements.storageCache.textContent = Utils.formatBytes(cacheSize);
    elements.storageOther.textContent = Utils.formatBytes(Math.max(0, otherSize));

    // Update system info
    elements.cpuUsage.textContent = AppState.cpuUsage + '%';
    elements.ramUsage.textContent = AppState.ramUsage + '%';

    // Update speed status
    elements.speedStatus.textContent = AppState.cpuUsage < 30 ? 'Optimized' : 'Ready';
}

// Update battery and network
async function updateRealTimeMetrics() {
    // Battery
    const batteryInfo = await DeviceMetrics.getBatteryInfo();
    if (batteryInfo.level !== 'N/A') {
        elements.batteryLevel.textContent = `${batteryInfo.level}%${batteryInfo.charging ? ' (charging)' : ''}`;
    } else {
        elements.batteryLevel.textContent = 'N/A';
    }

    // Network
    const networkInfo = DeviceMetrics.getNetworkInfo();
    elements.networkStatus.textContent = networkInfo.type;

    // Temperature (simulated)
    elements.deviceTemp.textContent = Utils.randomBetween(35, 42) + '°C';
}

// Event Listeners
function initEventListeners() {
    // Settings button
    elements.settingsBtn.addEventListener('click', () => {
        showModal(elements.settingsModal);
    });

    // Close settings
    elements.closeSettings.addEventListener('click', () => {
        hideModal(elements.settingsModal);
    });

    // Settings modal overlay click
    elements.settingsModal.querySelector('.modal-overlay').addEventListener('click', () => {
        hideModal(elements.settingsModal);
    });

    // Result close button
    elements.resultCloseBtn.addEventListener('click', () => {
        hideModal(elements.resultModal);
    });

    // Result modal overlay click
    elements.resultModal.querySelector('.modal-overlay').addEventListener('click', () => {
        hideModal(elements.resultModal);
    });

    // Action buttons
    elements.cleanCacheBtn.addEventListener('click', () => Cleaner.cleanCache());
    elements.optimizeMemoryBtn.addEventListener('click', () => Cleaner.optimizeMemory());
    elements.boostSpeedBtn.addEventListener('click', () => Cleaner.boostSpeed());
    elements.batterySaverBtn.addEventListener('click', () => Cleaner.saveBattery());
    elements.deepCleanBtn.addEventListener('click', () => Cleaner.deepClean());

    // Navigation
    elements.navItems.forEach(item => {
        item.addEventListener('click', () => {
            elements.navItems.forEach(nav => nav.classList.remove('active'));
            item.classList.add('active');

            const tab = item.dataset.tab;
            if (tab !== 'home') {
                Toast.show(`${tab.charAt(0).toUpperCase() + tab.slice(1)} feature coming soon!`, 'info');
            }
        });
    });

    // Settings toggles
    elements.darkModeToggle.addEventListener('change', (e) => {
        AppState.settings.darkMode = e.target.checked;
        document.body.classList.toggle('light-theme', !e.target.checked);
        saveSettings();
    });

    elements.notificationsToggle.addEventListener('change', (e) => {
        AppState.settings.notifications = e.target.checked;
        saveSettings();
        if (e.target.checked) {
            Toast.show('Notifications enabled', 'success');
        }
    });

    elements.autoCleanToggle.addEventListener('change', (e) => {
        AppState.settings.autoClean = e.target.checked;
        saveSettings();
        if (e.target.checked) {
            Toast.show('Auto-clean on launch enabled', 'success');
        }
    });

    elements.cleanImagesToggle.addEventListener('change', (e) => {
        AppState.settings.cleanImages = e.target.checked;
        saveSettings();
    });

    elements.cleanTempToggle.addEventListener('change', (e) => {
        AppState.settings.cleanTemp = e.target.checked;
        saveSettings();
    });

    // Online/offline status
    window.addEventListener('online', () => {
        AppState.isOnline = true;
        Toast.show('Back online', 'success');
        updateRealTimeMetrics();
    });

    window.addEventListener('offline', () => {
        AppState.isOnline = false;
        Toast.show('You are offline', 'warning');
        elements.networkStatus.textContent = 'Offline';
    });
}

// Settings persistence
function saveSettings() {
    localStorage.setItem('appSettings', JSON.stringify(AppState.settings));
}

function loadSettings() {
    const saved = localStorage.getItem('appSettings');
    if (saved) {
        AppState.settings = { ...AppState.settings, ...JSON.parse(saved) };
    }

    // Apply saved settings
    elements.darkModeToggle.checked = AppState.settings.darkMode;
    elements.notificationsToggle.checked = AppState.settings.notifications;
    elements.autoCleanToggle.checked = AppState.settings.autoClean;
    elements.cleanImagesToggle.checked = AppState.settings.cleanImages;
    elements.cleanTempToggle.checked = AppState.settings.cleanTemp;

    if (!AppState.settings.darkMode) {
        document.body.classList.add('light-theme');
    }
}

function loadHistory() {
    const saved = localStorage.getItem('cleaningHistory');
    if (saved) {
        AppState.cleaningHistory = JSON.parse(saved);
    }
}

// Initialize App
async function initApp() {
    // Load saved data
    loadSettings();
    loadHistory();

    // Scan device
    await DeviceMetrics.scan();
    await updateRealTimeMetrics();

    // Update UI
    updateUI();

    // Hide splash screen
    elements.splashScreen.classList.add('fade-out');
    await Utils.delay(500);
    elements.splashScreen.classList.add('hidden');
    elements.app.classList.remove('hidden');

    // Show welcome toast
    Toast.show('Welcome to Craig-O-Clean!', 'success');

    // Auto-clean if enabled
    if (AppState.settings.autoClean) {
        await Utils.delay(1000);
        Cleaner.cleanCache();
    }

    // Set up periodic metric updates
    setInterval(updateRealTimeMetrics, 30000);
}

// Initialize event listeners and start app
initEventListeners();
initApp();
