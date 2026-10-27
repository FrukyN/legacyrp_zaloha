let currentLicense = null;
let theoryQuestions = [];
let currentQuestionIndex = 0;
let errors = 0;
let localLicenses = {};
let userAccounts = [];

function formatMoney(value) {
    return (Math.floor(Number(value) || 0)).toLocaleString('cs-CZ');
}

window.addEventListener('message', function(event) {
    let data = event.data;
    if (data.action === "openMenu") {
        document.getElementById("app").classList.remove("hidden");
        localLicenses = data.licenses;
        userAccounts = data.accounts || [];
        loadLicenses(data.licenses, data.owned);
        document.getElementById("test-container").innerHTML = "Vyberte požadovanou skupinu řidičského oprávnění.";
    }
});

function loadLicenses(licenses, ownedStates) {
    const list = document.getElementById("license-list");
    list.innerHTML = "";
    Object.keys(licenses).forEach(key => {
        const state = ownedStates[key] || { theory: false, practical: false };
        
        const div = document.createElement("div");
        div.className = "character-card";
        
        if (state.practical === true) {
            div.style.opacity = "0.4";
            div.style.pointerEvents = "none";
            div.innerHTML = `
                <div class="character-avatar">${key}</div>
                <div class="character-name">${licenses[key].label}</div>
                <button class="action-btn primary" disabled style="background: var(--text-muted); border-color: var(--text-muted); cursor: not-allowed; color: #1a1a1a;">Vlastněno</button>
            `;
        } else if (state.theory === true) {
            div.innerHTML = `
                <div class="character-avatar">${key}</div>
                <div class="character-name">${licenses[key].label}</div>
                <button class="action-btn primary" style="background: var(--tlacitkobackground); border-color: var(--tlacitkaokra); color: var(--tlacitkatext);" onclick="resumePractical('${key}')">Zahájit jízdu</button>
            `;
        } else {
            div.innerHTML = `
                <div class="character-avatar">${key}</div>
                <div class="character-name">${licenses[key].label}</div>
                <button class="action-btn primary" onclick="showPaymentOptions('${key}')">Vybrat</button>
            `;
        }
        
        list.appendChild(div);
    });
}

function resumePractical(type) {
    currentLicense = type;
    const container = document.getElementById("test-container");
    container.innerHTML = `
        <div class="detail-block" style="text-align: center; padding-top: 30px;">
            <h2 style="color: var(--accent); font-size: 26px; margin-bottom: 5px;">Teorie hotová</h2>
            <p style="color: var(--text-muted); margin-bottom: 25px;">U této skupiny již máte úspěšně složenou teoretickou část (byla uložena). Můžete rovnou přejít k praktické zkoušce.</p>
            <button class="action-btn primary" style="padding: 15px 30px; font-size: 16px;" onclick="startPractical()">Zahájit praktickou zkoušku</button>
        </div>
    `;
}

function showPaymentOptions(type) {
    const license = localLicenses[type];
    if (!license.theory || license.theory.length === 0) {
        document.getElementById("test-container").innerHTML = `<div class="detail-block"><h2 style="color: var(--danger);">Chyba: Pro tuto skupinu nejsou nastaveny otázky!</h2></div>`;
        return;
    }

    const container = document.getElementById("test-container");
    container.innerHTML = `
        <div class="detail-block" style="text-align: center; margin-top: 20px;">
            <h2 style="font-size:24px; margin-bottom: 5px;">Platba za zkoušku</h2>
            <p style="color: var(--text-muted); margin-top: 0;">Skupina: <b>${license.label}</b> | Cena: <b>$${formatMoney(license.price)}</b></p>
            <div class="actions" style="margin-top: 30px; display: flex; justify-content: center; gap: 15px;">
                <button class="action-btn primary" onclick="processPayment('${type}', 'cash')">Zaplatit hotově</button>
                <button class="action-btn primary" style="background: rgba(37, 106, 175, 0.4); border-color: rgba(37, 106, 175, 0.8);" onclick="showBankAccounts('${type}')">Zaplatit kartou</button>
            </div>
        </div>
    `;
}

function showBankAccounts(type) {
    const license = localLicenses[type];
    const container = document.getElementById("test-container");

    if (!userAccounts || userAccounts.length === 0) {
        container.innerHTML = `
            <div class="detail-block" style="text-align: center; margin-top: 20px;">
                <h2 style="font-size:22px; color: var(--danger);">Nemáte žádný účet</h2>
                <p style="color: var(--text-muted);">Bohužel nemáte přístup k žádnému bankovnímu účtu s právem výběru.</p>
                <div class="actions" style="justify-content: center; margin-top: 20px;">
                    <button class="ghost" onclick="showPaymentOptions('${type}')">Zpět</button>
                </div>
            </div>
        `;
        return;
    }

    let accountsHtml = '';
    userAccounts.forEach(acc => {
        const isDefaultTag = acc.isDefault ? ' <span style="color: var(--accent); font-size: 13px;">(hlavní)</span>' : '';
        accountsHtml += `
            <button class="action-btn primary" style="display: flex; justify-content: space-between; align-items: center; width: 100%; padding: 12px 16px;" onclick="processPayment('${type}', 'bank', ${acc.id})">
                <span><b>${acc.label}</b>${isDefaultTag}</span>
                <span style="font-weight: 700; color: #a3e635;">$${formatMoney(acc.balance)}</span>
            </button>
        `;
    });

    container.innerHTML = `
        <div class="detail-block" style="margin-top: 10px;">
            <div style="text-align: center; margin-bottom: 15px;">
                <h2 style="font-size:22px; margin-bottom: 5px;">Výběr bankovního účtu</h2>
                <p style="color: var(--text-muted); margin: 0;">Poplatek: <b>$${formatMoney(license.price)}</b></p>
            </div>
            <div class="actions" style="flex-direction: column; gap: 8px; max-height: 250px; overflow-y: auto;">
                ${accountsHtml}
            </div>
            <div class="actions" style="justify-content: center; margin-top: 15px;">
                <button class="ghost" onclick="showPaymentOptions('${type}')">Zpět k výběru metody</button>
            </div>
        </div>
    `;
}

async function processPayment(type, method, accountId) {
    const response = await fetch(`https://${GetParentResourceName()}/processPayment`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ type: type, method: method, accountId: accountId })
    });
    const result = await response.json();
    
    const isOk = (result === true || (typeof result === 'object' && (result.ok === true || result.success === true)));
    
    if (isOk) {
        startTheory(type, localLicenses[type].theory);
    } else {
        const errorMsg = (typeof result === 'object' && result.message) ? result.message : 'Nemáte dostatek financí na tuto platební metodu!';
        const container = document.getElementById("test-container");

        const oldErr = document.getElementById("payment-error-msg");
        if (oldErr) oldErr.remove();

        const errP = document.createElement("p");
        errP.id = "payment-error-msg";
        errP.style = "color: var(--danger); text-align: center; margin-top: 15px; font-weight: bold;";
        errP.innerText = errorMsg;
        container.appendChild(errP);
    }
}

function startTheory(type, questions) {
    currentLicense = type;
    let amountToSlice = questions.length < 5 ? questions.length : 5;
    theoryQuestions = questions.sort(() => 0.5 - Math.random()).slice(0, amountToSlice); 
    currentQuestionIndex = 0;
    errors = 0;
    renderQuestion();
}

function renderQuestion() {
    const container = document.getElementById("test-container");
    if (currentQuestionIndex >= theoryQuestions.length) {
        finishTheory(true);
        return;
    }

    const q = theoryQuestions[currentQuestionIndex];
    let html = `<div class="detail-block"><h2 style="font-size:18px">${q.question}</h2><div class="actions" style="flex-direction:column">`;
    
    q.answers.forEach((ans, index) => {
        html += `<button class="action-btn primary" onclick="checkAnswer(${index}, ${q.correct})">${ans}</button>`;
    });
    
    html += `</div></div>`;
    container.innerHTML = html;
}

function checkAnswer(selected, correct) {
    if (selected !== correct) {
        errors++;
        if (errors >= 3) {
            finishTheory(false);
            return;
        }
    }
    currentQuestionIndex++;
    renderQuestion();
}

function finishTheory(passed) {
    const container = document.getElementById("test-container");
    if (passed) {
        fetch(`https://${GetParentResourceName()}/saveTheory`, {
            method: 'POST',
            body: JSON.stringify({ type: currentLicense })
        });

        container.innerHTML = `
            <div class="detail-block" style="text-align: center; padding-top: 30px;">
                <h2 style="color: rgba(79, 209, 165, 1); font-size: 26px; margin-bottom: 5px;">Test splněn!</h2>
                <p style="color: var(--text-muted); margin-bottom: 25px;">Úspěšně jste prošli teoretickou částí. Váš postup byl uložen. Nyní je na čase předvést vaše dovednosti v provozu.</p>
                <button class="action-btn primary" style="padding: 15px 30px; font-size: 16px;" onclick="startPractical()">Zahájit praktickou zkoušku</button>
            </div>
        `;
    } else {
        container.innerHTML = `
            <div class="detail-block" style="text-align: center; padding-top: 30px;">
                <h2 style="color: var(--danger); font-size: 26px;">Test nesplněn!</h2>
                <p style="color: var(--text-muted);">Měli jste příliš mnoho chyb. Můžete to zkusit znovu (bude nutné uhradit nový poplatek).</p>
            </div>
        `;
    }
}

function startPractical() {
    document.getElementById("app").classList.add("hidden");
    fetch(`https://${GetParentResourceName()}/startPractical`, {
        method: 'POST',
        body: JSON.stringify({ type: currentLicense })
    });
}

document.getElementById("close-btn").addEventListener("click", () => {
    document.getElementById("app").classList.add("hidden");
    fetch(`https://${GetParentResourceName()}/close`, { method: 'POST' });
});