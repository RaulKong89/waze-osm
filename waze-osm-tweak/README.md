# WazeOSM - Waze 3.9.6 cu OpenStreetMap

## Ce este?

WazeOSM este un tweak (dylib) care modifică aplicația Waze 3.9.6 pentru iOS 6 pentru a folosi **OpenStreetMap** în loc de Google Maps.

## Cum funcționează?

Tweak-ul se injectează în aplicația Waze și interceptează toate cererile de tile-uri către serverele Google Maps, redirecționându-le către OpenStreetMap.

## Ce modificări sunt făcute în IPA?

1. **WazeOSM.dylib** este adăugat în bundle-ul aplicației
2. **LC_LOAD_DYLIB** este injectat în binarul principal
3. **Semnătura** este actualizată cu ldid

## Instalare

### Cerințe:
- iPhone 4S/5/5C/5S cu iOS 6.0 - 6.1.3
- Jailbreak (evasi0n, p0sixspwn, etc.)
- Cydia Substrate (MobileSubstrate)

### Metoda 1: Cydia (Recomandată)
1. Adaugă repo-ul: `https://waze-osm.github.io/repo/`
2. Caută "WazeOSM" și instalează
3. Respring

### Metoda 2: Manuală
```bash
# Copiază dylib-ul pe device
scp WazeOSM.dylib root@<ip-iphone>:/Library/MobileSubstrate/DynamicLibraries/

# Instalează IPA-ul modificat
ideviceinstaller -i Waze-OSM-3.9.6.ipa

# Respring
ssh root@<ip-iphone> "killall -9 SpringBoard"
```

### Metoda 3: Doar dylib (pentru Waze deja instalat)
```bash
# Copiază dylib-ul
scp WazeOSM.dylib root@<ip-iphone>:/Library/MobileSubstrate/DynamicLibraries/

# Respring
ssh root@<ip-iphone> "killall -9 SpringBoard"
```

## Build Proces

### GitHub Actions (Automat)
1. Push pe `main` branch
2. Workflow-ul automat:
   - Build dylib cu Theos
   - Descarcă Waze 3.9.6 IPA
   - Injectează dylib
   - Creează Release cu IPA-ul modificat

### Local (Linux)
```bash
# Clone repo
git clone https://github.com/waze-osm/waze-osm.git
cd waze-osm

# Build dylib
cd waze-osm-tweak
python3 build.py

# Inject în IPA
python3 inject_dylib.py waze_3.9.6.ipa WazeOSM.dylib -o Waze-OSM-3.9.6.ipa
```

## Structura Proiectului

```
waze-osm/
├── waze-osm-tweak/
│   ├── Tweak.xm              # Sursa tweak-ului
│   ├── Makefile              # Build cu Theos
│   ├── build.py              # Build script Python
│   ├── inject_dylib.py       # Script injectare IPA
│   ├── control               # Control file pentru Cydia
│   └── .github/workflows/
│       └── build.yml         # CI/CD pentru build automat
└── README.md
```

## Compatibilitate

| Device | iOS 6.0 | iOS 6.1 | iOS 6.1.3 |
|--------|---------|---------|-----------|
| iPhone 4S | ✅ | ✅ | ✅ |
| iPhone 5 | ✅ | ✅ | ✅ |
| iPhone 5C | ✅ | ✅ | ✅ |
| iPhone 5S | ✅ | ✅ | ✅ |
| iPad 2/3/4 | ✅ | ✅ | ✅ |
| iPad mini | ✅ | ✅ | ✅ |

## Limitări

- **Nu există trafic în timp real** - Waze folosește servere proprii pentru trafic
- **Nu există comunitate Waze** - Serverele Waze sunt separate de hartă
- **Căutarea** folosește Nominatim (OSM), nu Google Places
- **Routing** folosește OSRM, nu Google Directions

## Depanare

### Waze nu pornește
- Verifică dacă Cydia Substrate este instalat
- Verifică dacă dylib-ul este în `/Library/MobileSubstrate/DynamicLibraries/`
- Verifică permisiunile: `chmod 755 WazeOSM.dylib`

### Harta nu se încarcă
- Verifică conexiunea la internet
- Verifică dacă tweak-ul este încărcat: `ps aux | grep Waze`
- Respring și încearcă din nou

### Eroare de semnătură
- Folosește `ldid -S` pentru a semna
- Nu folosi `codesign` pentru tweak-uri

## Licență

Acest proiect este doar pentru scopuri educaționale. Waze este o marcă înregistrată Google. OpenStreetMap este un proiect open-source.

## Credite

- **OpenStreetMap** - Date hartă (ODbL license)
- **Nominatim** - Serviciu căutare
- **OSRM** - Serviciu routing
- **Theos** - Build system pentru tweak-uri
- **Cydia Substrate** - Runtime modification framework
