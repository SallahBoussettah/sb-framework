// ============================================================================
// SB Notify - Premium Notification System
// Author: Salah Eddine Boussettah
// ============================================================================

const container = document.getElementById('notification-container');
let notifications = [];
let maxNotifications = 3;
let recentMessages = {}; // Deduplication tracking

// ============================================================================
// ICONS (SVG)
// ============================================================================
const icons = {
    success: `<svg viewBox="0 0 24 24"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41L9 16.17z"/></svg>`,
    error: `<svg viewBox="0 0 24 24"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12 19 6.41z"/></svg>`,
    warning: `<svg viewBox="0 0 24 24"><path d="M12 2L1 21h22L12 2zm0 3.83L19.53 19H4.47L12 5.83zM11 10v4h2v-4h-2zm0 6v2h2v-2h-2z"/></svg>`,
    info: `<svg viewBox="0 0 24 24"><path d="M11 7h2v2h-2zm0 4h2v6h-2zm1-9C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.41 0-8-3.59-8-8s3.59-8 8-8 8 3.59 8 8-3.59 8-8 8z"/></svg>`,
    primary: `<svg viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/></svg>`,
    close: `<svg viewBox="0 0 24 24"><path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12 19 6.41z"/></svg>`
};

// ============================================================================
// TITLES
// ============================================================================
const titles = {
    success: 'Success',
    error: 'Error',
    warning: 'Warning',
    info: 'Information',
    primary: 'Notice'
};

// ============================================================================
// CREATE NOTIFICATION
// ============================================================================
function createNotification(message, type, duration) {
    // Deduplication: skip if same message was shown recently
    const dedupKey = `${message}_${type}`;
    const now = Date.now();
    if (recentMessages[dedupKey] && (now - recentMessages[dedupKey]) < 1500) {
        return null; // Skip duplicate
    }
    recentMessages[dedupKey] = now;

    // Clean old dedup entries
    for (const key in recentMessages) {
        if (now - recentMessages[key] > 5000) {
            delete recentMessages[key];
        }
    }

    // Remove oldest if at max
    if (notifications.length >= maxNotifications) {
        removeNotification(notifications[0].id);
    }

    const id = Date.now() + Math.random();
    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    notification.id = `notify-${id}`;

    notification.innerHTML = `
        <div class="notification-icon">
            ${icons[type] || icons.primary}
        </div>
        <div class="notification-content">
            <div class="notification-title">${titles[type] || titles.primary}</div>
            <div class="notification-message">${escapeHtml(message)}</div>
        </div>
        <button class="notification-close" aria-label="Close">
            ${icons.close}
        </button>
        <div class="notification-progress-container">
            <div class="notification-progress"></div>
        </div>
    `;

    container.appendChild(notification);

    // Animate progress bar
    const progressBar = notification.querySelector('.notification-progress');
    progressBar.style.transition = `width ${duration}ms linear`;
    requestAnimationFrame(() => {
        requestAnimationFrame(() => {
            progressBar.style.width = '0%';
        });
    });

    // Store notification
    const notificationData = {
        id: id,
        element: notification,
        timeout: setTimeout(() => removeNotification(id), duration)
    };
    notifications.push(notificationData);

    // Close button click
    const closeBtn = notification.querySelector('.notification-close');
    closeBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        removeNotification(id);
    });

    // Click anywhere to dismiss
    notification.addEventListener('click', () => {
        removeNotification(id);
    });

    return id;
}

// ============================================================================
// REMOVE NOTIFICATION
// ============================================================================
function removeNotification(id) {
    const index = notifications.findIndex(n => n.id === id);
    if (index === -1) return;

    const notification = notifications[index];
    clearTimeout(notification.timeout);

    notification.element.classList.add('removing');

    setTimeout(() => {
        if (notification.element.parentNode) {
            notification.element.parentNode.removeChild(notification.element);
        }
        notifications = notifications.filter(n => n.id !== id);
    }, 300);
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function setPosition(position) {
    container.className = position;
}

// ============================================================================
// NUI MESSAGE HANDLER
// ============================================================================
window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.action) {
        case 'showNotification':
            if (data.position) {
                setPosition(data.position);
            }
            if (data.maxNotifications) {
                maxNotifications = data.maxNotifications;
            }
            createNotification(data.message, data.type || 'primary', data.duration || 5000);
            break;

        case 'hideAll':
            notifications.forEach(n => removeNotification(n.id));
            break;

        case 'setPosition':
            setPosition(data.position);
            break;
    }
});

// ============================================================================
// NOTIFY UI READY
// ============================================================================
fetch(`https://${GetParentResourceName()}/uiReady`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({})
});
