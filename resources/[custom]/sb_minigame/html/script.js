// sb_minigame - Standalone Minigame Engine
// 3 game types: timing, sequence, precision
// Colors follow UI_DESIGN_SYSTEM.md

(() => {
    'use strict';

    // Design system colors (for canvas rendering)
    const COLORS = {
        accent:      '#ff6b35',
        accentGlow:  'rgba(255, 107, 53, 0.4)',
        accentMuted: 'rgba(255, 107, 53, 0.15)',
        success:      '#22c55e',
        successMuted: 'rgba(34, 197, 94, 0.15)',
        error:        '#ef4444',
        errorMuted:   'rgba(239, 68, 68, 0.15)',
        bgPrimary:    '#0a0a0a',
        bgSecondary:  '#141414',
        border:       '#2a2a2a',
        borderHover:  '#3a3a3a',
        textSecondary:'#888888',
        textTertiary: '#555555',
    };

    // ===== DIFFICULTY PRESETS =====
    const DIFFICULTY = {
        timing: {
            1: { speed: 1.5,  zoneSize: 0.30 },
            2: { speed: 2.5,  zoneSize: 0.24 },
            3: { speed: 3.5,  zoneSize: 0.18 },
            4: { speed: 5.0,  zoneSize: 0.13 },
            5: { speed: 7.0,  zoneSize: 0.09 },
        },
        sequence: {
            1: { length: 3, displayTime: 1200 },
            2: { length: 4, displayTime: 1000 },
            3: { length: 5, displayTime: 800  },
            4: { length: 6, displayTime: 650  },
            5: { length: 8, displayTime: 500  },
        },
        precision: {
            1: { circleSize: 80, speed: 0.8, requiredTime: 2.0 },
            2: { circleSize: 65, speed: 1.2, requiredTime: 2.5 },
            3: { circleSize: 50, speed: 1.8, requiredTime: 3.0 },
            4: { circleSize: 38, speed: 2.5, requiredTime: 3.5 },
            5: { circleSize: 28, speed: 3.2, requiredTime: 4.0 },
        }
    };

    const KEYS = ['W', 'A', 'S', 'D'];

    // ===== STATE =====
    let state = {
        active: false,
        type: null,
        difficulty: 3,
        rounds: 3,
        currentRound: 0,
        roundsWon: 0,
        label: '',
        animFrame: null,
    };

    let timing = { position: 0, direction: 1, zoneStart: 0, speed: 0, zoneSize: 0 };
    let sequence = { keys: [], inputIndex: 0, phase: 'display', displayIndex: 0, displayTimer: null };
    let precision = { cx: 200, cy: 200, angle: 0, speed: 0, circleSize: 50, mouseX: 200, mouseY: 200, insideTime: 0, requiredTime: 3, lastTime: 0, timeoutId: null };

    // ===== DOM REFS =====
    const $ = id => document.getElementById(id);
    const overlay = $('overlay');
    const gameLabel = $('game-label');
    const roundDisplay = $('round-display');
    const resultDisplay = $('result-display');
    const timingGame = $('timing-game');
    const sequenceGame = $('sequence-game');
    const precisionGame = $('precision-game');

    // ===== NUI MESSAGE HANDLER =====
    window.addEventListener('message', (e) => {
        if (e.data.action === 'start') startGame(e.data);
        else if (e.data.action === 'close') closeGame();
    });

    // ===== KEYBOARD =====
    document.addEventListener('keydown', (e) => {
        if (!state.active) return;
        if (state.type === 'timing' && e.code === 'Space') {
            e.preventDefault();
            handleTimingInput();
        } else if (state.type === 'sequence' && sequence.phase === 'input') {
            const key = e.key.toUpperCase();
            if (KEYS.includes(key)) {
                e.preventDefault();
                handleSequenceInput(key);
            }
        }
    });

    // ===== MOUSE (Precision) =====
    document.addEventListener('mousemove', (e) => {
        if (!state.active || state.type !== 'precision') return;
        const canvas = $('precision-canvas');
        const rect = canvas.getBoundingClientRect();
        precision.mouseX = e.clientX - rect.left;
        precision.mouseY = e.clientY - rect.top;
    });

    // ===== GAME START =====
    function startGame(data) {
        state.active = true;
        state.type = data.type || 'timing';
        state.difficulty = Math.min(5, Math.max(1, data.difficulty || 3));
        state.rounds = Math.max(1, data.rounds || 3);
        state.currentRound = 0;
        state.roundsWon = 0;
        state.label = data.label || '';

        gameLabel.textContent = state.label;
        resultDisplay.classList.add('hidden');
        overlay.classList.remove('hidden');
        hideAllGames();
        startNextRound();
    }

    function hideAllGames() {
        timingGame.classList.add('hidden');
        sequenceGame.classList.add('hidden');
        precisionGame.classList.add('hidden');
    }

    // ===== ROUND MANAGEMENT =====
    function startNextRound() {
        state.currentRound++;
        if (state.currentRound > state.rounds) {
            endGame();
            return;
        }
        roundDisplay.textContent = 'Round ' + state.currentRound + ' / ' + state.rounds;
        resultDisplay.classList.add('hidden');
        hideAllGames();

        switch (state.type) {
            case 'timing':    startTimingRound(); break;
            case 'sequence':  startSequenceRound(); break;
            case 'precision': startPrecisionRound(); break;
        }
    }

    function roundResult(won) {
        if (won) state.roundsWon++;
        cancelAnimationFrame(state.animFrame);
        state.animFrame = null;
        setTimeout(() => startNextRound(), 600);
    }

    // ===== GAME END =====
    function endGame() {
        const total = state.rounds;
        const won = state.roundsWon;
        const success = won >= Math.ceil(total / 2);
        const score = Math.round((won / total) * 100);

        hideAllGames();
        resultDisplay.classList.remove('hidden');
        resultDisplay.className = success ? 'result-success' : 'result-fail';
        resultDisplay.querySelector('.result-text').textContent = success ? 'SUCCESS' : 'FAILED';

        setTimeout(() => {
            closeGame();
            fetch('https://sb_minigame/result', {
                method: 'POST',
                body: JSON.stringify({ success, score })
            });
        }, 1200);
    }

    function closeGame() {
        state.active = false;
        cancelAnimationFrame(state.animFrame);
        state.animFrame = null;
        if (sequence.displayTimer) { clearTimeout(sequence.displayTimer); sequence.displayTimer = null; }
        if (precision.timeoutId) { clearTimeout(precision.timeoutId); precision.timeoutId = null; }
        overlay.classList.add('hidden');
        hideAllGames();
    }

    // ============================================================
    //  TIMING BAR
    // ============================================================
    function startTimingRound() {
        const diff = DIFFICULTY.timing[state.difficulty];
        timing.speed = diff.speed;
        timing.zoneSize = diff.zoneSize;
        timing.position = 0;
        timing.direction = 1;

        const margin = timing.zoneSize;
        timing.zoneStart = margin + Math.random() * (1 - margin * 2 - timing.zoneSize);

        const bar = timingGame.querySelector('.timing-bar');
        const zone = timingGame.querySelector('.timing-zone');
        const marker = timingGame.querySelector('.timing-marker');

        zone.style.left = (timing.zoneStart * 100) + '%';
        zone.style.width = (timing.zoneSize * 100) + '%';
        marker.style.left = '0%';
        bar.classList.remove('flash-success', 'flash-fail');

        timingGame.classList.remove('hidden');

        let lastTime = performance.now();
        function tick(now) {
            if (!state.active || state.type !== 'timing') return;
            const dt = (now - lastTime) / 1000;
            lastTime = now;
            timing.position += timing.direction * timing.speed * dt;
            if (timing.position >= 1) { timing.position = 1; timing.direction = -1; }
            else if (timing.position <= 0) { timing.position = 0; timing.direction = 1; }
            marker.style.left = (timing.position * 100) + '%';
            state.animFrame = requestAnimationFrame(tick);
        }
        state.animFrame = requestAnimationFrame(tick);
    }

    function handleTimingInput() {
        if (state.type !== 'timing') return;
        const bar = timingGame.querySelector('.timing-bar');
        const inZone = timing.position >= timing.zoneStart &&
                       timing.position <= timing.zoneStart + timing.zoneSize;
        bar.classList.remove('flash-success', 'flash-fail');
        void bar.offsetWidth;
        bar.classList.add(inZone ? 'flash-success' : 'flash-fail');
        roundResult(inZone);
    }

    // ============================================================
    //  SEQUENCE
    // ============================================================
    function startSequenceRound() {
        const diff = DIFFICULTY.sequence[state.difficulty];
        sequence.keys = [];
        sequence.inputIndex = 0;
        sequence.phase = 'display';

        for (let i = 0; i < diff.length; i++) {
            sequence.keys.push(KEYS[Math.floor(Math.random() * KEYS.length)]);
        }

        sequenceGame.classList.remove('hidden');
        const display = sequenceGame.querySelector('.sequence-display');
        const input = sequenceGame.querySelector('.sequence-input');
        const hint = sequenceGame.querySelector('.sequence-hint');

        display.innerHTML = '';
        sequence.keys.forEach(k => {
            const el = document.createElement('div');
            el.className = 'sequence-key';
            el.textContent = k;
            display.appendChild(el);
        });
        input.innerHTML = '';
        hint.textContent = 'Watch the sequence...';

        let idx = 0;
        const keyEls = display.querySelectorAll('.sequence-key');

        function highlightNext() {
            if (!state.active || state.type !== 'sequence') return;
            if (idx > 0) keyEls[idx - 1].classList.remove('highlight');
            if (idx >= sequence.keys.length) {
                setTimeout(() => {
                    if (!state.active) return;
                    keyEls.forEach(el => el.classList.add('hidden-key'));
                    sequence.phase = 'input';
                    hint.textContent = 'Repeat the sequence!';
                    input.innerHTML = '';
                    sequence.keys.forEach(() => {
                        const el = document.createElement('div');
                        el.className = 'sequence-key';
                        el.textContent = '?';
                        input.appendChild(el);
                    });
                }, 300);
                return;
            }
            keyEls[idx].classList.add('highlight');
            idx++;
            sequence.displayTimer = setTimeout(highlightNext, diff.displayTime);
        }
        sequence.displayTimer = setTimeout(highlightNext, 400);
    }

    function handleSequenceInput(key) {
        if (sequence.phase !== 'input') return;
        const inputEls = sequenceGame.querySelector('.sequence-input').querySelectorAll('.sequence-key');
        const expected = sequence.keys[sequence.inputIndex];
        const correct = key === expected;

        const el = inputEls[sequence.inputIndex];
        el.textContent = key;
        el.classList.add(correct ? 'correct' : 'wrong');

        if (!correct) {
            setTimeout(() => roundResult(false), 400);
            return;
        }
        sequence.inputIndex++;
        if (sequence.inputIndex >= sequence.keys.length) {
            setTimeout(() => roundResult(true), 300);
        }
    }

    // ============================================================
    //  PRECISION
    // ============================================================
    function startPrecisionRound() {
        const diff = DIFFICULTY.precision[state.difficulty];
        precision.circleSize = diff.circleSize;
        precision.speed = diff.speed;
        precision.requiredTime = diff.requiredTime;
        precision.insideTime = 0;
        precision.angle = Math.random() * Math.PI * 2;
        precision.lastTime = performance.now();

        const canvas = $('precision-canvas');
        precision.cx = canvas.width / 2;
        precision.cy = canvas.height / 2;
        precision.mouseX = canvas.width / 2;
        precision.mouseY = canvas.height / 2;

        const fill = precisionGame.querySelector('.precision-bar-fill');
        fill.style.width = '0%';

        precisionGame.classList.remove('hidden');

        const ctx = canvas.getContext('2d');
        const w = canvas.width;
        const h = canvas.height;
        const pathRX = w * 0.28;
        const pathRY = h * 0.28;
        let roundDone = false;

        function tick(now) {
            if (!state.active || state.type !== 'precision' || roundDone) return;
            const dt = (now - precision.lastTime) / 1000;
            precision.lastTime = now;

            precision.angle += precision.speed * dt;
            const targetX = w / 2 + Math.sin(precision.angle) * pathRX;
            const targetY = h / 2 + Math.cos(precision.angle * 0.7) * pathRY;

            const dx = precision.mouseX - targetX;
            const dy = precision.mouseY - targetY;
            const dist = Math.sqrt(dx * dx + dy * dy);
            const inside = dist <= precision.circleSize;

            if (inside) precision.insideTime += dt;
            else precision.insideTime = Math.max(0, precision.insideTime - dt * 0.5);

            const progress = Math.min(1, precision.insideTime / precision.requiredTime);
            fill.style.width = (progress * 100) + '%';

            if (progress >= 1) {
                roundDone = true;
                roundResult(true);
                return;
            }

            // Draw
            ctx.clearRect(0, 0, w, h);

            // Subtle grid
            ctx.strokeStyle = COLORS.border;
            ctx.lineWidth = 0.5;
            for (let x = 0; x < w; x += 40) {
                ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, h); ctx.stroke();
            }
            for (let y = 0; y < h; y += 40) {
                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke();
            }

            // Target circle — orange when outside, green when inside
            ctx.beginPath();
            ctx.arc(targetX, targetY, precision.circleSize, 0, Math.PI * 2);
            ctx.fillStyle = inside ? COLORS.successMuted : COLORS.accentMuted;
            ctx.fill();
            ctx.strokeStyle = inside ? COLORS.success : COLORS.accent;
            ctx.lineWidth = 2;
            ctx.stroke();

            // Inner ring
            ctx.beginPath();
            ctx.arc(targetX, targetY, precision.circleSize * 0.45, 0, Math.PI * 2);
            ctx.strokeStyle = inside ? 'rgba(34, 197, 94, 0.3)' : 'rgba(255, 107, 53, 0.25)';
            ctx.lineWidth = 1;
            ctx.stroke();

            // Cursor crosshair
            const cx = precision.mouseX;
            const cy = precision.mouseY;
            const cursorColor = inside ? COLORS.success : COLORS.error;
            ctx.strokeStyle = cursorColor;
            ctx.lineWidth = 1.5;
            ctx.beginPath(); ctx.moveTo(cx - 10, cy); ctx.lineTo(cx + 10, cy); ctx.stroke();
            ctx.beginPath(); ctx.moveTo(cx, cy - 10); ctx.lineTo(cx, cy + 10); ctx.stroke();
            ctx.beginPath();
            ctx.arc(cx, cy, 3, 0, Math.PI * 2);
            ctx.fillStyle = cursorColor;
            ctx.fill();

            state.animFrame = requestAnimationFrame(tick);
        }

        state.animFrame = requestAnimationFrame(tick);

        // Timeout fail
        const timeoutMs = precision.requiredTime * 3 * 1000;
        precision.timeoutId = setTimeout(() => {
            if (!roundDone && state.active && state.type === 'precision') {
                roundDone = true;
                roundResult(false);
            }
        }, timeoutMs);
    }
})();
