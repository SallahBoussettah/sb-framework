// Everyday Chaos RP - Loading Screen
// Author: Salah Eddine Boussettah

// ============================================================================
// CONFIGURATION
// ============================================================================

const CONFIG = {
    // Background screenshots for slideshow
    backgrounds: [
        'background.jpg',
        'background2.jpg',
        'background3.png'
    ],

    // Set a video file to override the screenshot slideshow
    // The video's own audio is used -- the audio toggle mutes/unmutes it
    // Example: 'loading_video.mp4'
    video: 'loading_video.mp4',

    // How often backgrounds rotate in ms (only used when no video is set)
    backgroundRotateInterval: 10000,

    // Loading status messages
    statusMessages: {
        init: 'Initializing...',
        map: 'Loading map data...',
        session: 'Establishing connection...',
        done: 'Almost ready...'
    }
};

// ============================================================================
// DOM ELEMENTS
// ============================================================================

const bgLayer = document.getElementById('bgLayer');
const bgVideo = document.getElementById('bgVideo');
const progressBar = document.getElementById('progressBar');
const percentNum = document.getElementById('percentNum');
const statusText = document.getElementById('statusText');
const audioIcon = document.getElementById('audio-icon');

// ============================================================================
// STATE
// ============================================================================

let backgroundIndex = 0;
let audioOn = false;
let currentProgress = 0;

// ============================================================================
// BACKGROUND: SCREENSHOT SLIDESHOW
// ============================================================================

function initScreenshotSlideshow() {
    if (!bgLayer) return;

    CONFIG.backgrounds.forEach((bg, index) => {
        const slide = document.createElement('div');
        slide.className = 'bg-slide' + (index === 0 ? ' active' : '');
        slide.style.backgroundImage = `url('${bg}')`;
        bgLayer.appendChild(slide);
    });

    if (CONFIG.backgrounds.length > 1) {
        setInterval(rotateBackground, CONFIG.backgroundRotateInterval);
    }
}

function rotateBackground() {
    const slides = document.querySelectorAll('.bg-slide');
    if (slides.length === 0) return;

    slides[backgroundIndex].classList.remove('active');
    backgroundIndex = (backgroundIndex + 1) % slides.length;
    slides[backgroundIndex].classList.add('active');
}

// ============================================================================
// BACKGROUND: VIDEO OVERRIDE
// ============================================================================

function initVideo() {
    if (!bgVideo || !CONFIG.video) return;

    // Hide the screenshot slideshow
    bgLayer.style.display = 'none';

    // Set up video (starts muted, toggle unmutes)
    bgVideo.src = CONFIG.video;
    bgVideo.muted = true;
    bgVideo.autoplay = true;
    bgVideo.preload = 'auto';
    bgVideo.classList.add('active');

    // Add gradient overlay for video
    const overlay = document.createElement('div');
    overlay.className = 'bg-video-overlay active';
    document.body.insertBefore(overlay, document.querySelector('.scanlines'));

    // Attempt to play - may require user interaction in some browsers
    const playPromise = bgVideo.play();
    if (playPromise !== undefined) {
        playPromise.catch(() => {
            // Autoplay was prevented, video will remain visible but paused
            // FiveM loading screen should allow autoplay with muted videos
        });
    }
}

// ============================================================================
// AUDIO TOGGLE (controls video mute/unmute)
// ============================================================================

window.toggleAudio = function () {
    if (!CONFIG.video || !bgVideo) return;

    audioOn = !audioOn;
    bgVideo.muted = !audioOn;

    // Lucide replaces <i> with <svg>, so we swap the icon container's HTML
    const toggle = document.getElementById('audioToggle');
    if (toggle) {
        const iconName = audioOn ? 'volume-2' : 'volume-x';
        // Find the existing icon (could be <i> or <svg>) and replace it
        const existing = toggle.querySelector('svg, i');
        if (existing) {
            const newIcon = document.createElement('i');
            newIcon.setAttribute('data-lucide', iconName);
            existing.replaceWith(newIcon);
            lucide.createIcons();
        }
    }
};

// ============================================================================
// PROGRESS & STATUS
// ============================================================================

// Progress can only go forward -- never backwards
function updateProgress(percent) {
    const clamped = Math.min(100, Math.max(0, percent));
    if (clamped <= currentProgress) return;
    currentProgress = clamped;
    if (progressBar) progressBar.style.width = currentProgress + '%';
    if (percentNum) percentNum.textContent = Math.round(currentProgress);
}

function updateStatus(message) {
    if (statusText) statusText.textContent = message;
}

// ============================================================================
// FIVEM LOADING EVENTS
// ============================================================================

const handlers = {
    // Phase events -- only update the status text, NOT the progress bar
    startInitFunctionOrder(data) {
        if (data.type === 'INIT_BEFORE_MAP_LOADED') {
            updateStatus(CONFIG.statusMessages.init);
        } else if (data.type === 'INIT_AFTER_MAP_LOADED') {
            updateStatus(CONFIG.statusMessages.map);
        } else if (data.type === 'INIT_SESSION') {
            updateStatus(CONFIG.statusMessages.session);
        }
    },

    startDataFileEntries() {},

    initFunctionInvoking() {},

    performMapLoadFunction() {},

    // This is the real overall progress from FiveM (0.0 - 1.0)
    loadProgress(data) {
        updateProgress(data.loadFraction * 100);
    },

    onLogLine() {}
};

window.addEventListener('message', function (e) {
    const handler = handlers[e.data.eventName];
    if (handler) {
        handler(e.data);
    }
});

// ============================================================================
// INITIALIZATION
// ============================================================================

// Initialize Lucide icons
lucide.createIcons();

// Decide: video override or screenshot slideshow
if (CONFIG.video) {
    initVideo();
} else {
    initScreenshotSlideshow();
}

// Set initial state
updateProgress(0);
updateStatus(CONFIG.statusMessages.init);

// ============================================================================
// TESTING (uncomment to test outside FiveM)
// ============================================================================
/*
let testProgress = 0;
setInterval(() => {
    testProgress += Math.random() * 5;
    if (testProgress > 100) testProgress = 100;
    updateProgress(testProgress);
}, 500);
*/
