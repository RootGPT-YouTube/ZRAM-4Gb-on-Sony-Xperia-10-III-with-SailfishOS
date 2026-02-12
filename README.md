# [ITALIANO] Ottimizzazione di ZRAM (4Gb+Swappiness=20) su SailfishOS.

## Obiettivo: ottimizzare ZRAM su SailfishOS con script personalizzato e servizio systemd.

### Questa guida mostra come creare uno script per riconfigurare ZRAM (dimensione, algoritmo di compressione, priorità dello swap) e come renderlo automatico tramite un servizio systemd.  
È stata testata su Sony Xperia 10 III con SailfishOS e Jolla C2.  

Creazione dello script ZRAM che genererà 4Gb di ZRAM, lo chiameremo perciò zram4.  
Creiamo lo script in /usr/local/sbin/:  
Entra come root:
```bash
devel-su
```
poi:
```bash
nano /usr/local/sbin/zram4
```
Contenuto consigliato:  
```bash
#!/bin/sh
# Disattiva lo swap attuale
swapoff /dev/zram0 2>/dev/null
# Reset del device ZRAM
echo 1 > /sys/block/zram0/reset
# Imposta algoritmo di compressione (trascurabile)
echo lz4 > /sys/block/zram0/comp_algorithm  
# Imposta dimensione ZRAM (4GB, va dichiarato in bytes)
echo 4294967296 > /sys/block/zram0/disksize
# Ricrea lo swap
mkswap /dev/zram0
# Attiva lo swap con priorità 5
swapon /dev/zram0 -p 5
# Imposta swappiness finale
sysctl -w vm.swappiness=20
```
Rendi lo script eseguibile:  
```bash
chmod +x /usr/local/sbin/zram4
```
Creiamo il file del servizio:  
```bash
nano /etc/systemd/system/zram-override.service
```
Contenuto:  
```bash
[Unit]
Description=Override ZRAM parameters after boot
After=multi-user.target

[Service]
Type=oneshot
ExecStartPre=/usr/bin/sleep 10
ExecStart=/usr/local/sbin/zram4

[Install]
WantedBy=multi-user.target
```
Perché il ritardo di 10 secondi?  

SailfishOS e il layer Android (droid-hal) inizializzano ZRAM molto presto. Il ritardo garantisce che il nostro script sovrascriva i valori finali, evitando conflitti.  

#### Attivazione del servizio  
Ricaricare il demone:
```bash
systemctl daemon-reload
```
Avviare il servizio:
```bash
systemctl start zram-override.service
```
Abilitare il servizio
```bash
systemctl enable zram-override.service
```
Riavviare lo smartphone, aspettare almeno 10 secondi dopo aver effettuato l'accesso e digitare:
`swapon --show` o `zramctl` per verificare la presenza di ZRAM attivo con la giusta quantità di memoria (nel nostro caso 4Gb) e `cat /proc/sys/vm/swappiness` per verificare il corretto swappiness (nel nostro caso 20).  
Fine. Adesso lo smartphone avrà più ZRAM da usare e da usare meglio.

### IL MODO FACILE: AUTOINSTALLAZIONE MODULO DI 4GB DI ZRAM SOLO PER DISPOSITIVI SAILFISHOS CON ALMENO ALTRETTANTI GB DI RAM:  
Entra come root:
```bash
devel-su
```
poi:
```bash
curl -fsSL --retry 3 https://raw.githubusercontent.com/RootGPT-YouTube/ZRAM-4Gb-on-Sony-Xperia-10-III-with-SailfishOS/main/install.sh | bash
```
  
# EXTRA: aggiungere uno SWAPFILE con priorità inferiore a ZRAM.  

## Metodo 1 (testato su Sony Xperia 10 III): Creazione swapfile da 1024MB in /  
Entra come root:
```bash
devel-su
```
Crea il file da 1 GB:
```bash
fallocate -l 1024M /swapfile
```
Imposta i permessi corretti:
```bash
chmod 600 /swapfile
```
Formatta il file come swap:
```bash
mkswap /swapfile
```
Attivalo:
```bash
swapon /swapfile
```
La priorità dello swap si imposta con:
```bash
swapon --priority -2 /swapfile
```
Puoi verificare:
```bash
swapon --show
```
Vedrai una colonna chiamata PRIO.  

#### Il prossimo passo sarà rendere il file swap permanente (fstab).  
Apri /etc/fstab:
```bash
nano /etc/fstab
```
Aggiungi questa riga:
```
/swapfile none swap sw,nofail,pri=-2 0 0
```
Salva e chiudi.  

## Metodo 2 [MILLE GRAZIE A NEPHROS] (testato su Jolla C2): Creazione swapfile in /home/swap/  
Prima di tutto creiamo lo swapfile in /home/swap e lo chiamiamo swap0.  
Accedi come root:
```bash
devel-su
```
Creiamo la cartella per lo swapfile:
```bash
mkdir -p /home/swap
```
Diamo i giusti permessi alla cartella:
```bash
chmod 0700 /home/swap
```
Creiamo lo swapfile:
```bash
fallocate -l 1024M /home/swap/swap0
```
Diamo i giusti permessi allo swapfile:
```bash
chmod 0600 /home/swap/swap0
```
Prepariamo il file affinché il kernel lo riconosca come swap ed etichettiamolo per comodità come home-swap0:
```bash
mkswap -L home-swap0 /home/swap/swap0
```
Adesso creiamo il servizio systemd:
```bash
nano /usr/lib/systemd/system/home-swap-swap0.swap
```
Al suo interno incolliamo questo codice:
```bash
[Unit]
Description=Enable swap file on home
ConditionPathExists=/home/swap/swap0
DefaultDependencies=false

Conflicts=shutdown.target

Conflicts=umount.target
Before=umount.target

After=local-fs.target init-done.service
Requires=local-fs.target

After=home.mount
Requires=home.mount

PartOf=swap.target

[Swap]
What=/home/swap/swap0
Options=nofail
Priority=-2

[Install]
WantedBy=multi-user.target
```
A questo punto rimane da ricaricare il demone, avviare il servizio (opzionale, ma consigliato) e abilitare il servizio in modo che si avvii in automatico ad ogni avvio.  
Ricarica il demone:
```bash
systemctl daemon-reload
```
Avvia il servizio:
```bash
systemctl start home-swap-swap0.swap
```
Abilita il servizio:
```bash
systemctl enable home-swap-swap0.swap
```
Si può controllare se è andato tutto a buon fine digitando:
```bash
swapon --show
```
## Perché è utile avere sia zram che uno swapfile?  
- zram comprime la RAM e la usa come “RAM aggiuntiva veloce”, ottima per evitare rallentamenti.  
- lo swapfile entra in gioco solo quando serve davvero, offrendo spazio di emergenza che evita crash, OOM‑killer e chiusure forzate delle app.  
  
### In sintesi (molto semplificato)
zram = velocità.  
swapfile = sicurezza e stabilità.  

Lavorano insieme: zram gestisce il carico leggero e veloce, lo swapfile protegge il sistema quando la RAM è completamente piena.  

# [ENGLISH] ZRAM Optimization (4 GB + Swappiness=20) on Sony Xperia 10 III with SailfishOS

## Goal: optimize ZRAM on SailfishOS using a custom script and a systemd service.

### This guide explains how to create a script that reconfigures ZRAM (size, compression algorithm, swap priority) and how to automate it through a systemd service.
It has been tested on the Sony Xperia 10 III running SailfishOS.

Create the ZRAM script (4 GB ZRAM)
We will create a script that sets up 4 GB of ZRAM, so we’ll call it zram4.

Create the script in `/usr/local/sbin/`:  
Take the root access:
```bash
devel-su
```
Then:
```bash
nano /usr/local/sbin/zram4
```
Recommended content:
```bash
#!/bin/sh
# Disable current swap
swapoff /dev/zram0 2>/dev/null
# Reset the ZRAM device
echo 1 > /sys/block/zram0/reset
# Set compression algorithm (not critical)
echo lz4 > /sys/block/zram0/comp_algorithm
# Set ZRAM size (4 GB)
echo 4294967296 > /sys/block/zram0/disksize
# Recreate swap
mkswap /dev/zram0
# Enable swap with priority 5
swapon /dev/zram0 -p 5
# Set final swappiness
sysctl -w vm.swappiness=20
```
Make the script executable:  
```bash
chmod +x /usr/local/sbin/zram4
```
Create the systemd service:  
```bash
nano /etc/systemd/system/zram-override.service
```
Content:  
```bash
[Unit]
Description=Override ZRAM parameters after boot
After=multi-user.target
  
[Service]
Type=oneshot
ExecStartPre=/usr/bin/sleep 10
ExecStart=/usr/local/sbin/zram4
  
[Install]
WantedBy=multi-user.target
```
Why the 10‑second delay?
SailfishOS and the Android layer (droid-hal) initialize ZRAM very early during boot.
The delay ensures that our script overrides the final values, avoiding conflicts.  

Enable the service:  
```bash
systemctl daemon-reload
systemctl enable zram-override.service
systemctl start zram-override.service
```
After rebooting the phone, wait at least 10 seconds after logging in, then run: `swapon --show` or `zramctl`. So you can check active ZRAM and size (4 GB in this example).  
  
Now, check swappiness (should be 20):  
```bash
cat /proc/sys/vm/swappiness
```
  
Done. Your smartphone now has more ZRAM available — and uses it more efficiently.

BETA: ONLY FOR SAILFISHOS WITH AT LEAST 4GB OF RAM:  
Take root access:
```bash
devel-su
```
Then:
```bash
curl -fsSL --retry 3 https://raw.githubusercontent.com/RootGPT-YouTube/ZRAM-4Gb-on-Sony-Xperia-10-III-with-SailfishOS/main/install.sh | bash
```

# EXTRA: add a SWAPFILE with lower priority than ZRAM.
## Method 1 (tested on Sony Xperia 10 III): Creating a 1024 MB swapfile in /
Create a 1024 MB swapfile
Become root:
```bash
devel-su
```
Create a 1 GB file:
```bash
fallocate -l 1024M /swapfile
```
Set the correct permissions:
```bash
chmod 600 /swapfile
```
Format the file as swap:
```bash
mkswap /swapfile
```
Activate it:
```bash
swapon /swapfile
```
Set the priority to -2  
Swap priority is set with:
```bash
swapon --priority -2 /swapfile
```
You can verify it with:
```bash
swapon --show
```
You will see a column called PRIO.  

Make it permanent (fstab)
Open `/etc/fstab`:
```bash
nano /etc/fstab
```
Add this line:

```bash
/swapfile none swap sw,nofail,pri=-2 0 0
```
Save and exit.

## Method 2 [VERY THANKS TO NEPHROS] (tested on Jolla C2): Creating a swapfile in /home/swap/  
First, we create the swapfile in `/home/swap` and name it `swap0`.
Log in as root:
```bash
devel-su
```
Create the directory for the swapfile:
```bash
mkdir -p /home/swap
```
Set the correct permissions on the directory:
```bash
chmod 0700 /home/swap
```
Create the swapfile:
```bash
fallocate -l 1024M /home/swap/swap0
```
Set the correct permissions on the swapfile:
```bash
chmod 0600 /home/swap/swap0
```
Prepare the file so the kernel recognizes it as swap, and label it for convenience as `home-swap0`:
```bash
mkswap -L home-swap0 /home/swap/swap0
```
Now create the systemd service:
```bash
nano /usr/lib/systemd/system/home-swap-swap0.swap
```
Paste the following code inside:
```bash
[Unit]
Description=Enable swap file on home
ConditionPathExists=/home/swap/swap0
DefaultDependencies=false

Conflicts=shutdown.target

Conflicts=umount.target
Before=umount.target

After=local-fs.target init-done.service
Requires=local-fs.target

After=home.mount
Requires=home.mount

PartOf=swap.target

[Swap]
What=/home/swap/swap0
Options=nofail
Priority=-2

[Install]
WantedBy=multi-user.target
```
At this point, you just need to reload the daemon, start the service (optional but recommended), and enable it so it starts automatically at boot.  
Reload the daemon:
```bash
systemctl daemon-reload
```
Start the service:
```bash
systemctl start home-swap-swap0.swap
```
Enable the service:
```bash
systemctl enable home-swap-swap0.swap
```
You can check whether everything worked correctly by typing:
```bash
swapon --show
```

## Why it’s useful to have both zram and a swapfile?

- zram compresses RAM and acts as “fast extra memory,” which helps prevent slowdowns.  
- the swapfile kicks in only when really needed, providing emergency space that prevents crashes, the OOM‑killer, and forced app closures.  

### In a very simplified way
zram = speed.  
swapfile = safety and stability.  
  
They work together: zram handles light and fast memory pressure, while the swapfile protects the system when RAM is completely full.
