const bar = document.getElementById('progress-bar');
const val = document.getElementById('progress-val');
const wrapper = document.getElementById('progress-wrapper');
const label = document.getElementById('progress-text');
const iconEl = document.getElementById('progress-icon');

let progressInterval = null;
let currentProgress = 0;

function startProgress(data) {
    // Reset state
    clearInterval(progressInterval);
    currentProgress = 0;
    bar.style.width = '0%';
    val.innerText = '0%';
    wrapper.classList.remove('sb-complete', 'sb-cancelling');

    // Set label
    label.innerText = (data.label || 'Processing...').toUpperCase();

    // Set icon
    if (data.icon) {
        iconEl.setAttribute('data-lucide', data.icon);
        iconEl.style.display = '';
        lucide.createIcons();
    } else {
        iconEl.style.display = 'none';
    }

    // Show wrapper
    wrapper.classList.add('active');

    // Start progress
    const duration = data.duration || 5000;
    const step = 50; // Update every 50ms
    const increment = (step / duration) * 100;

    progressInterval = setInterval(() => {
        currentProgress += increment;

        if (currentProgress >= 100) {
            currentProgress = 100;
            clearInterval(progressInterval);
            progressInterval = null;

            bar.style.width = '100%';
            val.innerText = '100%';

            // Flash animation
            wrapper.classList.add('sb-complete');

            // Hide after flash and notify client
            setTimeout(() => {
                wrapper.classList.remove('active', 'sb-complete');
                bar.style.width = '0%';
                val.innerText = '0%';
                fetch(`https://${GetParentResourceName()}/progressComplete`, {
                    method: 'POST',
                    body: JSON.stringify({})
                });
            }, 600);
            return;
        }

        bar.style.width = currentProgress + '%';
        val.innerText = Math.floor(currentProgress) + '%';
    }, step);
}

function cancelProgress() {
    clearInterval(progressInterval);
    progressInterval = null;
    currentProgress = 0;

    wrapper.classList.add('sb-cancelling');

    setTimeout(() => {
        wrapper.classList.remove('active', 'sb-cancelling');
        bar.style.width = '0%';
        val.innerText = '0%';
    }, 300);
}

// NUI message listener
window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.action) {
        case 'start':
            startProgress(data);
            break;
        case 'cancel':
            cancelProgress();
            break;
    }
});
