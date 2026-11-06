let mdtData = null;
let penalCodeData = [];
let activeTab = 'dashboard';
let selectedChargesForIncident = [];
let viewingIncident = null;

const app = document.getElementById('mdt-app');

// ==========================================
// NUI MESSAGE LISTENER
// ==========================================
window.addEventListener('message', (event) => {
    const item = event.data;
    if (item.action === 'open') {
        mdtData = item.data;
        penalCodeData = item.penalCode || [];
        
        if (item.departmentName) {
            document.getElementById('dept-badge').innerText = item.departmentName;
        }

        setupOfficerProfile(item.data.profile);
        renderDashboard(item.data);
        renderPenalCode();
        renderCodes();
        
        app.classList.add('visible');
    } else if (item.action === 'close') {
        app.classList.remove('visible');
    }
});

// Zavření klávesou ESC
window.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        // Pokud je otevřen nějaký modal, zavři pouze modal
        const openModals = document.querySelectorAll('.modal-backdrop.show');
        if (openModals.length > 0) {
            openModals.forEach(m => m.classList.remove('show'));
            return;
        }
        closeMDT();
    }
});

document.getElementById('btn-close-mdt').addEventListener('click', closeMDT);

function closeMDT() {
    fetch(`https://${GetParentResourceName()}/close`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

function GetParentResourceName() {
    return window.GetParentResourceName ? window.GetParentResourceName() : 'fr_mdt';
}

// Živý čas
setInterval(() => {
    const now = new Date();
    document.getElementById('live-clock').innerText = now.toLocaleTimeString('cs-CZ');
}, 1000);

// Přepínání tabů
document.querySelectorAll('.nav-btn').forEach(btn => {
    btn.addEventListener('click', () => {
        const tab = btn.dataset.tab;
        switchTab(tab);
    });
});

function switchTab(tabName) {
    document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'));
    document.querySelectorAll('.tab-pane').forEach(p => p.classList.remove('active'));

    const targetBtn = document.querySelector(`.nav-btn[data-tab="${tabName}"]`);
    if (targetBtn) targetBtn.classList.add('active');

    activeTab = tabName;
    const targetPane = document.getElementById(`pane-${activeTab}`);
    if (targetPane) targetPane.classList.add('active');

    // Auto-refresh při otevření tabu
    if (activeTab === 'dashboard') refreshDashboard();
    if (activeTab === 'warrants') refreshWarrants();
    if (activeTab === 'incidents') refreshIncidents();
    if (activeTab === 'bolos') refreshBolos();
    if (activeTab === 'dispatch') refreshDispatch();
    if (activeTab === 'logs') refreshLogs();
    if (activeTab === 'admin') refreshStaff();
}

// ==========================================
// DŮSTOJNÍK & STATUS & PRÁVA
// ==========================================
function setupOfficerProfile(profile) {
    if (!profile) return;
    document.getElementById('officer-name').innerText = profile.name || 'Důstojník';
    document.getElementById('officer-callsign').innerText = profile.callsign || '1-A-01';
    document.getElementById('officer-role-badge').innerText = (profile.role || 'officer').toUpperCase();
    document.getElementById('unit-status-select').value = profile.status || '10-8';

    const role = profile.role || 'officer';
    const hasSupervisor = (role === 'supervisor' || role === 'command' || role === 'admin');
    const hasAdmin = (role === 'command' || role === 'admin');

    const mgtLabel = document.getElementById('nav-management-label');
    const logsBtn = document.getElementById('nav-btn-logs');
    const adminBtn = document.getElementById('nav-btn-admin');

    if (hasSupervisor) {
        mgtLabel.style.display = 'block';
        logsBtn.style.display = 'flex';
    } else {
        mgtLabel.style.display = 'none';
        logsBtn.style.display = 'none';
    }

    if (hasAdmin) {
        mgtLabel.style.display = 'block';
        adminBtn.style.display = 'flex';
    } else {
        adminBtn.style.display = 'none';
    }
}

document.getElementById('unit-status-select').addEventListener('change', (e) => {
    fetch(`https://${GetParentResourceName()}/setUnitStatus`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ status: e.target.value })
    });
});

document.getElementById('btn-edit-callsign').addEventListener('click', () => {
    const newCallsign = prompt('Zadejte nový volací znak (Callsign):', document.getElementById('officer-callsign').innerText);
    if (newCallsign && newCallsign.trim() !== '') {
        fetch(`https://${GetParentResourceName()}/updateCallsign`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ callsign: newCallsign.trim() })
        }).then(() => {
            document.getElementById('officer-callsign').innerText = newCallsign.trim().toUpperCase();
        });
    }
});

// ==========================================
// 1. DASHBOARD
// ==========================================
function renderDashboard(data) {
    document.getElementById('stat-units').innerText = data.units ? data.units.length : 0;
    document.getElementById('stat-warrants').innerText = data.warrants ? data.warrants.length : 0;
    document.getElementById('stat-bolos').innerText = data.bolos ? data.bolos.length : 0;
    document.getElementById('stat-calls').innerText = data.dispatchCalls ? data.dispatchCalls.length : 0;

    // Jednotky ve službě
    const unitList = document.getElementById('dashboard-unit-list');
    unitList.innerHTML = '';
    (data.units || []).forEach(u => {
        const row = document.createElement('div');
        row.className = 'unit-row';
        row.innerHTML = `
            <div>
                <span class="unit-tag">[${escapeHtml(u.callsign)}]</span>
                <span>${escapeHtml(u.name)} (${escapeHtml(u.department)})</span>
            </div>
            <span class="unit-status-badge status-${u.status}">${u.status}</span>
        `;
        unitList.appendChild(row);
    });

    // Oznámení
    const bulletinList = document.getElementById('dashboard-bulletin-list');
    bulletinList.innerHTML = '';
    (data.bulletins || []).forEach(b => {
        const item = document.createElement('div');
        item.className = 'result-item';
        item.innerHTML = `
            <div class="result-item-title">
                <span>${b.is_pinned ? '<i class="fa-solid fa-thumbtack" style="color:#f59e0b"></i> ' : ''}${escapeHtml(b.title)}</span>
                <span style="font-size: 11px; color: #94a3b8;">${escapeHtml(b.created_at)}</span>
            </div>
            <div style="font-size: 12.5px; color: #cbd5e1; margin: 6px 0;">${escapeHtml(b.content)}</div>
            <div class="result-item-meta">Autor: ${escapeHtml(b.author_name)}</div>
        `;
        bulletinList.appendChild(item);
    });
}

function refreshDashboard() {
    fetch(`https://${GetParentResourceName()}/getDashboard`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).then(res => res.json()).then(data => {
        if (data) renderDashboard(data);
    });
}

document.getElementById('btn-refresh-roster').addEventListener('click', refreshDashboard);

// ==========================================
// 2. OBČANÉ
// ==========================================
document.getElementById('btn-search-citizen').addEventListener('click', searchCitizens);
document.getElementById('citizen-search-input').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') searchCitizens();
});

function searchCitizens() {
    const query = document.getElementById('citizen-search-input').value.trim();
    if (!query) return;

    fetch(`https://${GetParentResourceName()}/searchCitizens`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ query: query })
    }).then(res => res.json()).then(results => {
        const container = document.getElementById('citizen-results-list');
        container.innerHTML = '';

        if (!results || results.length === 0) {
            container.innerHTML = '<div class="empty-state">Žádní občané nenalezeni.</div>';
            return;
        }

        results.forEach(c => {
            const item = document.createElement('div');
            item.className = 'result-item';
            item.innerHTML = `
                <div class="result-item-title">
                    <span>${escapeHtml(c.firstName)} ${escapeHtml(c.lastName)}</span>
                    ${c.activeWarrants > 0 ? '<span class="unit-status-badge status-10-6">WANTED</span>' : ''}
                </div>
                <div class="result-item-meta">ID: ${c.charId} · Nar: ${c.dob || 'N/A'} · Tel: ${c.phoneNumber || 'N/A'}</div>
            `;
            item.addEventListener('click', () => loadCitizenDetail(c.charId));
            container.appendChild(item);
        });
    });
}

function loadCitizenDetail(charId) {
    fetch(`https://${GetParentResourceName()}/getCitizenDetail`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ charId: charId })
    }).then(res => res.json()).then(data => {
        if (!data || !data.citizen) return;

        const c = data.citizen;
        const card = document.getElementById('citizen-detail-card');
        card.style.display = 'block';

        document.getElementById('cd-fullname').innerText = `${c.firstName} ${c.lastName}`;
        document.getElementById('cd-id').innerText = c.charId;
        document.getElementById('cd-dob').innerText = c.dob || '00.00.0000';
        document.getElementById('cd-gender').innerText = c.gender === 'female' ? 'Žena' : 'Muž';
        document.getElementById('cd-phone').innerText = c.phoneNumber || 'Nemá';

        // Tagy & Zatykač
        const tagsContainer = document.getElementById('cd-tags-container');
        tagsContainer.innerHTML = '';
        if (data.warrants && data.warrants.length > 0) {
            tagsContainer.innerHTML += '<span class="charge-pill" style="background:#f43f5e30; color:#f43f5e; border-color:#f43f5e;"><i class="fa-solid fa-handcuffs"></i> AKTIVNÍ ZATYKAČ</span>';
        }

        // Registrované zbraně
        const wepList = document.getElementById('cd-weapons-list');
        wepList.innerHTML = '';
        if (data.weapons && data.weapons.length > 0) {
            data.weapons.forEach(w => {
                const row = document.createElement('div');
                row.className = 'unit-row';
                row.style.marginBottom = '5px';
                row.style.cursor = 'pointer';
                row.innerHTML = `
                    <span><strong style="color:var(--accent)">[${escapeHtml(w.serial)}]</strong> ${escapeHtml(w.label || w.model)}</span>
                    <span>${w.is_stolen ? '<strong style="color:var(--danger)">KRADENÁ</strong>' : '<span style="color:var(--success)">Legální</span>'} · ${w.registered_date}</span>
                `;
                row.onclick = () => {
                    switchTab('weapons');
                    document.getElementById('weapon-search-input').value = w.serial;
                    searchWeapons();
                    loadWeaponDetail(w.serial);
                };
                wepList.appendChild(row);
            });
        } else {
            wepList.innerHTML = '<span style="font-size:12px; color:#64748b;">Žádné registrované zbraně.</span>';
        }

        // Vozidla
        const vehList = document.getElementById('cd-vehicles-list');
        vehList.innerHTML = '';
        if (data.vehicles && data.vehicles.length > 0) {
            data.vehicles.forEach(v => {
                const row = document.createElement('div');
                row.className = 'unit-row';
                row.style.marginBottom = '5px';
                row.style.cursor = 'pointer';
                row.innerHTML = `
                    <span><strong style="color:var(--accent)">[${escapeHtml(v.plate)}]</strong> ${escapeHtml(v.model)}</span>
                    <span>${v.is_stolen ? '<strong style="color:var(--danger)">KRADENÉ</strong>' : (v.fr_state || 'V garáži')}</span>
                `;
                row.onclick = () => {
                    switchTab('vehicles');
                    document.getElementById('vehicle-search-input').value = v.plate;
                    searchVehicles();
                    loadVehicleDetail(v.plate);
                };
                vehList.appendChild(row);
            });
        } else {
            vehList.innerHTML = '<span style="font-size:12px; color:#64748b;">Žádná registrovaná vozidla.</span>';
        }

        // Historie spisů
        const histList = document.getElementById('cd-history-list');
        histList.innerHTML = '';
        if (data.incidents && data.incidents.length > 0) {
            data.incidents.forEach(inc => {
                const row = document.createElement('div');
                row.className = 'result-item';
                row.style.padding = '8px 12px';
                row.style.marginBottom = '5px';
                row.innerHTML = `
                    <div style="font-weight:600; font-size:13px;">${escapeHtml(inc.title)}</div>
                    <div style="font-size:11px; color:#94a3b8;">Pokuta: $${inc.total_fine || 0} · Vězení: ${inc.total_jail || 0} m · ${inc.created_at}</div>
                `;
                row.onclick = () => viewIncident(inc.id);
                histList.appendChild(row);
            });
        } else {
            histList.innerHTML = '<span style="font-size:12px; color:#64748b;">Čistý trestní rejstřík.</span>';
        }

        // Poznámky
        const notesList = document.getElementById('cd-notes-list');
        notesList.innerHTML = '';
        (data.notes || []).forEach(n => {
            notesList.innerHTML += `
                <div class="result-item" style="padding: 8px 12px; margin-bottom: 5px;">
                    <div style="font-size:12.5px;">${escapeHtml(n.note)}</div>
                    <div style="font-size:10.5px; color:#64748b; margin-top:4px;">${escapeHtml(n.author_name)} · ${n.created_at}</div>
                </div>
            `;
        });

        // Tlačítko pro přidání poznámky
        document.getElementById('btn-add-citizen-note').onclick = () => {
            const noteText = prompt('Zadejte poznámku k občanovi:');
            if (noteText && noteText.trim() !== '') {
                fetch(`https://${GetParentResourceName()}/saveCitizenNote`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ charId: c.charId, note: noteText.trim() })
                }).then(() => loadCitizenDetail(c.charId));
            }
        };
    });
}

// ==========================================
// 3. VOZIDLA
// ==========================================
document.getElementById('btn-search-vehicle').addEventListener('click', searchVehicles);
document.getElementById('vehicle-search-input').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') searchVehicles();
});

function searchVehicles() {
    const query = document.getElementById('vehicle-search-input').value.trim();
    if (!query) return;

    fetch(`https://${GetParentResourceName()}/searchVehicles`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ query: query })
    }).then(res => res.json()).then(results => {
        const container = document.getElementById('vehicle-results-list');
        container.innerHTML = '';

        if (!results || results.length === 0) {
            container.innerHTML = '<div class="empty-state">Žádná vozidla nenalezena.</div>';
            return;
        }

        results.forEach(v => {
            const item = document.createElement('div');
            item.className = 'result-item';
            item.innerHTML = `
                <div class="result-item-title">
                    <span style="color:var(--accent)">[${escapeHtml(v.plate)}]</span>
                    <span>${escapeHtml(v.model)}</span>
                </div>
                <div class="result-item-meta">Majitel: ${escapeHtml(v.ownerName || 'Neznámý')} ${v.is_stolen ? '· <strong style="color:var(--danger)">KRADENÉ</strong>' : ''}</div>
            `;
            item.addEventListener('click', () => loadVehicleDetail(v.plate));
            container.appendChild(item);
        });
    });
}

function loadVehicleDetail(plate) {
    fetch(`https://${GetParentResourceName()}/getVehicleDetail`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ plate: plate })
    }).then(res => res.json()).then(data => {
        if (!data || !data.vehicle) return;

        const v = data.vehicle;
        const card = document.getElementById('vehicle-detail-card');
        card.style.display = 'block';

        document.getElementById('vd-plate').innerText = v.plate;
        document.getElementById('vd-model').innerText = v.model;
        
        const ownerEl = document.getElementById('vd-owner');
        ownerEl.innerText = v.ownerName || 'Neznámý / Frakční';
        if (v.owner) {
            ownerEl.onclick = () => {
                switchTab('citizens');
                document.getElementById('citizen-search-input').value = v.owner;
                searchCitizens();
                loadCitizenDetail(v.owner);
            };
        } else {
            ownerEl.onclick = null;
        }

        document.getElementById('vd-vin').innerText = v.vin || '-';
        document.getElementById('vd-state').innerText = v.fr_state === 'impound' ? 'Zabaveno (Impound)' : (v.fr_state || 'V garáži');

        document.getElementById('vd-notes-textarea').value = data.note || '';

        const boloBtn = document.getElementById('btn-toggle-bolo');
        boloBtn.className = data.isStolen ? 'btn-danger btn-sm' : 'btn-outline btn-sm';
        boloBtn.innerHTML = data.isStolen ? '<i class="fa-solid fa-triangle-exclamation"></i> KRADENÉ (BOLO AKTIVNÍ)' : '<i class="fa-solid fa-shield"></i> Označit jako kradené';
        
        boloBtn.onclick = () => {
            const newState = !data.isStolen;
            fetch(`https://${GetParentResourceName()}/setVehicleStolen`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ plate: v.plate, isStolen: newState })
            }).then(() => loadVehicleDetail(v.plate));
        };

        document.getElementById('btn-save-veh-note').onclick = () => {
            const noteVal = document.getElementById('vd-notes-textarea').value;
            fetch(`https://${GetParentResourceName()}/saveVehicleNote`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ plate: v.plate, note: noteVal })
            }).then(() => alert('Poznámka k vozidlu byla uložena.'));
        };
    });
}

// ==========================================
// 4. REGISTR ZBRANÍ
// ==========================================
document.getElementById('btn-search-weapon').addEventListener('click', searchWeapons);
document.getElementById('weapon-search-input').addEventListener('keydown', (e) => {
    if (e.key === 'Enter') searchWeapons();
});

function searchWeapons() {
    const query = document.getElementById('weapon-search-input').value.trim();
    if (!query) return;

    fetch(`https://${GetParentResourceName()}/searchWeapons`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ query: query })
    }).then(res => res.json()).then(results => {
        const container = document.getElementById('weapon-results-list');
        container.innerHTML = '';

        if (!results || results.length === 0) {
            container.innerHTML = '<div class="empty-state">Žádné zbraně nenalezeny.</div>';
            return;
        }

        results.forEach(w => {
            const item = document.createElement('div');
            item.className = 'result-item';
            item.innerHTML = `
                <div class="result-item-title">
                    <span style="color:var(--accent)">[${escapeHtml(w.serial)}]</span>
                    <span>${escapeHtml(w.label || w.model)}</span>
                </div>
                <div class="result-item-meta">Majitel: ${escapeHtml(w.owner_name || 'Neznámý')} ${w.is_stolen ? '· <strong style="color:var(--danger)">KRADENÁ</strong>' : '· <span style="color:var(--success)">Legální</span>'}</div>
            `;
            item.addEventListener('click', () => loadWeaponDetail(w.serial));
            container.appendChild(item);
        });
    });
}

function loadWeaponDetail(serial) {
    fetch(`https://${GetParentResourceName()}/getWeaponDetail`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ serial: serial })
    }).then(res => res.json()).then(w => {
        if (!w) return;

        const card = document.getElementById('weapon-detail-card');
        card.style.display = 'block';

        document.getElementById('wd-serial').innerText = w.serial;
        document.getElementById('wd-label').innerText = w.label || w.model;
        document.getElementById('wd-model').innerText = w.model;

        const ownerEl = document.getElementById('wd-owner');
        ownerEl.innerText = w.owner_name || 'Neznámý';
        if (w.owner_id) {
            ownerEl.onclick = () => {
                switchTab('citizens');
                document.getElementById('citizen-search-input').value = w.owner_id;
                searchCitizens();
                loadCitizenDetail(w.owner_id);
            };
        } else {
            ownerEl.onclick = null;
        }

        document.getElementById('wd-registered').innerText = w.created_at || '-';
        document.getElementById('wd-by').innerText = w.registered_by || 'Systém';

        document.getElementById('wd-ballistics-textarea').value = w.ballistics_notes || '';

        const stolenBtn = document.getElementById('btn-toggle-weapon-stolen');
        stolenBtn.className = w.is_stolen ? 'btn-danger btn-sm' : 'btn-outline btn-sm';
        stolenBtn.innerHTML = w.is_stolen ? '<i class="fa-solid fa-triangle-exclamation"></i> KRADENÁ (HLÁŠENO)' : '<i class="fa-solid fa-shield"></i> Označit jako kradenou';

        stolenBtn.onclick = () => {
            const newState = !w.is_stolen;
            fetch(`https://${GetParentResourceName()}/setWeaponStolen`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ serial: w.serial, isStolen: newState })
            }).then(() => loadWeaponDetail(w.serial));
        };

        document.getElementById('btn-save-ballistics').onclick = () => {
            const notes = document.getElementById('wd-ballistics-textarea').value;
            fetch(`https://${GetParentResourceName()}/saveWeaponBallistics`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ serial: w.serial, notes: notes })
            }).then(() => alert('Balistické záznamy byly uloženy.'));
        };
    });
}

document.getElementById('btn-open-weapon-modal').addEventListener('click', () => {
    document.getElementById('weapon-form-serial').value = '';
    document.getElementById('weapon-form-model').value = '';
    document.getElementById('weapon-form-label').value = '';
    document.getElementById('weapon-form-ownerid').value = '';
    document.getElementById('weapon-form-ownername').value = '';
    document.getElementById('weapon-form-ballistics').value = '';
    document.getElementById('weapon-form-stolen').checked = false;
    openModal('modal-weapon');
});

document.getElementById('btn-confirm-weapon').addEventListener('click', () => {
    const serial = document.getElementById('weapon-form-serial').value.trim();
    const model = document.getElementById('weapon-form-model').value.trim();
    if (!serial || !model) return alert('Zadejte sériové číslo i model zbraně!');

    const payload = {
        serial: serial,
        model: model,
        label: document.getElementById('weapon-form-label').value.trim() || model,
        ownerId: document.getElementById('weapon-form-ownerid').value.trim(),
        ownerName: document.getElementById('weapon-form-ownername').value.trim(),
        ballistics: document.getElementById('weapon-form-ballistics').value.trim(),
        isStolen: document.getElementById('weapon-form-stolen').checked
    };

    fetch(`https://${GetParentResourceName()}/registerWeapon`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
    }).then(() => {
        closeModal('modal-weapon');
        document.getElementById('weapon-search-input').value = serial;
        searchWeapons();
        loadWeaponDetail(serial);
    });
});

// ==========================================
// 5. INCIDENTY & SPISY
// ==========================================
function refreshIncidents() {
    const search = document.getElementById('incident-search-input').value.trim();
    fetch(`https://${GetParentResourceName()}/getIncidents`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ search: search })
    }).then(res => res.json()).then(incidents => {
        const tbody = document.getElementById('incidents-table-body');
        tbody.innerHTML = '';

        if (!incidents || incidents.length === 0) {
            tbody.innerHTML = '<tr><td colspan="8" style="text-align:center; color:#64748b; padding:20px;">Nebyly nalezeny žádné spisy.</td></tr>';
            return;
        }

        incidents.forEach(inc => {
            tbody.innerHTML += `
                <tr>
                    <td><strong>#${inc.id}</strong></td>
                    <td>${escapeHtml(inc.title)}</td>
                    <td>${escapeHtml(inc.creator_name)}</td>
                    <td><strong style="color:var(--success)">$${(inc.total_fine || 0).toLocaleString()}</strong></td>
                    <td><strong style="color:var(--danger)">${inc.total_jail || 0} m</strong></td>
                    <td><span class="unit-status-badge ${inc.status === 'closed' ? 'status-10-8' : 'status-10-6'}">${inc.status === 'closed' ? 'Uzavřený' : 'Otevřený'}</span></td>
                    <td>${inc.created_at}</td>
                    <td><button class="btn-xs btn-outline" onclick="viewIncident(${inc.id})"><i class="fa-solid fa-eye"></i> Zobrazit</button></td>
                </tr>
            `;
        });
    });
}

document.getElementById('incident-search-input').addEventListener('input', () => {
    refreshIncidents();
});

document.getElementById('btn-new-incident').addEventListener('click', () => {
    selectedChargesForIncident = [];
    document.getElementById('inc-form-title').value = '';
    document.getElementById('inc-form-suspect').value = '';
    document.getElementById('inc-form-desc').value = '';
    document.getElementById('inc-form-evidence').value = '';
    document.getElementById('inc-form-status').value = 'open';
    updateSelectedChargesUI();
    openModal('modal-incident');
});

function updateSelectedChargesUI() {
    const pills = document.getElementById('inc-selected-charges');
    pills.innerHTML = '';
    let totalFine = 0;
    let totalJail = 0;

    selectedChargesForIncident.forEach((ch, idx) => {
        totalFine += ch.fine || 0;
        totalJail += ch.jail || 0;
        pills.innerHTML += `
            <span class="charge-pill">
                ${escapeHtml(ch.title)} ($${ch.fine}, ${ch.jail}m)
                <i class="fa-solid fa-xmark" onclick="removeCharge(${idx})"></i>
            </span>
        `;
    });

    document.getElementById('inc-summary-fine').innerText = `$${totalFine.toLocaleString()}`;
    document.getElementById('inc-summary-jail').innerText = `${totalJail} měsíců`;
}

window.removeCharge = function(index) {
    selectedChargesForIncident.splice(index, 1);
    updateSelectedChargesUI();
};

// Vyhledávání a přidávání sazeb do spisu
const chargeSearchInput = document.getElementById('charge-picker-search');
const chargeDropdown = document.getElementById('charge-picker-dropdown');

chargeSearchInput.addEventListener('input', (e) => {
    const q = e.target.value.toLowerCase().trim();
    if (!q) {
        chargeDropdown.style.display = 'none';
        return;
    }

    chargeDropdown.innerHTML = '';
    let matches = 0;

    penalCodeData.forEach(cat => {
        cat.charges.forEach(ch => {
            if (ch.title.toLowerCase().includes(q) || (ch.desc && ch.desc.toLowerCase().includes(q))) {
                matches++;
                const item = document.createElement('div');
                item.className = 'dropdown-charge-item';
                item.innerHTML = `<strong>${escapeHtml(ch.title)}</strong> - $${ch.fine} | ${ch.jail} m<br><small style="color:#94a3b8">${escapeHtml(ch.desc || '')}</small>`;
                item.onclick = () => {
                    selectedChargesForIncident.push(ch);
                    updateSelectedChargesUI();
                    chargeSearchInput.value = '';
                    chargeDropdown.style.display = 'none';
                };
                chargeDropdown.appendChild(item);
            }
        });
    });

    chargeDropdown.style.display = matches > 0 ? 'block' : 'none';
});

document.getElementById('btn-save-incident-confirm').addEventListener('click', () => {
    const title = document.getElementById('inc-form-title').value.trim();
    if (!title) return alert('Zadejte název incidentu!');

    let totalFine = 0;
    let totalJail = 0;
    selectedChargesForIncident.forEach(c => {
        totalFine += c.fine || 0;
        totalJail += c.jail || 0;
    });

    const suspectName = document.getElementById('inc-form-suspect').value.trim();

    const payload = {
        title: title,
        description: document.getElementById('inc-form-desc').value.trim(),
        evidence: document.getElementById('inc-form-evidence').value.trim(),
        suspects: [{ name: suspectName, charges: selectedChargesForIncident }],
        totalFine: totalFine,
        totalJail: totalJail,
        status: document.getElementById('inc-form-status').value
    };

    fetch(`https://${GetParentResourceName()}/saveIncident`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
    }).then(() => {
        closeModal('modal-incident');
        refreshIncidents();
    });
});

window.viewIncident = function(id) {
    fetch(`https://${GetParentResourceName()}/getIncidentDetail`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: id })
    }).then(res => res.json()).then(inc => {
        if (!inc) return;
        viewingIncident = inc;

        document.getElementById('vi-title').innerText = `Spis #${inc.id}: ${inc.title}`;
        document.getElementById('vi-creator').innerText = inc.creator_name;
        document.getElementById('vi-date').innerText = inc.created_at;
        document.getElementById('vi-status').innerHTML = `<span class="unit-status-badge ${inc.status === 'closed' ? 'status-10-8' : 'status-10-6'}">${inc.status === 'closed' ? 'Uzavřený' : 'Otevřený'}</span>`;
        document.getElementById('vi-fine').innerText = `$${(inc.total_fine || 0).toLocaleString()}`;
        document.getElementById('vi-jail').innerText = `${inc.total_jail || 0} měsíců`;

        // Podezřelí & Obvinění
        const suspContainer = document.getElementById('vi-suspects-list');
        suspContainer.innerHTML = '';
        if (inc.suspects && inc.suspects.length > 0) {
            inc.suspects.forEach(s => {
                const sBox = document.createElement('div');
                sBox.style.marginBottom = '8px';
                let chargesPills = '';
                (s.charges || []).forEach(ch => {
                    chargesPills += `<span class="charge-pill">${escapeHtml(ch.title)} ($${ch.fine}, ${ch.jail}m)</span> `;
                });
                sBox.innerHTML = `<div><strong>Podezřelý:</strong> ${escapeHtml(s.name || 'Neznámý')}</div><div style="margin-top:4px;">${chargesPills}</div>`;
                suspContainer.appendChild(sBox);
            });
        } else {
            suspContainer.innerHTML = '<span style="color:#64748b; font-size:12px;">Žádní konkrétní podezřelí uvedeni.</span>';
        }

        document.getElementById('vi-description').innerText = inc.description || 'Bez popisu.';
        document.getElementById('vi-evidence').innerText = inc.evidence || 'Žádné doličné důkazy.';

        const toggleBtn = document.getElementById('btn-toggle-incident-status');
        toggleBtn.innerText = inc.status === 'closed' ? 'Otevřít spis znovu' : 'Uzavřít spis (Pravomocný)';
        toggleBtn.className = inc.status === 'closed' ? 'btn-outline' : 'btn-danger';

        toggleBtn.onclick = () => {
            const newStatus = inc.status === 'closed' ? 'open' : 'closed';
            inc.status = newStatus;
            fetch(`https://${GetParentResourceName()}/saveIncident`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(inc)
            }).then(() => {
                closeModal('modal-view-incident');
                refreshIncidents();
            });
        };

        openModal('modal-view-incident');
    });
};

// ==========================================
// 6. ZATYKAČE (WARRANTS)
// ==========================================
function refreshWarrants() {
    fetch(`https://${GetParentResourceName()}/getWarrants`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).then(res => res.json()).then(warrants => {
        const grid = document.getElementById('warrants-grid-list');
        grid.innerHTML = '';

        if (!warrants || warrants.length === 0) {
            grid.innerHTML = '<div class="empty-state" style="grid-column: 1/-1;">Žádné aktivní celostátní zatykače.</div>';
            return;
        }

        warrants.forEach(w => {
            const card = document.createElement('div');
            card.className = `warrant-card ${w.status}`;
            card.innerHTML = `
                <h3 style="font-size:16px; margin-bottom: 6px;">${escapeHtml(w.suspect_name)}</h3>
                <div style="font-size:12px; color:var(--text-muted); margin-bottom: 8px;">Důvod: <strong style="color:#fff">${escapeHtml(w.reason)}</strong></div>
                <div style="font-size:11.5px; color:#94a3b8;">Vydal: ${escapeHtml(w.creator_name)} · Vyprší: ${w.expires_at}</div>
                <div style="margin-top: 12px; display: flex; justify-content: space-between; align-items: center;">
                    <span class="unit-status-badge ${w.status === 'active' ? 'status-10-6' : 'status-10-7'}">${w.status === 'active' ? 'AKTIVNÍ' : 'VYŘÍZEN'}</span>
                    ${w.status === 'active' ? `<button class="btn-xs btn-outline" onclick="executeWarrant(${w.id})">Vyřídit</button>` : ''}
                </div>
            `;
            grid.appendChild(card);
        });
    });
}

document.getElementById('btn-create-warrant').addEventListener('click', () => {
    openModal('modal-warrant');
});

document.getElementById('btn-confirm-warrant').addEventListener('click', () => {
    const payload = {
        suspectName: document.getElementById('warrant-form-name').value.trim(),
        suspectId: document.getElementById('warrant-form-charid').value.trim(),
        reason: document.getElementById('warrant-form-reason').value.trim(),
        days: document.getElementById('warrant-form-days').value
    };

    if (!payload.suspectName || !payload.suspectId) return alert('Vyplňte jméno i ID podezřelého!');

    fetch(`https://${GetParentResourceName()}/createWarrant`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
    }).then(() => {
        closeModal('modal-warrant');
        refreshWarrants();
    });
});

window.executeWarrant = function(id) {
    fetch(`https://${GetParentResourceName()}/setWarrantStatus`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id: id, status: 'executed' })
    }).then(() => refreshWarrants());
};

// ==========================================
// 7. AKTIVNÍ BOLOS
// ==========================================
function refreshBolos() {
    fetch(`https://${GetParentResourceName()}/getBolos`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).then(res => res.json()).then(bolos => {
        const grid = document.getElementById('bolos-grid-list');
        grid.innerHTML = '';

        if (!bolos || bolos.length === 0) {
            grid.innerHTML = '<div class="empty-state" style="grid-column: 1/-1;">V San Andreas nejsou vyhlášena žádná hlášení BOLO.</div>';
            return;
        }

        bolos.forEach(b => {
            const card = document.createElement('div');
            card.className = `bolo-card danger-${b.danger_level || 'medium'}`;

            let typeLabel = 'Osoba';
            let typeColor = 'status-10-8';
            if (b.type === 'vehicle') { typeLabel = 'Vozidlo'; typeColor = 'status-10-97'; }
            if (b.type === 'other') { typeLabel = 'Jiné'; typeColor = 'status-10-6'; }

            card.innerHTML = `
                <div class="bolo-header">
                    <span class="bolo-type-badge unit-status-badge ${typeColor}">${typeLabel}</span>
                    <span style="font-size: 11px; color: #94a3b8;">${b.created_at}</span>
                </div>
                <div class="bolo-title">${escapeHtml(b.title)}</div>
                <div class="bolo-meta-row">
                    ${b.target_name ? `<span>Cíl: <strong>${escapeHtml(b.target_name)}</strong></span> ` : ''}
                    ${b.plate ? `<span>SPZ: <strong style="color:var(--accent)">[${escapeHtml(b.plate)}]</strong></span>` : ''}
                </div>
                <div class="bolo-reason">${escapeHtml(b.reason)}</div>
                <div style="display:flex; justify-content:space-between; align-items:center; font-size:11.5px; color:#94a3b8;">
                    <span>Vydal: <strong>${escapeHtml(b.creator_name)}</strong></span>
                    <button class="btn-xs btn-outline" onclick="deleteBolo(${b.id})"><i class="fa-solid fa-trash"></i> Smazat BOLO</button>
                </div>
            `;
            grid.appendChild(card);
        });
    });
}

document.getElementById('btn-create-bolo').addEventListener('click', () => {
    document.getElementById('bolo-form-title').value = '';
    document.getElementById('bolo-form-target').value = '';
    document.getElementById('bolo-form-plate').value = '';
    document.getElementById('bolo-form-reason').value = '';
    openModal('modal-bolo');
});

document.getElementById('btn-confirm-bolo').addEventListener('click', () => {
    const title = document.getElementById('bolo-form-title').value.trim();
    const reason = document.getElementById('bolo-form-reason').value.trim();
    if (!title || !reason) return alert('Zadejte titulek i důvod BOLO!');

    const payload = {
        type: document.getElementById('bolo-form-type').value,
        dangerLevel: document.getElementById('bolo-form-danger').value,
        title: title,
        targetName: document.getElementById('bolo-form-target').value.trim(),
        plate: document.getElementById('bolo-form-plate').value.trim(),
        reason: reason
    };

    fetch(`https://${GetParentResourceName()}/createBolo`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
    }).then(() => {
        closeModal('modal-bolo');
        refreshBolos();
    });
});

window.deleteBolo = function(id) {
    if (confirm('Opravdu chcete smazat toto hlášení BOLO?')) {
        fetch(`https://${GetParentResourceName()}/deleteBolo`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id: id })
        }).then(() => refreshBolos());
    }
};

// ==========================================
// 8. KÓDY A VOLACÍ ZNAKY (CODES & DIVISIONS)
// ==========================================
function renderCodes() {
    // 10-Codes
    const codesContainer = document.getElementById('tencodes-container');
    codesContainer.innerHTML = '';

    const tenCodes = (mdtData && mdtData.tenCodes) ? mdtData.tenCodes : [
        { code: '10-4', title: 'Rozumím / Přijato', desc: 'Potvrzení příjmu zprávy.' },
        { code: '10-6', title: 'Zaneprázdněn', desc: 'Jednotka řeší úkon, nevolejte.' },
        { code: '10-7', title: 'Konec služby', desc: 'Odhlášení ze směny.' },
        { code: '10-8', title: 'Ve službě / K dispozici', desc: 'Připraven k výjezdu.' },
        { code: '10-13', title: 'DŮSTOJNÍK V NOUZI', desc: 'Officer down! Okamžitá podpora!' },
        { code: '10-20', title: 'Poloha jednotky', desc: 'Dotaz na aktuální GPS pozici.' },
        { code: '10-31', title: 'Probíhající loupež', desc: 'Probíhá přepadení obchodu/banky.' },
        { code: '10-43', title: 'Zraněná osoba / Lékař', desc: 'Požadavek na sanitku EMS.' },
        { code: '10-50', title: 'Dopravní nehoda', desc: 'Havárie vozidel na silnici.' },
        { code: '10-60', title: 'Krádež vozidla', desc: 'Zjištěno odcizení motorového vozidla.' },
        { code: '10-70', title: 'Požár', desc: 'Zahoření budovy nebo vozidla.' },
        { code: '10-71', title: 'Střelba', desc: 'Hlášeny výstřely v lokalitě.' },
        { code: '10-97', title: 'Na místě hlášení', desc: 'Jednotka dorazila na scénu.' },
        { code: '10-99', title: 'PANIC BUTTON', desc: 'Extrémní nouze, ohrožení života.' }
    ];

    tenCodes.forEach(tc => {
        const row = document.createElement('div');
        row.className = 'tencode-row';
        row.innerHTML = `
            <span class="tencode-code">${escapeHtml(tc.code)}</span>
            <div class="tencode-desc">
                <strong>${escapeHtml(tc.title)}</strong>
                <div style="font-size:11px; color:#94a3b8;">${escapeHtml(tc.desc || '')}</div>
            </div>
        `;
        codesContainer.appendChild(row);
    });

    // Divisions
    const divContainer = document.getElementById('divisions-container');
    divContainer.innerHTML = '';

    const divisions = (mdtData && mdtData.divisions) ? mdtData.divisions : [
        { code: 'ADAM (A)', name: 'Dvoučlenná hlídka (Patrol)', desc: 'Základní motorizovaná jednotka ve dvou důstojnících.' },
        { code: 'BOY (B)', name: 'Dvoučlenná hlídka - Supervisor', desc: 'Vozidlo velitele směny / seržanta.' },
        { code: 'LINCOLN (L)', name: 'Jednočlenná hlídka', desc: 'Samostatná hlídková jednotka.' },
        { code: 'MARY (M)', name: 'Dopravní divize / Motohlídka', desc: 'Hlídkování na motocyklu a dopravní kontroly.' },
        { code: 'AIR (AIR)', name: 'Letecká podpora (ASU)', desc: 'Policejní vrtulník a vzdušné sledování.' },
        { code: 'DAVID (D)', name: 'Speciální jednotka (SWAT)', desc: 'Taktická zásahová skupina.' },
        { code: 'DETECTIVE (DB)', name: 'Kriminální vyšetřovací divize', desc: 'Detektivové, vyšetřování závažných trestných činů.' },
        { code: 'MEDIC (EMS)', name: 'Záchranná zdravotnická služba', desc: 'Sanitní vozy a záchranáři.' }
    ];

    divisions.forEach(d => {
        const item = document.createElement('div');
        item.className = 'division-item';
        item.innerHTML = `
            <div>
                <strong>${escapeHtml(d.name)}</strong>
                <div style="font-size:11.5px; color:#94a3b8;">${escapeHtml(d.desc)}</div>
            </div>
            <span class="division-badge">${escapeHtml(d.code)}</span>
        `;
        divContainer.appendChild(item);
    });
}

document.getElementById('codes-filter-input').addEventListener('input', (e) => {
    const q = e.target.value.toLowerCase().trim();
    document.querySelectorAll('.tencode-row').forEach(row => {
        row.style.display = row.innerText.toLowerCase().includes(q) ? 'flex' : 'none';
    });
});

// ==========================================
// 9. SAZEBNÍK TRESTŮ (PENAL CODE)
// ==========================================
function renderPenalCode() {
    const container = document.getElementById('penalcode-list');
    container.innerHTML = '';

    penalCodeData.forEach(cat => {
        const catCard = document.createElement('div');
        catCard.className = 'penal-cat-card';

        let chargesHtml = '';
        cat.charges.forEach(ch => {
            chargesHtml += `
                <div class="penal-item">
                    <div>
                        <strong>${escapeHtml(ch.title)}</strong>
                        <div style="font-size:11.5px; color:#94a3b8;">${escapeHtml(ch.desc)}</div>
                    </div>
                    <div style="text-align: right; min-width: 140px;">
                        <span style="color:var(--success); font-weight:700;">$${ch.fine.toLocaleString()}</span>
                        ${ch.jail > 0 ? ` · <span style="color:var(--danger); font-weight:700;">${ch.jail} m</span>` : ''}
                    </div>
                </div>
            `;
        });

        catCard.innerHTML = `
            <div class="penal-cat-header" style="background: ${cat.color}20; color: ${cat.color}; border-left: 4px solid ${cat.color};">
                <i class="fa-solid fa-scale-balanced"></i>
                ${escapeHtml(cat.category)}
            </div>
            ${chargesHtml}
        `;
        container.appendChild(catCard);
    });
}

document.getElementById('penalcode-search-input').addEventListener('input', (e) => {
    const q = e.target.value.toLowerCase().trim();
    document.querySelectorAll('.penal-item').forEach(item => {
        const text = item.innerText.toLowerCase();
        item.style.display = text.includes(q) ? 'flex' : 'none';
    });
});

// ==========================================
// 10. DISPATCH ZÁZNAM
// ==========================================
function refreshDispatch() {
    fetch(`https://${GetParentResourceName()}/getDashboard`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).then(res => res.json()).then(data => {
        const container = document.getElementById('dispatch-feed-container');
        container.innerHTML = '';

        const calls = data.dispatchCalls || [];
        if (calls.length === 0) {
            container.innerHTML = '<div class="empty-state">Žádná aktivní tísňová hlášení.</div>';
            return;
        }

        calls.forEach(call => {
            const card = document.createElement('div');
            card.className = 'result-item';
            card.style.marginBottom = '10px';
            card.innerHTML = `
                <div class="result-item-title">
                    <span style="color:${call.color || 'var(--accent)'}"><i class="${call.icon || 'fa-solid fa-bell'}"></i> [${escapeHtml(call.code || '10-00')}] ${escapeHtml(call.title)}</span>
                    <span style="font-size:11px; color:#94a3b8;">${call.time} (#${call.id})</span>
                </div>
                <div style="font-size:12.5px; margin: 4px 0;"><i class="fa-solid fa-location-dot" style="color:#64748b"></i> ${escapeHtml(call.street || '')} ${call.zone ? `· ${escapeHtml(call.zone)}` : ''}</div>
                <div style="font-size:12px; color:#cbd5e1;">${escapeHtml(call.description || '')}</div>
                <div style="margin-top: 8px; display: flex; justify-content: flex-end;">
                    <button class="btn-xs btn-primary" onclick="setGps(${call.coords.x}, ${call.coords.y})"><i class="fa-solid fa-location-arrow"></i> Nastavit GPS</button>
                </div>
            `;
            container.appendChild(card);
        });
    });
}

window.setGps = function(x, y) {
    fetch(`https://${GetParentResourceName()}/setGps`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ x: x, y: y })
    });
};

// ==========================================
// 11. AUDIT LOGY (ZÁZNAMY)
// ==========================================
function refreshLogs() {
    const search = document.getElementById('logs-search-input').value.trim();
    fetch(`https://${GetParentResourceName()}/getAuditLogs`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ search: search })
    }).then(res => res.json()).then(logs => {
        const tbody = document.getElementById('logs-table-body');
        tbody.innerHTML = '';

        if (!logs || logs.length === 0) {
            tbody.innerHTML = '<tr><td colspan="5" style="text-align:center; color:#64748b; padding:20px;">Žádné záznamy nenalezeny.</td></tr>';
            return;
        }

        logs.forEach(l => {
            tbody.innerHTML += `
                <tr>
                    <td><strong>#${l.id}</strong></td>
                    <td style="font-size:11.5px; color:#94a3b8;">${l.created_at}</td>
                    <td><strong>${escapeHtml(l.officer_name)}</strong></td>
                    <td><span class="log-action-badge log-${l.action}">${escapeHtml(l.action)}</span></td>
                    <td style="font-size:12.5px; color:#cbd5e1;">${escapeHtml(l.details)}</td>
                </tr>
            `;
        });
    });
}

document.getElementById('btn-refresh-logs').addEventListener('click', refreshLogs);
document.getElementById('logs-search-input').addEventListener('input', refreshLogs);

// ==========================================
// 12. ADMINISTRACE & PERSONÁL
// ==========================================
function refreshStaff() {
    fetch(`https://${GetParentResourceName()}/getStaffList`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    }).then(res => res.json()).then(staff => {
        const tbody = document.getElementById('staff-table-body');
        tbody.innerHTML = '';

        if (!staff || staff.length === 0) {
            tbody.innerHTML = '<tr><td colspan="7" style="text-align:center; color:#64748b; padding:20px;">Žádný personál nenalezen nebo nemáte dostatečná oprávnění.</td></tr>';
            return;
        }

        staff.forEach(s => {
            const row = document.createElement('tr');
            row.innerHTML = `
                <td><strong>${s.charId}</strong></td>
                <td>${escapeHtml(s.firstName)} ${escapeHtml(s.lastName)}</td>
                <td><span class="badge-dept" style="font-size:10px;">${(s.job_name || 'POLICE').toUpperCase()}</span></td>
                <td>${s.job_grade || 0}</td>
                <td><strong style="color:var(--accent)">[${escapeHtml(s.callsign)}]</strong></td>
                <td><span class="officer-role-badge">${(s.mdt_role || 'officer').toUpperCase()}</span></td>
                <td><button class="btn-xs btn-outline btn-edit-role"><i class="fa-solid fa-pen-to-square"></i> Změnit roli</button></td>
            `;

            row.querySelector('.btn-edit-role').onclick = () => {
                openRoleModal(s);
            };

            tbody.appendChild(row);
        });
    });
}

document.getElementById('btn-refresh-staff').addEventListener('click', refreshStaff);

function openRoleModal(staffMember) {
    document.getElementById('role-form-name').value = `${staffMember.firstName} ${staffMember.lastName} (CharID: ${staffMember.charId})`;
    document.getElementById('role-form-charid').value = staffMember.charId;
    document.getElementById('role-form-select').value = staffMember.mdt_role || 'officer';
    updateRoleDescription(staffMember.mdt_role || 'officer');
    openModal('modal-role');
}

document.getElementById('role-form-select').addEventListener('change', (e) => {
    updateRoleDescription(e.target.value);
});

function updateRoleDescription(role) {
    const info = document.getElementById('role-permissions-info');
    const descriptions = {
        officer: '<strong>Základní přístup (Officer):</strong> Vyhledávání občanů a vozidel, přidávání poznámek, vytváření incidentů, prohlížení sazebníku.',
        detective: '<strong>Kriminálka (Detective):</strong> Přístup do registru zbraní, balistických stop, vytváření a editace incidentů a zatykačů.',
        supervisor: '<strong>Vedení směny (Supervisor):</strong> Vydávání zatykačů, vyhlašování BOLO, prohlížení auditních záznamů MDT (Logs).',
        command: '<strong>Vysoké velení (Command):</strong> Správa personálu a přidělování rolí, mazání BOLO, plný přístup do audit logů.',
        admin: '<strong>Systémový administrátor:</strong> Kompletní neomezený přístup ke všem modulům a databázovým funkcím.'
    };
    info.innerHTML = descriptions[role] || 'Standardní přístup.';
}

document.getElementById('btn-confirm-role').addEventListener('click', () => {
    const charId = document.getElementById('role-form-charid').value;
    const newRole = document.getElementById('role-form-select').value;

    fetch(`https://${GetParentResourceName()}/setOfficerRole`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ charId: charId, role: newRole })
    }).then(() => {
        closeModal('modal-role');
        refreshStaff();
    });
});

// ==========================================
// MODAL OKNA & OZNÁMENÍ
// ==========================================
document.getElementById('btn-add-bulletin').addEventListener('click', () => {
    openModal('modal-bulletin');
});

document.getElementById('btn-confirm-bulletin').addEventListener('click', () => {
    const title = document.getElementById('bulletin-form-title').value.trim();
    const content = document.getElementById('bulletin-form-content').value.trim();
    const isPinned = document.getElementById('bulletin-form-pinned').checked;

    if (!title || !content) return alert('Vyplňte titulek i text oznámení!');

    fetch(`https://${GetParentResourceName()}/saveBulletin`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ title: title, content: content, isPinned: isPinned })
    }).then(() => {
        closeModal('modal-bulletin');
        refreshDashboard();
    });
});

function openModal(id) {
    const modal = document.getElementById(id);
    if (modal) modal.classList.add('show');
}

function closeModal(id) {
    const modal = document.getElementById(id);
    if (modal) modal.classList.remove('show');
}

document.querySelectorAll('[data-close]').forEach(btn => {
    btn.addEventListener('click', () => {
        closeModal(btn.dataset.close);
    });
});

function escapeHtml(str) {
    if (!str) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}