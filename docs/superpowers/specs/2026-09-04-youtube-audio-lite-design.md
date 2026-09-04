# YouTube Audio Lite — Design

## Obiettivo

Creare una piccola applicazione macOS nativa che riproduca solamente l'audio di un singolo video YouTube e liberi la memoria occupata da Google Chrome appena la riproduzione è realmente iniziata.

L'applicazione deve essere installabile in `/Applications`, avere controlli completi da lettore audio e offrire sei temi grafici moderni. Il repository pubblico conterrà sorgenti, test e procedura di build, ma non dipendenze o binari pesanti.

## Vincoli

- macOS 15 su Apple Silicon.
- Interfaccia AppKit compilata nativamente con Swift; niente Electron, WebView o server locale.
- Riutilizzo di `mpv` e `yt-dlp` installati tramite Homebrew.
- Riproduzione di un solo video per volta; playlist disabilitate.
- Nessun download permanente del contenuto multimediale.
- Chrome viene chiuso completamente soltanto dopo una conferma osservabile dell'avvio della riproduzione.

## Interfaccia

La finestra principale contiene:

- campo per l'URL;
- azioni `Incolla`, `Usa Chrome` e `Riproduci`;
- titolo/stato della riproduzione;
- pulsanti indietro 15 secondi, play/pausa, avanti 15 secondi e stop;
- barra temporale con tempo trascorso e durata;
- controllo volume e mute;
- selettore del tema.

I temi sono palette statiche e leggere: Carbon, Arctic, Sunset, Forest, Violet e Paper. La selezione viene salvata in `UserDefaults`.

## Flusso

1. L'utente inserisce un URL oppure sceglie `Usa Chrome`.
2. Per `Usa Chrome`, AppleScript legge l'URL della scheda attiva della finestra principale di Google Chrome. L'app gestisce esplicitamente Chrome non aperto, finestra assente e permesso Automation negato.
3. L'URL viene accettato soltanto se usa HTTP o HTTPS e l'host è `youtube.com`, un suo sottodominio, oppure `youtu.be`.
4. L'app avvia `mpv` senza video, delegando l'estrazione a `yt-dlp`, con playlist disabilitate e cache contenuta.
5. L'app controlla `mpv` tramite socket JSON IPC locale. Solo un evento/proprietà che dimostra l'avvio effettivo della riproduzione autorizza la chiusura di Google Chrome tramite AppleScript.
6. La stessa sessione IPC alimenta stato, posizione, durata e controlli del lettore.
7. Stop, chiusura finestra o terminazione dell'app arrestano il processo figlio e rimuovono il socket temporaneo.

La chiusura di Chrome avviene anche quando l'URL è stato inserito manualmente, purché Chrome sia in esecuzione quando l'audio parte.

## Componenti

- `AppDelegate`: ciclo di vita dell'app e costruzione della finestra.
- `PlayerController`: processo `mpv`, IPC, stato e comandi del lettore.
- `YouTubeURL`: parsing e validazione deterministica degli URL.
- `ChromeController`: lettura della scheda attiva e chiusura dell'applicazione Chrome.
- `Theme`: sei palette e persistenza della scelta.
- `PlayerViewController`: collegamento tra controlli grafici e stato del lettore.

Le interfacce separano la validazione, l'automazione di Chrome e l'esecuzione del player, così le parti deterministiche possono essere testate senza aprire applicazioni esterne.

## Errori e sicurezza

- Percorsi di `mpv` e `yt-dlp` risolti da posizioni Homebrew note e dal `PATH`; assenza segnalata chiaramente.
- URL passato a `Process` come argomento, mai interpolato in una shell.
- Socket IPC creato in una directory temporanea specifica della sessione.
- Errori di avvio, IPC, estrazione o permessi mostrati nell'interfaccia.
- Chrome resta aperto se l'avvio audio non viene confermato.
- Un nuovo avvio arresta in modo ordinato l'eventuale sessione precedente.

## Build e installazione

Il progetto usa Swift Package Manager per compilazione e test. Uno script riproducibile assembla il bundle `.app`, crea `Info.plist`, firma ad hoc il bundle e lo installa in `/Applications/YouTube Audio Lite.app`.

Poiché l'app usa Apple Events per controllare Chrome, `Info.plist` dichiara la relativa motivazione d'uso. Al primo accesso macOS può chiedere il consenso Automation.

## Verifica

- Test automatici per URL validi e rifiutati, selezione dei percorsi eseguibili e codifica dei comandi IPC.
- `swift test`.
- build release e controllo della struttura del bundle.
- avvio dell'app installata.
- prova manuale reale con un video YouTube: acquisizione URL da Chrome, avvio audio, chiusura di Chrome, pausa/riprendi, seek, volume, mute e stop.
- misurazione indicativa della memoria del processo dell'app durante la riproduzione, riportata come osservazione e non come garanzia universale.

## Distribuzione

Il repository GitHub pubblico si chiamerà `youtube-audio-lite`. Conterrà codice, test, README e script; non conterrà credenziali, cache, media o artefatti di build. La release iniziale verrà pubblicata solo dopo le verifiche locali disponibili.
