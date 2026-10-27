let selectedPlayerId = null;
let selectedAdminName = null;
let selectedReportId = null;
let menuOpen = false;

const IN_GAME = typeof GetParentResourceName === 'function';

// --- KOMUNIKACE S LUA (NUI) ---
function sendNUI(action, payload = {}) {
    if (!IN_GAME) {
        console.log(`[Mock NUI] ${action}`, payload);
        return Promise.resolve(null);
    }
    return fetch(`https://${GetParentResourceName()}/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(payload)
    })
        .then(r => r.json())
        .catch(err => {
            console.error('Chyba NUI komunikace:', err);
            return null;
        });
}

// Odešle akci na server. Vrací true, pokud ji server provedl (mimo hru vždy true kvůli testování).
async function act(payload) {
    const res = await sendNUI('executeAction', payload);
    return !IN_GAME || (res !== null && res.ok === true);
}

function setVisible(visible) {
    menuOpen = visible;
    document.body.style.display = visible ? '' : 'none';
}

function closeNUI() {
    setVisible(false);
    sendNUI('closeMenu');
}

// --- OZNÁMENÍ: celé je to ox_lib (lib.notify) na straně Lua ---
const NOTIFY_TYPES = { default: 'inform', success: 'success', danger: 'error', warning: 'warning' };
function notify(message, type = 'default', duration) {
    if (!IN_GAME) {
        console.log(`[Notify:${type}] ${message}`);
        return;
    }
    sendNUI('notify', { message, type: NOTIFY_TYPES[type] || 'inform', duration });
}

// --- DIALOGY (náhrada za confirm()/prompt(), které ve FiveM CEF nefungují) ---
let dialogResolve = null;

function closeDialog(result) {
    document.getElementById('dialogModal')?.classList.remove('show');
    if (dialogResolve) {
        const resolve = dialogResolve;
        dialogResolve = null;
        resolve(result);
    }
}

function openDialog({ title, message, input = false, placeholder = '', okLabel = 'Potvrdit' }) {
    return new Promise(resolve => {
        if (dialogResolve) closeDialog(input ? null : false);
        dialogResolve = resolve;

        const modal = document.getElementById('dialogModal');
        const field = document.getElementById('dialogInput');
        document.getElementById('dialogTitle').innerText = title;
        document.getElementById('dialogMessage').innerText = message;
        document.getElementById('dialogOk').innerText = okLabel;

        field.classList.toggle('hidden', !input);
        field.value = '';
        field.placeholder = placeholder;
        modal.classList.add('show');
        setTimeout(() => (input ? field : document.getElementById('dialogOk')).focus(), 30);
    });
}

const askConfirm = (message) => openDialog({ title: 'Potvrzení', message });
const askText = (message, placeholder = '') => openDialog({ title: 'Zadej hodnotu', message, input: true, placeholder, okLabel: 'Odeslat' });

// Jednoduchý escape proti XSS při vkládání textu do innerHTML
const HTML_ESCAPE_MAP = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
function escapeHtml(str) {
    return String(str ?? '').replace(/[&<>"']/g, ch => HTML_ESCAPE_MAP[ch]);
}

// Globální handlery pro inline onclicky z HTML
window.closeReportModal = () => document.getElementById('createReportModal')?.classList.remove('show');
window.closeChatModal = () => document.getElementById('chatModal')?.classList.remove('show');

document.addEventListener("DOMContentLoaded", () => {
    if (!IN_GAME) setVisible(true);
    const closeMenuBtn = document.getElementById('closeMenuBtn');
    const navItems = document.querySelectorAll('.nav-item');
    const sections = document.querySelectorAll('main > section');

    // Aktuální rok v patičce
    const yearElem = document.getElementById('year');
    if (yearElem) yearElem.innerText = new Date().getFullYear();

    // --- PŘEPÍNÁNÍ TABŮ ---
    navItems.forEach(item => {
        item.addEventListener('click', (e) => {
            e.preventDefault();
            const targetId = item.getAttribute('data-target');
            if (!targetId) return;

            navItems.forEach(nav => nav.classList.remove('active'));
            item.classList.add('active');

            sections.forEach(sec => {
                sec.classList.add('hidden');
                sec.classList.remove('show');
            });

            const activeSection = document.getElementById(targetId);
            if (activeSection) {
                activeSection.classList.remove('hidden');
                setTimeout(() => activeSection.classList.add('show'), 10);
            }
        });
    });

    // --- SPRÁVA HRÁČE (MODAL) ---
    const modal = document.getElementById('playerModal');
    const modalTitle = document.getElementById('modalPlayerName');
    const closeModalBtn = document.getElementById('closeModalBtn');
    const btnPedMenu = document.getElementById('btnPedMenu');
    const btnLogout = document.getElementById('btnLogout');

    const resetPlayerModalState = () => {
        const freezeBtn = document.getElementById('btnFreezePlayer');
        if (freezeBtn) {
            freezeBtn.setAttribute('data-frozen', 'false');
            freezeBtn.innerText = 'Zamknout (Freeze)';
        }
        const noteInput = document.getElementById('staffNoteInput');
        if (noteInput) noteInput.value = '';
        const warnInput = document.getElementById('warnReasonInput');
        if (warnInput) warnInput.value = '';
    };

    const openPlayerModal = (playerId, playerName, isOffline = false) => {
        selectedPlayerId = playerId;
        if (modalTitle) {
            modalTitle.innerText = isOffline
                ? `Offline správa: ${playerName}`
                : `Správa: ${playerName} (ID: ${playerId})`;
        }
        resetPlayerModalState();
        if (modal) modal.classList.add('show');
        if (!isOffline) loadPlayerDetail(playerId);
    };

    document.querySelectorAll('.btn-modal[data-player]').forEach(btn => {
        btn.addEventListener('click', (e) => {
            const target = e.currentTarget;
            openPlayerModal(
                target.getAttribute('data-player'),
                target.getAttribute('data-name'),
                target.getAttribute('data-offline') === 'true'
            );
        });
    });

    if (closeModalBtn && modal) {
        closeModalBtn.addEventListener('click', () => {
            modal.classList.remove('show');
            selectedPlayerId = null;
        });
    }

    if (btnPedMenu) {
        btnPedMenu.addEventListener('click', async () => {
            if (!selectedPlayerId) return;
            if (!await act({ action: 'forceCommand', playerId: selectedPlayerId, command: 'pedmenu' })) return;
            notify('PedMenu vynuceno hráči.', 'success');
        });
    }

    if (btnLogout) {
        btnLogout.addEventListener('click', async () => {
            if (!selectedPlayerId) return;
            if (!await askConfirm('Opravdu chceš tohoto hráče odhlásit ze serveru?')) return;
            if (!await act({ action: 'forceLogout', playerId: selectedPlayerId })) return;
            notify('Hráč byl odhlášen.', 'warning');
            modal?.classList.remove('show');
        });
    }

    // --- SPRÁVA VOZIDLA (MODAL) ---
    let selectedVehiclePlate = null;
    const vehicleModal = document.getElementById('vehicleModal');
    const modalVehicleTitle = document.getElementById('modalVehicleTitle');
    const closeVehicleModalBtn = document.getElementById('closeVehicleModalBtn');
    const btnToggleVehicleLock = document.getElementById('btnToggleVehicleLock');
    const btnToggleImpound = document.getElementById('btnToggleImpound');
    const btnDeleteVehicleModal = document.getElementById('btnDeleteVehicleModal');
    const btnTransferVehicleOwner = document.getElementById('btnTransferVehicleOwner');
    const btnSaveVehicleNote = document.getElementById('btnSaveVehicleNote');

    const openVehicleModal = (btn) => {
        selectedVehiclePlate = btn.getAttribute('data-plate');
        const model = btn.getAttribute('data-model') || 'Neznámý model';
        const owner = btn.getAttribute('data-owner') || 'Neznámý majitel';
        const vin = btn.getAttribute('data-vin') || '–';
        const fuel = btn.getAttribute('data-fuel') || '–';
        const engine = btn.getAttribute('data-engine') || '–';
        const body = btn.getAttribute('data-body') || '–';
        const status = btn.getAttribute('data-status') || '–';
        const locked = btn.getAttribute('data-locked') === 'true';
        const impounded = btn.getAttribute('data-impounded') === 'true';

        if (modalVehicleTitle) modalVehicleTitle.innerText = `Vozidlo: ${model} (${selectedVehiclePlate})`;
        document.getElementById('modalVehiclePlate').innerText = selectedVehiclePlate;
        document.getElementById('modalVehicleVin').innerText = vin;
        document.getElementById('modalVehicleModel').innerText = model;
        document.getElementById('modalVehicleOwner').innerText = owner;
        document.getElementById('modalVehicleFuel').innerText = `${fuel}%`;
        document.getElementById('modalVehicleEngine').innerText = `${engine}%`;
        document.getElementById('modalVehicleBody').innerText = `${body}%`;
        document.getElementById('modalVehicleStatus').innerText = status;

        if (btnToggleVehicleLock) {
            btnToggleVehicleLock.setAttribute('data-locked', String(locked));
            btnToggleVehicleLock.innerText = locked ? 'Odemknout dveře' : 'Zamknout dveře';
        }
        if (btnToggleImpound) {
            btnToggleImpound.setAttribute('data-impounded', String(impounded));
            btnToggleImpound.innerText = impounded ? 'Vydat z depa' : 'Zabavit do depa';
        }

        vehicleModal?.querySelectorAll('[data-action]').forEach(actionBtn => {
            actionBtn.setAttribute('data-id', selectedVehiclePlate);
        });

        document.getElementById('vehicleNoteInput').value = '';
        document.getElementById('vehicleNewOwnerInput').value = '';
        vehicleModal?.classList.add('show');
    };

    document.querySelectorAll('.btn-vehicle-modal').forEach(btn => {
        btn.addEventListener('click', (e) => openVehicleModal(e.currentTarget));
    });

    closeVehicleModalBtn?.addEventListener('click', () => {
        vehicleModal?.classList.remove('show');
        selectedVehiclePlate = null;
    });

    btnToggleVehicleLock?.addEventListener('click', async () => {
        if (!selectedVehiclePlate) return;
        const isLocked = btnToggleVehicleLock.getAttribute('data-locked') === 'true';
        const newState = !isLocked;
        btnToggleVehicleLock.setAttribute('data-locked', String(newState));
        btnToggleVehicleLock.innerText = newState ? 'Odemknout dveře' : 'Zamknout dveře';
        if (!await act({ action: 'toggleVehicleLock', plate: selectedVehiclePlate, locked: newState })) return;
        notify(newState ? 'Vozidlo bylo zamčeno.' : 'Vozidlo bylo odemčeno.', 'warning');
    });

    btnToggleImpound?.addEventListener('click', async () => {
        if (!selectedVehiclePlate) return;
        const isImpounded = btnToggleImpound.getAttribute('data-impounded') === 'true';
        const newState = !isImpounded;
        btnToggleImpound.setAttribute('data-impounded', String(newState));
        btnToggleImpound.innerText = newState ? 'Vydat z depa' : 'Zabavit do depa';
        if (!await act({ action: 'toggleVehicleImpound', plate: selectedVehiclePlate, impounded: newState })) return;
        notify(newState ? 'Vozidlo bylo zabaveno do depa.' : 'Vozidlo bylo vydáno z depa.', newState ? 'danger' : 'success');
    });

    const btnRepairVehicleModal = vehicleModal?.querySelector('[data-action="repairVehicleModal"]');
    const btnRefuelVehicleModal = vehicleModal?.querySelector('[data-action="refuelVehicleModal"]');

    btnRepairVehicleModal?.addEventListener('click', async () => {
        if (!selectedVehiclePlate) return;
        if (!await act({ action: 'repairVehicle', plate: selectedVehiclePlate })) return;
        const engineElem = document.getElementById('modalVehicleEngine');
        const bodyElem = document.getElementById('modalVehicleBody');
        if (engineElem) engineElem.innerText = '100%';
        if (bodyElem) bodyElem.innerText = '100%';
        notify('Vozidlo bylo opraveno a vyčištěno.', 'success');
    });

    btnRefuelVehicleModal?.addEventListener('click', async () => {
        if (!selectedVehiclePlate) return;
        if (!await act({ action: 'refuelVehicle', plate: selectedVehiclePlate })) return;
        const fuelElem = document.getElementById('modalVehicleFuel');
        if (fuelElem) fuelElem.innerText = '100%';
        notify('Vozidlo bylo dotankováno.', 'success');
    });

    btnDeleteVehicleModal?.addEventListener('click', async () => {
        if (!selectedVehiclePlate) return;
        if (!await askConfirm('Opravdu chceš toto vozidlo trvale smazat? Tuto akci nelze vzít zpět.')) return;
        if (!await act({ action: 'deleteVehicle', plate: selectedVehiclePlate })) return;
        notify(`Vozidlo ${selectedVehiclePlate} bylo smazáno.`, 'danger');
        vehicleModal?.classList.remove('show');
    });

    btnTransferVehicleOwner?.addEventListener('click', async () => {
        const newOwner = document.getElementById('vehicleNewOwnerInput')?.value.trim();
        if (!selectedVehiclePlate || !newOwner) {
            notify('Zadej nového majitele.', 'danger');
            return;
        }
        if (!await act({ action: 'transferVehicleOwner', plate: selectedVehiclePlate, newOwner })) return;
        document.getElementById('modalVehicleOwner').innerText = newOwner;
        notify(`Majitel vozidla byl změněn na ${newOwner}.`, 'success');
        document.getElementById('vehicleNewOwnerInput').value = '';
    });

    btnSaveVehicleNote?.addEventListener('click', async () => {
        const note = document.getElementById('vehicleNoteInput')?.value.trim();
        if (!selectedVehiclePlate || !note) {
            notify('Poznámka nemůže být prázdná.', 'danger');
            return;
        }
        if (!await act({ action: 'saveVehicleNote', plate: selectedVehiclePlate, note })) return;
        notify('Poznámka k vozidlu byla uložena.', 'success');
    });

    // --- SPRÁVA FRAKCE (MODAL) ---
    let selectedFactionId = null;
    const frakceModal = document.getElementById('frakceModal');
    const modalFactionTitle = document.getElementById('modalFactionTitle');
    const closeFrakceModalBtn = document.getElementById('closeFrakceModalBtn');
    const btnPayFactionSalaries = document.getElementById('btnPayFactionSalaries');
    const btnDeleteFaction = document.getElementById('btnDeleteFaction');
    const btnFactionAddFunds = document.getElementById('btnFactionAddFunds');
    const btnFactionRemoveFunds = document.getElementById('btnFactionRemoveFunds');
    const btnSaveFactionNote = document.getElementById('btnSaveFactionNote');

    const formatMoney = (n) => `${n < 0 ? '-' : ''}$${Math.abs(n).toLocaleString('cs-CZ')}`;

    const openFrakceModal = (btn) => {
        selectedFactionId = btn.getAttribute('data-faction');
        const label = btn.getAttribute('data-faction-label') || selectedFactionId;
        const type = btn.getAttribute('data-type') || '–';
        const account = btn.getAttribute('data-account') || '–';
        const accountClass = btn.getAttribute('data-account-class') || 'text-success';
        const balance = Number(btn.getAttribute('data-balance') || 0);
        const members = btn.getAttribute('data-members') || '0';
        const boss = btn.getAttribute('data-boss') || '–';

        if (modalFactionTitle) modalFactionTitle.innerText = `Frakce: ${label}`;
        document.getElementById('modalFactionId').innerText = selectedFactionId;
        document.getElementById('modalFactionBoss').innerText = boss;
        document.getElementById('modalFactionType').innerText = type;
        document.getElementById('modalFactionMembers').innerText = members;

        const accountElem = document.getElementById('modalFactionAccount');
        accountElem.innerText = account;
        accountElem.className = accountClass;

        const balanceElem = document.getElementById('modalFactionBalance');
        balanceElem.innerText = formatMoney(balance);
        balanceElem.className = balance < 0 ? 'text-danger' : 'text-success';
        balanceElem.setAttribute('data-balance', String(balance));

        frakceModal?.querySelectorAll('[data-action]').forEach(actionBtn => {
            actionBtn.setAttribute('data-id', selectedFactionId);
        });

        document.getElementById('factionNoteInput').value = '';
        document.getElementById('factionAmountInput').value = '';
        frakceModal?.classList.add('show');
    };

    document.querySelectorAll('.btn-frakce-modal').forEach(btn => {
        btn.addEventListener('click', (e) => openFrakceModal(e.currentTarget));
    });

    closeFrakceModalBtn?.addEventListener('click', () => {
        frakceModal?.classList.remove('show');
        selectedFactionId = null;
    });

    btnPayFactionSalaries?.addEventListener('click', async () => {
        if (!selectedFactionId) return;
        if (!await askConfirm('Vynutit vyplacení výplat všem online členům frakce?')) return;
        if (!await act({ action: 'payFactionSalaries', faction: selectedFactionId })) return;
        notify('Výplaty byly vyplaceny.', 'success');
    });

    btnDeleteFaction?.addEventListener('click', async () => {
        if (!selectedFactionId) return;
        if (!await askConfirm('Opravdu chceš tuto frakci trvale zrušit? Tuto akci nelze vzít zpět.')) return;
        if (!await act({ action: 'deleteFaction', faction: selectedFactionId })) return;
        notify('Frakce byla zrušena.', 'danger');
        frakceModal?.classList.remove('show');
    });

    const handleFactionFunds = async (mode) => {
        const amount = Number(document.getElementById('factionAmountInput')?.value);
        if (!selectedFactionId || !amount || amount <= 0) {
            notify('Zadej platnou částku.', 'danger');
            return;
        }
        const balanceElem = document.getElementById('modalFactionBalance');
        const current = Number(balanceElem.getAttribute('data-balance') || 0);
        const updated = mode === 'add' ? current + amount : current - amount;
        balanceElem.innerText = formatMoney(updated);
        balanceElem.className = updated < 0 ? 'text-danger' : 'text-success';
        balanceElem.setAttribute('data-balance', String(updated));

        if (!await act({ action: 'setFactionBalance', mode, faction: selectedFactionId, amount })) return;
        notify(
            mode === 'add' ? `Frakci přidáno ${formatMoney(amount)}.` : `Frakci odebráno ${formatMoney(amount)}.`,
            'success'
        );
        document.getElementById('factionAmountInput').value = '';
    };
    btnFactionAddFunds?.addEventListener('click', () => handleFactionFunds('add'));
    btnFactionRemoveFunds?.addEventListener('click', () => handleFactionFunds('remove'));

    btnSaveFactionNote?.addEventListener('click', async () => {
        const note = document.getElementById('factionNoteInput')?.value.trim();
        if (!selectedFactionId || !note) {
            notify('Poznámka nemůže být prázdná.', 'danger');
            return;
        }
        if (!await act({ action: 'saveFactionNote', faction: selectedFactionId, note })) return;
        notify('Poznámka k frakci byla uložena.', 'success');
    });

    // --- OBECNÁ FUNKCE PRO VYHLEDÁVÁNÍ/FILTROVÁNÍ KARET ---
    function setupCardFilter({ inputId, selectId, checkboxId, listId }) {
        const input = document.getElementById(inputId);
        const select = selectId ? document.getElementById(selectId) : null;
        const checkbox = checkboxId ? document.getElementById(checkboxId) : null;
        const list = document.getElementById(listId);
        if (!list) return;

        const applyFilter = () => {
            const filterText = (input?.value || '').toLowerCase();
            const filterType = select?.value || 'none';
            const onlineOnly = checkbox?.checked || false;

            list.querySelectorAll('.card').forEach(card => {
                const text = card.innerText.toLowerCase();
                let visible = !filterText || text.includes(filterText);

                if (visible && filterType !== 'none') {
                    visible = card.getAttribute('data-filter-' + filterType) === 'true'
                        || text.includes(filterType);
                }

                if (visible && onlineOnly) {
                    visible = !text.includes('[offline]') && !text.includes('offline');
                }

                card.style.display = visible ? '' : 'none';
            });
        };

        input?.addEventListener('keyup', applyFilter);
        select?.addEventListener('change', applyFilter);
        checkbox?.addEventListener('change', applyFilter);
    }

    setupCardFilter({ inputId: 'playerSearchInput', selectId: 'playerSearchType', checkboxId: 'searchOffline', listId: 'playerList' });
    setupCardFilter({ inputId: 'vehicleSearchInput', selectId: 'vehicleSearchType', listId: 'vehicleList' });
    setupCardFilter({ inputId: 'frakceSearchInput', selectId: 'frakceSearchType', listId: 'frakceList' });

    // --- RYCHLÉ AKCE A NÁSTROJE (S POTVRZENÍM U NEBEZPEČNÝCH AKCÍ) ---
    // Akce, které mají vlastní handler (potvrzení si řeší samy).
    const HANDLED_ELSEWHERE = new Set([
        'approveWhitelist', 'rejectWhitelist', 'closeReport', 'openReportChat',
        'removeAdmin', 'sendAnnouncement', 'unbanPlayer', 'clearWarn', 'editban',
        'repairVehicleModal', 'refuelVehicleModal', 'plannedrestart'
    ]);

    async function handleGenericAction(e) {
        const target = e.currentTarget;
        const actionType = target.getAttribute('data-action');
        if (HANDLED_ELSEWHERE.has(actionType)) return;

        const confirmMsg = target.getAttribute('data-confirm');
        if (confirmMsg && !await askConfirm(confirmMsg)) return;

        const extra = {};
        if (actionType === 'tpCoords') {
            const coords = await askText('Souřadnice pro teleport (x, y, z):', 'např. 215.5, -810.2, 30.7');
            if (!coords) return;
            extra.coords = coords;
        }

        const targetId = target.getAttribute('data-id') || selectedPlayerId;
        const ok = await act({ action: actionType, id: targetId, ...extra });
        if (ok && ['toggleNoclip', 'toggleGodmode', 'toggleInvis'].includes(actionType)) {
            target.classList.toggle('active');
        }
        // Výsledek akce oznamuje server přes ox_lib
    }

    const bindGeneric = (btn) => btn.addEventListener('click', handleGenericAction);
    document.querySelectorAll('button[data-action]').forEach(bindGeneric);

    // --- PLÁNOVANÝ RESTART SERVERU ---
    const plannedRestartModal = document.getElementById('plannedRestartModal');
    const btnPlannedrestart = document.getElementById('btnPlannedrestart');
    const closePlannedRestartModalBtn = document.getElementById('closePlannedRestartModalBtn');
    const plannedRestartTimeInput = document.getElementById('plannedRestartTimeInput');
    const plannedRestartMessage = document.getElementById('plannedRestartMessage');
    const btnConfirmPlannedRestart = document.getElementById('btnConfirmPlannedRestart');
    const btnCancelPlannedRestart = document.getElementById('btnCancelPlannedRestart');
    const plannedRestartActiveBox = document.getElementById('plannedRestartActiveBox');
    const plannedRestartActiveTime = document.getElementById('plannedRestartActiveTime');
    const plannedRestartCountdown = document.getElementById('plannedRestartCountdown');
    const statNextRestart = document.getElementById('statNextRestart');
    const presetButtons = plannedRestartModal ? plannedRestartModal.querySelectorAll('[data-preset]') : [];
    const warnCheckboxes = plannedRestartModal ? plannedRestartModal.querySelectorAll('[data-warn-min]') : [];

    let scheduledRestartAt = null;
    let scheduledWarnedMinutes = new Set();
    let restartCountdownInterval = null;

    const formatClock = (date) => date.toLocaleTimeString('cs-CZ', { hour: '2-digit', minute: '2-digit' });

    const formatCountdown = (ms) => {
        if (ms <= 0) return 'právě teď';
        const totalMinutes = Math.floor(ms / 60000);
        const hours = Math.floor(totalMinutes / 60);
        const minutes = totalMinutes % 60;
        if (hours > 0) return `${hours} h ${minutes} min`;
        return `${minutes} min`;
    };

    function setNextRestartLabel(text) {
        if (statNextRestart) statNextRestart.innerText = text;
    }

    function stopRestartCountdown() {
        if (restartCountdownInterval) {
            clearInterval(restartCountdownInterval);
            restartCountdownInterval = null;
        }
    }

    function tickRestartCountdown() {
        if (!scheduledRestartAt) return;
        const remainingMs = scheduledRestartAt.getTime() - Date.now();

        if (remainingMs <= 0) {
            if (plannedRestartCountdown) plannedRestartCountdown.innerText = 'probíhá restart…';
            setNextRestartLabel('Restartuje se…');
            stopRestartCountdown();
            return;
        }

        const remainingLabel = formatCountdown(remainingMs);
        if (plannedRestartCountdown) plannedRestartCountdown.innerText = remainingLabel;
        setNextRestartLabel(remainingLabel);
    }

    function activateScheduledRestartUI() {
        if (!scheduledRestartAt) return;
        plannedRestartActiveBox?.classList.remove('hidden');
        if (plannedRestartActiveTime) plannedRestartActiveTime.innerText = formatClock(scheduledRestartAt);
        btnPlannedrestart && (btnPlannedrestart.innerText = `Naplánováno: ${formatClock(scheduledRestartAt)}`);
        stopRestartCountdown();
        tickRestartCountdown();
        restartCountdownInterval = setInterval(tickRestartCountdown, 15000);
    }

    function resetScheduledRestartUI() {
        scheduledRestartAt = null;
        scheduledWarnedMinutes = new Set();
        stopRestartCountdown();
        plannedRestartActiveBox?.classList.add('hidden');
        if (btnPlannedrestart) btnPlannedrestart.innerText = 'Naplánovat restart';
        setNextRestartLabel('Nenaplánováno');
    }

    btnPlannedrestart?.addEventListener('click', () => {
        presetButtons.forEach(b => b.classList.remove('active'));
        if (plannedRestartMessage) plannedRestartMessage.value = '';
        if (plannedRestartTimeInput) plannedRestartTimeInput.value = '';
        plannedRestartModal?.classList.add('show');
    });

    closePlannedRestartModalBtn?.addEventListener('click', () => plannedRestartModal?.classList.remove('show'));

    presetButtons.forEach(btn => {
        btn.addEventListener('click', () => {
            presetButtons.forEach(b => b.classList.remove('active'));
            btn.classList.add('active');
            const minutesFromNow = Number(btn.getAttribute('data-preset'));
            const target = new Date(Date.now() + minutesFromNow * 60000);
            if (plannedRestartTimeInput) {
                const hh = String(target.getHours()).padStart(2, '0');
                const mm = String(target.getMinutes()).padStart(2, '0');
                plannedRestartTimeInput.value = `${hh}:${mm}`;
            }
        });
    });

    plannedRestartTimeInput?.addEventListener('input', () => presetButtons.forEach(b => b.classList.remove('active')));

    btnConfirmPlannedRestart?.addEventListener('click', async () => {
        const timeValue = plannedRestartTimeInput?.value;
        if (!timeValue) {
            notify('Zadej čas restartu nebo zvol rychlou volbu.', 'danger');
            return;
        }

        const [hh, mm] = timeValue.split(':').map(Number);
        const target = new Date();
        target.setSeconds(0, 0);
        target.setHours(hh, mm);
        if (target.getTime() <= Date.now()) {
            target.setDate(target.getDate() + 1);
        }

        const warnMinutes = Array.from(warnCheckboxes)
            .filter(cb => cb.checked)
            .map(cb => Number(cb.getAttribute('data-warn-min')))
            .sort((a, b) => b - a);

        const message = plannedRestartMessage?.value.trim() || '';

        if (!await askConfirm(`Naplánovat restart serveru na ${formatClock(target)}?`)) return;

        scheduledRestartAt = target;
        scheduledWarnedMinutes = new Set();

        if (!await act({
            action: 'scheduleRestart',
            delay: Math.round((target.getTime() - Date.now()) / 1000),
            warnMinutes,
            message
        })) return;

        activateScheduledRestartUI();
        notify(`Restart naplánován na ${formatClock(target)}.`, 'success');
        plannedRestartModal?.classList.remove('show');
    });

    btnCancelPlannedRestart?.addEventListener('click', async () => {
        if (!await askConfirm('Opravdu chceš zrušit naplánovaný restart?')) return;
        if (!await act({ action: 'cancelScheduledRestart' })) return;
        resetScheduledRestartUI();
        notify('Naplánovaný restart byl zrušen.', 'warning');
    });

    resetScheduledRestartUI();

    // --- OZNÁMENÍ CELÉMU SERVERU ---
    const btnSendAnnouncement = document.getElementById('btnSendAnnouncement');
    if (btnSendAnnouncement) {
        btnSendAnnouncement.addEventListener('click', async () => {
            const message = await askText('Text oznámení pro všechny hráče na serveru:', 'Např. Dnes ve 20:00 probíhá event…');
            if (!message || !message.trim()) return;
            if (!await act({ action: 'sendAnnouncement', message: message.trim() })) return;
            notify('Oznámení bylo odesláno všem hráčům.', 'success');
        });
    }

    // --- INTERAKTIVNÍ STAFF CHAT ---
    const staffChatInput = document.getElementById('staffChatInput');
    const sendStaffChatBtn = document.getElementById('sendStaffChatBtn');
    const adminStaffChat = document.getElementById('adminStaffChat');

    const handleSendStaffMsg = () => {
        if (!staffChatInput || !staffChatInput.value.trim()) return;
        const msg = staffChatInput.value.trim();

        const msgElem = document.createElement('div');
        msgElem.className = 'msg admin';
        msgElem.innerHTML = `<strong>Ty:</strong> ${escapeHtml(msg)}`;
        adminStaffChat.appendChild(msgElem);
        adminStaffChat.scrollTop = adminStaffChat.scrollHeight;

        sendNUI('sendStaffMessage', { message: msg });
        staffChatInput.value = '';
    };

    if (sendStaffChatBtn) sendStaffChatBtn.addEventListener('click', handleSendStaffMsg);
    if (staffChatInput) {
        staffChatInput.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') handleSendStaffMsg();
        });
    }

    // --- EKONOMIKA: ÚPRAVA FINANCÍ HRÁČE ---
    const btnEcoAdd = document.getElementById('btnEcoAdd');
    const btnEcoRemove = document.getElementById('btnEcoRemove');
    const ecoPlayerId = document.getElementById('ecoPlayerId');
    const ecoAmount = document.getElementById('ecoAmount');
    const ecoAccountType = document.getElementById('ecoAccountType');

    const handleEcoAction = async (mode) => {
        const targetId = ecoPlayerId?.value.trim();
        const amount = Number(ecoAmount?.value);

        if (!targetId) {
            notify('Zadej ID hráče.', 'danger');
            return;
        }
        if (!amount || amount <= 0) {
            notify('Zadej platnou částku.', 'danger');
            return;
        }

        if (!await act({
            action: 'setPlayerMoney',
            mode: mode,
            id: targetId,
            amount: amount,
            account: ecoAccountType?.value || 'cash'
        })) return;

        notify(
            mode === 'add'
                ? `Hráči #${targetId} přidáno $${amount.toLocaleString('cs-CZ')}.`
                : `Hráči #${targetId} odebráno $${amount.toLocaleString('cs-CZ')}.`,
            'success'
        );

        if (ecoAmount) ecoAmount.value = '';
    };

    if (btnEcoAdd) btnEcoAdd.addEventListener('click', () => handleEcoAction('add'));
    if (btnEcoRemove) btnEcoRemove.addEventListener('click', () => handleEcoAction('remove'));

    // --- EKONOMIKA: VYHLEDÁVÁNÍ FIREM ---
    const companySearchInput = document.getElementById('companySearchInput');
    if (companySearchInput) {
        companySearchInput.addEventListener('keyup', (e) => {
            const filter = e.target.value.toLowerCase();
            document.querySelectorAll('#companyList tr').forEach(row => {
                row.style.display = row.innerText.toLowerCase().includes(filter) ? "" : "none";
            });
        });
    }

    // --- FILTROVÁNÍ V LOGÁCH ---
    const logSearchInput = document.getElementById('logSearchInput');
    const logCategoryFilter = document.getElementById('logCategoryFilter');
    const applyLogFilter = () => {
        const filter = (logSearchInput?.value || '').toLowerCase();
        const category = logCategoryFilter?.value || 'all';
        document.querySelectorAll('#logsContainer .log-entry').forEach(entry => {
            const matchesText = !filter || entry.innerText.toLowerCase().includes(filter);
            const matchesCategory = category === 'all' || entry.classList.contains('log-' + category);
            entry.style.display = (matchesText && matchesCategory) ? "flex" : "none";
        });
    };
    logSearchInput?.addEventListener('keyup', applyLogFilter);
    logCategoryFilter?.addEventListener('change', applyLogFilter);

    // --- FREEZE TOGGLE V PLAYER MODALU ---
    const btnFreezePlayer = document.getElementById('btnFreezePlayer');
    if (btnFreezePlayer) {
        btnFreezePlayer.addEventListener('click', async () => {
            if (!selectedPlayerId) return;
            const isFrozen = btnFreezePlayer.getAttribute('data-frozen') === 'true';
            const newState = !isFrozen;
            btnFreezePlayer.setAttribute('data-frozen', String(newState));
            btnFreezePlayer.innerText = newState ? 'Odemknout (Unfreeze)' : 'Zamknout (Freeze)';
            if (!await act({ action: 'toggleFreeze', id: selectedPlayerId, state: newState })) return;
            notify(newState ? 'Hráč byl zamčen.' : 'Hráč byl odemčen.', 'warning');
        });
    }

    // --- POZNÁMKA SPRÁVCE ---
    const btnSaveNote = document.getElementById('btnSaveNote');
    const staffNoteInput = document.getElementById('staffNoteInput');
    if (btnSaveNote) {
        btnSaveNote.addEventListener('click', async () => {
            if (!selectedPlayerId || !staffNoteInput?.value.trim()) {
                notify('Poznámka nemůže být prázdná.', 'danger');
                return;
            }
            if (!await act({ action: 'saveStaffNote', id: selectedPlayerId, note: staffNoteInput.value.trim() })) return;
            notify('Poznámka byla uložena.', 'success');
        });
    }

    // --- UDĚLENÍ VAROVÁNÍ ---
    const btnAddWarn = document.getElementById('btnAddWarn');
    const warnReasonInput = document.getElementById('warnReasonInput');
    const warnsList = document.getElementById('warnsList');
    if (btnAddWarn) {
        btnAddWarn.addEventListener('click', async () => {
            const reason = warnReasonInput?.value.trim();
            if (!selectedPlayerId || !reason) {
                notify('Zadej důvod varování.', 'danger');
                return;
            }

            if (!await act({ action: 'addWarn', id: selectedPlayerId, reason })) return;

            if (warnsList) {
                const entry = document.createElement('div');
                entry.className = 'log-entry';
                entry.innerHTML = `<span class="badge badge-warning">Nové</span><span class="log-text">${escapeHtml(reason)} — uděleno právě teď</span>`;
                warnsList.appendChild(entry);
            }
            notify('Varování bylo uděleno.', 'warning');
            if (warnReasonInput) warnReasonInput.value = '';
        });
    }

    // --- BANOVÁNÍ (Z PLAYER MODALU) ---
    const btnModalBan = document.getElementById('btnModalBan');
    if (btnModalBan) {
        btnModalBan.addEventListener('click', async () => {
            const reason = document.getElementById('modalBanReason')?.value.trim();
            const duration = document.getElementById('modalBanDuration')?.value;
            if (!selectedPlayerId || !reason) {
                notify('Zadej důvod banu.', 'danger');
                return;
            }
            if (!await askConfirm(`Opravdu chceš zabanovat tohoto hráče? (${duration})`)) return;

            if (!await act({ action: 'banPlayer', id: selectedPlayerId, reason, duration })) return;
            notify('Hráč byl zabanován.', 'danger');
            modal?.classList.remove('show');
        });
    }

    // --- RYCHLÝ BAN (SEKCE BANY) ---
    const btnQuickBan = document.getElementById('btnQuickBan');
    if (btnQuickBan) {
        btnQuickBan.addEventListener('click', async () => {
            const targetId = document.getElementById('banPlayerId')?.value.trim();
            const reason = document.getElementById('banReason')?.value.trim();
            const duration = document.getElementById('banDuration')?.value;
            if (!targetId || !reason) {
                notify('Vyplň ID hráče a důvod.', 'danger');
                return;
            }
            if (!await askConfirm(`Zabanovat hráče "${targetId}"? (${duration})`)) return;

            if (!await act({ action: 'banPlayer', id: targetId, reason, duration })) return;
            notify('Ban byl udělen.', 'danger');
            document.getElementById('banPlayerId').value = '';
            document.getElementById('banReason').value = '';
        });
    }

    // --- ODBANOVÁNÍ, EDITACE BANU, ZRUŠENÍ VAROVÁNÍ ---
    const statActiveBans = document.getElementById('statActiveBans');
    const statActiveWarns = document.getElementById('statActiveWarns');
    const decrement = (el) => {
        if (el) el.innerText = String(Math.max(0, (parseInt(el.innerText, 10) || 0) - 1));
    };

    function bindUnban(btn) {
        btn.addEventListener('click', async (e) => {
            const target = e.currentTarget;
            const id = target.getAttribute('data-id');
            if (!await askConfirm('Opravdu chceš tohoto hráče odbanovat?')) return;
            if (!await act({ action: 'unbanPlayer', id })) return;
            target.closest('tr')?.remove();
            decrement(statActiveBans);
            notify('Hráč byl odbanován.', 'success');
        });
    }

    function bindEditBan(btn) {
        btn.addEventListener('click', async (e) => {
            const id = e.currentTarget.getAttribute('data-id');
            const reason = await askText('Nový důvod banu:', 'Cheating, RDM…');
            if (!reason || !reason.trim()) return;
            if (!await act({ action: 'editBan', id, reason: reason.trim() })) return;
            notify('Důvod banu byl upraven.', 'success');
            refreshData();
        });
    }

    function bindClearWarn(btn) {
        btn.addEventListener('click', async (e) => {
            const target = e.currentTarget;
            const id = target.getAttribute('data-id');
            if (!await askConfirm('Opravdu chceš toto varování zrušit?')) return;
            if (!await act({ action: 'clearWarn', id })) return;
            target.closest('tr')?.remove();
            decrement(statActiveWarns);
            notify('Varování bylo zrušeno.', 'success');
        });
    }

    document.querySelectorAll('button[data-action="unbanPlayer"]').forEach(bindUnban);
    document.querySelectorAll('button[data-action="editban"]').forEach(bindEditBan);
    document.querySelectorAll('button[data-action="clearWarn"]').forEach(bindClearWarn);

    // --- VYHLEDÁVÁNÍ V BANECH ---
    const banSearchInput = document.getElementById('banSearchInput');
    if (banSearchInput) {
        banSearchInput.addEventListener('keyup', (e) => {
            const filter = e.target.value.toLowerCase();
            document.querySelectorAll('#banList tr').forEach(row => {
                row.style.display = row.innerText.toLowerCase().includes(filter) ? "" : "none";
            });
        });
    }

    // --- VYHLEDÁVÁNÍ HRÁČŮ NA MAPĚ ---
    const mapPlayerSearch = document.getElementById('mapPlayerSearch');
    if (mapPlayerSearch) {
        mapPlayerSearch.addEventListener('keyup', (e) => {
            const filter = e.target.value.toLowerCase();
            document.querySelectorAll('#mapPlayerTable tbody tr').forEach(row => {
                row.style.display = row.innerText.toLowerCase().includes(filter) ? "" : "none";
            });
        });
    }

    // --- KLIKNUTÍ NA BLIP NA MAPĚ ---
    document.querySelectorAll('.map-blip[data-player]').forEach(blip => {
        blip.addEventListener('click', () => {
            openPlayerModal(blip.getAttribute('data-player'), blip.getAttribute('data-name'));
        });
    });

    // --- ACL: MODAL ÚPRAVY OPRÁVNĚNÍ ADMINA ---
    const permissionsModal = document.getElementById('permissionsModal');
    const modalAdminName = document.getElementById('modalAdminName');
    const closePermissionsModalBtn = document.getElementById('closePermissionsModalBtn');
    const btnSavePermissions = document.getElementById('btnSavePermissions');

    function attachPermissionsHandler(btn) {
        btn.addEventListener('click', (e) => {
            selectedAdminName = e.currentTarget.getAttribute('data-admin');
            let current = {};
            try { current = JSON.parse(e.currentTarget.getAttribute('data-perms') || '{}'); } catch (_) { /* statický řádek */ }
            document.querySelectorAll('#permissionsModal input[data-perm]').forEach(input => {
                const key = input.getAttribute('data-perm');
                if (key in current) input.checked = !!current[key];
            });
            if (modalAdminName) modalAdminName.innerText = `Oprávnění administrátora: ${selectedAdminName}`;
            if (permissionsModal) permissionsModal.classList.add('show');
        });
    }
    function attachRemoveAdminHandler(btn) {
        btn.addEventListener('click', async (e) => {
            const target = e.currentTarget;
            const adminName = target.getAttribute('data-admin');
            const confirmMsg = target.getAttribute('data-confirm') || `Opravdu chceš odebrat admina ${adminName}?`;
            if (!await askConfirm(confirmMsg)) return;
            if (!await act({ action: 'removeAdmin', admin: adminName })) return;
            target.closest('tr')?.remove();
            notify(`${adminName} byl odebrán z administrátorského týmu.`, 'danger');
        });
    }

    document.querySelectorAll('.btn-edit-permissions').forEach(attachPermissionsHandler);
    document.querySelectorAll('button[data-action="removeAdmin"]').forEach(attachRemoveAdminHandler);

    if (closePermissionsModalBtn && permissionsModal) {
        closePermissionsModalBtn.addEventListener('click', () => permissionsModal.classList.remove('show'));
    }

    if (btnSavePermissions) {
        btnSavePermissions.addEventListener('click', async () => {
            const perms = {};
            document.querySelectorAll('#permissionsModal input[data-perm]').forEach(input => {
                perms[input.getAttribute('data-perm')] = input.checked;
            });
            if (!await act({ action: 'saveAdminPermissions', admin: selectedAdminName, permissions: perms })) return;
            notify(`Oprávnění pro ${selectedAdminName} byla uložena.`, 'success');
            if (permissionsModal) permissionsModal.classList.remove('show');
        });
    }

    // --- SPRÁVA ADMINŮ: PŘIDÁNÍ NOVÉHO ADMINA ---
    const addAdminModal = document.getElementById('addAdminModal');
    const btnOpenAddAdminModal = document.getElementById('btnOpenAddAdminModal');
    const closeAddAdminModalBtn = document.getElementById('closeAddAdminModalBtn');
    const btnConfirmAddAdmin = document.getElementById('btnConfirmAddAdmin');

    btnOpenAddAdminModal?.addEventListener('click', () => addAdminModal?.classList.add('show'));
    closeAddAdminModalBtn?.addEventListener('click', () => addAdminModal?.classList.remove('show'));

    btnConfirmAddAdmin?.addEventListener('click', async () => {
        const name = document.getElementById('newAdminName')?.value.trim();
        const identifier = document.getElementById('newAdminIdentifier')?.value.trim();
        const role = document.getElementById('newAdminRole')?.value;
        const roleLabels = { trial: 'Trial Admin', admin: 'Admin', senior: 'Senior Admin', super: 'SuperAdmin' };

        if (!name || !identifier) {
            notify('Vyplň jméno i identifikátor hráče.', 'danger');
            return;
        }

        if (!await act({ action: 'addAdmin', name, identifier, role })) return;

        notify(`${name} byl přidán jako ${roleLabels[role] || role}.`, 'success');
        document.getElementById('newAdminName').value = '';
        document.getElementById('newAdminIdentifier').value = '';
        addAdminModal?.classList.remove('show');
        refreshData();
    });

    // --- WHITELIST: SCHVÁLENÍ / ODMÍTNUTÍ ---
    function updateWhitelistBadge() {
        const remaining = document.querySelectorAll('#whitelist .data-table tbody tr').length;
        const badge = document.getElementById('whitelistPendingBadge');
        if (badge) badge.innerText = `Čeká na schválení: ${remaining}`;
    }

    document.querySelectorAll('button[data-action="approveWhitelist"], button[data-action="rejectWhitelist"]').forEach(btn => {
        btn.addEventListener('click', async (e) => {
            const target = e.currentTarget;
            const action = target.getAttribute('data-action');
            const id = target.getAttribute('data-id');
            if (!await act({ action, id })) return;
            target.closest('tr')?.remove();
            updateWhitelistBadge();
            notify(
                action === 'approveWhitelist' ? 'Žádost byla schválena.' : 'Žádost byla odmítnuta.',
                action === 'approveWhitelist' ? 'success' : 'danger'
            );
        });
    });

    // --- REPORTY: UZAVŘENÍ, PŘEVZETÍ, CHAT ---
    function updateReportsCount() {
        const remaining = document.querySelectorAll('#reportsList .report-item').length;
        const badge = document.getElementById('reportsBadge');
        const pendingCount = document.getElementById('reportsPendingCount');
        if (badge) badge.innerText = `[${remaining}]`;
        if (pendingCount) pendingCount.innerText = String(remaining);
    }

    const chatModal = document.getElementById('chatModal');
    const chatModalTitle = document.getElementById('chatModalTitle');
    const reportChatMessages = document.getElementById('reportChatMessages');
    const reportChatInput = document.getElementById('reportChatInput');
    const sendReportChatBtn = document.getElementById('sendReportChatBtn');

    function attachCloseReportHandler(btn) {
        btn.addEventListener('click', async (e) => {
            const id = e.currentTarget.getAttribute('data-id');
            if (!await askConfirm('Opravdu chceš tento report uzavřít?')) return;
            if (!await act({ action: 'closeReport', id })) return;
            document.getElementById(`report-${id}`)?.remove();
            updateReportsCount();
            notify(`Report #${id} byl uzavřen.`, 'success');
        });
    }
    function attachOpenReportChatHandler(btn) {
        btn.addEventListener('click', (e) => {
            const target = e.currentTarget;
            selectedReportId = target.getAttribute('data-id');
            const playerName = target.getAttribute('data-name') || 'hráč';
            if (chatModalTitle) chatModalTitle.innerText = `Chat s hráčem — Report #${selectedReportId} (${playerName})`;
            if (reportChatMessages) {
                reportChatMessages.innerHTML = '<div class="msg system">Chat k reportu je viditelný pouze pro adminy a hráče.</div>';
            }
            chatModal?.classList.add('show');
        });
    }

    document.querySelectorAll('button[data-action="closeReport"]').forEach(attachCloseReportHandler);
    document.querySelectorAll('button[data-action="openReportChat"]').forEach(attachOpenReportChatHandler);

    const handleSendReportChat = async () => {
        if (!reportChatInput?.value.trim() || !selectedReportId) return;
        const msg = reportChatInput.value.trim();
        const msgElem = document.createElement('div');
        msgElem.className = 'msg admin';
        msgElem.innerHTML = `<strong>Admin:</strong> ${escapeHtml(msg)}`;
        reportChatMessages?.appendChild(msgElem);
        if (reportChatMessages) reportChatMessages.scrollTop = reportChatMessages.scrollHeight;
        if (!await act({ action: 'sendReportChatMessage', id: selectedReportId, message: msg })) return;
        reportChatInput.value = '';
    };
    sendReportChatBtn?.addEventListener('click', handleSendReportChat);
    reportChatInput?.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') handleSendReportChat();
    });

    // --- REPORTY: ZAPSÁNÍ MANUÁLNÍHO REPORTU ---
    const createReportModal = document.getElementById('createReportModal');
    const btnCreateReport = document.getElementById('btnCreateReport');
    const btnConfirmCreateReport = document.getElementById('btnConfirmCreateReport');

    btnCreateReport?.addEventListener('click', () => createReportModal?.classList.add('show'));

    btnConfirmCreateReport?.addEventListener('click', async () => {
        const playerRef = document.getElementById('newReportPlayerId')?.value.trim();
        const title = document.getElementById('newReportTitle')?.value.trim();
        const category = document.getElementById('newReportCategory')?.value;

        if (!playerRef || !title) {
            notify('Vyplň hráče i předmět reportu.', 'danger');
            return;
        }

        if (!await act({ action: 'createManualReport', playerRef, title, category })) return;

        notify('Manuální report byl zapsán.', 'success');
        document.getElementById('newReportPlayerId').value = '';
        document.getElementById('newReportTitle').value = '';
        createReportModal?.classList.remove('show');
        refreshData();
    });

    updateReportsCount();

    // --- DOS: EVIDENCE PŘEPÍNÁNÍ ZÁLOŽEK A FILTRACE ---
    const btnDosTabCars = document.getElementById('btnDosTabCars');
    const btnDosTabMlo = document.getElementById('btnDosTabMlo');
    const dosTableCars = document.getElementById('dosTableCars');
    const dosTableMlo = document.getElementById('dosTableMlo');
    const dosSearchInput = document.getElementById('dosSearchInput');

    let currentDosTab = 'cars';

    const switchDosTab = (tab) => {
        currentDosTab = tab;
        if (tab === 'cars') {
            btnDosTabCars?.classList.add('active');
            btnDosTabMlo?.classList.remove('active');
            dosTableCars?.classList.remove('hidden');
            dosTableMlo?.classList.add('hidden');
        } else {
            btnDosTabMlo?.classList.add('active');
            btnDosTabCars?.classList.remove('active');
            dosTableMlo?.classList.remove('hidden');
            dosTableCars?.classList.add('hidden');
        }
        applyDosFilter();
    };

    btnDosTabCars?.addEventListener('click', () => switchDosTab('cars'));
    btnDosTabMlo?.addEventListener('click', () => switchDosTab('mlo'));

    const applyDosFilter = () => {
        const filter = (dosSearchInput?.value || '').toLowerCase();
        const activeTbody = currentDosTab === 'cars'
            ? document.getElementById('dosCarsBody')
            : document.getElementById('dosMloBody');

        if (!activeTbody) return;
        activeTbody.querySelectorAll('tr').forEach(row => {
            row.style.display = row.innerText.toLowerCase().includes(filter) ? '' : 'none';
        });
    };

    dosSearchInput?.addEventListener('keyup', applyDosFilter);

    // --- DOS: MODAL PRO PŘIDÁNÍ ZÁZNAMU ---
    const addDosModal = document.getElementById('addDosModal');
    const btnOpenAddDosModal = document.getElementById('btnOpenAddDosModal');
    const closeAddDosModalBtn = document.getElementById('closeAddDosModalBtn');
    const btnConfirmAddDos = document.getElementById('btnConfirmAddDos');
    const dosTypeSelect = document.getElementById('dosTypeSelect');
    const lblDosCode = document.getElementById('lblDosCode');
    const dosItemCode = document.getElementById('dosItemCode');

    btnOpenAddDosModal?.addEventListener('click', () => addDosModal?.classList.add('show'));
    closeAddDosModalBtn?.addEventListener('click', () => addDosModal?.classList.remove('show'));

    dosTypeSelect?.addEventListener('change', () => {
        if (dosTypeSelect.value === 'mlo') {
            if (lblDosCode) lblDosCode.innerText = 'Souřadnice (x, y, z)';
            if (dosItemCode) dosItemCode.placeholder = 'např. 0, 0, 0';
        } else {
            if (lblDosCode) lblDosCode.innerText = 'Spawn kód';
            if (dosItemCode) dosItemCode.placeholder = 'např. zr3806str';
        }
    });

    btnConfirmAddDos?.addEventListener('click', async () => {
        const isMlo = dosTypeSelect?.value === 'mlo';
        const name = document.getElementById('dosItemName')?.value.trim();
        const code = document.getElementById('dosItemCode')?.value.trim();
        const folder = document.getElementById('dosItemFolder')?.value.trim();
        const link = document.getElementById('dosItemLink')?.value.trim();
        const note = document.getElementById('dosItemNote')?.value.trim();

        if (!name || !folder) {
            notify('Vyplň alespoň název a složku.', 'danger');
            return;
        }

        const tr = document.createElement('tr');
        const safeLink = link ? `<a href="${escapeHtml(link)}" target="_blank" class="table-link">Otevřít odkaz ↗</a>` : '–';

        if (isMlo) {
            tr.innerHTML = `
                <td><img src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='64' height='36'%3E%3Crect width='64' height='36' fill='%2314133b'/%3E%3Ctext x='32' y='22' font-size='11' text-anchor='middle' fill='%235f84ff' font-family='sans-serif'%3EIMG%3C/text%3E%3C/svg%3E" alt="${escapeHtml(name)}" class="dos-thumbnail"></td>
                <td><strong>${escapeHtml(name)}</strong></td>
                <td><code>${escapeHtml(code || '0, 0, 0')}</code></td>
                <td><code>${escapeHtml(folder)}</code></td>
                <td>${safeLink}</td>
                <td><span class="badge badge-accent">MLO</span></td>
                <td>${escapeHtml(note || '–')}</td>
            `;
            document.getElementById('dosMloBody')?.prepend(tr);
            switchDosTab('mlo');

            const statDosMlo = document.getElementById('statDosMlo');
            if (statDosMlo) statDosMlo.innerText = String((parseInt(statDosMlo.innerText, 10) || 0) + 1);
        } else {
            tr.innerHTML = `
                <td><img src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='64' height='36'%3E%3Crect width='64' height='36' fill='%2314133b'/%3E%3Ctext x='32' y='22' font-size='11' text-anchor='middle' fill='%235f84ff' font-family='sans-serif'%3EIMG%3C/text%3E%3C/svg%3E" alt="${escapeHtml(name)}" class="dos-thumbnail"></td>
                <td><strong>${escapeHtml(name)}</strong></td>
                <td><code>${escapeHtml(code || '–')}</code></td>
                <td><code>${escapeHtml(folder)}</code></td>
                <td>${safeLink}</td>
                <td><span class="badge badge-success">Aktivní</span></td>
                <td><span class="badge badge-warning">Custom vozidla</span></td>
                <td>${escapeHtml(note || '–')}</td>
            `;
            document.getElementById('dosCarsBody')?.prepend(tr);
            switchDosTab('cars');

            const statDosCars = document.getElementById('statDosCars');
            if (statDosCars) statDosCars.innerText = String((parseInt(statDosCars.innerText, 10) || 0) + 1);
        }

        if (!await act({ action: 'addDosEntry', itemType: isMlo ? 'mlo' : 'car', name, code, folder, link, note })) return;
        notify(`Položka "${name}" byla zaevidována do DOS.`, 'success');

        document.getElementById('dosItemName').value = '';
        document.getElementById('dosItemCode').value = '';
        document.getElementById('dosItemFolder').value = '';
        document.getElementById('dosItemLink').value = '';
        document.getElementById('dosItemNote').value = '';
        addDosModal?.classList.remove('show');
    });

    // --- ADMIN DUTY TOGGLE ---
    const dutyToggle = document.getElementById('dutyToggle');
    const dutyStatusLabel = document.getElementById('dutyStatusLabel');
    if (dutyToggle) {
        dutyToggle.addEventListener('change', async () => {
            const onDuty = dutyToggle.checked;
            if (dutyStatusLabel) dutyStatusLabel.innerText = onDuty ? 'Na duty' : 'Mimo duty';
            if (!await act({ action: 'toggleAdminDuty', state: onDuty })) return;
            notify(onDuty ? 'Byl jsi nastaven jako aktivní admin (on duty).' : 'Ukončil jsi admin duty.', onDuty ? 'success' : 'warning');

            const activeAdminsElem = document.getElementById('statActiveAdmins');
            if (activeAdminsElem) {
                const current = parseInt(activeAdminsElem.innerText, 10) || 0;
                activeAdminsElem.innerText = String(Math.max(0, current + (onDuty ? 1 : -1)));
            }
        });
    }

    // --- DISCORD WEBHOOK ---
    const btnSaveWebhook = document.getElementById('btnSaveWebhook');
    const btnTestWebhook = document.getElementById('btnTestWebhook');

    if (btnSaveWebhook) {
        btnSaveWebhook.addEventListener('click', async () => {
            if (!await act({
                action: 'saveWebhookConfig',
                url: document.getElementById('discordWebhookUrl')?.value.trim(),
                categories: {
                    audit: document.getElementById('webhookAudit')?.checked,
                    bans: document.getElementById('webhookBans')?.checked,
                    economy: document.getElementById('webhookEconomy')?.checked,
                    chat: document.getElementById('webhookChat')?.checked
                }
            })) return;
            notify('Konfigurace webhooku byla uložena.', 'success');
        });
    }

    if (btnTestWebhook) {
        btnTestWebhook.addEventListener('click', async () => {
            if (!await act({ action: 'testWebhook' })) return;
            notify('Testovací zpráva byla odeslána na Discord.', 'default');
        });
    }

    // --- ZAVÍRÁNÍ ---
    if (closeMenuBtn) closeMenuBtn.addEventListener('click', closeNUI);
    document.getElementById('closeScreenshotBtn')?.addEventListener('click', () => document.getElementById('screenshotModal')?.classList.remove('show'));

    document.getElementById('dialogOk')?.addEventListener('click', () => {
        const field = document.getElementById('dialogInput');
        closeDialog(field.classList.contains('hidden') ? true : field.value);
    });
    document.getElementById('dialogCancel')?.addEventListener('click', () => {
        const field = document.getElementById('dialogInput');
        closeDialog(field.classList.contains('hidden') ? false : null);
    });
    document.getElementById('dialogInput')?.addEventListener('keydown', (e) => {
        if (e.key === 'Enter') document.getElementById('dialogOk').click();
    });

    document.addEventListener('keyup', (e) => {
        if (e.key !== 'Escape' || !menuOpen) return;
        const openModals = document.querySelectorAll('.modal.show');
        const top = openModals[openModals.length - 1];
        if (!top) return closeNUI();
        if (top.id === 'dialogModal') {
            document.getElementById('dialogCancel').click();
        } else {
            top.classList.remove('show');
        }
    });

    document.querySelectorAll('.modal').forEach(m => {
        m.addEventListener('click', (e) => {
            if (e.target !== m) return;
            if (m.id === 'dialogModal') document.getElementById('dialogCancel').click();
            else m.classList.remove('show');
        });
    });

    // =====================================================================
    //  DATA ZE SERVERU (hráči, bany, varování, reporty, admini, dashboard)
    // =====================================================================
    const setText = (id, value) => {
        const el = document.getElementById(id);
        if (el && value !== undefined && value !== null) el.innerText = value;
    };

    // Která záložka vyžaduje které oprávnění (klíče odpovídají config.lua / ACL modalu)
    const TAB_PERMISSIONS = {
        players: 'players', bans: 'ban', vozidla: 'vehicles', frakce: 'server', economy: 'economy',
        whitelist: 'whitelist', tools: 'use', map: 'players', reports: 'use', chat: 'use',
        logs: 'use', dos: 'server', settings: 'server', sadmin: 'staffmanage', logadmin: 'staffmanage'
    };

    function applyMe(me) {
        document.querySelectorAll('.js-whoami').forEach(el => {
            el.innerText = `Přihlášen jako: ${me.name}, ${me.roleLabel}`;
        });

        const perms = me.perms || {};
        navItems.forEach(item => {
            const needed = TAB_PERMISSIONS[item.getAttribute('data-target')];
            if (needed) item.classList.toggle('hidden', !perms[needed]);
        });
        document.querySelector('.admin-duty')?.classList.toggle('hidden', !perms.use);

        if (dutyToggle) dutyToggle.checked = !!me.onDuty;
        if (dutyStatusLabel) dutyStatusLabel.innerText = me.onDuty ? 'Na duty' : 'Mimo duty';
    }

    function applyDashboard(d) {
        setText('statOnlinePlayers', d.online !== undefined ? `${d.online} / ${d.max}` : undefined);
        setText('statActiveAdmins', d.activeAdmins);
        setText('statPendingReports', d.pendingReports);
        setText('statStatus', d.status);
        setText('statUptime', d.uptime);
        setText('statPlayersTotalConnected', d.online);
        setText('statPlayersConnected24h', d.connected24h);
        setText('statPlayersNew24h', d.new24h !== undefined ? `+${d.new24h}` : undefined);
        setText('statActiveBans', d.activeBans);
        setText('statActiveWarns', d.activeWarns);
        setText('statBans24h', d.bans24h);

        // Naplánovaný restart – server posílá zbývající sekundy (nezávislé na hodinách klienta)
        if (d.restartIn !== undefined && d.restartIn !== null) {
            scheduledRestartAt = new Date(Date.now() + d.restartIn * 1000);
            activateScheduledRestartUI();
        } else if (scheduledRestartAt) {
            resetScheduledRestartUI();
        }
    }

    const playerList = document.getElementById('playerList');
    function renderPlayers(players) {
        if (!playerList) return;
        playerList.innerHTML = '';
        if (!players.length) {
            playerList.innerHTML = '<p class="k">Na serveru nikdo není.</p>';
            return;
        }
        players.forEach(p => {
            const card = document.createElement('div');
            card.className = 'card';
            card.dataset.filterAdmin = String(!!p.isAdmin);
            card.dataset.filterWhitelist = String(!!p.whitelisted);
            card.dataset.filterNote = String(!!p.hasNote);
            card.dataset.filterBan = String(!!p.hasWarn);

            const lines = [
                ['Jméno', p.charName], ['Group', p.group],
                ['Ping', p.ping !== undefined ? `${p.ping} ms` : null],
                ['Telefon', p.phone], ['Stavy', p.states]
            ].filter(([, v]) => v);

            card.innerHTML =
                `<h3>[${escapeHtml(p.id)}] ${escapeHtml(p.name)}</h3>` +
                lines.map(([k, v]) => `<p>${k}: ${escapeHtml(v)}</p>`).join('') +
                '<button class="btn btn-small btn-modal">Spravovat Hráče</button>';
            card.querySelector('.btn-modal').addEventListener('click', () => openPlayerModal(String(p.id), p.name));
            playerList.appendChild(card);
        });
        document.getElementById('playerSearchInput')?.dispatchEvent(new Event('keyup'));
    }

    function renderBans(bans) {
        const body = document.getElementById('banList');
        if (!body) return;
        body.innerHTML = '';
        bans.forEach(b => {
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td><strong>${escapeHtml(b.name)}</strong></td>
                <td><code>${escapeHtml(b.identifier)}</code></td>
                <td>${escapeHtml(b.reason)}</td>
                <td>${escapeHtml(b.createdLabel)}</td>
                <td><span class="badge ${b.permanent ? 'badge-danger' : 'badge-warning'}">${escapeHtml(b.expiresLabel)}</span></td>
                <td>${escapeHtml(b.admin)}</td>
                <td class="table-actions">
                    <button class="btn btn-small" data-action="unbanPlayer" data-id="${escapeHtml(b.id)}">Odbanovat</button>
                    <button class="btn btn-small" data-action="editban" data-id="${escapeHtml(b.id)}">Edit</button>
                </td>`;
            bindUnban(tr.querySelector('[data-action="unbanPlayer"]'));
            bindEditBan(tr.querySelector('[data-action="editban"]'));
            body.appendChild(tr);
        });
        document.getElementById('banSearchInput')?.dispatchEvent(new Event('keyup'));
    }

    function renderWarns(warns) {
        const body = document.getElementById('warnList');
        if (!body) return;
        body.innerHTML = '';
        warns.forEach(w => {
            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td><strong>${escapeHtml(w.name)}</strong></td>
                <td>${escapeHtml(w.reason)}</td>
                <td><span class="badge badge-warning">${w.index} / 3</span></td>
                <td>${escapeHtml(w.whenLabel)}</td>
                <td>${escapeHtml(w.admin)}</td>
                <td class="table-actions">
                    <button class="btn btn-small btn-danger" data-action="clearWarn" data-id="${escapeHtml(w.id)}">Zrušit</button>
                </td>`;
            bindClearWarn(tr.querySelector('[data-action="clearWarn"]'));
            body.appendChild(tr);
        });
    }

    function renderReports(reports) {
        const list = document.getElementById('reportsList');
        if (!list) return;
        list.innerHTML = reports.length ? '' : '<p class="k">Žádné čekající reporty.</p>';
        reports.forEach(r => {
            const card = document.createElement('div');
            card.className = 'card report-item';
            card.id = `report-${r.id}`;
            card.innerHTML = `
                <div class="report-header">
                    <div>
                        <span class="badge badge-warning">#${escapeHtml(r.id)} - ${escapeHtml(r.categoryLabel)}</span>
                        <h3 style="margin-top: 0.3rem;">${escapeHtml(r.title)}</h3>
                        <p class="report-meta">Hráč: <strong>${escapeHtml(r.playerName)}${r.playerId ? ` (ID: ${escapeHtml(r.playerId)})` : ''}</strong> | ${escapeHtml(r.whenLabel)}${r.assignedTo ? ` | Převzal: ${escapeHtml(r.assignedTo)}` : ''}</p>
                    </div>
                    <div class="report-actions">
                        ${r.playerId ? `<button class="btn btn-small" data-action="gotoReportPlayer" data-id="${escapeHtml(r.playerId)}">Přejít k hráči</button>` : ''}
                        <button class="btn btn-small btn-ghost" data-action="openReportChat" data-id="${escapeHtml(r.id)}" data-name="${escapeHtml(r.playerName)}">Otevřít Chat</button>
                        <button class="btn btn-small2" data-action="gotoReportLocation" data-id="${escapeHtml(r.id)}">Převzít</button>
                        <button class="btn btn-small btn-danger" data-action="closeReport" data-id="${escapeHtml(r.id)}">Uzavřít</button>
                    </div>
                </div>`;
            card.querySelectorAll('[data-action="gotoReportPlayer"], [data-action="gotoReportLocation"]').forEach(bindGeneric);
            attachOpenReportChatHandler(card.querySelector('[data-action="openReportChat"]'));
            attachCloseReportHandler(card.querySelector('[data-action="closeReport"]'));
            list.appendChild(card);
        });
        updateReportsCount();
    }

    const ROLE_BADGES = { trial: 'badge-warning', admin: 'badge-accent', senior: 'badge-accent', super: 'badge-danger', owner: 'badge-danger' };
    function renderAdmins(admins) {
        const body = document.getElementById('adminList');
        if (!body) return;
        body.innerHTML = '';
        admins.forEach(a => {
            const tr = document.createElement('tr');
            tr.setAttribute('data-admin-row', a.name);
            tr.innerHTML = `
                <td><strong>${escapeHtml(a.name)}${a.protected ? ' (Owner)' : ''}</strong></td>
                <td><code>${escapeHtml(a.identifier)}</code></td>
                <td><span class="badge ${ROLE_BADGES[a.role] || 'badge-accent'}">${escapeHtml(a.roleLabel)}</span></td>
                <td class="table-actions">${a.protected
                    ? '<button class="btn btn-small btn-ghost" disabled>Upravit</button>'
                    : `<button class="btn btn-small btn-edit-permissions" data-admin="${escapeHtml(a.name)}" data-perms='${escapeHtml(JSON.stringify(a.perms || {}))}'>Upravit Práva</button>
                       <button class="btn btn-small btn-danger" data-action="removeAdmin" data-admin="${escapeHtml(a.name)}" data-confirm="Opravdu chceš odebrat administrátorská práva hráči ${escapeHtml(a.name)}?">Odebrat</button>`}
                </td>`;
            const editBtn = tr.querySelector('.btn-edit-permissions');
            if (editBtn) attachPermissionsHandler(editBtn);
            const removeBtn = tr.querySelector('[data-action="removeAdmin"]');
            if (removeBtn) attachRemoveAdminHandler(removeBtn);
            body.appendChild(tr);
        });
    }

    function applyData(d) {
        if (d.me) applyMe(d.me);
        if (d.dashboard) applyDashboard(d.dashboard);
        if (d.players) renderPlayers(d.players);
        if (d.bans) renderBans(d.bans);
        if (d.warns) renderWarns(d.warns);
        if (d.reports) renderReports(d.reports);
        if (d.admins) renderAdmins(d.admins);
    }

    async function refreshData() {
        const data = await sendNUI('requestData');
        if (data && data.dashboard) applyData(data);
    }

    // Detail hráče do modalu (identifikátory, playtime, poznámka, varování)
    async function loadPlayerDetail(playerId) {
        const d = await sendNUI('getPlayerDetail', { id: playerId });
        if (!d || selectedPlayerId !== playerId) return;

        setText('modalSessionTime', d.sessionTime);
        setText('modalPlayTime', d.playTime);
        setText('modalJoinDate', d.joinDate);
        const wl = document.getElementById('modalHasWl');
        if (wl) {
            wl.innerText = d.hasWl ? 'ano' : 'ne';
            wl.className = d.hasWl ? 'text-success' : 'text-danger';
        }

        const ids = document.getElementById('modalIdentifiers');
        if (ids && d.identifiers) {
            ids.innerHTML = d.identifiers.map(i => `<p>${escapeHtml(i.label)}: <code>${escapeHtml(i.value)}</code></p>`).join('');
        }

        const note = document.getElementById('staffNoteInput');
        if (note) note.value = d.note || '';

        if (warnsList) {
            warnsList.innerHTML = (d.warns || []).map(w =>
                `<div class="log-entry"><span class="badge badge-warning">${w.index}/3</span><span class="log-text">${escapeHtml(w.reason)} — uděleno <strong>${escapeHtml(w.admin)}</strong>, ${escapeHtml(w.whenLabel)}</span></div>`
            ).join('') || '<p class="k">Hráč nemá žádná varování.</p>';
        }
    }

    // Periodické obnovování dat, dokud je menu otevřené
    setInterval(() => { if (menuOpen && IN_GAME) refreshData(); }, 8000);

    // Chat adminů a chat k reportům přichází z Lua jako zprávy
    function appendChatLine(container, author, message) {
        if (!container) return;
        const el = document.createElement('div');
        el.className = 'msg';
        el.innerHTML = `<strong>${escapeHtml(author)}:</strong> ${escapeHtml(message)}`;
        container.appendChild(el);
        container.scrollTop = container.scrollHeight;
    }

    // --- ZPRACOVÁNÍ ZPRÁV Z LUA KLIENTA ---
    window.addEventListener('message', (event) => {
        const data = event.data;
        switch (data.action) {
            case 'openMenu':
                setVisible(true);
                applyData(data);
                break;
            case 'updateData':
                applyData(data);
                break;
            case 'closeMenu':
                setVisible(false);
                document.querySelectorAll('.modal.show').forEach(m => m.classList.remove('show'));
                break;
            case 'staffChat':
                appendChatLine(adminStaffChat, data.from, data.message);
                break;
            case 'screenshot':
                document.getElementById('screenshotTitle').innerText = `Screenshot hráče ${data.name || ''}`;
                document.getElementById('screenshotImage').src = data.image;
                document.getElementById('screenshotModal')?.classList.add('show');
                break;
            case 'reportChat':
                if (String(selectedReportId) === String(data.reportId)) {
                    appendChatLine(reportChatMessages, data.from, data.message);
                }
                break;
        }
    });
});
