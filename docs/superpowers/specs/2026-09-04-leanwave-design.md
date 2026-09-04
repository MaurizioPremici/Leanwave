# Leanwave — Design

## Obiettivo

Creare una piccola applicazione macOS nativa chiamata Leanwave che riproduca solamente l'audio di un singolo video YouTube. Quando la riproduzione è realmente iniziata, l'utente può scegliere se chiudere la sola scheda YouTube, chiudere completamente Google Chrome oppure lasciare tutto aperto.

L'applicazione deve essere installabile in `/Applications`, avere controlli completi da lettore audio e offrire sei temi grafici moderni. Il repository pubblico conterrà sorgenti, test e procedura di build, ma non dipendenze o binari pesanti.

Tutti i testi visibili nell'applicazione, inclusi pulsanti, stati, conferme ed errori, sono in inglese.

## Vincoli

- macOS 15 su Apple Silicon.
- Interfaccia AppKit compilata nativamente con Swift; niente Electron, WebView o server locale.
- Riutilizzo di `mpv` e `yt-dlp` installati tramite Homebrew.
- Riproduzione di un solo video per volta; playlist disabilitate.
- Nessun download permanente del contenuto multimediale.
- Nessuna scheda o applicazione viene chiusa automaticamente.
- La scelta di chiusura viene richiesta soltanto dopo una conferma osservabile dell'avvio della riproduzione.
- La finestra resta al livello `floating`, sopra le normali finestre delle altre applicazioni, ma rimane riducibile e chiudibile.

## Interfaccia

La finestra principale contiene:

- campo per l'URL;
- azioni `Paste`, `Fetch Again` e `Play`;
- titolo/stato della riproduzione;
- pulsanti indietro 15 secondi, play/pausa, avanti 15 secondi e stop;
- barra temporale con tempo trascorso e durata;
- controllo volume e mute;
- selettore del tema.
- controlli visibili `−` e `×` per ridurre e chiudere la finestra.

I temi sono palette statiche e leggere: Carbon, Arctic, Sunset, Forest, Violet e Paper. La selezione viene salvata in `UserDefaults`.

La GUI usa una gerarchia visiva essenziale ma curata: testata personalizzata, tipografia di sistema, spaziatura ampia, card con bordo sottile e ombra contenuta, angoli arrotondati e un solo colore d'accento per tema. Non usa immagini remote, WebView, trasparenze estese o animazioni decorative. I controlli devono restare immediatamente leggibili e accessibili in ogni tema.

## Flusso

1. All'apertura, l'app prova automaticamente a leggere l'URL della scheda attiva della finestra principale di Google Chrome. Compila il campo soltanto se trova un URL YouTube valido; non avvia la riproduzione automaticamente.
2. L'utente può modificare o incollare manualmente l'URL in qualsiasi momento. `Fetch Again` ripete l'acquisizione dalla scheda Chrome attualmente attiva, così può recuperare una pagina aperta successivamente.
3. L'app gestisce esplicitamente Chrome non aperto, finestra assente e permesso Automation negato. Un fallimento del recupero automatico non blocca l'inserimento manuale.
4. L'URL viene accettato soltanto se usa HTTP o HTTPS e l'host è `youtube.com`, un suo sottodominio, oppure `youtu.be`.
5. L'app risolve il flusso con `yt-dlp --no-cookies`, senza accedere al portachiavi o ai cookie di Chrome. Un relay loopback temporaneo serve a `mpv` piccoli intervalli del flusso e conserva seek e cache contenuta senza salvare il media.
6. L'app controlla `mpv` tramite socket JSON IPC locale. Quando un evento/proprietà dimostra l'avvio effettivo della riproduzione, presenta una finestra con tre scelte in inglese: `Close YouTube Tab`, `Quit Chrome` e `Keep Open`.
7. `Close YouTube Tab` chiude soltanto la scheda esatta acquisita da Chrome. Per un URL inserito manualmente, l'app cerca una scheda con lo stesso URL; se non la trova, mantiene Chrome aperto e lo segnala.
8. `Quit Chrome` termina l'intera applicazione tramite AppleScript. `Keep Open` non modifica Chrome.
9. La stessa sessione IPC alimenta stato, posizione, durata e controlli del lettore.
10. Stop, chiusura finestra o terminazione dell'app arrestano il processo figlio e rimuovono il socket temporaneo.

## Componenti

- `AppDelegate`: ciclo di vita dell'app e costruzione della finestra.
- `PlayerController`: processo `mpv`, IPC, stato e comandi del lettore.
- `YouTubeURL`: parsing e validazione deterministica degli URL.
- `ChromeController`: lettura e identificazione della scheda attiva, chiusura mirata della scheda o chiusura dell'applicazione Chrome.
- `Theme`: sei palette e persistenza della scelta.
- `PlayerViewController`: collegamento tra controlli grafici e stato del lettore.

Le interfacce separano la validazione, l'automazione di Chrome e l'esecuzione del player, così le parti deterministiche possono essere testate senza aprire applicazioni esterne.

## Errori e sicurezza

- Percorsi di `mpv` e `yt-dlp` risolti da posizioni Homebrew note e dal `PATH`; assenza segnalata chiaramente.
- URL passato a `Process` come argomento, mai interpolato in una shell.
- Socket IPC creato in una directory temporanea specifica della sessione.
- Errori di avvio, IPC, estrazione o permessi mostrati nell'interfaccia.
- Chrome resta aperto se l'avvio audio non viene confermato, se l'utente sceglie `Keep Open` o se la scheda richiesta non può essere identificata con sicurezza.
- Un nuovo avvio arresta in modo ordinato l'eventuale sessione precedente.

## Build e installazione

Il progetto usa Swift Package Manager per compilazione e test. Uno script riproducibile assembla il bundle `.app`, crea `Info.plist`, firma ad hoc il bundle e lo installa in `/Applications/Leanwave.app`.

Poiché l'app usa Apple Events per controllare Chrome, `Info.plist` dichiara la relativa motivazione d'uso. Al primo accesso macOS può chiedere il consenso Automation.

## Verifica

- Test automatici per URL validi e rifiutati, selezione dei percorsi eseguibili e codifica dei comandi IPC.
- `swift test`.
- build release e controllo della struttura del bundle.
- avvio dell'app installata.
- prova manuale reale con un video YouTube: acquisizione URL da Chrome, avvio audio, ciascuna delle tre scelte di chiusura, pausa/riprendi, seek, volume, mute e stop.
- misurazione indicativa della memoria del processo dell'app durante la riproduzione, riportata come osservazione e non come garanzia universale.

## Distribuzione

Il repository GitHub pubblico si chiamerà `leanwave`. Conterrà codice, test, README e script; non conterrà credenziali, cache, media o artefatti di build. La release iniziale verrà pubblicata solo dopo le verifiche locali disponibili.
