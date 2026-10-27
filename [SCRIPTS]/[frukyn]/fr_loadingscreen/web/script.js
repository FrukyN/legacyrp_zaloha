// --- NASTAVENÍ PLAYLISTU SOUNDCLOUD ---
// Vlož sem celé URL adresy skladeb
const SOUNDCLOUD_TRACKS = [
    'https://soundcloud.com/korey-keat/animal-i-have-become-three',
    'https://soundcloud.com/mybodyisacage/drive',
    'https://soundcloud.com/fromivanb/ivan-b-sweaters',
    'https://soundcloud.com/spinninrecords/sea-shanty-wellerman-out-now',
    
    ]; 

let currentVolume = 15; // Výchozí hlasitost (0 - 100)
// ---------------------------

let widget;
let isPlaying = false; 
let currentIndex = Math.floor(Math.random() * SOUNDCLOUD_TRACKS.length);

// Jakmile se načte stránka, inicializujeme SoundCloud přehrávač
document.addEventListener("DOMContentLoaded", () => {
    const iframe = document.getElementById('yt-placeholder');
    widget = SC.Widget(iframe);

    // Jakmile je widget připraven
    widget.bind(SC.Widget.Events.READY, function() {
        widget.setVolume(currentVolume);
        loadCurrentSong(); // Začneme načítat první track
    });

    // Event spuštění přehrávání
    widget.bind(SC.Widget.Events.PLAY, function() {
        isPlaying = true;
        document.getElementById('btn-playpause').innerHTML = "Pozastavit";
        
        // Získání názvu skladby
        widget.getCurrentSound(function(sound) {
            if (sound && sound.title) {
                document.getElementById('song-title').innerText = sound.title;
            } else {
                document.getElementById('song-title').innerText = "Neznámá skladba";
            }
        });
    });

    // Event pozastavení
    widget.bind(SC.Widget.Events.PAUSE, function() {
        isPlaying = false;
        document.getElementById('btn-playpause').innerHTML = "Přehrát";
    });

    // Event po dohrání písničky (přepne na další)
    widget.bind(SC.Widget.Events.FINISH, function() {
        playNextSong();
    });
});

// Funkce pro načtení a spuštění konkrétního tracku z pole
function loadCurrentSong() {
    document.getElementById('song-title').innerText = "Načítání skladby...";
    
    widget.load(SOUNDCLOUD_TRACKS[currentIndex], {
        auto_play: true, // Automaticky se pokusí spustit
        hide_related: true,
        show_comments: false,
        show_user: false,
        show_reposts: false,
        visual: false,
        callback: function() {
            widget.setVolume(currentVolume);
        }
    });
}

function playNextSong() {
    currentIndex++;
    if (currentIndex >= SOUNDCLOUD_TRACKS.length) {
        currentIndex = 0;
    }
    loadCurrentSong();
}

function playPrevSong() {
    currentIndex--;
    if (currentIndex < 0) {
        currentIndex = SOUNDCLOUD_TRACKS.length - 1;
    }
    loadCurrentSong();
}

// --- OBSLUHA TLAČÍTEK ---

document.getElementById('btn-playpause').addEventListener('click', () => {
    widget.toggle(); // Samo přepíná mezi Play a Pause
});

document.getElementById('btn-next').addEventListener('click', playNextSong);
document.getElementById('btn-prev').addEventListener('click', playPrevSong);

document.getElementById('btn-volup').addEventListener('click', () => {
    currentVolume += 10; // Přidáváme po 10 procentech
    if (currentVolume > 100) currentVolume = 100;
    widget.setVolume(currentVolume);
});

document.getElementById('btn-voldown').addEventListener('click', () => {
    currentVolume -= 10;
    if (currentVolume < 0) currentVolume = 0;
    widget.setVolume(currentVolume);
});