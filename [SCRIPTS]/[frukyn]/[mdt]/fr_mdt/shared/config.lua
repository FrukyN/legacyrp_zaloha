Config = {}

Config.Debug = false

-- Frakce s přístupem do policejního MDT
Config.AuthorizedJobs = {
    ['police'] = { label = 'Police Department', badge = 'LSPD', minGrade = 0 },
    ['lspd'] = { label = 'Police Department', badge = 'LSPD', minGrade = 0 },
    ['sheriff'] = { label = 'Sheriff Office', badge = 'BCSO', minGrade = 0 },
    ['bcso'] = { label = 'Sheriff Office', badge = 'BCSO', minGrade = 0 },
    ['sasp'] = { label = 'State Police', badge = 'SASP', minGrade = 0 },
    ['doj'] = { label = 'Ministerstvo spravedlnosti', badge = 'DOJ', minGrade = 0 },
    ['ambulance'] = { label = 'Emergency Medical Services', badge = 'EMS', minGrade = 0, readOnly = true },
    ['ems'] = { label = 'Emergency Medical Services', badge = 'EMS', minGrade = 0, readOnly = true }
}

-- Klávesová zkratka pro otevření MDT
Config.OpenKeybind = 'F10'
Config.Command = 'mdt'

-- Předmět v inventáři nutný pro otevření (nastav na false, pokud stačí příkaz/klávesa)
Config.RequiredItem = false -- např. 'police_tablet'

-- Názvy výchozích oddělení pro zobrazení
Config.DepartmentName = 'Los Santos Police Department'
Config.SystemName = 'POLICE COMPUTER AIDED DISPATCH // MDT SYSTEM'

-- Výchozí platnost zatykače ve dnech
Config.WarrantDurationDays = 7

-- Úrovně oprávnění v MDT
Config.Roles = {
    ['officer'] = { label = 'Důstojník', level = 1 },
    ['supervisor'] = { label = 'Supervizor (Seržant+)', level = 2 },
    ['command'] = { label = 'Vedení (Poručík+)', level = 3 },
    ['admin'] = { label = 'Administrátor MDT / Chief', level = 4 }
}

-- Přehled 10-kódů a signálů (Český policejní standard)
Config.TenCodes = {
    { code = '10-0', title = 'Pozor na frekvenci', desc = 'Varování o důležité relaci, zvýšit pozornost.' },
    { code = '10-1', title = 'Špatný signál', desc = 'Nesrozumitelné rádiové vysílání.' },
    { code = '10-2', title = 'Dobrý signál', desc = 'Čistý a srozumitelný příjem.' },
    { code = '10-3', title = 'Rádiový klid (Stop vysílání)', desc = 'Okamžitý zákaz vysílání pro všechny jednotky mimo zasahující.' },
    { code = '10-4', title = 'Rozumím / Příjem', desc = 'Zpráva přijata a pochopena.' },
    { code = '10-6', title = 'Zaneprázdněn', desc = 'Jednotka vykonává činnost, není k dispozici pro běžné výzvy.' },
    { code = '10-7', title = 'Konec služby (Off-Duty)', desc = 'Jednotka ukončila službu a opouští frekvenci.' },
    { code = '10-8', title = 'Ve službě (On-Duty / Volný)', desc = 'Jednotka je k dispozici pro přidělení výzvy.' },
    { code = '10-10', title = 'Rvačka / Fyzické napadení', desc = 'Probíhající fyzický konflikt na veřejnosti.' },
    { code = '10-12', title = 'Přítomnost civilisty', desc = 'V blízkosti hlídky nebo ve voze je nezúčastněná osoba.' },
    { code = '10-13', title = 'Důstojník zraněn / v bezvědomí', desc = 'Kolega v ohrožení života! Okamžitá podpora a EMS nutná.' },
    { code = '10-14', title = 'Požadavek na EMS', desc = 'Na místo je potřeba vyslat zdravotnickou záchrannou službu.' },
    { code = '10-19', title = 'Návrat na stanici', desc = 'Hlídka se vrací na základnu/okrsek.' },
    { code = '10-20', title = 'Poloha hlídky', desc = 'Dotaz na aktuální pozici nebo nahlášení polohy.' },
    { code = '10-23', title = 'Příjezd na místo události', desc = 'Hlídka dorazila k nahlášené situaci.' },
    { code = '10-31', title = 'Probíhající trestný čin / Poplach', desc = 'Aktivní trestná činnost, loupež nebo tichý alarm.' },
    { code = '10-38', title = 'Dopravní kontrola (Traffic Stop)', desc = 'Zastavování podezřelého nebo přestupkového vozidla.' },
    { code = '10-41', title = 'Zahájení hlídkové činnosti', desc = 'Nástup do aktivní hlídky v rajonu.' },
    { code = '10-42', title = 'Ukončení směny', desc = 'Odjezd z rajonu, konec hlídky.' },
    { code = '10-50', title = 'Dopravní nehoda', desc = 'Havárie vozidel na komunikaci.' },
    { code = '10-60', title = 'Krádež motorového vozidla', desc = 'Carjacking / hlášené odcizení automobilu.' },
    { code = '10-70', title = 'Požár', desc = 'Požár budovy, vozidla nebo lesního porostu.' },
    { code = '10-71', title = 'Střelba v oblasti', desc = 'Aktivní střelba na veřejnosti nebo na hlídku.' },
    { code = '10-80', title = 'Pronásledování vozidla (Pursuit)', desc = 'Aktivní pronásledování ujíždějícího podezřelého.' },
    { code = '10-90', title = 'Probíhající loupež', desc = 'Aktivní přepadení banky, klenotnictví nebo obchodu.' },
    { code = '10-97', title = 'Na místě', desc = 'Jednotka je přítomna na místě hlášené události.' },
    { code = '10-99', title = 'PANIC BUTTON (Tísňové tlačítko)', desc = 'Nejvyšší priorita! Policista v přímém ohrožení života.' }
}

-- Označení volacích znaků a divizí
Config.Divisions = {
    { prefix = 'ADAM', desc = 'Standardní dvoučlenná motorizovaná hlídka (např. 1-A-12)' },
    { prefix = 'LINCOLN', desc = 'Jednočlenná motorizovaná hlídka (např. 1-L-04)' },
    { prefix = 'MARY', desc = 'Dopravní motohlídka (Policejní motocykl)' },
    { prefix = 'AIR', desc = 'Letecká podpora (Vrtulník LSPD / BCSO)' },
    { prefix = 'K9', desc = 'Psovod (Kynologická služba)' },
    { prefix = 'DAVID', desc = 'SWAT / Zásahová jednotka' },
    { prefix = 'HENRY', desc = 'High-Speed Interceptor (Dálniční stíhací hlídka)' },
    { prefix = 'OCEAN', desc = 'Pobřežní hlídka / Člun' }
}
