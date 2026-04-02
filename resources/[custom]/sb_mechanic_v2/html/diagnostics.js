// sb_mechanic_v2 | Diagnostic Tablet JS
// NUI messages, DTC rendering, SVG zone interaction

(function() {
    'use strict';

    const container = document.getElementById('tablet-device');
    const plateDisplay = document.getElementById('plate-display');
    const dtcList = document.getElementById('dtc-list');
    const dtcEmpty = document.getElementById('dtc-empty');
    const codesCount = document.getElementById('codes-count');
    const xpGainEl = document.getElementById('xp-gain');
    const scanTimestamp = document.getElementById('scan-timestamp');
    const btnClose = document.getElementById('btn-close');

    let currentResults = [];

    // ===== NUI MESSAGE HANDLER =====
    window.addEventListener('message', function(event) {
        const data = event.data;
        switch (data.action) {
            case 'open':
                openTablet(data);
                break;
            case 'close':
                closeTablet();
                break;
        }
    });

    // ===== OPEN TABLET =====
    function openTablet(data) {
        container.classList.remove('hidden');

        plateDisplay.textContent = data.plate || '--------';
        scanTimestamp.textContent = data.timestamp || '--:--:--';

        // Update skill pips
        const level = data.diagLevel || 1;
        for (let i = 1; i <= 5; i++) {
            const pip = document.getElementById('pip' + i);
            if (pip) {
                pip.classList.toggle('active', i <= level);
            }
        }

        // XP gain
        if (data.xpGain && data.xpGain > 0) {
            xpGainEl.textContent = '+' + data.xpGain + ' XP';
        } else {
            xpGainEl.textContent = '';
        }

        currentResults = data.results || [];
        renderDTCList(currentResults);
        updateZoneColors(currentResults);
    }

    // ===== CLOSE TABLET =====
    function closeTablet() {
        container.classList.add('hidden');
        currentResults = [];
    }

    // ===== RENDER DTC LIST =====
    function renderDTCList(results) {
        const rows = dtcList.querySelectorAll('.dtc-row');
        rows.forEach(r => r.remove());

        if (!results || results.length === 0) {
            dtcEmpty.classList.remove('hidden');
            codesCount.textContent = '0 codes';
            return;
        }

        dtcEmpty.classList.add('hidden');
        codesCount.textContent = results.length + (results.length === 1 ? ' code' : ' codes');

        // Sort: critical first
        const severityOrder = { critical: 0, warning: 1, info: 2 };
        results.sort((a, b) => {
            const aO = severityOrder[a.severity] !== undefined ? severityOrder[a.severity] : 3;
            const bO = severityOrder[b.severity] !== undefined ? severityOrder[b.severity] : 3;
            return aO - bO;
        });

        results.forEach(dtc => {
            const row = document.createElement('div');
            row.className = 'dtc-row';

            // Top line: code + label + severity + pct
            const topLine = document.createElement('div');
            topLine.className = 'dtc-top-line';

            const codeEl = document.createElement('span');
            codeEl.className = 'dtc-code';
            codeEl.textContent = dtc.code || '????';
            topLine.appendChild(codeEl);

            const labelEl = document.createElement('span');
            labelEl.className = 'dtc-label';
            labelEl.textContent = dtc.label || 'Unknown fault';
            topLine.appendChild(labelEl);

            if (dtc.showSeverity && dtc.severity) {
                const sevEl = document.createElement('span');
                sevEl.className = 'dtc-severity ' + dtc.severity;
                sevEl.textContent = dtc.severity;
                topLine.appendChild(sevEl);
            }

            if (dtc.conditionPct !== undefined && dtc.conditionPct !== null) {
                const pctEl = document.createElement('span');
                pctEl.className = 'dtc-pct';
                pctEl.textContent = dtc.conditionPct + '%';
                topLine.appendChild(pctEl);
            }

            row.appendChild(topLine);

            // Bottom line: required parts/tools (if available)
            const hasPartInfo = dtc.requiredPart || dtc.requiredTool;
            if (hasPartInfo) {
                const needsLine = document.createElement('div');
                needsLine.className = 'dtc-needs-line';

                const needsLabel = document.createElement('span');
                needsLabel.className = 'dtc-needs-label';
                needsLabel.textContent = 'NEEDS:';
                needsLine.appendChild(needsLabel);

                if (dtc.requiredPart) {
                    const partEl = document.createElement('span');
                    partEl.className = 'dtc-needs-part';
                    partEl.textContent = dtc.requiredPart;
                    needsLine.appendChild(partEl);
                }

                if (dtc.requiredTool) {
                    const toolEl = document.createElement('span');
                    toolEl.className = 'dtc-needs-tool';
                    toolEl.textContent = dtc.requiredTool;
                    needsLine.appendChild(toolEl);
                }

                if (dtc.repairSkillReq) {
                    const skillEl = document.createElement('span');
                    skillEl.className = 'dtc-needs-skill';
                    skillEl.textContent = 'L' + dtc.repairSkillReq;
                    needsLine.appendChild(skillEl);
                }

                if (dtc.repairLocation === 'workshop') {
                    const locEl = document.createElement('span');
                    locEl.className = 'dtc-needs-workshop';
                    locEl.textContent = 'SHOP';
                    needsLine.appendChild(locEl);
                }

                row.appendChild(needsLine);
            }

            dtcList.appendChild(row);
        });
    }

    // ===== UPDATE SVG ZONE COLORS =====
    function updateZoneColors(results) {
        const zoneComponents = {
            engine:       ['engine_block', 'spark_plugs', 'air_filter', 'oil_level', 'oil_quality', 'coolant_level', 'radiator', 'turbo'],
            exhaust:      ['oil_quality', 'coolant_level', 'turbo', 'engine_block'],
            body:         ['body_panels', 'windshield', 'headlights', 'taillights'],
            brakes:       ['brake_pads_front', 'brake_pads_rear', 'brake_rotors', 'brake_fluid'],
            suspension:   ['shocks_front', 'shocks_rear', 'springs', 'alignment', 'wheel_bearings'],
            tires:        ['tire_fl', 'tire_fr', 'tire_rl', 'tire_rr', 'wheel_bearings'],
            undercarriage:['oil_level', 'coolant_level', 'trans_fluid', 'brake_fluid'],
        };

        const triggeredComponents = {};
        (results || []).forEach(dtc => {
            const comp = dtc.component;
            if (!comp) return;
            const sev = dtc.severity || 'info';
            const current = triggeredComponents[comp];
            if (!current || sevRank(sev) < sevRank(current)) {
                triggeredComponents[comp] = sev;
            }
        });

        document.querySelectorAll('.zone-hit').forEach(zone => {
            const zoneName = zone.getAttribute('data-zone');
            if (!zoneName) return;

            zone.classList.remove('zone-good', 'zone-warning', 'zone-danger');

            const comps = zoneComponents[zoneName] || [];
            let worst = null;

            comps.forEach(comp => {
                const sev = triggeredComponents[comp];
                if (sev && (!worst || sevRank(sev) < sevRank(worst))) {
                    worst = sev;
                }
            });

            if (worst === 'critical') {
                zone.classList.add('zone-danger');
            } else if (worst === 'warning') {
                zone.classList.add('zone-warning');
            } else if (results && results.length > 0) {
                zone.classList.add('zone-good');
            }
        });
    }

    function sevRank(sev) {
        if (sev === 'critical') return 0;
        if (sev === 'warning') return 1;
        if (sev === 'info') return 2;
        return 3;
    }

    // ===== SVG ZONE CLICKS =====
    document.querySelectorAll('.zone-hit').forEach(zone => {
        zone.addEventListener('click', function() {
            const zoneName = this.getAttribute('data-zone');
            if (!zoneName) return;
            fetch('https://sb_mechanic_v2/inspectZone', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ zone: zoneName }),
            }).catch(() => {});
        });
    });

    // ===== CLOSE BUTTON =====
    btnClose.addEventListener('click', function() {
        fetch('https://sb_mechanic_v2/closeDiagnostics', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({}),
        }).catch(() => {});
    });

    // ===== ESC KEY =====
    document.addEventListener('keydown', function(e) {
        if (e.key === 'Escape') {
            fetch('https://sb_mechanic_v2/closeDiagnostics', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({}),
            }).catch(() => {});
        }
    });

})();
