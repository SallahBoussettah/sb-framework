/*
    Everyday Chaos RP - Alert System NUI
    Author: Salah Eddine Boussettah

    Handles alert display, animations, expiry timers, and NUI callbacks.
*/

// ============================================================================
// SVG ICONS (inline — no CDN dependency in FiveM NUI)
// ============================================================================

const ICONS = {
    'shield': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z"/></svg>',
    'heart-pulse': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19.5 12.572l-7.5 7.428l-7.5-7.428A5 5 0 0 1 12 6.006a5 5 0 0 1 7.5 6.572"/><path d="M5 12h2l2-3 3 6 2-3h2"/></svg>',
    'wrench': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14.7 6.3a1 1 0 0 0 0 1.4l1.6 1.6a1 1 0 0 0 1.4 0l3.77-3.77a6 6 0 0 1-7.94 7.94l-6.91 6.91a2.12 2.12 0 0 1-3-3l6.91-6.91a6 6 0 0 1 7.94-7.94l-3.76 3.76z"/></svg>',
    'alert-triangle': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3"/><path d="M12 9v4"/><path d="M12 17h.01"/></svg>',
    'bell': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 8a6 6 0 0 1 12 0c0 7 3 9 3 9H3s3-2 3-9"/><path d="M10.3 21a1.94 1.94 0 0 0 3.4 0"/></svg>',
    'map-pin': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 10c0 4.993-5.539 10.193-7.399 11.799a1 1 0 0 1-1.202 0C9.539 20.193 4 14.993 4 10a8 8 0 0 1 16 0"/><circle cx="12" cy="10" r="3"/></svg>',
    'user': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>',
    'users': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>',
    'check': '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>',
};

function getIcon(name) {
    return ICONS[name] || ICONS['bell'];
}

// ============================================================================
// STATE
// ============================================================================

const activeAlerts = {};    // { alertId: { data, element, timer } }
const MAX_VISIBLE = 3;

// ============================================================================
// TIME FORMATTING
// ============================================================================

function formatTime(timestamp) {
    const now = Math.floor(Date.now() / 1000);
    const diff = now - timestamp;

    if (diff < 10) return 'NOW';
    if (diff < 60) return diff + 's';
    if (diff < 3600) return Math.floor(diff / 60) + 'm';
    return Math.floor(diff / 3600) + 'h';
}

function updateTimestamps() {
    for (const id in activeAlerts) {
        const alert = activeAlerts[id];
        const timeEl = alert.element.querySelector('.alert-time');
        if (timeEl) {
            timeEl.textContent = formatTime(alert.data.timestamp);
        }
    }
}

// Update timestamps every 10 seconds
setInterval(updateTimestamps, 10000);

// ============================================================================
// CREATE ALERT
// ============================================================================

function createAlert(data) {
    const container = document.getElementById('alertBox');
    if (!container) return;

    // Remove if already exists (update)
    if (activeAlerts[data.id]) {
        removeAlert(data.id, false);
    }

    // Enforce max visible
    const alertIds = Object.keys(activeAlerts);
    if (alertIds.length >= MAX_VISIBLE) {
        // Remove oldest
        const oldestId = alertIds[0];
        removeAlert(oldestId, true);
    }

    // Build HTML
    const card = document.createElement('div');
    card.className = 'alert-card';
    card.setAttribute('data-type', data.type || 'general');
    card.setAttribute('data-id', data.id);

    if (data.isPanic) {
        card.setAttribute('data-type', 'panic');
    }

    const iconSvg = getIcon(data.icon || 'bell');
    const responderText = data.responderCount > 0
        ? `<div class="alert-responders">${data.responderCount} responding</div>`
        : '';

    card.innerHTML = `
        <div class="color-strip"></div>
        <div class="alert-header">
            <span class="alert-header-icon">${iconSvg}</span>
            <h2>${escapeHtml(data.header || 'Dispatch')}</h2>
            <span class="alert-time">NOW</span>
        </div>
        <div class="alert-body">
            <div class="alert-title">${escapeHtml(data.title || 'Alert')}</div>
            ${data.location ? `<div class="alert-info-row">${getIcon('map-pin')} ${escapeHtml(data.location)}</div>` : ''}
            ${data.caller ? `<div class="alert-info-row">${getIcon('user')} ${escapeHtml(data.caller)}</div>` : ''}
            ${data.description ? `<div class="alert-description">${escapeHtml(data.description)}</div>` : ''}
            ${responderText}
        </div>
        <div class="alert-footer">
            <div class="key-hint"><span class="key-btn">${escapeHtml(data.gpsKey || 'H')}</span> GPS</div>
            <div class="key-hint"><span class="key-btn">${escapeHtml(data.acceptKey || 'Y')}</span> Accept</div>
        </div>
        <div class="alert-accepted-badge">${getIcon('check')} RESPONDING</div>
        <div class="progress-bar" data-progress="true"></div>
    `;

    // Add to top of container
    container.insertBefore(card, container.firstChild);

    // Start expiry progress bar
    const duration = (data.duration || 30) * 1000;
    const progressBar = card.querySelector('[data-progress]');
    if (progressBar) {
        // Start at 100%, animate to 0%
        progressBar.style.width = '100%';
        progressBar.style.transitionDuration = duration + 'ms';
        requestAnimationFrame(() => {
            requestAnimationFrame(() => {
                progressBar.style.width = '0%';
            });
        });
    }

    // Auto-remove after duration
    const timer = setTimeout(() => {
        removeAlert(data.id, true);
        // Notify Lua that alert expired from NUI
        fetch(`https://${GetParentResourceName()}/alertExpired`, {
            method: 'POST',
            body: JSON.stringify({ id: data.id })
        });
    }, duration);

    activeAlerts[data.id] = {
        data: data,
        element: card,
        timer: timer,
    };
}

// ============================================================================
// REMOVE ALERT
// ============================================================================

function removeAlert(alertId, animate) {
    const alert = activeAlerts[alertId];
    if (!alert) return;

    clearTimeout(alert.timer);

    if (animate) {
        alert.element.classList.add('removing');
        setTimeout(() => {
            if (alert.element.parentNode) {
                alert.element.parentNode.removeChild(alert.element);
            }
            delete activeAlerts[alertId];
        }, 300);
    } else {
        if (alert.element.parentNode) {
            alert.element.parentNode.removeChild(alert.element);
        }
        delete activeAlerts[alertId];
    }
}

// ============================================================================
// UPDATE ALERT
// ============================================================================

function markAccepted(alertId) {
    const alert = activeAlerts[alertId];
    if (!alert) return;

    alert.element.classList.add('accepted');

    // Auto-dismiss after 2 seconds
    setTimeout(() => {
        removeAlert(alertId, true);
    }, 2000);
}

function updateResponders(alertId, count) {
    const alert = activeAlerts[alertId];
    if (!alert) return;

    let responderEl = alert.element.querySelector('.alert-responders');
    if (count > 0) {
        if (!responderEl) {
            responderEl = document.createElement('div');
            responderEl.className = 'alert-responders';
            const body = alert.element.querySelector('.alert-body');
            if (body) body.appendChild(responderEl);
        }
        responderEl.textContent = count + ' responding';
    }
}

// ============================================================================
// UTILITY
// ============================================================================

function escapeHtml(str) {
    if (!str) return '';
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
}

// ============================================================================
// FiveM NUI MESSAGE HANDLER
// ============================================================================

window.addEventListener('message', function(event) {
    const msg = event.data;

    switch (msg.action) {
        case 'newAlert':
            createAlert(msg.data);
            break;

        case 'removeAlert':
            removeAlert(msg.data.id, true);
            break;

        case 'alertAccepted':
            markAccepted(msg.data.id);
            break;

        case 'updateResponders':
            updateResponders(msg.data.id, msg.data.count);
            break;
    }
});

// ============================================================================
// INIT — Tell Lua we're ready
// ============================================================================

window.addEventListener('DOMContentLoaded', function() {
    fetch(`https://${GetParentResourceName()}/uiReady`, {
        method: 'POST',
        body: JSON.stringify({})
    });
});
