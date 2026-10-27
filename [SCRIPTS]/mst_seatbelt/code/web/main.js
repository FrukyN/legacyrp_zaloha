const i = document.getElementById('seatbelt-indicator');
let v = false, t = null;
let heartbeatAudio = null;
let heartbeatTimeout = null;
let heartbeatStartTime = null;
let heartbeatTotalDuration = null;

const clearT = () => { if (t) clearTimeout(t); };

const playHeartbeat = (volume, duration) => {
    stopHeartbeat();

    heartbeatTotalDuration = duration || 0;
    heartbeatStartTime = Date.now();

    const playLoop = () => {
        if (!heartbeatStartTime) return;

        const elapsed = Date.now() - heartbeatStartTime;
        const remaining = heartbeatTotalDuration - elapsed;

        if (remaining <= 0) {
            stopHeartbeat();
            return;
        }

        heartbeatAudio = new Audio('assets/heartbeat.ogg');
        heartbeatAudio.volume = Math.max(0, Math.min(1, volume || 1.0));
        heartbeatAudio.loop = false;

        heartbeatAudio.addEventListener('ended', () => {
            if (!heartbeatStartTime) return;

            const elapsedAfterEnd = Date.now() - heartbeatStartTime;
            const remainingAfterEnd = heartbeatTotalDuration - elapsedAfterEnd;

            if (remainingAfterEnd > 0) {
                playLoop();
            } else {
                stopHeartbeat();
            }
        });

        heartbeatAudio.play().catch(err => console.error('Failed to play heartbeat:', err));
    };

    playLoop();

    if (heartbeatTotalDuration > 0) {
        heartbeatTimeout = setTimeout(() => {
            stopHeartbeat();
        }, heartbeatTotalDuration);
    }
};

const stopHeartbeat = () => {
    heartbeatStartTime = null;
    heartbeatTotalDuration = null;

    if (heartbeatAudio) {
        heartbeatAudio.pause();
        heartbeatAudio.currentTime = 0;
        heartbeatAudio = null;
    }
    if (heartbeatTimeout) {
        clearTimeout(heartbeatTimeout);
        heartbeatTimeout = null;
    }
};

const applyHUDConfig = (config) => {
    if (!config || !i) return;
    const root = document.documentElement;

    if (config.position) {
        if (config.position.top) root.style.setProperty('--hud-top', config.position.top);
        if (config.position.right) root.style.setProperty('--hud-right', config.position.right);
    }

    if (config.size) {
        if (config.size.width) root.style.setProperty('--hud-width', config.size.width);
        if (config.size.height) root.style.setProperty('--hud-height', config.size.height);
    }
};

window.addEventListener('message', e => {
    const { type, duration, volume } = e.data;
    if (!i && type !== 'playHeartbeat' && type !== 'stopHeartbeat') return;

    switch (type) {
        case 'updateHUDConfig':
            applyHUDConfig(e.data.config);
            break;
        case 'showIndicator':
            if (!v) {
                v = true;
                i.classList.add('show');
                clearT();
            }
            break;
        case 'hideIndicator':
            if (v) {
                v = false;
                i.classList.remove('show');
                clearT();
            }
            break;
        case 'showTemporary':
            if (!v) {
                v = true;
                i.classList.add('show');
            }
            clearT();
            if (duration) {
                t = setTimeout(() => {
                    v = false;
                    i.classList.remove('show');
                }, duration);
            }
            break;
        case 'playHeartbeat':
            playHeartbeat(volume, duration);
            break;
        case 'stopHeartbeat':
            stopHeartbeat();
            break;
    }
});
