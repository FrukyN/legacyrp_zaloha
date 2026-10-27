window.addEventListener('message', function(event) {
    let data = event.data;

    if (data.action === "setVisible") {
        document.getElementById('hud-container').style.display = data.state ? 'block' : 'none';
    }
    
    if (data.action === "setLogo") {
        document.getElementById('server-logo').style.display = data.state ? 'block' : 'none';
    }
    
    if (data.action === "setPosition") {
        let hud = document.getElementById('player-hud');
        hud.classList.remove('top-right', 'top-left', 'bottom-left', 'bottom-right');
        hud.classList.add(data.position);
    }

    if (data.action === "setCinematic") {
        let topBar = document.getElementById('cinematic-top');
        let bottomBar = document.getElementById('cinematic-bottom');
        if (data.state) {
            topBar.classList.add('active');
            bottomBar.classList.add('active');
        } else {
            topBar.classList.remove('active');
            bottomBar.classList.remove('active');
        }
    }

    if (data.action === "updateVoiceRange") {
        for (let i = 1; i <= 3; i++) {
            let dot = document.getElementById(`dot-${i}`);
            if (i <= data.mode) { dot.classList.add('active'); } 
            else { dot.classList.remove('active'); }
        }
    }

    // OPRAVA: Místo prohledávání teček aplikujeme mluvení jen na celý rodičovský kontejner
    if (data.action === "updateTalkingState") {
        let voiceContainer = document.getElementById('voice-container');
        if (data.state) {
            voiceContainer.classList.add('is-talking');
        } else {
            voiceContainer.classList.remove('is-talking');
        }
    }

// Nová funkce obsahující podmínky pro zobrazení/skrytí celého obalu
    function updateCircle(id, wrapperId, value, hideCondition) {
        // Ochrana před hodnotami mimo 0-100, které by rozbily SVG
        let safeValue = Math.max(0, Math.min(100, value));
        let offset = 100 - safeValue;
        document.getElementById(id).style.strokeDashoffset = offset;
        
        // Získání obalu daného kolečka
        let wrapper = document.getElementById(wrapperId);
        if (hideCondition) {
            wrapper.classList.add('hidden'); // Skryjeme obal (vymizí z Flexboxu)
        } else {
            wrapper.classList.remove('hidden'); // Odhalíme
        }
    }

    if (data.action === "updateHealth") {
        // Zdraví schováme, když je na 100%. Armor, když spadne na 0. Staminu, když se doplní na 100%.
        updateCircle('circle-health', 'wrapper-health', data.health, data.health >= 100);
        updateCircle('circle-armor', 'wrapper-armor', data.armor, data.armor <= 0);
        updateCircle('circle-stamina', 'wrapper-stamina', data.stamina, data.stamina >= 100);
        
        let vignette = document.getElementById('low-hp-vignette');
        if (data.health < 30) {
            vignette.classList.remove('hidden');
        } else {
            vignette.classList.add('hidden');
        }
    }

    if (data.action === "updateNeeds") {
        // Tyto staty schováme, jakmile je hráč plně ukojen / zdráv (hodnota je 0 nebo nižší)
        updateCircle('circle-hunger', 'wrapper-hunger', data.hunger, data.hunger <= 0);
        updateCircle('circle-thirst', 'wrapper-thirst', data.thirst, data.thirst <= 0);
        updateCircle('circle-stress', 'wrapper-stress', data.stress, data.stress <= 0);
        updateCircle('circle-alcohol', 'wrapper-alcohol', data.alcohol, data.alcohol <= 0);
        updateCircle('circle-drug', 'wrapper-drug', data.drug, data.drug <= 0);
    }

    if (data.action === "updateCarHud") {
        let carHud = document.getElementById('car-hud');
        let playerHud = document.getElementById('player-hud'); 
        
        if (data.inVehicle) {
            carHud.classList.remove('hidden');
            playerHud.classList.add('in-vehicle');
            
            document.getElementById('speed').innerText = data.speed;
            document.getElementById('gear').innerText = data.gear;
            document.getElementById('fuel').innerText = Math.round(data.fuel);
            document.getElementById('compass').innerText = data.compass;
            document.getElementById('street').innerText = data.street;
            
            document.getElementById('indicator-left').classList.toggle('active', data.leftBlinker);
            document.getElementById('indicator-right').classList.toggle('active', data.rightBlinker);
            
            document.getElementById('cruise-control').classList.toggle('active', data.cruiseControl);
            document.getElementById('speed-limiter').classList.toggle('active', data.speedLimiter);
        } else {
            carHud.classList.add('hidden');
            playerHud.classList.remove('in-vehicle');
        }
    }
});