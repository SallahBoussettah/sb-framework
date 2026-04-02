let isRenewal = false;
let storedMugshotBase64 = '';
let storedCharacteristics = {};
let selectedTheme = 'white';

// ============================================================================
// NUI MESSAGE HANDLER
// ============================================================================

window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.action) {
        case 'openForm':
            openForm(data);
            break;
        case 'showCard':
            showCard(data);
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
// BASE64 CONVERSION (nui-img URL -> base64 data URI)
// ============================================================================

function convertToBase64(data) {
    const imgUrl = data.imgUrl;
    const handle = data.handle;

    if (!imgUrl) {
        fetch('https://sb_id/base64Result', {
            method: 'POST',
            body: JSON.stringify({ base64: '', handle: handle })
        });
        return;
    }

    const xhr = new XMLHttpRequest();
    xhr.onload = function () {
        const reader = new FileReader();
        reader.onloadend = function () {
            fetch('https://sb_id/base64Result', {
                method: 'POST',
                body: JSON.stringify({
                    base64: reader.result,
                    handle: handle
                })
            });
        };
        reader.readAsDataURL(xhr.response);
    };
    xhr.onerror = function () {
        fetch('https://sb_id/base64Result', {
            method: 'POST',
            body: JSON.stringify({ base64: '', handle: handle })
        });
    };
    xhr.open('GET', imgUrl);
    xhr.responseType = 'blob';
    xhr.send();
}

// ============================================================================
// APPLICATION FORM
// ============================================================================

function openForm(data) {
    closeAll();
    isRenewal = data.isRenewal || false;
    storedMugshotBase64 = data.mugshotBase64 || '';
    storedCharacteristics = data.characteristics || {};

    const subtitle = document.getElementById('form-subtitle');
    subtitle.textContent = isRenewal ? 'ID Card Renewal' : 'ID Card Application';

    const costEl = document.getElementById('form-cost-value');
    costEl.textContent = '$' + (data.cost || 50);

    document.getElementById('address-input').value = '';

    // Reset theme picker to default
    selectedTheme = 'white';
    document.querySelectorAll('.theme-option').forEach(btn => {
        btn.classList.toggle('selected', btn.dataset.theme === 'white');
    });

    document.getElementById('form-container').classList.remove('hidden');

    setTimeout(() => {
        document.getElementById('address-input').focus();
    }, 100);
}

function closeForm() {
    document.getElementById('form-container').classList.add('hidden');
}

// Theme picker
document.querySelectorAll('.theme-option').forEach(btn => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.theme-option').forEach(b => b.classList.remove('selected'));
        btn.classList.add('selected');
        selectedTheme = btn.dataset.theme;
    });
});

// Submit button
document.getElementById('btn-submit').addEventListener('click', () => {
    const address = document.getElementById('address-input').value.trim();
    if (address.length < 3) {
        shakeInput();
        return;
    }

    fetch('https://sb_id/submitApplication', {
        method: 'POST',
        body: JSON.stringify({
            address: address,
            isRenewal: isRenewal,
            mugshotBase64: storedMugshotBase64,
            characteristics: storedCharacteristics,
            cardTheme: selectedTheme
        })
    });

    closeForm();
});

// Cancel button
document.getElementById('btn-cancel').addEventListener('click', () => {
    fetch('https://sb_id/close', {
        method: 'POST',
        body: JSON.stringify({})
    });
    closeForm();
});

// Enter key submits
document.getElementById('address-input').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
        document.getElementById('btn-submit').click();
    }
});

function shakeInput() {
    const input = document.getElementById('address-input');
    input.style.borderColor = 'rgba(220, 50, 50, 0.6)';
    input.style.animation = 'none';
    input.offsetHeight;
    input.style.animation = 'shake 0.4s ease';
    setTimeout(() => {
        input.style.borderColor = '';
        input.style.animation = '';
    }, 500);
}

// ============================================================================
// ID CARD DISPLAY
// ============================================================================

function showCard(data) {
    closeAll();

    const info = data.data;
    if (!info) return;

    // ID number
    document.getElementById('card-citizenid').textContent = info.citizenid || '---';

    // Names
    document.getElementById('card-lastname').textContent = (info.lastname || '---').toUpperCase();
    document.getElementById('card-firstname').textContent = (info.firstname || '---').toUpperCase();

    // Address
    document.getElementById('card-address').textContent = (info.address || '---').toUpperCase();

    // DOB
    document.getElementById('card-dob').textContent = info.dob || '---';

    // Physical characteristics
    document.getElementById('card-gender').textContent = info.sex || formatGender(info.gender);
    document.getElementById('card-hair').textContent = info.hair || '---';
    document.getElementById('card-eyes').textContent = info.eyes || '---';
    document.getElementById('card-height').textContent = info.height || '---';
    document.getElementById('card-weight').textContent = info.weight || '---';
    document.getElementById('card-bloodtype').textContent = info.bloodtype || '---';

    // Dates
    document.getElementById('card-issued').textContent = info.issueDate || '---';
    document.getElementById('card-expiry').textContent = info.expiryDate || '---';

    // Signature (cursive first + last name)
    const sigFirst = info.firstname || '';
    const sigLast = info.lastname || '';
    document.getElementById('card-signature').textContent = sigFirst.toLowerCase() + ' ' + sigLast.toLowerCase();

    // Expired overlay
    const expiredEl = document.getElementById('expired-overlay');
    if (data.expired) {
        expiredEl.classList.remove('hidden');
    } else {
        expiredEl.classList.add('hidden');
    }

    // Apply card theme
    const cardEl = document.querySelector('.id-card');
    cardEl.classList.remove('theme-white', 'theme-black');
    const theme = (info.cardTheme === 'black') ? 'theme-black' : 'theme-white';
    cardEl.classList.add(theme);

    // Mugshot photo
    setMugshotPhoto(data);

    document.getElementById('card-container').classList.remove('hidden');
}

function setMugshotPhoto(data) {
    const photoFrame = document.getElementById('photo-frame');

    // Priority: live nui-img URL (self-view) > stored base64 > placeholder
    const liveMugshotUrl = data.liveMugshotUrl || '';
    const storedBase64 = data.mugshot || '';

    if (liveMugshotUrl) {
        // Self-view: use the live nui-img URL directly
        photoFrame.innerHTML = `<img src="${liveMugshotUrl}" alt="Photo" />`;
    } else if (storedBase64 && storedBase64.startsWith('data:')) {
        // Other player view: use stored base64 from metadata
        photoFrame.innerHTML = `<img src="${storedBase64}" alt="Photo" />`;
    } else {
        // Fallback: placeholder icon
        photoFrame.innerHTML = '<i class="fa-solid fa-user photo-placeholder"></i>';
    }
}

function formatGender(gender) {
    if (!gender) return '---';
    const g = gender.toString().toLowerCase();
    if (g === '0' || g === 'male' || g === 'm') return 'M';
    if (g === '1' || g === 'female' || g === 'f') return 'F';
    return gender;
}

// ============================================================================
// CLOSE
// ============================================================================

function closeAll() {
    document.getElementById('form-container').classList.add('hidden');
    document.getElementById('card-container').classList.add('hidden');
}

// Escape key
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        fetch('https://sb_id/close', {
            method: 'POST',
            body: JSON.stringify({})
        });
        closeAll();
    }
});
