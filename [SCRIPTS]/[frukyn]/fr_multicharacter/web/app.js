const app = document.getElementById('app');
const list = document.getElementById('characterList');
const detailPanel = document.getElementById('detailPanel');

let state = {
    characters: [],
    selectedCharacter: null,
    maxSlots: 1
};

function escapeHtml(value) {
    return String(value ?? '').replace(/[&<>"']/g, (char) => ({
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        "'": '&#039;',
    }[char]));
}

function getDisplayName(character) {
    const firstName = character?.firstName ?? character?.firstname ?? '';
    const lastName = character?.lastName ?? character?.lastname ?? '';
    return `${firstName} ${lastName}`.trim();
}

function normalizeDateValue(value) {
    if (!value || value === '-') return '-';
    if (typeof value === 'number') return new Date(value).toISOString().slice(0, 10);
    if (typeof value === 'string') {
        if (/^\d{13,}$/.test(value)) return new Date(Number(value)).toISOString().slice(0, 10);
        if (/^\d{4}-\d{2}-\d{2}$/.test(value)) return value;
        if (/^\d{2}\/\d{2}\/\d{4}$/.test(value)) {
            const [day, month, year] = value.split('/');
            return `${year}-${month}-${day}`;
        }
        const parsed = new Date(value);
        if (!Number.isNaN(parsed.getTime())) return parsed.toISOString().slice(0, 10);
    }
    return value;
}

function renderDetails(character) {
    if (!character) {
        detailPanel.innerHTML = `
            <div class="detail-placeholder">
                <p>Vyber postavu nebo vytvoř novou.</p>
            </div>
        `;
        return;
    }

    const fullName = getDisplayName(character);
    
    // Extrakce data narození
    const dobRaw = character.date || character.dateOfBirth || character.date_of_birth || character.dob;
    const dob = normalizeDateValue(dobRaw || '-');
    
    // Extrakce data posledního hraní
    const lastPlayedRaw = character.lastPlayed || character.lastplayed;
    let lastPlayedFormatted = 'Neznámé';
    if (lastPlayedRaw) {
        const d = new Date(lastPlayedRaw);
        lastPlayedFormatted = !isNaN(d.getTime()) ? d.toLocaleDateString('cs-CZ') : String(lastPlayedRaw).split(' ')[0];
    }

    // Extrakce zaměstnání
    let jobLabel = 'Nezaměstnaný';
    if (character.groups && typeof character.groups === 'object' && Object.keys(character.groups).length > 0) {
        jobLabel = Object.keys(character.groups).map(g => g.charAt(0).toUpperCase() + g.slice(1)).join(', ');
    } else if (character.job) {
        jobLabel = typeof character.job === 'string' ? character.job : (character.job.label || character.job.name || 'Nezaměstnaný');
    }

    detailPanel.innerHTML = `
        <div class="detail-block">
            <div>
                <div class="eyebrow">Detail postavy</div>
                <h2>${escapeHtml(fullName)}</h2>
            </div>

            <div class="detail-row"><span>Naposledy hráno</span><strong>${escapeHtml(lastPlayedFormatted)}</strong></div>
            <div class="detail-row"><span>Datum narození</span><strong>${escapeHtml(dob)}</strong></div>
            <div class="detail-row"><span>Zaměstnání</span><strong>${escapeHtml(jobLabel)}</strong></div>

            <div class="actions">
                <button class="action-btn primary" type="button" data-select="${character.charId}">Vybrat</button>
                <button class="action-btn danger" type="button" data-delete="${character.charId}" disabled style="opacity: 0.4; cursor: not-allowed; filter: grayscale(100%);">Smazat</button>
            </div>
        </div>
    `;

    detailPanel.querySelector('[data-select]')?.addEventListener('click', () => {
        fetch(`https://fr_multicharacter/selectCharacter`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({ charId: character.charId })
        });
    });
}

function renderCharacters() {
    list.innerHTML = '';

    if (!state.characters || state.characters.length === 0) {
        const emptyCard = document.createElement('div');
        emptyCard.className = 'character-card';
        emptyCard.innerHTML = `
            <div class="character-info-wrapper">
                <div class="character-name">Žádné postavy</div>
                <div class="meta">Vytvoř novou postavu pro zahájení hraní.</div>
            </div>
        `;
        list.appendChild(emptyCard);
    }

    state.characters.forEach((character) => {
        const card = document.createElement('div');
        const fullName = getDisplayName(character);

        const lastPlayedRaw = character.lastPlayed || character.lastplayed;
        let lastPlayedFormatted = 'Neznámé';
        if (lastPlayedRaw) {
            const d = new Date(lastPlayedRaw);
            lastPlayedFormatted = !isNaN(d.getTime()) ? d.toLocaleDateString('cs-CZ') : String(lastPlayedRaw).split(' ')[0];
        }

        card.className = `character-card ${state.selectedCharacter && state.selectedCharacter.charId === character.charId ? 'selected' : ''}`;
        card.innerHTML = `
            <div class="character-avatar">${escapeHtml((character.firstName ?? character.firstname ?? 'A').charAt(0))}</div>
            <div class="character-info-wrapper">
                <div class="character-name">${escapeHtml(fullName)}</div>
                <div class="meta">Naposledy hráno:<br>${escapeHtml(lastPlayedFormatted)}</div>
            </div>
        `;
        
        card.addEventListener('click', () => {
            state.selectedCharacter = character;
            renderCharacters();
            renderDetails(character);
            
            // Odeslání ID postavy do Lua pro zobrazení modelu
            fetch(`https://fr_multicharacter/previewCharacter`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({ charId: character.charId })
            });
        });
        
        list.appendChild(card);
    });

    const newButton = document.createElement('button');
    newButton.className = 'new-character';
    newButton.type = 'button';
    
    if (state.characters.length >= state.maxSlots) {
        newButton.textContent = `Limit postav dosažen (${state.maxSlots})`;
        newButton.disabled = true;
        newButton.style.opacity = '0.5';
        newButton.style.cursor = 'not-allowed';
    } else {
        newButton.textContent = 'Vytvořit novou postavu';
        newButton.addEventListener('click', () => {
            fetch(`https://fr_multicharacter/startLibCreation`, { method: 'POST', body: JSON.stringify({}) });
        });
    }

    list.appendChild(newButton);
}

function handleMessage(event) {
    const data = event.data || {};

    switch (data.action) {
        case 'open':
            app.classList.remove('hidden');
            state.characters = data.characters || [];
            renderCharacters();
            if (state.characters.length > 0) {
                state.selectedCharacter = state.characters[0];
                renderDetails(state.selectedCharacter);
                
                // Načte model postavy hned při prvotním spuštění UI
                fetch(`https://fr_multicharacter/previewCharacter`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                    body: JSON.stringify({ charId: state.selectedCharacter.charId })
                });
            } else {
                state.selectedCharacter = null;
                renderDetails(null);
            }
            break;
        case 'close':
            app.classList.add('hidden');
            state.selectedCharacter = null;
            break;
        case 'characters:update':
            state.characters = data.characters || [];
            renderCharacters();
            if (state.characters.length > 0) {
                if (!state.selectedCharacter) state.selectedCharacter = state.characters[0];
                renderDetails(state.selectedCharacter);
            } else {
                state.selectedCharacter = null;
                renderDetails(null);
            }
            break;
        case 'setLimit':
            state.maxSlots = data.maxSlots || 1;
            renderCharacters();
            break;
        default:
            break;
    }
}

window.addEventListener('message', handleMessage);
renderCharacters();