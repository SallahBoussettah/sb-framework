let questions = [];
let currentQuestion = 0;
let selectedAnswers = [];  // 1-indexed answer per question

// ============================================================================
// NUI MESSAGE HANDLER
// ============================================================================

window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.action) {
        case 'openExam':
            openExam(data);
            break;
        case 'showResult':
            showResult(data);
            break;
        case 'showDrivingHUD':
            showDrivingHUD(data);
            break;
        case 'updateHUD':
            updateHUD(data);
            break;
        case 'hideDrivingHUD':
            hideDrivingHUD();
            break;
        case 'showLicense':
            showLicense(data);
            break;
        case 'convertBase64':
            convertToBase64(data);
            break;
        case 'close':
            closeAll();
            break;
    }
});

// ============================================================================
// BASE64 CONVERSION (sb_id pattern)
// ============================================================================

function convertToBase64(data) {
    const imgUrl = data.imgUrl;
    const handle = data.handle;

    if (!imgUrl) {
        fetch('https://sb_dmv/base64Result', {
            method: 'POST',
            body: JSON.stringify({ base64: '', handle: handle })
        });
        return;
    }

    const xhr = new XMLHttpRequest();
    xhr.onload = function () {
        const reader = new FileReader();
        reader.onloadend = function () {
            fetch('https://sb_dmv/base64Result', {
                method: 'POST',
                body: JSON.stringify({ base64: reader.result, handle: handle })
            });
        };
        reader.readAsDataURL(xhr.response);
    };
    xhr.onerror = function () {
        fetch('https://sb_dmv/base64Result', {
            method: 'POST',
            body: JSON.stringify({ base64: '', handle: handle })
        });
    };
    xhr.open('GET', imgUrl);
    xhr.responseType = 'blob';
    xhr.send();
}

// ============================================================================
// THEORY EXAM
// ============================================================================

function openExam(data) {
    closeAll();
    questions = data.questions || [];
    currentQuestion = 0;
    selectedAnswers = new Array(questions.length).fill(0);

    renderQuestion();
    document.getElementById('exam-container').classList.remove('hidden');
}

function renderQuestion() {
    if (currentQuestion >= questions.length) return;

    const q = questions[currentQuestion];
    document.getElementById('exam-counter').textContent = (currentQuestion + 1) + ' / ' + questions.length;
    document.getElementById('question-text').textContent = q.question;

    const optionsList = document.getElementById('options-list');
    optionsList.innerHTML = '';

    q.options.forEach((opt, idx) => {
        const btn = document.createElement('button');
        btn.className = 'option-btn';
        btn.textContent = opt;
        if (selectedAnswers[currentQuestion] === idx + 1) {
            btn.classList.add('selected');
        }
        btn.addEventListener('click', () => {
            selectedAnswers[currentQuestion] = idx + 1;
            // Update selection UI
            optionsList.querySelectorAll('.option-btn').forEach(b => b.classList.remove('selected'));
            btn.classList.add('selected');
            // Enable next button
            document.getElementById('btn-exam-next').disabled = false;
        });
        optionsList.appendChild(btn);
    });

    // Update button text
    const nextBtn = document.getElementById('btn-exam-next');
    nextBtn.textContent = (currentQuestion === questions.length - 1) ? 'Submit' : 'Next';
    nextBtn.disabled = selectedAnswers[currentQuestion] === 0;
}

// Next / Submit button
document.getElementById('btn-exam-next').addEventListener('click', () => {
    if (selectedAnswers[currentQuestion] === 0) return;

    if (currentQuestion < questions.length - 1) {
        currentQuestion++;
        renderQuestion();
    } else {
        // Submit all answers
        fetch('https://sb_dmv/submitAnswers', {
            method: 'POST',
            body: JSON.stringify({ answers: selectedAnswers })
        });
        document.getElementById('exam-container').classList.add('hidden');
    }
});

// Cancel button
document.getElementById('btn-exam-cancel').addEventListener('click', () => {
    fetch('https://sb_dmv/close', {
        method: 'POST',
        body: JSON.stringify({})
    });
    closeAll();
});

// ============================================================================
// RESULT SCREEN
// ============================================================================

function showResult(data) {
    closeAll();

    const iconEl = document.getElementById('result-icon');
    const titleEl = document.getElementById('result-title');
    const subtitleEl = document.getElementById('result-subtitle');
    const messageEl = document.getElementById('result-message');

    if (data.passed) {
        iconEl.className = 'result-icon pass';
        iconEl.innerHTML = '<i class="fa-solid fa-circle-check"></i>';
        titleEl.textContent = 'PASSED';
        titleEl.style.color = 'var(--success)';
    } else {
        iconEl.className = 'result-icon fail';
        iconEl.innerHTML = '<i class="fa-solid fa-circle-xmark"></i>';
        titleEl.textContent = 'FAILED';
        titleEl.style.color = 'var(--negative)';
    }

    if (data.resultType === 'theory') {
        subtitleEl.textContent = 'Score: ' + data.score + ' / 10';
        if (data.passed) {
            messageEl.textContent = data.customMessage || 'You may now proceed to the parking test. Speak with the instructor.';
        } else {
            messageEl.textContent = data.customMessage || 'You need at least 7/10 to pass. Please wait before retrying.';
        }
    } else if (data.resultType === 'practical') {
        subtitleEl.textContent = 'Penalty Points: ' + data.penalties + ' / ' + data.maxPenalties;
        if (data.passed) {
            messageEl.textContent = data.customMessage || 'Test passed! Speak with the instructor for your next test.';
        } else {
            messageEl.textContent = data.customMessage || 'Too many penalty points. Please wait before retrying.';
        }
    }

    document.getElementById('result-container').classList.remove('hidden');
}

// Result close button
document.getElementById('btn-result-close').addEventListener('click', () => {
    fetch('https://sb_dmv/close', {
        method: 'POST',
        body: JSON.stringify({})
    });
    closeAll();
});

// ============================================================================
// DRIVING HUD
// ============================================================================

function showDrivingHUD(data) {
    document.getElementById('driving-hud').classList.remove('hidden');
    updateHUD(data);
}

function updateHUD(data) {
    const speedEl = document.getElementById('hud-speed');
    const limitSection = document.getElementById('hud-limit-section');
    const limitValue = document.getElementById('hud-limit-value');
    const penaltiesEl = document.getElementById('hud-penalties');
    const checkpointEl = document.getElementById('hud-checkpoint');
    const phaseEl = document.getElementById('hud-phase');

    const speed = data.speed || 0;
    const limit = data.speedLimit || 0;

    speedEl.textContent = speed;

    if (limit > 0) {
        limitSection.classList.remove('no-limit');
        limitValue.textContent = limit;
        speedEl.classList.toggle('over-limit', speed > limit);
    } else {
        limitSection.classList.add('no-limit');
        limitValue.textContent = '--';
        speedEl.classList.remove('over-limit');
    }

    const penalties = data.penalties || 0;
    const maxPenalties = data.maxPenalties || 30;
    penaltiesEl.textContent = penalties + ' / ' + maxPenalties;
    penaltiesEl.classList.toggle('danger', penalties > maxPenalties * 0.6);

    const cp = data.checkpoint || 0;
    const total = data.totalCheckpoints || 0;
    checkpointEl.textContent = cp + ' / ' + total;

    if (data.phase) {
        phaseEl.textContent = data.phase;
    }
}

function hideDrivingHUD() {
    document.getElementById('driving-hud').classList.add('hidden');
}

// ============================================================================
// LICENSE CARD
// ============================================================================

function showLicense(data) {
    closeAll();

    const info = data.data;
    if (!info) return;

    document.getElementById('license-number').textContent = info.license_number || info.citizenid || '---';
    document.getElementById('license-lastname').textContent = (info.lastname || '---').toUpperCase();
    document.getElementById('license-firstname').textContent = (info.firstname || '---').toUpperCase();
    document.getElementById('license-dob').textContent = info.dob || '---';
    document.getElementById('license-issued').textContent = info.issued || '---';
    document.getElementById('license-class').textContent = info.class || 'C';

    // Signature
    const sigFirst = info.firstname || '';
    const sigLast = info.lastname || '';
    document.getElementById('license-signature').textContent = sigFirst.toLowerCase() + ' ' + sigLast.toLowerCase();

    // Photo
    const photoFrame = document.getElementById('license-photo');
    const liveUrl = data.liveMugshotUrl || '';
    const stored = data.mugshot || '';

    if (liveUrl) {
        photoFrame.innerHTML = '<img src="' + liveUrl + '" alt="Photo" />';
    } else if (stored && stored.startsWith('data:')) {
        photoFrame.innerHTML = '<img src="' + stored + '" alt="Photo" />';
    } else {
        photoFrame.innerHTML = '<i class="fa-solid fa-user photo-placeholder"></i>';
    }

    document.getElementById('license-container').classList.remove('hidden');
}

// ============================================================================
// CLOSE
// ============================================================================

function closeAll() {
    document.getElementById('exam-container').classList.add('hidden');
    document.getElementById('result-container').classList.add('hidden');
    document.getElementById('license-container').classList.add('hidden');
    // Note: driving HUD is NOT closed by closeAll - it's controlled separately
}

// Escape key
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        // Don't close driving HUD with escape
        const examVisible = !document.getElementById('exam-container').classList.contains('hidden');
        const resultVisible = !document.getElementById('result-container').classList.contains('hidden');
        const licenseVisible = !document.getElementById('license-container').classList.contains('hidden');

        if (examVisible || resultVisible || licenseVisible) {
            fetch('https://sb_dmv/close', {
                method: 'POST',
                body: JSON.stringify({})
            });
            closeAll();
        }
    }
});
