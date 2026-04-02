// ============================================================================
// SB Jobs v2 - Employment Center Dashboard
// ============================================================================

let currentMode = null; // 'browse' or 'manage'
let currentTab = 'public';
let currentJob = null;
let publicJobs = [];
let rpListings = [];
let appliedListings = {}; // { "listingId": true } — listings player already applied to
let bossData = null;
let activePublicJob = null;
let hasIdCard = true;
let hasPhone = true;
let detailOpen = false;
let detailType = null; // 'public' or 'rp'
let detailData = null;

// ============================================================================
// NUI MESSAGE HANDLER
// ============================================================================

window.addEventListener('message', (e) => {
    const data = e.data;

    if (data.action === 'open') {
        currentMode = data.mode;

        if (data.mode === 'browse') {
            currentJob = data.currentJob || { name: 'unemployed', label: 'Unemployed', grade: 0, gradeLabel: 'None' };
            publicJobs = data.publicJobs || [];
            rpListings = data.rpListings || [];
            appliedListings = data.appliedListings || {};
            activePublicJob = data.activePublicJob || null;
            hasIdCard = data.hasIdCard !== false;
            hasPhone = data.hasPhone !== false;
            currentTab = 'public';

            document.getElementById('browse-content').style.display = 'flex';
            document.getElementById('manage-content').style.display = 'none';

            renderCurrentJob();
            setActiveTab('public');
            renderPublicJobs();
            renderRPListings();

        } else if (data.mode === 'manage') {
            bossData = data.bossData;
            currentJob = null;

            document.getElementById('browse-content').style.display = 'none';
            document.getElementById('manage-content').style.display = 'flex';

            renderBossPanel();
        }

        closeDetail();
        document.getElementById('container').style.display = 'flex';
    }

    if (data.action === 'close') {
        document.getElementById('container').style.display = 'none';
    }
});

// ============================================================================
// CURRENT JOB BADGE
// ============================================================================

function renderCurrentJob() {
    if (!currentJob) return;
    document.getElementById('current-job-name').textContent = currentJob.label || 'Unemployed';
    const gradeEl = document.getElementById('current-job-grade');
    if (currentJob.name !== 'unemployed' && currentJob.gradeLabel) {
        gradeEl.textContent = currentJob.gradeLabel;
        gradeEl.style.display = 'block';
    } else {
        gradeEl.style.display = 'none';
    }
}

// ============================================================================
// TAB SWITCHING
// ============================================================================

function setActiveTab(tab) {
    currentTab = tab;
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.tab === tab);
    });
    document.querySelectorAll('.tab-content').forEach(el => {
        el.classList.remove('active');
    });
    document.getElementById('tab-content-' + tab).classList.add('active');
    closeDetail();
}

document.getElementById('tab-public').addEventListener('click', () => setActiveTab('public'));
document.getElementById('tab-rp').addEventListener('click', () => setActiveTab('rp'));

// ============================================================================
// PUBLIC JOB CARDS
// ============================================================================

function renderPublicJobs() {
    const grid = document.getElementById('public-jobs-grid');
    document.getElementById('public-job-count').textContent = publicJobs.length + ' available';

    if (publicJobs.length === 0) {
        grid.innerHTML = `
            <div class="no-jobs">
                <i class="fas fa-pizza-slice"></i>
                <p>No public jobs available right now</p>
                <p class="no-jobs-sub">Check back later for new opportunities</p>
            </div>
        `;
        return;
    }

    grid.innerHTML = '';
    publicJobs.forEach(job => {
        const card = document.createElement('div');
        card.className = 'public-job-card';

        const xpProgress = calcXPProgress(job);
        const isActive = activePublicJob === job.id;

        let startBtnHTML;
        if (isActive) {
            startBtnHTML = `<button class="pjc-start-btn in-progress" data-job-id="${job.id}"><i class="fas fa-spinner fa-spin"></i> In Progress</button>`;
        } else if (!hasIdCard) {
            startBtnHTML = `<button class="pjc-start-btn" style="background:var(--negative-dim);color:var(--negative);cursor:default;" disabled><i class="fas fa-id-card"></i> ID Card Required</button>`;
        } else {
            startBtnHTML = `<button class="pjc-start-btn" data-job-id="${job.id}"><i class="fas fa-play"></i> Start Job</button>`;
        }

        card.innerHTML = `
            <div class="pjc-top">
                <div class="pjc-icon">
                    <i class="fas ${job.icon}"></i>
                </div>
                <div class="pjc-info">
                    <div class="pjc-title">${job.label}</div>
                    <div class="pjc-desc">${job.description}</div>
                </div>
            </div>
            <div class="pjc-progress">
                <span class="pjc-level-label">Level ${job.level}/${job.maxLevel}</span>
                <div class="pjc-xp-bar-wrap">
                    <div class="pjc-xp-bar" style="width: ${xpProgress.percent}%"></div>
                </div>
                <span class="pjc-xp-label">${xpProgress.label}</span>
            </div>
            <div class="pjc-footer">
                <span class="pjc-pay">$${job.pay}/delivery</span>
                <span class="pjc-vehicle"><i class="fas fa-motorcycle"></i> ${job.vehicle}</span>
            </div>
            ${startBtnHTML}
        `;

        // Click card to open detail
        card.querySelector('.pjc-top').addEventListener('click', () => openPublicJobDetail(job));
        card.querySelector('.pjc-progress').addEventListener('click', () => openPublicJobDetail(job));
        card.querySelector('.pjc-footer').addEventListener('click', () => openPublicJobDetail(job));

        // Start button
        const startBtn = card.querySelector('.pjc-start-btn');
        if (!startBtn.disabled) {
            startBtn.addEventListener('click', (e) => {
                e.stopPropagation();
                if (isActive) return;
                if (!hasIdCard) return;
                if (activePublicJob) return;
                fetchNUI('startPublicJob', { jobId: job.id });
            });
        }

        grid.appendChild(card);
    });
}

function calcXPProgress(job) {
    if (job.level >= job.maxLevel) {
        return { percent: 100, label: 'MAX' };
    }

    const currentLevelXP = job.xpForCurrentLevel;
    const nextLevelXP = job.xpRequired;
    const xpInLevel = job.xp - currentLevelXP;
    const xpNeeded = nextLevelXP - currentLevelXP;

    if (xpNeeded <= 0) return { percent: 100, label: 'MAX' };

    const percent = Math.min(100, Math.max(0, (xpInLevel / xpNeeded) * 100));
    return {
        percent: percent,
        label: job.xp + '/' + nextLevelXP + ' XP'
    };
}

// ============================================================================
// RP LISTING CARDS
// ============================================================================

function renderRPListings() {
    const grid = document.getElementById('rp-listings-grid');
    document.getElementById('rp-listing-count').textContent = rpListings.length + ' listing' + (rpListings.length !== 1 ? 's' : '');

    if (rpListings.length === 0) {
        grid.innerHTML = `
            <div class="no-jobs">
                <i class="fas fa-building"></i>
                <p>No open positions right now</p>
                <p class="no-jobs-sub">Check back later — employers post new listings when they're hiring</p>
            </div>
        `;
        return;
    }

    grid.innerHTML = '';
    rpListings.forEach(listing => {
        const card = document.createElement('div');
        card.className = 'rp-listing-card';

        const timeAgo = formatTimeAgo(listing.createdAt);
        const payStr = formatPay(listing.pay);
        const alreadyApplied = appliedListings[String(listing.listingId)] === true;

        card.innerHTML = `
            <div class="rlc-top">
                <div class="rlc-icon cat-${listing.category}">
                    <i class="fas ${listing.icon}"></i>
                </div>
                <div class="rlc-info">
                    <div class="rlc-title">${listing.label}</div>
                    <div class="rlc-hiring">Now Hiring!</div>
                    <div class="rlc-poster">Posted by: ${listing.posterName} &middot; ${timeAgo}</div>
                </div>
            </div>
            <div class="rlc-desc">${listing.description}</div>
            <div class="rlc-footer">
                <span class="rlc-pay">${payStr}</span>
                ${alreadyApplied
                    ? `<button class="rlc-apply-btn" style="background:var(--success-dim);color:var(--success);cursor:default;" disabled>
                        <i class="fas fa-check"></i> Applied
                       </button>`
                    : !hasPhone
                    ? `<button class="rlc-apply-btn" style="background:var(--negative-dim);color:var(--negative);cursor:default;" disabled>
                        <i class="fas fa-phone-slash"></i> Phone Required
                       </button>`
                    : `<button class="rlc-apply-btn" data-listing-id="${listing.listingId}">
                        <i class="fas fa-paper-plane"></i> Apply
                       </button>`
                }
            </div>
        `;

        if (!alreadyApplied && hasPhone) {
            card.querySelector('.rlc-apply-btn').addEventListener('click', (e) => {
                e.stopPropagation();
                fetchNUI('applyRPJob', { listingId: listing.listingId });
                // Mark as applied locally
                appliedListings[String(listing.listingId)] = true;
                const btn = card.querySelector('.rlc-apply-btn');
                btn.innerHTML = '<i class="fas fa-check"></i> Applied';
                btn.style.background = 'var(--success-dim)';
                btn.style.color = 'var(--success)';
                btn.style.cursor = 'default';
                btn.disabled = true;
            });
        }

        grid.appendChild(card);
    });
}

// ============================================================================
// BOSS PANEL
// ============================================================================

function renderBossPanel() {
    if (!bossData) return;

    const panel = document.getElementById('boss-panel');
    document.getElementById('boss-panel-title').textContent = bossData.jobLabel + ' — Management';

    const isActive = bossData.listing && bossData.listing.active === true;
    const hasPhone = bossData.hasPhone;

    let html = '';

    // No phone warning
    if (!hasPhone) {
        html += `
            <div class="boss-section">
                <div class="boss-toggle-card" style="border-color: var(--negative); background: var(--negative-dim);">
                    <div class="boss-toggle-info">
                        <div class="boss-toggle-label" style="color: var(--negative);">Phone Required</div>
                        <div class="boss-toggle-status">You need an activated phone to post job listings. Visit a store to get one.</div>
                    </div>
                </div>
            </div>
        `;
        panel.innerHTML = html;
        return;
    }

    html += `
        <div class="boss-section">
            <div class="boss-section-title"><i class="fas fa-megaphone"></i> Hiring Status</div>
            <div class="boss-toggle-card">
                <div class="boss-toggle-info">
                    <div class="boss-toggle-label">${bossData.jobLabel}</div>
                    <div class="boss-toggle-status ${isActive ? 'active' : ''}">
                        ${isActive ? 'Currently hiring — visible at Job Center' : 'Not hiring — listing hidden'}
                    </div>
                </div>
                <button class="boss-toggle-btn ${isActive ? 'close-hiring' : 'open'}" id="boss-toggle-btn">
                    ${isActive ? 'Close Hiring' : 'Open for Hire'}
                </button>
            </div>
        </div>
    `;

    if (isActive && bossData.applications && bossData.applications.length > 0) {
        html += `
            <div class="boss-section">
                <div class="boss-section-title"><i class="fas fa-users"></i> Applications (${bossData.applications.length})</div>
        `;

        bossData.applications.forEach(app => {
            html += `
                <div class="app-card" data-app-id="${app.id}">
                    <div class="app-top-row">
                        <div class="app-info">
                            <div class="app-name">${app.name}</div>
                            <div class="app-phone-row">
                                <div class="app-phone">${app.phone}</div>
                                <button class="app-copy-btn" data-phone="${app.phone}">
                                    <i class="fas fa-copy"></i> Copy
                                </button>
                            </div>
                            <div class="app-date">${formatTimeAgo(app.createdAt)}</div>
                        </div>
                        <span class="app-status ${app.status}">${app.status}</span>
                    </div>
                    <div class="app-actions">
                        <button class="app-action-btn act-interview ${app.status === 'interviewing' ? 'active' : ''}" data-app-id="${app.id}" data-status="interviewing">
                            <i class="fas fa-comments"></i> Interview
                        </button>
                        <button class="app-action-btn act-accept ${app.status === 'accepted' ? 'active' : ''}" data-app-id="${app.id}" data-status="accepted">
                            <i class="fas fa-check"></i> Accept
                        </button>
                        <button class="app-action-btn act-reject ${app.status === 'rejected' ? 'active' : ''}" data-app-id="${app.id}" data-status="rejected">
                            <i class="fas fa-times"></i> Reject
                        </button>
                    </div>
                </div>
            `;
        });

        html += '</div>';
    } else if (isActive) {
        html += `
            <div class="boss-section">
                <div class="boss-section-title"><i class="fas fa-users"></i> Applications</div>
                <div class="no-jobs" style="padding: 30px;">
                    <i class="fas fa-inbox"></i>
                    <p>No applications yet</p>
                    <p class="no-jobs-sub">Players can apply through the Job Center NPC</p>
                </div>
            </div>
        `;
    }

    panel.innerHTML = html;

    // Copy phone buttons
    panel.querySelectorAll('.app-copy-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const phone = btn.dataset.phone;
            navigator.clipboard.writeText(phone).then(() => {
                btn.innerHTML = '<i class="fas fa-check"></i> Copied';
                btn.classList.add('copied');
                setTimeout(() => {
                    btn.innerHTML = '<i class="fas fa-copy"></i> Copy';
                    btn.classList.remove('copied');
                }, 2000);
            }).catch(() => {
                // Fallback for NUI environments where clipboard API may not work
                const input = document.createElement('input');
                input.value = phone;
                document.body.appendChild(input);
                input.select();
                document.execCommand('copy');
                document.body.removeChild(input);
                btn.innerHTML = '<i class="fas fa-check"></i> Copied';
                btn.classList.add('copied');
                setTimeout(() => {
                    btn.innerHTML = '<i class="fas fa-copy"></i> Copy';
                    btn.classList.remove('copied');
                }, 2000);
            });
        });
    });

    // Status action buttons
    panel.querySelectorAll('.app-action-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.stopPropagation();
            const appId = parseInt(btn.dataset.appId);
            const status = btn.dataset.status;
            fetchNUI('updateAppStatus', { appId: appId, status: status });

            // Update local state for immediate feedback
            const app = bossData.applications.find(a => a.id === appId);
            if (app) app.status = status;
            renderBossPanel();
        });
    });

    // Toggle button
    document.getElementById('boss-toggle-btn').addEventListener('click', () => {
        const newState = !isActive;
        fetchNUI('toggleListing', { active: newState });
        // Update local state for immediate feedback
        if (bossData.listing) {
            bossData.listing.active = newState;
        } else {
            bossData.listing = { active: newState };
        }
        if (!newState) {
            bossData.applications = [];
        }
        renderBossPanel();
    });
}

// ============================================================================
// DETAIL PANEL - PUBLIC JOB
// ============================================================================

function openPublicJobDetail(job) {
    detailOpen = true;
    detailType = 'public';
    detailData = job;

    const panel = document.getElementById('detail-panel');
    panel.classList.add('open');

    const body = document.getElementById('detail-body');
    const footer = document.getElementById('detail-footer');

    const xpProgress = calcXPProgress(job);

    let levelsHTML = '';
    (job.levels || []).forEach(lv => {
        const isCurrent = lv.level === job.level;
        const isLocked = lv.level > job.level;
        levelsHTML += `
            <tr class="${isCurrent ? 'current-level' : ''} ${isLocked ? 'locked' : ''}">
                <td>${lv.level}</td>
                <td>${lv.xpRequired} XP</td>
                <td>$${lv.pay}</td>
                <td>${lv.vehicle}</td>
            </tr>
        `;
    });

    body.innerHTML = `
        <div class="detail-icon-wrap">
            <i class="fas ${job.icon}"></i>
        </div>
        <h3 class="detail-job-title">${job.label}</h3>
        <p class="detail-description">${job.description}</p>

        <div class="detail-section">
            <h4><i class="fas fa-chart-line"></i> Your Progress</h4>
            <div class="pjc-progress" style="margin-bottom: 8px;">
                <span class="pjc-level-label">Level ${job.level}/${job.maxLevel}</span>
                <div class="pjc-xp-bar-wrap">
                    <div class="pjc-xp-bar" style="width: ${xpProgress.percent}%"></div>
                </div>
                <span class="pjc-xp-label">${xpProgress.label}</span>
            </div>
            <div style="font-size: 12px; color: var(--text-dim);">${job.totalCompletions} total deliveries completed</div>
        </div>

        <div class="detail-section">
            <h4><i class="fas fa-trophy"></i> Level Milestones</h4>
            <table class="level-table">
                <thead>
                    <tr>
                        <th>Lvl</th>
                        <th>XP</th>
                        <th>Pay</th>
                        <th>Vehicle</th>
                    </tr>
                </thead>
                <tbody>
                    ${levelsHTML}
                </tbody>
            </table>
        </div>
    `;

    const isActive = activePublicJob === job.id;
    if (isActive) {
        footer.innerHTML = `
            <button class="btn-action quit" id="btn-detail-action">
                <i class="fas fa-stop"></i> Quit Job
            </button>
        `;
        document.getElementById('btn-detail-action').addEventListener('click', () => {
            fetchNUI('quitPublicJob');
            closeDetail();
        });
    } else if (!hasIdCard) {
        footer.innerHTML = `
            <button class="btn-action" id="btn-detail-action" style="background:var(--negative-dim);color:var(--negative);cursor:default;" disabled>
                <i class="fas fa-id-card"></i> ID Card Required
            </button>
        `;
    } else {
        footer.innerHTML = `
            <button class="btn-action" id="btn-detail-action">
                <i class="fas fa-play"></i> Start Job
            </button>
        `;
        document.getElementById('btn-detail-action').addEventListener('click', () => {
            if (activePublicJob) return;
            fetchNUI('startPublicJob', { jobId: job.id });
            closeDetail();
        });
    }
}

// ============================================================================
// DETAIL PANEL CLOSE
// ============================================================================

function closeDetail() {
    detailOpen = false;
    detailType = null;
    detailData = null;
    document.getElementById('detail-panel').classList.remove('open');
}

document.getElementById('detail-back').addEventListener('click', closeDetail);

// ============================================================================
// EVENT LISTENERS
// ============================================================================

document.getElementById('btn-close').addEventListener('click', () => {
    fetchNUI('close');
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        if (detailOpen) {
            closeDetail();
        } else {
            fetchNUI('close');
        }
    }
});

// ============================================================================
// HELPERS
// ============================================================================

function formatPay(pay) {
    if (!pay) return '--';
    return '$' + pay.min.toLocaleString() + ' - $' + pay.max.toLocaleString();
}

function formatTimeAgo(dateStr) {
    if (!dateStr) return '';
    const date = new Date(dateStr);
    const now = new Date();
    const diffMs = now - date;
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);

    if (diffMins < 1) return 'Just now';
    if (diffMins < 60) return diffMins + ' min ago';
    if (diffHours < 24) return diffHours + ' hour' + (diffHours !== 1 ? 's' : '') + ' ago';
    if (diffDays < 7) return diffDays + ' day' + (diffDays !== 1 ? 's' : '') + ' ago';
    return date.toLocaleDateString();
}

function fetchNUI(eventName, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${eventName}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    }).catch((err) => {
        console.error('[sb_jobs] NUI fetch failed:', eventName, err);
    });
}
