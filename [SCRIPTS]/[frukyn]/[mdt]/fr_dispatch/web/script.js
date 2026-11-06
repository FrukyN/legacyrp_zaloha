const container = document.getElementById('dispatch-container');

// Audio kontext pro realistické zvuky vysílačky bez nutnosti externích wav souborů
const AudioContext = window.AudioContext || window.webkitAudioContext;
let audioCtx = null;

function playRadioBeep(priority) {
    try {
        if (!audioCtx) audioCtx = new AudioContext();
        if (audioCtx.state === 'suspended') audioCtx.resume();

        const osc = audioCtx.createOscillator();
        const gain = audioCtx.createGain();
        osc.connect(gain);
        gain.connect(audioCtx.destination);

        const now = audioCtx.currentTime;

        if (priority === 3) {
            // Priority Panic / Officer Down - dvou-tónový warble
            osc.type = 'sawtooth';
            osc.frequency.setValueAtTime(880, now);
            osc.frequency.setValueAtTime(1174, now + 0.12);
            osc.frequency.setValueAtTime(880, now + 0.24);
            osc.frequency.setValueAtTime(1174, now + 0.36);

            gain.gain.setValueAtTime(0.18, now);
            gain.gain.exponentialRampToValueAtTime(0.01, now + 0.55);

            osc.start(now);
            osc.stop(now + 0.55);
        } else {
            // Standardní policejní radio chirp
            osc.type = 'sine';
            osc.frequency.setValueAtTime(650, now);
            osc.frequency.exponentialRampToValueAtTime(950, now + 0.08);

            gain.gain.setValueAtTime(0.12, now);
            gain.gain.exponentialRampToValueAtTime(0.01, now + 0.18);

            osc.start(now);
            osc.stop(now + 0.18);
        }
    } catch (e) {
        // Fallback pro tichý režim
    }
}

window.addEventListener('message', (event) => {
    const item = event.data;
    if (item.action === 'newAlert' && item.data) {
        showAlert(item.data);
    }
});

function showAlert(data) {
    const card = document.createElement('div');
    card.className = 'alert-card';

    const color = data.color || '#3b82f6';
    const duration = 8000;

    playRadioBeep(data.priority || 1);

    const vehicleHtml = data.vehicle ? `
        <div class="alert-info-row">
            <i class="fa-solid fa-car"></i>
            <span>${escapeHtml(data.vehicle.model)} [${escapeHtml(data.vehicle.plate)}] · ${escapeHtml(data.vehicle.color || '')}</span>
        </div>
    ` : '';

    const callerHtml = data.caller ? `
        <div class="alert-info-row">
            <i class="fa-solid fa-user"></i>
            <span>${escapeHtml(data.caller)}</span>
        </div>
    ` : '';

    card.innerHTML = `
        <div class="alert-header">
            <span class="code-badge" style="background: ${color}25; color: ${color}; border: 1px solid ${color}60;">
                <i class="${data.icon || 'fa-solid fa-bell'}"></i>
                ${escapeHtml(data.code || '10-00')}
            </span>
            <span class="alert-time">${escapeHtml(data.time || '')}</span>
        </div>
        <div class="alert-title">${escapeHtml(data.title || 'Hlášení')}</div>
        <div class="alert-info-row">
            <i class="fa-solid fa-location-dot"></i>
            <span>${escapeHtml(data.street || 'Neznámá ulice')} ${data.zone ? `· ${escapeHtml(data.zone)}` : ''}</span>
        </div>
        ${vehicleHtml}
        ${callerHtml}
        ${data.description ? `<div class="alert-desc">${escapeHtml(data.description)}</div>` : ''}
        <div class="alert-footer">
            <span class="keybind-hint">
                <span class="key-kbd">G</span> Nastavit GPS
            </span>
            <span>#${data.id || ''}</span>
        </div>
        <div class="progress-bar-container">
            <div class="progress-bar-fill" style="background: ${color};"></div>
        </div>
    `;

    container.appendChild(card);

    // Limit maximálně 4 současných notifikací na obrazovce
    if (container.children.length > 4) {
        const oldest = container.firstElementChild;
        if (oldest) removeCard(oldest);
    }

    // Animace vstupu
    requestAnimationFrame(() => {
        card.classList.add('show');
        const fill = card.querySelector('.progress-bar-fill');
        if (fill) {
            fill.style.transitionDuration = `${duration}ms`;
            fill.style.width = '0%';
        }
    });

    const timer = setTimeout(() => {
        removeCard(card);
    }, duration);

    card.dataset.timer = timer;
}

function removeCard(card) {
    if (!card) return;
    clearTimeout(card.dataset.timer);
    card.classList.remove('show');
    card.classList.add('hide');
    setTimeout(() => {
        if (card.parentNode) {
            card.parentNode.removeChild(card);
        }
    }, 400);
}

function escapeHtml(str) {
    if (!str) return '';
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#039;');
}
