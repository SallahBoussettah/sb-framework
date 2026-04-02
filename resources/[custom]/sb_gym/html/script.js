/*
    Everyday Chaos RP - Gym UI Script
    Author: Salah Eddine Boussettah
*/

const skillsPanel = document.getElementById('skillsPanel');
const exerciseMenu = document.getElementById('exerciseMenu');
const exerciseList = document.getElementById('exerciseList');
const buffIndicator = document.getElementById('buffIndicator');
const buffTimer = document.getElementById('buffTimer');

let buffInterval = null;
let buffEndTime = 0;

// ============================================
// NUI MESSAGE HANDLER
// ============================================

window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.action) {
        case 'openSkillsPanel':
            openSkillsPanel(data.skills, data.hasBuff, data.buffTimeLeft);
            break;

        case 'openExerciseMenu':
            openExerciseMenu(data.exercises);
            break;

        case 'close':
            closeAllPanels();
            break;
    }
});

// ============================================
// SKILLS PANEL
// ============================================

function openSkillsPanel(skills, hasBuff, buffTimeLeft) {
    closeAllPanels();

    // Update skill bars
    updateSkillBar('strength', skills.strength);
    updateSkillBar('stamina', skills.stamina);
    updateSkillBar('lung', skills.lung);

    // Handle buff indicator
    if (hasBuff && buffTimeLeft > 0) {
        buffIndicator.classList.remove('hidden');
        buffEndTime = Date.now() + buffTimeLeft;
        startBuffTimer();
    } else {
        buffIndicator.classList.add('hidden');
        stopBuffTimer();
    }

    skillsPanel.classList.remove('hidden');
}

function updateSkillBar(skillName, value) {
    const bar = document.getElementById(skillName + 'Bar');
    const valueSpan = document.getElementById(skillName + 'Value');

    if (bar && valueSpan) {
        bar.style.width = value + '%';
        valueSpan.textContent = Math.floor(value);
    }
}

function startBuffTimer() {
    stopBuffTimer();

    buffInterval = setInterval(() => {
        const remaining = Math.max(0, buffEndTime - Date.now());

        if (remaining <= 0) {
            stopBuffTimer();
            buffIndicator.classList.add('hidden');
            return;
        }

        const minutes = Math.floor(remaining / 60000);
        const seconds = Math.floor((remaining % 60000) / 1000);
        buffTimer.textContent = `${minutes}:${seconds.toString().padStart(2, '0')}`;
    }, 1000);
}

function stopBuffTimer() {
    if (buffInterval) {
        clearInterval(buffInterval);
        buffInterval = null;
    }
}

// ============================================
// EXERCISE MENU
// ============================================

function openExerciseMenu(exercises) {
    closeAllPanels();
    exerciseList.innerHTML = '';

    // Icon mapping for exercises
    const icons = {
        pushups: 'fa-person-praying',
        situps: 'fa-person-falling-burst',
        yoga: 'fa-om'
    };

    exercises.forEach(exercise => {
        const item = document.createElement('div');
        item.className = 'exercise-item';
        item.onclick = () => startExercise(exercise.id);

        const icon = icons[exercise.id] || 'fa-dumbbell';
        const durationSec = Math.floor(exercise.duration / 1000);

        item.innerHTML = `
            <div class="exercise-icon">
                <i class="fas ${icon}"></i>
            </div>
            <div class="exercise-info">
                <div class="exercise-label">${exercise.label}</div>
                <div class="exercise-meta">
                    <span class="skill-badge ${exercise.skill}">${exercise.skill}</span>
                    <span><i class="fas fa-clock"></i> ${durationSec}s</span>
                </div>
            </div>
            <i class="fas fa-chevron-right exercise-arrow"></i>
        `;

        exerciseList.appendChild(item);
    });

    exerciseMenu.classList.remove('hidden');
}

function startExercise(exerciseId) {
    fetch(`https://${GetParentResourceName()}/startExercise`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ exerciseId: exerciseId })
    });
}

// ============================================
// CLOSE UI
// ============================================

function closeAllPanels() {
    skillsPanel.classList.add('hidden');
    exerciseMenu.classList.add('hidden');
    stopBuffTimer();
}

function closeUI() {
    closeAllPanels();
    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

// ============================================
// KEYBOARD HANDLER
// ============================================

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        closeUI();
    }
});
