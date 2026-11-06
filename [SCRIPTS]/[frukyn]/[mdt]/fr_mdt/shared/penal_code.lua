PenalCode = {
    {
        category = 'Dopravní přestupky a delikty',
        color = '#38bdf8',
        charges = {
            { id = 't01', title = 'Překročení rychlosti v obci', fine = 500, jail = 0, points = 2, desc = 'Jízda rychlostí vyšší než 50 km/h v zastavěné oblasti.' },
            { id = 't02', title = 'Překročení rychlosti mimo obec / dálnice', fine = 800, jail = 0, points = 3, desc = 'Jízda rychlostí vyšší než povolená na okresních silnicích a dálnicích.' },
            { id = 't03', title = 'Jízda v protisměru', fine = 1200, jail = 0, points = 4, desc = 'Úmyslná jízda v protisměrném jízdním pruhu ohrožující provoz.' },
            { id = 't04', title = 'Nerespektování světelné signalizace (Červená)', fine = 600, jail = 0, points = 3, desc = 'Průjezd křižovatkou na červený signál.' },
            { id = 't05', title = 'Řízení bez řidičského oprávnění', fine = 2500, jail = 5, points = 5, desc = 'Řízení motorového vozidla bez platného řidičského průkazu.' },
            { id = 't06', title = 'Řízení pod vlivem alkoholu / omamných látek', fine = 4500, jail = 15, points = 6, desc = 'Řízení s pozitivním testem na alkohol či drogy.' },
            { id = 't07', title = 'Neuposlechnutí výzvy k zastavení / Ujíždění hlídce', fine = 6000, jail = 20, points = 7, desc = 'Aktivní pokus o ujetí služebnímu vozidlu IZS se zapnutou signalizací.' },
            { id = 't08', title = 'Ujetí od dopravní nehody', fine = 3500, jail = 10, points = 5, desc = 'Opuštění místa nehody bez poskytnutí součinnosti či první pomoci.' },
            { id = 't09', title = 'Nebezpečná / agresivní jízda (Street Racing)', fine = 5000, jail = 15, points = 6, desc = 'Účast na nelegálních závodech nebo bezohledné ohrožování ostatních účastníků.' },
        }
    },
    {
        category = 'Násilné trestné činy',
        color = '#f43f5e',
        charges = {
            { id = 'v01', title = 'Fyzické napadení občana', fine = 3000, jail = 10, desc = 'Úmyslné fyzické napadení jiné osoby bez použití zbraně.' },
            { id = 'v02', title = 'Napadení se zbraní v ruce', fine = 6500, jail = 20, desc = 'Vyhrožování nebo útok střelnou či chladnou zbraní.' },
            { id = 'v03', title = 'Napadení veřejného činitele', fine = 8000, jail = 25, desc = 'Fyzický útok na policistu, záchranáře nebo hasiče ve službě.' },
            { id = 'v04', title = 'Těžké ublížení na zdraví', fine = 10000, jail = 35, desc = 'Způsobení vážného zranění s trvalými následky nebo hospitalizací.' },
            { id = 'v05', title = 'Únos a omezování osobní svobody', fine = 15000, jail = 40, desc = 'Zadržování osoby proti její vůli, držení rukojmí.' },
            { id = 'v06', title = 'Pokus o vraždu', fine = 25000, jail = 50, desc = 'Přímý pokus o usmrcení jiné osoby.' },
            { id = 'v07', title = 'Vražda prvního stupně', fine = 50000, jail = 75, desc = 'Předem promyšlené usmrcení člověka.' },
            { id = 'v08', title = 'Vražda veřejného činitele', fine = 75000, jail = 90, desc = 'Usmrcení policisty nebo úřední osoby při výkonu služby.' },
        }
    },
    {
        category = 'Majetková trestná činnost a loupeže',
        color = '#f59e0b',
        charges = {
            { id = 'p01', title = 'Krádež motorového vozidla (Grand Theft Auto)', fine = 5000, jail = 15, desc = 'Odcizení nebo neoprávněné užívání cizího motorového vozidla.' },
            { id = 'p02', title = 'Krádež služebního vozidla IZS', fine = 12000, jail = 25, desc = 'Odcizení policejního, záchranářského nebo hasičského vozidla.' },
            { id = 'p03', title = 'Vloupání do obydlí / soukromého objektu', fine = 6000, jail = 20, desc = 'Násilné vniknutí do nemovitosti za účelem krádeže.' },
            { id = 'p04', title = 'Loupežné přepadení večerky / obchodu', fine = 10000, jail = 30, desc = 'Ozbrojené přepadení prodejny nebo čerpací stanice.' },
            { id = 'p05', title = 'Vykradení banky / trezoru', fine = 35000, jail = 50, desc = 'Ozbrojené loupežné přepadení finanční instituce.' },
            { id = 'p06', title = 'Poškozování cizí věci / Vandalismus', fine = 2000, jail = 5, desc = 'Úmyslné poškození nebo zničení cizího majetku.' },
        }
    },
    {
        category = 'Zbraně a omamné látky',
        color = '#a855f7',
        charges = {
            { id = 'w01', title = 'Držení nelegální střelné zbraně (Class 1 - Pistole)', fine = 5000, jail = 15, desc = 'Držení pistole bez platného zbrojního průkazu.' },
            { id = 'w02', title = 'Držení automatické / těžké zbraně (Class 2 / 3)', fine = 15000, jail = 35, desc = 'Držení SMG, útočné pušky, brokovnice nebo výbušniny.' },
            { id = 'w03', title = 'Nedovolené ozbrojování a distribuce zbraní', fine = 40000, jail = 60, desc = 'Nelegální prodej, výroba nebo překupnictví zbraní.' },
            { id = 'w04', title = 'Držení omamných látek (menší množství)', fine = 2500, jail = 5, desc = 'Přechovávání drog pro vlastní spotřebu.' },
            { id = 'w05', title = 'Distribuce a prodej omamných látek', fine = 15000, jail = 35, desc = 'Prodej drog dalším osobám ve velkém měřítku.' },
            { id = 'w06', title = 'Střelba na veřejném prostranství', fine = 7000, jail = 20, desc = 'Neoprávněná střelba v obydlených oblastech.' },
        }
    },
    {
        category = 'Veřejný pořádek a maření spravedlnosti',
        color = '#10b981',
        charges = {
            { id = 'o01', title = 'Neuposlechnutí výzvy úřední osoby', fine = 2000, jail = 5, desc = 'Odmítnutí splnění zákonného příkazu policisty.' },
            { id = 'o02', title = 'Výtržnictví a narušování veřejného pořádku', fine = 1500, jail = 5, desc = 'Agresivní chování na veřejnosti, vulgární napadání.' },
            { id = 'o03', title = 'Křivé obvinění / Křivá výpověď', fine = 5000, jail = 15, desc = 'Lživé svědectví s cílem poškodit jinou osobu nebo vyšetřování.' },
            { id = 'o04', title = 'Podplácení / Pokus o úplatek', fine = 10000, jail = 25, desc = 'Nabídnutí finanční či jiné odměny policistovi.' },
            { id = 'o05', title = 'Maření výkonu úředního rozhodnutí', fine = 8000, jail = 20, desc = 'Porušení zákazu řízení, únik z vazby apod.' },
        }
    }
}
