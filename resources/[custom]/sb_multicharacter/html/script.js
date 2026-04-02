/**
 * Everyday Chaos RP - Multicharacter NUI Script
 * Author: Salah Eddine Boussettah
 */

// ============================================
// STATE
// ============================================
const state = {
    characters: [],
    maxSlots: 3,
    selectedCharacter: null,
    selectedSpawnLocation: null,
    allowDelete: true,
    deleteConfirmText: 'DELETE',
    spawnLocations: [],
    nationalities: [],
    creationStep: 1,
    creationData: {
        charinfo: {
            firstname: '',
            lastname: '',
            birthdate: '1990-01-01',
            gender: 0,
            nationality: 'American'
        },
        appearance: {}
    },
    clothingData: null,
    parents: [],
    faceFeatures: {},
    headOverlays: {},
    currentFocus: 'fullBody'
};

// Parent names (GTA V heritage)
const parentNames = {
    mother: [
        'Hannah', 'Audrey', 'Jasmine', 'Giselle', 'Amelia', 'Isabella', 'Zoe', 'Ava',
        'Camila', 'Violet', 'Sophia', 'Evelyn', 'Nicole', 'Ashley', 'Grace', 'Brianna',
        'Natalie', 'Olivia', 'Elizabeth', 'Charlotte', 'Emma', 'Misty', 'Elena', 'Anna',
        'Mary', 'Adriana', 'Maria', 'Gabriela', 'Mia', 'Rebecca', 'Sarah', 'Patricia',
        'Jessica', 'Emily', 'Samantha', 'Amanda', 'Angela', 'Rachel', 'Michelle', 'Jennifer',
        'Stephanie', 'Linda', 'Karen', 'Lisa', 'Barbara', 'Margaret'
    ],
    father: [
        'Benjamin', 'Daniel', 'Joshua', 'Noah', 'Andrew', 'Juan', 'Alex', 'Isaac',
        'Evan', 'Ethan', 'Vincent', 'Angel', 'Diego', 'Adrian', 'Gabriel', 'Michael',
        'Santiago', 'Kevin', 'Louis', 'Samuel', 'Anthony', 'Claude', 'Niko', 'John',
        'James', 'William', 'David', 'Richard', 'Joseph', 'Thomas', 'Christopher', 'Charles',
        'Matthew', 'Robert', 'Steven', 'Edward', 'Brian', 'Jeffrey', 'George', 'Donald',
        'Kenneth', 'Ronald', 'Timothy', 'Jason', 'Frank', 'Raymond'
    ]
};

// Face features by category
const featureCategories = {
    nose: [
        { id: 0, name: 'Nose Width' },
        { id: 1, name: 'Nose Peak Height' },
        { id: 2, name: 'Nose Peak Length' },
        { id: 3, name: 'Nose Bone Height' },
        { id: 4, name: 'Nose Peak Lowering' },
        { id: 5, name: 'Nose Bone Twist' }
    ],
    eyebrows: [
        { id: 6, name: 'Eyebrow Height' },
        { id: 7, name: 'Eyebrow Depth' }
    ],
    cheeks: [
        { id: 8, name: 'Cheekbone Height' },
        { id: 9, name: 'Cheekbone Width' },
        { id: 10, name: 'Cheeks Width' }
    ],
    eyes: [
        { id: 11, name: 'Eye Opening' }
    ],
    lips: [
        { id: 12, name: 'Lips Thickness' }
    ],
    jaw: [
        { id: 13, name: 'Jaw Bone Width' },
        { id: 14, name: 'Jaw Bone Depth' },
        { id: 15, name: 'Chin Height' },
        { id: 16, name: 'Chin Depth' },
        { id: 17, name: 'Chin Width' },
        { id: 18, name: 'Chin Hole' },
        { id: 19, name: 'Neck Thickness' }
    ]
};

// Overlay limits
const overlayLimits = {
    eyeColor: { min: 0, max: 31 },
    blemishes: { min: -1, max: 23 },
    ageing: { min: -1, max: 14 },
    complexion: { min: -1, max: 11 },
    moles: { min: -1, max: 17 },
    sunDamage: { min: -1, max: 10 }
};

// ============================================
// INIT
// ============================================
document.addEventListener('DOMContentLoaded', () => {
    lucide.createIcons();
    setupEventListeners();
});

// Listen for NUI messages
window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.action) {
        case 'openCharacterSelect':
            openCharacterSelect(data);
            break;
        case 'openCharacterCreation':
            openCharacterCreation(data);
            break;
        case 'close':
            closeUI();
            break;
        case 'showLoading':
            showLoading(data.message);
            break;
        case 'hideLoading':
            hideLoading();
            break;
        case 'showError':
            showToast(data.message, 'error');
            break;
        case 'showSuccess':
            showToast(data.message, 'success');
            break;
    }
});

// ============================================
// EVENT LISTENERS
// ============================================
function setupEventListeners() {
    // Character Selection
    document.getElementById('btn-new-character').addEventListener('click', () => {
        if (state.characters.length >= state.maxSlots) {
            showToast('Maximum characters reached', 'warning');
            return;
        }
        post('newCharacter', { slot: state.characters.length + 1 });
    });

    document.getElementById('btn-play').addEventListener('click', () => {
        if (!state.selectedCharacter || !state.selectedSpawnLocation) {
            showToast('Please select a spawn location', 'warning');
            return;
        }
        post('selectCharacter', {
            citizenid: state.selectedCharacter.citizenid,
            spawnLocation: state.selectedSpawnLocation
        });
    });

    document.getElementById('btn-delete').addEventListener('click', () => {
        if (!state.selectedCharacter) return;
        openDeleteModal();
    });

    // Delete Modal
    document.getElementById('close-delete-modal').addEventListener('click', closeDeleteModal);
    document.getElementById('btn-cancel-delete').addEventListener('click', closeDeleteModal);
    document.getElementById('delete-confirm-input').addEventListener('input', (e) => {
        const btn = document.getElementById('btn-confirm-delete');
        btn.disabled = e.target.value !== state.deleteConfirmText;
    });
    document.getElementById('btn-confirm-delete').addEventListener('click', () => {
        if (state.selectedCharacter) {
            post('deleteCharacter', { citizenid: state.selectedCharacter.citizenid });
            closeDeleteModal();
        }
    });

    // Character Creation Navigation
    document.getElementById('btn-back').addEventListener('click', () => {
        if (state.creationStep === 1) {
            post('cancelCreation', {});
            return;
        }
        setCreationStep(state.creationStep - 1);
    });

    document.getElementById('btn-next').addEventListener('click', () => {
        if (!validateCurrentStep()) return;
        setCreationStep(state.creationStep + 1);
    });

    document.getElementById('btn-create').addEventListener('click', () => {
        if (!validateCurrentStep()) return;
        submitCharacterCreation();
    });

    document.getElementById('btn-cancel-creation').addEventListener('click', () => {
        post('cancelCreation', {});
    });

    document.getElementById('btn-randomize').addEventListener('click', () => {
        fetch(`https://${getResourceName()}/randomizeAppearance`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        })
        .then(resp => resp.json())
        .then(data => {
            if (data && data.appearance) {
                state.creationData.appearance = data.appearance;
            }
        })
        .catch(err => console.error('Randomize error:', err));
    });

    // Gender Selection
    document.querySelectorAll('.gender-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.gender-btn').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            const gender = parseInt(btn.dataset.gender);
            state.creationData.charinfo.gender = gender;
            fetch(`https://${getResourceName()}/changeGender`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ gender })
            }).then(r => r.json()).then(data => {
                if (data && data.clothingData) {
                    state.clothingData = data.clothingData;
                }
            }).catch(err => console.error('changeGender error:', err));
        });
    });

    // Heritage Controls
    document.querySelectorAll('.parent-nav').forEach(btn => {
        btn.addEventListener('click', () => {
            const parent = btn.dataset.parent;
            const dir = parseInt(btn.dataset.dir);
            changeParent(parent, dir);
        });
    });

    // Sliders
    document.getElementById('slider-resemblance').addEventListener('input', (e) => {
        updateHeritage();
    });

    document.getElementById('slider-skintone').addEventListener('input', (e) => {
        updateHeritage();
    });

    // Feature Tabs
    document.querySelectorAll('.feature-tab').forEach(tab => {
        tab.addEventListener('click', () => {
            document.querySelectorAll('.feature-tab').forEach(t => t.classList.remove('active'));
            tab.classList.add('active');
            renderFeatureSliders(tab.dataset.tab);
        });
    });

    // Overlay Controls
    document.querySelectorAll('.num-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            const overlay = btn.dataset.overlay;
            const dir = parseInt(btn.dataset.dir);
            changeOverlay(overlay, dir);
        });
    });

    // Style Tabs
    document.querySelectorAll('.style-tab').forEach(tab => {
        tab.addEventListener('click', () => {
            document.querySelectorAll('.style-tab').forEach(t => t.classList.remove('active'));
            tab.classList.add('active');
            renderStyleContent(tab.dataset.tab);
        });
    });

    // Camera Controls
    document.querySelectorAll('.camera-btn[data-focus]').forEach(btn => {
        btn.addEventListener('click', () => {
            document.querySelectorAll('.camera-btn[data-focus]').forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            const focus = btn.dataset.focus;
            state.currentFocus = focus;
            post('setCameraFocus', { focus });
        });
    });

    // Pose Cycle Button
    state.currentPose = 1;
    const poseBtn = document.getElementById('btn-pose');
    const poseLabel = document.getElementById('pose-label');
    if (poseBtn) {
        poseBtn.addEventListener('click', () => {
            const totalPoses = 8;
            state.currentPose = (state.currentPose % totalPoses) + 1;
            post('setPose', { index: state.currentPose });
            if (poseLabel) poseLabel.textContent = state.currentPose + '/' + totalPoses;
        });
    }

    // Input changes for creation
    document.getElementById('input-firstname').addEventListener('input', (e) => {
        state.creationData.charinfo.firstname = e.target.value;
    });

    document.getElementById('input-lastname').addEventListener('input', (e) => {
        state.creationData.charinfo.lastname = e.target.value;
    });

    document.getElementById('input-birthdate').addEventListener('change', (e) => {
        state.creationData.charinfo.birthdate = e.target.value;
    });

    document.getElementById('input-nationality').addEventListener('change', (e) => {
        state.creationData.charinfo.nationality = e.target.value;
    });

    // Keyboard
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            if (!document.getElementById('delete-modal').classList.contains('hidden')) {
                closeDeleteModal();
            }
        }
    });
}

// ============================================
// CHARACTER SELECT
// ============================================
function openCharacterSelect(data) {
    state.characters = data.characters || [];
    state.maxSlots = data.maxSlots || 3;
    state.spawnLocations = data.spawnLocations || [];
    state.allowDelete = data.allowDelete !== false;
    state.deleteConfirmText = data.deleteConfirmText || 'DELETE';
    state.nationalities = data.nationalities || [];

    // Show app
    document.getElementById('app').classList.remove('hidden');
    document.getElementById('character-select').classList.remove('hidden');
    document.getElementById('character-creation').classList.add('hidden');

    // Update counts
    document.getElementById('char-count').textContent = state.characters.length;
    document.getElementById('max-slots').textContent = state.maxSlots;

    // Render character list
    renderCharacterList();

    // Render spawn locations
    renderSpawnLocations('spawn-locations');

    // Select first character if available
    if (state.characters.length > 0) {
        selectCharacter(state.characters[0]);
    } else {
        state.selectedCharacter = null;
        document.getElementById('character-info').classList.add('hidden');
        document.getElementById('no-character-selected').classList.remove('hidden');
    }

    // Update delete button visibility
    document.getElementById('btn-delete').style.display = state.allowDelete ? 'flex' : 'none';

    // Initialize camera focus
    state.currentFocus = 'fullBody';
    updateCameraButtons('fullBody');

    lucide.createIcons();
}

function renderCharacterList() {
    const container = document.getElementById('character-list');
    container.innerHTML = '';

    state.characters.forEach(char => {
        const card = document.createElement('div');
        card.className = 'character-card';
        card.dataset.citizenid = char.citizenid;

        card.innerHTML = `
            <div class="character-card-header">
                <div class="character-avatar">
                    <i data-lucide="${char.gender === 1 ? 'user' : 'user'}"></i>
                </div>
                <div class="character-card-info">
                    <h3>${char.firstname} ${char.lastname}</h3>
                    <p>${char.job || 'Unemployed'}</p>
                </div>
            </div>
            <div class="character-card-stats">
                <span><i data-lucide="wallet"></i> $${formatNumber(char.cash || 0)}</span>
                <span><i data-lucide="landmark"></i> $${formatNumber(char.bank || 0)}</span>
            </div>
        `;

        card.addEventListener('click', () => {
            selectCharacter(char);
            post('previewCharacter', { citizenid: char.citizenid });
        });

        container.appendChild(card);
    });

    lucide.createIcons();
}

function selectCharacter(char) {
    state.selectedCharacter = char;

    // Update card selection
    document.querySelectorAll('.character-card').forEach(card => {
        card.classList.toggle('selected', card.dataset.citizenid === char.citizenid);
    });

    // Show info panel
    document.getElementById('no-character-selected').classList.add('hidden');
    document.getElementById('character-info').classList.remove('hidden');

    // Update info
    document.getElementById('display-name').textContent = `${char.firstname} ${char.lastname}`;
    document.getElementById('display-gender').textContent = char.gender === 1 ? 'Female' : 'Male';
    document.getElementById('display-job').textContent = char.job || 'Unemployed';
    document.getElementById('display-cash').textContent = `$${formatNumber(char.cash || 0)}`;
    document.getElementById('display-bank').textContent = `$${formatNumber(char.bank || 0)}`;
    document.getElementById('display-last-played').textContent = formatDate(char.lastPlayed);

    // Reset spawn selection
    state.selectedSpawnLocation = null;
    document.querySelectorAll('#spawn-locations .spawn-option').forEach(opt => {
        opt.classList.remove('selected');
    });
}

function renderSpawnLocations(containerId) {
    const container = document.getElementById(containerId);
    container.innerHTML = '';

    state.spawnLocations.forEach(loc => {
        const option = document.createElement('div');
        option.className = 'spawn-option';
        option.dataset.id = loc.id;

        const iconName = loc.useSaved ? 'map-pin' : 'building';

        option.innerHTML = `
            <i data-lucide="${iconName}"></i>
            <span class="spawn-option-name">${loc.name || loc.label}</span>
        `;

        option.addEventListener('click', () => {
            container.querySelectorAll('.spawn-option').forEach(opt => {
                opt.classList.remove('selected');
            });
            option.classList.add('selected');
            state.selectedSpawnLocation = loc.id;
        });

        container.appendChild(option);
    });

    lucide.createIcons();
}

// ============================================
// CHARACTER CREATION
// ============================================
function openCharacterCreation(data) {
    state.creationStep = 1;
    state.creationData = {
        charinfo: {
            firstname: '',
            lastname: '',
            birthdate: '1990-01-01',
            gender: 0,
            nationality: 'American'
        },
        appearance: {
            mother: 21,
            father: 0,
            resemblance: 0.5,
            skinTone: 0.5,
            faceFeatures: {},
            headOverlays: {
                // Initialize eyebrows with default visible values
                // NOTE: GTA V bug - opacity 1.0 doesn't work, use 0.99
                2: { index: 0, opacity: 0.99, color: 0 }
            },
            hair: { style: 0, color: 0, highlight: 0 },
            eyeColor: 0,
            components: {},
            props: {}
        }
    };

    state.spawnLocations = data.spawnLocations || [];
    state.clothingData = data.clothingData;

    // Populate nationalities
    const nationalitySelect = document.getElementById('input-nationality');
    nationalitySelect.innerHTML = '';
    (data.nationalities || ['American']).forEach(nat => {
        const option = document.createElement('option');
        option.value = nat;
        option.textContent = nat;
        nationalitySelect.appendChild(option);
    });

    // Show creation screen
    document.getElementById('app').classList.remove('hidden');
    document.getElementById('character-select').classList.add('hidden');
    document.getElementById('character-creation').classList.remove('hidden');

    // Reset form
    document.getElementById('input-firstname').value = '';
    document.getElementById('input-lastname').value = '';
    document.getElementById('input-birthdate').value = '1990-01-01';
    document.querySelectorAll('.gender-btn').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.gender === '0');
    });

    // Init parent display
    updateParentDisplay('mother', 21);
    updateParentDisplay('father', 0);

    // Init sliders
    document.getElementById('slider-resemblance').value = 50;
    document.getElementById('slider-skintone').value = 50;

    // Init feature sliders
    for (let i = 0; i < 20; i++) {
        state.creationData.appearance.faceFeatures[i] = 0;
    }

    // Init overlays
    Object.keys(overlayLimits).forEach(key => {
        const el = document.getElementById(`${key}-value`);
        if (el) {
            if (key === 'eyeColor') {
                el.textContent = '0';
            } else {
                el.textContent = '-1';
            }
        }
    });

    // Render spawn locations for creation
    renderSpawnLocations('creation-spawn-locations');

    // Show first step
    setCreationStep(1);

    lucide.createIcons();
}

function setCreationStep(step) {
    state.creationStep = step;

    // Update stepper
    document.querySelectorAll('.sb-step').forEach(s => {
        const stepNum = parseInt(s.dataset.step);
        s.classList.remove('sb-step-active', 'sb-step-completed');
        if (stepNum === step) {
            s.classList.add('sb-step-active');
        } else if (stepNum < step) {
            s.classList.add('sb-step-completed');
        }
    });

    // Show/hide steps
    for (let i = 1; i <= 5; i++) {
        const el = document.getElementById(`step-${i}`);
        if (el) {
            el.classList.toggle('hidden', i !== step);
        }
    }

    // Update navigation buttons
    const btnBack = document.getElementById('btn-back');
    const btnNext = document.getElementById('btn-next');
    const btnCreate = document.getElementById('btn-create');

    btnBack.querySelector('span').textContent = step === 1 ? 'Cancel' : 'Back';
    btnNext.classList.toggle('hidden', step === 5);
    btnCreate.classList.toggle('hidden', step !== 5);

    // Step-specific setup
    if (step === 3) {
        renderFeatureSliders('nose');
    } else if (step === 4) {
        updateStyleTabs();
        renderStyleContent('hair');
    } else if (step === 5) {
        updateSummary();
    }

    // Update camera focus based on step
    if (step === 2 || step === 3) {
        post('setCameraFocus', { focus: 'face' });
    } else if (step === 4) {
        post('setCameraFocus', { focus: 'fullBody' });
    }
}

function validateCurrentStep() {
    if (state.creationStep === 1) {
        const firstname = document.getElementById('input-firstname').value.trim();
        const lastname = document.getElementById('input-lastname').value.trim();

        if (firstname.length < 2) {
            showToast('First name must be at least 2 characters', 'error');
            return false;
        }
        if (lastname.length < 2) {
            showToast('Last name must be at least 2 characters', 'error');
            return false;
        }

        state.creationData.charinfo.firstname = firstname;
        state.creationData.charinfo.lastname = lastname;
    }

    if (state.creationStep === 5) {
        if (!state.selectedSpawnLocation) {
            showToast('Please select a starting location', 'error');
            return false;
        }
    }

    return true;
}

function updateSummary() {
    const { charinfo } = state.creationData;
    const birthDate = new Date(charinfo.birthdate);
    const age = new Date().getFullYear() - birthDate.getFullYear();

    document.getElementById('summary-name').textContent = `${charinfo.firstname} ${charinfo.lastname}`;
    document.getElementById('summary-details').textContent =
        `${charinfo.gender === 1 ? 'Female' : 'Male'}, ${age} years old, ${charinfo.nationality}`;
}

function submitCharacterCreation() {
    const spawnLocation = state.spawnLocations.find(l => l.id === state.selectedSpawnLocation);

    const data = {
        charinfo: state.creationData.charinfo,
        appearance: state.creationData.appearance,
        spawnLocation: spawnLocation
    };

    post('createCharacter', data);
}

// ============================================
// HERITAGE
// ============================================
function changeParent(type, direction) {
    const current = type === 'mother' ? state.creationData.appearance.mother : state.creationData.appearance.father;
    const maxParent = 20; // 0-20 = clean vanilla faces, 21+ = DLC with tattoos
    let newVal = current + direction;

    if (newVal < 0) newVal = maxParent;
    if (newVal > maxParent) newVal = 0;

    if (type === 'mother') {
        state.creationData.appearance.mother = newVal;
    } else {
        state.creationData.appearance.father = newVal;
    }

    updateParentDisplay(type, newVal);
    updateHeritage();
}

function updateParentDisplay(type, id) {
    const nameEl = document.getElementById(`${type}-name`);
    const idEl = document.getElementById(`${type}-id`);

    nameEl.textContent = parentNames[type][id] || 'Unknown';
    idEl.textContent = `#${id}`;
}

function updateHeritage() {
    const resemblance = parseInt(document.getElementById('slider-resemblance').value) / 100;
    const skinTone = parseInt(document.getElementById('slider-skintone').value) / 100;

    state.creationData.appearance.resemblance = resemblance;
    state.creationData.appearance.skinTone = skinTone;

    post('setHeritage', {
        mother: state.creationData.appearance.mother,
        father: state.creationData.appearance.father,
        resemblance: resemblance,
        skinTone: skinTone
    });
}

// ============================================
// FACE FEATURES
// ============================================
function renderFeatureSliders(category) {
    const container = document.getElementById('features-content');
    container.innerHTML = '';

    const features = featureCategories[category] || [];

    features.forEach(feature => {
        const value = state.creationData.appearance.faceFeatures[feature.id] || 0;

        const group = document.createElement('div');
        group.className = 'sb-input-group';
        group.innerHTML = `
            <label class="sb-label">
                <span>${feature.name}</span>
                <span class="slider-value">${(value * 100).toFixed(0)}%</span>
            </label>
            <input type="range" class="sb-slider" data-feature="${feature.id}"
                   min="-100" max="100" value="${value * 100}">
        `;

        const slider = group.querySelector('input');
        const valueDisplay = group.querySelector('.slider-value');

        slider.addEventListener('input', (e) => {
            const val = parseInt(e.target.value) / 100;
            valueDisplay.textContent = `${e.target.value}%`;
            state.creationData.appearance.faceFeatures[feature.id] = val;
            post('setFaceFeature', { featureId: feature.id, value: val });
        });

        container.appendChild(group);
    });
}

function changeOverlay(type, direction) {
    const limits = overlayLimits[type];
    const valueEl = document.getElementById(`${type}-value`);
    let current = parseInt(valueEl.textContent);

    let newVal = current + direction;
    if (newVal < limits.min) newVal = limits.max;
    if (newVal > limits.max) newVal = limits.min;

    valueEl.textContent = newVal;

    if (type === 'eyeColor') {
        state.creationData.appearance.eyeColor = newVal;
        post('setEyeColor', { color: newVal });
    } else {
        const overlayMap = {
            blemishes: 0,
            ageing: 3,
            complexion: 6,
            moles: 9,
            sunDamage: 7
        };
        const overlayId = overlayMap[type];
        if (overlayId !== undefined) {
            state.creationData.appearance.headOverlays[overlayId] = {
                index: newVal === -1 ? 255 : newVal,
                opacity: 1.0
            };
            post('setHeadOverlay', {
                overlayId: overlayId,
                index: newVal === -1 ? 255 : newVal,
                opacity: 1.0
            });
        }
    }
}

// ============================================
// STYLE (Hair, Facial Hair, Makeup, Clothing)
// ============================================
function updateStyleTabs() {
    const isFemale = state.creationData.charinfo.gender === 1;
    const facialTab = document.querySelector('.style-tab[data-tab="facial"]');

    if (facialTab) {
        // Hide Facial Hair tab for female characters
        facialTab.style.display = isFemale ? 'none' : '';
    }

    // Reset active tab to hair when entering step
    document.querySelectorAll('.style-tab').forEach(t => t.classList.remove('active'));
    const hairTab = document.querySelector('.style-tab[data-tab="hair"]');
    if (hairTab) hairTab.classList.add('active');
}

function renderStyleContent(tab) {
    const container = document.getElementById('style-content');
    container.innerHTML = '';

    switch (tab) {
        case 'hair':
            renderHairOptions(container);
            break;
        case 'facial':
            renderFacialHairOptions(container);
            break;
        case 'makeup':
            renderMakeupOptions(container);
            break;
        case 'clothing':
            renderClothingOptions(container);
            break;
    }
}

function renderHairOptions(container) {
    const hairStyle = state.creationData.appearance.hair?.style || 0;
    const hairColor = state.creationData.appearance.hair?.color || 0;
    const hairHighlight = state.creationData.appearance.hair?.highlight || 0;

    const maxHair = state.clothingData?.maxHairStyles ?? 75;

    container.innerHTML = `
        <div class="sb-input-group">
            <label class="sb-label">Hair Style</label>
            <div class="number-input-large">
                <button class="num-btn" data-type="hairStyle" data-dir="-1">-</button>
                <span id="hairStyle-value">${hairStyle}</span>
                <button class="num-btn" data-type="hairStyle" data-dir="1">+</button>
            </div>
            <input type="range" class="sb-slider" id="slider-hairStyle" min="0" max="${maxHair}" value="${hairStyle}" style="margin-top: 4px;">
        </div>
        <div class="sb-input-group">
            <label class="sb-label">Hair Color</label>
            <input type="range" class="sb-slider" id="slider-hairColor" min="0" max="63" value="${hairColor}">
        </div>
        <div class="sb-input-group">
            <label class="sb-label">Highlight Color</label>
            <input type="range" class="sb-slider" id="slider-hairHighlight" min="0" max="63" value="${hairHighlight}">
        </div>
    `;

    // Helper: apply hair style value (shared by buttons + slider)
    function applyHairStyle(val) {
        document.getElementById('hairStyle-value').textContent = val;
        const slider = document.getElementById('slider-hairStyle');
        if (slider) slider.value = val;
        state.creationData.appearance.hair.style = val;
        post('setHair', { style: val });
    }

    // Hair style buttons
    container.querySelectorAll('[data-type="hairStyle"]').forEach(btn => {
        btn.addEventListener('click', () => {
            const dir = parseInt(btn.dataset.dir);
            let val = parseInt(document.getElementById('hairStyle-value').textContent) + dir;
            if (val < 0) val = maxHair;
            if (val > maxHair) val = 0;
            applyHairStyle(val);
        });
    });

    // Hair style slider
    document.getElementById('slider-hairStyle').addEventListener('input', (e) => {
        applyHairStyle(parseInt(e.target.value));
    });

    // Hair color slider
    document.getElementById('slider-hairColor').addEventListener('input', (e) => {
        const val = parseInt(e.target.value);
        state.creationData.appearance.hair.color = val;
        post('setHair', {
            style: state.creationData.appearance.hair.style,
            color: val,
            highlight: state.creationData.appearance.hair.highlight
        });
    });

    // Highlight slider
    document.getElementById('slider-hairHighlight').addEventListener('input', (e) => {
        const val = parseInt(e.target.value);
        state.creationData.appearance.hair.highlight = val;
        post('setHair', {
            style: state.creationData.appearance.hair.style,
            color: state.creationData.appearance.hair.color,
            highlight: val
        });
    });
}

function renderFacialHairOptions(container) {
    // Only show for male characters
    if (state.creationData.charinfo.gender === 1) {
        container.innerHTML = `<p style="color: var(--sb-text-secondary); text-align: center; padding: 2rem;">Facial hair is not available for female characters.</p>`;
        return;
    }

    // Get current values from state
    // NOTE: GTA V bug - opacity 1.0 doesn't work, use 0.99 (shown as 99% in slider)
    const overlay = state.creationData.appearance.headOverlays[1] || {};
    const currentStyle = overlay.index === 255 ? -1 : (overlay.index ?? -1);
    const currentOpacity = Math.round((overlay.opacity ?? 0.99) * 100);
    const currentColor = overlay.color ?? 0;

    container.innerHTML = `
        <div class="sb-input-group">
            <label class="sb-label">Facial Hair Style</label>
            <div class="number-input-large">
                <button class="num-btn" data-overlay="facialHair" data-dir="-1">-</button>
                <span id="facialHair-value">${currentStyle}</span>
                <button class="num-btn" data-overlay="facialHair" data-dir="1">+</button>
            </div>
        </div>
        <div class="sb-input-group">
            <label class="sb-label">Opacity</label>
            <input type="range" class="sb-slider" id="slider-facialHairOpacity" min="0" max="100" value="${currentOpacity}">
        </div>
        <div class="sb-input-group">
            <label class="sb-label">Color</label>
            <input type="range" class="sb-slider" id="slider-facialHairColor" min="0" max="63" value="${currentColor}">
        </div>
    `;

    setupOverlayControls('facialHair', 1, 28);

    // Facial hair opacity slider
    document.getElementById('slider-facialHairOpacity')?.addEventListener('input', (e) => {
        let opacity = parseInt(e.target.value) / 100;
        // GTA V bug: opacity 1.0 doesn't work, cap at 0.99
        if (opacity >= 1.0) opacity = 0.99;
        const overlay = state.creationData.appearance.headOverlays[1] || { index: 255 };
        state.creationData.appearance.headOverlays[1] = { ...overlay, opacity: opacity };
        post('setHeadOverlay', {
            overlayId: 1,
            index: overlay.index,
            opacity: opacity,
            color: overlay.color || 0
        });
    });

    // Facial hair color slider
    document.getElementById('slider-facialHairColor')?.addEventListener('input', (e) => {
        const color = parseInt(e.target.value);
        const overlay = state.creationData.appearance.headOverlays[1] || { index: 255, opacity: 1.0 };
        state.creationData.appearance.headOverlays[1] = { ...overlay, color: color };
        post('setHeadOverlay', {
            overlayId: 1,
            index: overlay.index,
            opacity: overlay.opacity || 1.0,
            color: color
        });
    });
}

function renderMakeupOptions(container) {
    const isFemale = state.creationData.charinfo.gender === 1;

    // Get current values from state
    const eyebrowOverlay = state.creationData.appearance.headOverlays[2] || {};
    const eyebrowStyle = eyebrowOverlay.index === 255 ? -1 : (eyebrowOverlay.index ?? 0);
    const eyebrowColor = eyebrowOverlay.color ?? 0;

    const lipstickOverlay = state.creationData.appearance.headOverlays[8] || {};
    const lipstickStyle = lipstickOverlay.index === 255 ? -1 : (lipstickOverlay.index ?? -1);
    const lipstickColor = lipstickOverlay.color ?? 0;

    const blushOverlay = state.creationData.appearance.headOverlays[5] || {};
    const blushStyle = blushOverlay.index === 255 ? -1 : (blushOverlay.index ?? -1);
    const blushColor = blushOverlay.color ?? 0;

    // Eyebrows are available for both genders
    let html = `
        <div class="sb-input-group">
            <label class="sb-label">Eyebrows Style</label>
            <div class="number-input-large">
                <button class="num-btn" data-overlay="eyebrows" data-dir="-1">-</button>
                <span id="eyebrows-value">${eyebrowStyle}</span>
                <button class="num-btn" data-overlay="eyebrows" data-dir="1">+</button>
            </div>
        </div>
        <div class="sb-input-group">
            <label class="sb-label">Eyebrow Color</label>
            <input type="range" class="sb-slider" id="slider-eyebrowsColor" min="0" max="63" value="${eyebrowColor}">
        </div>
    `;

    // Lipstick and Blush only for female characters
    if (isFemale) {
        html += `
            <div class="sb-input-group">
                <label class="sb-label">Lipstick Style</label>
                <div class="number-input-large">
                    <button class="num-btn" data-overlay="lipstick" data-dir="-1">-</button>
                    <span id="lipstick-value">${lipstickStyle}</span>
                    <button class="num-btn" data-overlay="lipstick" data-dir="1">+</button>
                </div>
            </div>
            <div class="sb-input-group">
                <label class="sb-label">Lipstick Color</label>
                <input type="range" class="sb-slider" id="slider-lipstickColor" min="0" max="63" value="${lipstickColor}">
            </div>
            <div class="sb-input-group">
                <label class="sb-label">Blush Style</label>
                <div class="number-input-large">
                    <button class="num-btn" data-overlay="blush" data-dir="-1">-</button>
                    <span id="blush-value">${blushStyle}</span>
                    <button class="num-btn" data-overlay="blush" data-dir="1">+</button>
                </div>
            </div>
            <div class="sb-input-group">
                <label class="sb-label">Blush Color</label>
                <input type="range" class="sb-slider" id="slider-blushColor" min="0" max="63" value="${blushColor}">
            </div>
        `;
    }

    container.innerHTML = html;

    // Setup eyebrows (available for both)
    setupOverlayControls('eyebrows', 2, 33, 0);

    // Eyebrow color
    document.getElementById('slider-eyebrowsColor')?.addEventListener('input', (e) => {
        const color = parseInt(e.target.value);
        const overlay = state.creationData.appearance.headOverlays[2] || { index: 0, opacity: 1.0 };
        state.creationData.appearance.headOverlays[2] = { ...overlay, color: color };
        post('setHeadOverlay', {
            overlayId: 2,
            index: overlay.index || 0,
            opacity: overlay.opacity || 1.0,
            color: color
        });
    });

    // Setup lipstick and blush only for female
    if (isFemale) {
        setupOverlayControls('lipstick', 8, 9);
        setupOverlayControls('blush', 5, 6);

        // Lipstick color
        document.getElementById('slider-lipstickColor')?.addEventListener('input', (e) => {
            const color = parseInt(e.target.value);
            const overlay = state.creationData.appearance.headOverlays[8] || { index: 255, opacity: 1.0 };
            state.creationData.appearance.headOverlays[8] = { ...overlay, color: color };
            post('setHeadOverlay', {
                overlayId: 8,
                index: overlay.index,
                opacity: overlay.opacity || 1.0,
                color: color
            });
        });

        // Blush color
        document.getElementById('slider-blushColor')?.addEventListener('input', (e) => {
            const color = parseInt(e.target.value);
            const overlay = state.creationData.appearance.headOverlays[5] || { index: 255, opacity: 1.0 };
            state.creationData.appearance.headOverlays[5] = { ...overlay, color: color };
            post('setHeadOverlay', {
                overlayId: 5,
                index: overlay.index,
                opacity: overlay.opacity || 1.0,
                color: color
            });
        });
    }
}

function setupOverlayControls(name, overlayId, max, min = -1) {
    const btns = document.querySelectorAll(`[data-overlay="${name}"]`);
    btns.forEach(btn => {
        btn.addEventListener('click', () => {
            const dir = parseInt(btn.dataset.dir);
            const valueEl = document.getElementById(`${name}-value`);
            let val = parseInt(valueEl.textContent) + dir;
            if (val < min) val = max;
            if (val > max) val = min;
            valueEl.textContent = val;

            // Preserve existing opacity and color from state
            // NOTE: GTA V bug - opacity of exactly 1.0 doesn't work, use 0.99 max
            const existingOverlay = state.creationData.appearance.headOverlays[overlayId] || {};
            let opacity = typeof existingOverlay.opacity === 'number' ? existingOverlay.opacity : 0.99;
            if (opacity <= 0) opacity = 0.99;
            if (opacity >= 1.0) opacity = 0.99;
            const color = typeof existingOverlay.color === 'number' ? existingOverlay.color : 0;

            state.creationData.appearance.headOverlays[overlayId] = {
                index: val === -1 ? 255 : val,
                opacity: opacity,
                color: color
            };

            post('setHeadOverlay', {
                overlayId: overlayId,
                index: val === -1 ? 255 : val,
                opacity: opacity,
                color: color
            });
        });
    });
}

function renderClothingOptions(container) {
    const components = [
        { id: 11, name: 'Tops', type: 'component' },
        { id: 8, name: 'Undershirt', type: 'component' },
        { id: 4, name: 'Pants', type: 'component' },
        { id: 6, name: 'Shoes', type: 'component' },
        { id: 3, name: 'Torso', type: 'component' },
        { id: 7, name: 'Neck/Tie', type: 'component' },
        { id: 5, name: 'Bag', type: 'component' },
        { id: 9, name: 'Armor', type: 'component' },
        { id: 1, name: 'Mask', type: 'component' }
    ];

    const props = [
        { id: 0, name: 'Hats', type: 'prop' },
        { id: 1, name: 'Glasses', type: 'prop' },
        { id: 2, name: 'Earrings', type: 'prop' },
        { id: 6, name: 'Watches', type: 'prop' },
        { id: 7, name: 'Bracelets', type: 'prop' }
    ];

    // Info banner about addon clothing
    let html = '<div style="background: rgba(249, 115, 22, 0.1); border: 1px solid var(--sb-accent); border-radius: 6px; padding: 8px; margin-bottom: 1rem; font-size: 0.75rem; color: var(--sb-text-secondary);">';
    html += '<span style="color: var(--sb-accent); font-weight: 600;">ℹ️ Addon Clothing</span><br>';
    html += 'Some items may appear in wrong categories due to addon pack organization.';
    html += '</div>';

    html += '<h3 style="margin-bottom: 1rem; color: var(--sb-text-secondary); font-size: 0.875rem;">Clothing</h3>';
    components.forEach(comp => {
        const current = state.creationData.appearance.components?.[comp.id]?.drawable ?? -1;
        const compData = state.clothingData?.['comp_' + comp.id];
        const maxVal = Math.max(0, (compData?.maxDrawables ?? 1) - 1);
        html += `
            <div class="sb-input-group">
                <label class="sb-label">${comp.name}</label>
                <div class="number-input-large">
                    <button class="num-btn" data-component="${comp.id}" data-dir="-1">-</button>
                    <span id="component-${comp.id}-value">${current}</span>
                    <button class="num-btn" data-component="${comp.id}" data-dir="1">+</button>
                </div>
                <input type="range" class="sb-slider" id="component-${comp.id}-slider" min="-1" max="${maxVal}" value="${current}" style="margin-top: 4px;">
            </div>
        `;
    });

    html += '<h3 style="margin: 1.5rem 0 1rem 0; color: var(--sb-text-secondary); font-size: 0.875rem;">Accessories</h3>';
    props.forEach(prop => {
        const current = state.creationData.appearance.props?.[prop.id]?.drawable ?? -1;
        const propData = state.clothingData?.['prop_' + prop.id];
        const maxVal = Math.max(0, (propData?.maxDrawables ?? 1) - 1);
        html += `
            <div class="sb-input-group">
                <label class="sb-label">${prop.name}</label>
                <div class="number-input-large">
                    <button class="num-btn" data-prop="${prop.id}" data-dir="-1">-</button>
                    <span id="prop-${prop.id}-value">${current}</span>
                    <button class="num-btn" data-prop="${prop.id}" data-dir="1">+</button>
                </div>
                <input type="range" class="sb-slider" id="prop-${prop.id}-slider" min="-1" max="${maxVal}" value="${current}" style="margin-top: 4px;">
            </div>
        `;
    });

    container.innerHTML = html;

    // Helper: apply component value (shared by buttons + slider)
    function applyComponentValue(compId, val) {
        const valueEl = document.getElementById(`component-${compId}-value`);
        const slider = document.getElementById(`component-${compId}-slider`);
        valueEl.textContent = val;
        if (slider) slider.value = val;

        if (!state.creationData.appearance.components) {
            state.creationData.appearance.components = {};
        }

        if (val === -1) {
            delete state.creationData.appearance.components[compId];
        } else {
            state.creationData.appearance.components[compId] = { drawable: val, texture: 0 };
        }

        post('setComponent', { componentId: compId, drawable: val, texture: 0 });
    }

    // Helper: apply prop value (shared by buttons + slider)
    function applyPropValue(propId, val) {
        const valueEl = document.getElementById(`prop-${propId}-value`);
        const slider = document.getElementById(`prop-${propId}-slider`);
        valueEl.textContent = val;
        if (slider) slider.value = val;

        if (!state.creationData.appearance.props) {
            state.creationData.appearance.props = {};
        }

        if (val === -1) {
            delete state.creationData.appearance.props[propId];
        } else {
            state.creationData.appearance.props[propId] = { drawable: val, texture: 0 };
        }

        post('setProp', { propId: propId, drawable: val, texture: 0 });
    }

    // Setup component buttons + sliders
    components.forEach(comp => {
        const compData = state.clothingData?.['comp_' + comp.id];
        const maxDrawables = compData?.maxDrawables ?? 999;

        // +/- buttons
        document.querySelectorAll(`[data-component="${comp.id}"]`).forEach(btn => {
            btn.addEventListener('click', () => {
                const dir = parseInt(btn.dataset.dir);
                let val = parseInt(document.getElementById(`component-${comp.id}-value`).textContent) + dir;
                if (val < -1) val = -1;
                if (val >= maxDrawables) val = maxDrawables - 1;
                applyComponentValue(comp.id, val);
            });
        });

        // Slider
        const slider = document.getElementById(`component-${comp.id}-slider`);
        if (slider) {
            slider.addEventListener('input', (e) => {
                applyComponentValue(comp.id, parseInt(e.target.value));
            });
        }
    });

    // Setup prop buttons + sliders
    props.forEach(prop => {
        const propData = state.clothingData?.['prop_' + prop.id];
        const maxDrawables = propData?.maxDrawables ?? 999;

        // +/- buttons
        document.querySelectorAll(`[data-prop="${prop.id}"]`).forEach(btn => {
            btn.addEventListener('click', () => {
                const dir = parseInt(btn.dataset.dir);
                let val = parseInt(document.getElementById(`prop-${prop.id}-value`).textContent) + dir;
                if (val < -1) val = -1;
                if (val >= maxDrawables) val = maxDrawables - 1;
                applyPropValue(prop.id, val);
            });
        });

        // Slider
        const slider = document.getElementById(`prop-${prop.id}-slider`);
        if (slider) {
            slider.addEventListener('input', (e) => {
                applyPropValue(prop.id, parseInt(e.target.value));
            });
        }
    });
}

// ============================================
// DELETE MODAL
// ============================================
function openDeleteModal() {
    if (!state.selectedCharacter) return;

    document.getElementById('delete-char-name').textContent =
        `${state.selectedCharacter.firstname} ${state.selectedCharacter.lastname}`;
    document.getElementById('confirm-text').textContent = state.deleteConfirmText;
    document.getElementById('delete-confirm-input').value = '';
    document.getElementById('btn-confirm-delete').disabled = true;
    document.getElementById('delete-modal').classList.remove('hidden');
}

function closeDeleteModal() {
    document.getElementById('delete-modal').classList.add('hidden');
}

// ============================================
// LOADING & TOAST
// ============================================
function showLoading(message = 'Loading...') {
    document.getElementById('loading-message').textContent = message;
    document.getElementById('loading-overlay').classList.remove('hidden');
}

function hideLoading() {
    document.getElementById('loading-overlay').classList.add('hidden');
}

function showToast(message, type = 'info') {
    const container = document.getElementById('toast-container');

    const toast = document.createElement('div');
    toast.className = `toast toast-${type}`;

    const iconName = type === 'success' ? 'check-circle' : type === 'error' ? 'x-circle' : 'alert-circle';

    toast.innerHTML = `
        <i data-lucide="${iconName}" class="toast-icon"></i>
        <div class="toast-content">
            <span class="toast-message">${message}</span>
        </div>
    `;

    container.appendChild(toast);
    lucide.createIcons();

    setTimeout(() => {
        toast.style.animation = 'fadeOut 0.3s ease forwards';
        setTimeout(() => toast.remove(), 300);
    }, 3000);
}

// ============================================
// UTILITIES
// ============================================
function closeUI() {
    document.getElementById('app').classList.add('hidden');
}

function post(event, data = {}) {
    fetch(`https://${getResourceName()}/${event}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    }).catch(err => console.error('NUI Post Error:', err));
}

function formatNumber(num) {
    // Round to 2 decimal places to fix floating point errors
    const rounded = Math.round(num * 100) / 100;
    // Format with commas, show as integer if whole number
    if (rounded % 1 === 0) {
        return Math.floor(rounded).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
    }
    return rounded.toFixed(2).replace(/\d(?=(\d{3})+\.)/g, '$&,');
}

function formatDate(dateStr) {
    if (!dateStr) return 'Never';
    const date = new Date(dateStr);
    const now = new Date();
    const diff = now - date;

    if (diff < 60000) return 'Just now';
    if (diff < 3600000) return `${Math.floor(diff / 60000)} min ago`;
    if (diff < 86400000) return `${Math.floor(diff / 3600000)} hours ago`;
    if (diff < 604800000) return `${Math.floor(diff / 86400000)} days ago`;

    return date.toLocaleDateString();
}

// FiveM NUI helper
function getResourceName() {
    if (typeof GetParentResourceName !== 'undefined') {
        return GetParentResourceName();
    }
    return 'sb_multicharacter';
}

// ============================================
// CHARACTER CONTROLS (Mouse & Keyboard via NUI)
// ============================================
let isDragging = false;
let lastMouseX = 0;

// Right-click drag = Rotate CHARACTER
document.addEventListener('mousedown', (e) => {
    if (e.button === 2 || e.button === 1) { // Right-click or middle-click
        isDragging = true;
        lastMouseX = e.clientX;
        e.preventDefault();
    }
});

document.addEventListener('mousemove', (e) => {
    if (isDragging) {
        const deltaX = e.clientX - lastMouseX;
        if (Math.abs(deltaX) > 1) {
            // Rotate character (positive = right, negative = left)
            post('rotateCharacter', { deltaX: deltaX * 0.3 });
            lastMouseX = e.clientX;
        }
    }
});

document.addEventListener('mouseup', (e) => {
    if (e.button === 2 || e.button === 1) {
        isDragging = false;
    }
});

// Prevent context menu on right-click
document.addEventListener('contextmenu', (e) => {
    e.preventDefault();
});

// Mouse scroll wheel = Actual zoom (camera distance)
// Only zoom if not scrolling inside the UI panel
document.addEventListener('wheel', (e) => {
    // Check if the scroll is inside a scrollable UI element
    const isInsidePanel = e.target.closest('.creation-panel, .character-select, .panel, .style-content, #style-content, .sb-input-group, .spawn-locations, #spawn-locations, .character-list, #character-list');

    // If inside a scrollable panel, let the UI scroll naturally (don't zoom)
    if (isInsidePanel) {
        return;
    }

    if (e.deltaY < 0) {
        // Scroll up = zoom IN (camera closer)
        post('zoomCamera', { direction: -1 });
    } else if (e.deltaY > 0) {
        // Scroll down = zoom OUT (camera further)
        post('zoomCamera', { direction: 1 });
    }
});

// Keyboard controls (Arrow keys)
document.addEventListener('keydown', (e) => {
    switch (e.key) {
        case 'ArrowLeft':
            post('rotateCharacter', { deltaX: -2 });
            e.preventDefault();
            break;
        case 'ArrowRight':
            post('rotateCharacter', { deltaX: 2 });
            e.preventDefault();
            break;
        case 'ArrowUp':
            post('moveCameraVertical', { direction: 1 });
            e.preventDefault();
            break;
        case 'ArrowDown':
            post('moveCameraVertical', { direction: -1 });
            e.preventDefault();
            break;
        case 'r':
        case 'R':
            // Reset camera and character rotation
            post('resetCamera', {});
            break;
    }
});

function updateCameraButtons(focus) {
    document.querySelectorAll('.camera-btn[data-focus]').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.focus === focus);
    });
}

// Add fadeOut animation
const style = document.createElement('style');
style.textContent = `
    @keyframes fadeOut {
        from { opacity: 1; transform: translateX(0); }
        to { opacity: 0; transform: translateX(100%); }
    }
    .number-input-large {
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 1rem;
    }
    .number-input-large .num-btn {
        width: 36px;
        height: 36px;
    }
    .number-input-large span {
        min-width: 40px;
        text-align: center;
        font-size: 1rem;
        font-weight: 600;
        color: var(--sb-accent);
    }
    .slider-value {
        color: var(--sb-accent);
        font-size: 0.75rem;
    }
`;
document.head.appendChild(style);
