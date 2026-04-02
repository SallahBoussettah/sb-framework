/*
    Everyday Chaos RP - Death Screen
    Author: Salah Eddine Boussettah
    Vanilla JS (no dependencies)
*/

let currentTimer = 0;
let timerInterval = null;
let isDead = false;

const screen = document.getElementById('death-screen');
const timerEl = document.getElementById('timer');
const killerSection = document.getElementById('killer-section');
const killerName = document.getElementById('killer-name');
const killerLabel = document.getElementById('killer-label');
const titleEl = document.getElementById('title');
const subtitleEl = document.getElementById('subtitle');
const btnEmergency = document.getElementById('btn-emergency');
const btnEmergencyText = document.getElementById('btn-emergency-text');
const btnRespawn = document.getElementById('btn-respawn');
const respawnInfo = document.getElementById('respawn-info');

// Format seconds to MM:SS
function formatTime(seconds) {
    if (seconds < 0) seconds = 0;
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return String(mins).padStart(2, '0') + ':' + String(secs).padStart(2, '0');
}

// Show death screen
function show(data) {
    isDead = true;
    currentTimer = data.timer || 0;

    // Update texts
    if (data.texts) {
        titleEl.textContent = data.texts.Title || 'YOU ARE DYING';
        subtitleEl.textContent = data.texts.Subtitle || 'BLEEDOUT IMMINENT';
        killerLabel.textContent = data.texts.KilledBy || 'KILLED BY';
        btnEmergencyText.textContent = data.texts.CallEmergency || 'CALL EMERGENCY';
    }

    // Update killer
    if (data.killer) {
        killerName.textContent = data.killer;
        killerSection.classList.add('visible');
    } else {
        killerSection.classList.remove('visible');
    }

    // Update timer display
    timerEl.textContent = formatTime(currentTimer);

    // Reset buttons
    btnEmergency.classList.remove('disabled');
    btnRespawn.style.display = 'none';
    btnRespawn.classList.remove('disabled');
    respawnInfo.textContent = 'You will be able to respawn when the timer expires';

    // Show screen
    screen.style.display = 'block';
    requestAnimationFrame(() => {
        screen.classList.add('visible');
    });

    // Start countdown
    clearInterval(timerInterval);
    timerInterval = setInterval(tick, 1000);
}

// Hide death screen
function hide() {
    isDead = false;
    clearInterval(timerInterval);

    screen.classList.remove('visible');
    setTimeout(() => {
        screen.style.display = 'none';
        // Reset animations by removing and re-adding content
        killerSection.classList.remove('visible');
    }, 800);
}

// Timer tick
function tick() {
    if (!isDead) {
        clearInterval(timerInterval);
        return;
    }

    currentTimer--;
    timerEl.textContent = formatTime(currentTimer);

    if (currentTimer <= 0) {
        clearInterval(timerInterval);
        // Show respawn button
        btnRespawn.style.display = 'flex';
        respawnInfo.textContent = 'Hospital bill: $500';
        // Notify client timer expired
        fetch(`https://${GetParentResourceName()}/timerExpired`, {
            method: 'POST',
            body: JSON.stringify({})
        });
    }
}

// Button handler
btnEmergency.addEventListener('click', function() {
    if (btnEmergency.classList.contains('disabled')) return;
    btnEmergency.classList.add('disabled');

    fetch(`https://${GetParentResourceName()}/callEmergency`, {
        method: 'POST',
        body: JSON.stringify({})
    });
});

// Respawn button handler
btnRespawn.addEventListener('click', function() {
    if (btnRespawn.classList.contains('disabled')) return;
    btnRespawn.classList.add('disabled');

    fetch(`https://${GetParentResourceName()}/respawn`, {
        method: 'POST',
        body: JSON.stringify({})
    });
});

// NUI message handler
window.addEventListener('message', function(event) {
    const data = event.data;

    switch (data.action) {
        case 'show':
            show(data);
            break;

        case 'hide':
            hide();
            break;

        case 'setKiller':
            if (data.killer) {
                killerName.textContent = data.killer;
                killerSection.classList.add('visible');
            }
            break;
    }
});

// Close on Escape (safety fallback)
document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape' && isDead) {
        // Don't allow escape to close death screen
        e.preventDefault();
    }
});
