# [ITALIANO] Ottimizzazione di ZRAM (4Gb+Swappiness=20) su Sony Xperia 10 III con SailfishOS.

## Obiettivo: ottimizzare ZRAM su SailfishOS con script personalizzato e servizio systemd.

### Questa guida mostra come creare uno script per riconfigurare ZRAM (dimensione, algoritmo di compressione, priorità dello swap) e come renderlo automatico tramite un servizio systemd.  
È stata testata su Sony Xperia 10 III con SailfishOS.  

Creazione dello script ZRAM che genererà 4Gb di ZRAM, lo chiameremo perciò zram4.  
Creiamo lo script in /usr/local/sbin/:  
`devel-su`  
`nano /usr/local/sbin/zram4`  

Contenuto consigliato:  
`#!/bin/sh`  
`# Disattiva lo swap attuale`  
`swapoff /dev/zram0 2>/dev/null`  
`# Reset del device ZRAM`  
`echo 1 > /sys/block/zram0/reset`  
`# Imposta algoritmo di compressione (trascurabile)`  
`echo lz4 > /sys/block/zram0/comp_algorithm`  
`# Imposta dimensione ZRAM (4 GB)`  
`echo 4294967296 > /sys/block/zram0/disksize`  
`# Ricrea lo swap`  
`mkswap /dev/zram0`  
`# Attiva lo swap con priorità 5`  
`swapon /dev/zram0 -p 5`  
`# Imposta swappiness finale`  
`sysctl -w vm.swappiness=20`  

Rendi lo script eseguibile:  
`chmod +x /usr/local/sbin/zram4`

Creiamo il file del servizio:  
`nano /etc/systemd/system/zram-override.service`

Contenuto:  
`[Unit]`  
`Description=Override ZRAM parameters after boot`  
`After=multi-user.target`  

`[Service]`  
`Type=oneshot`  
`ExecStartPre=/usr/bin/sleep 10`  
`ExecStart=/usr/local/sbin/zram4`  

`[Install]`  
`WantedBy=multi-user.target`  

Perché il ritardo di 10 secondi?

SailfishOS e il layer Android (droid-hal) inizializzano ZRAM molto presto. Il ritardo garantisce che il nostro script sovrascriva i valori finali, evitando conflitti.

Attivazione del servizio:  
`systemctl daemon-reload`  
`systemctl enable zram-override.service`  
`systemctl start zram-override.service`

Riavviare lo smartphone, aspettare almeno 10 secondi dopo aver effettuato l'accesso e digitare:
`swapon --show` o `zramctl` per verificare la presenza di ZRAM attivo con la giusta quantità di memoria (nel nostro caso 4Gb) e `cat /proc/sys/vm/swappiness` per verificare il corretto swappiness (nel nostro caso 20).

Fine. Adesso lo smartphone avrà più ZRAM da usare e da usare meglio.

### SOLO PER DISPOSITIVI SAILFISHOS CON ALMENO 4GB DI RAM:  
`devel-su`  
`curl -fsSL --retry 3 https://raw.githubusercontent.com/RootGPT-YouTube/ZRAM-4Gb-on-Sony-Xperia-10-III-with-SailfishOS/main/install.sh | bash`
  
# EXTRA: aggiungere uno SWAPFILE con priorità inferiore a ZRAM.  
## Creare uno swapfile da 1024 MB  
Entra come root:

```bash
devel-su
```
Crea il file da 1 GB:

````bash
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

## Impostare la priorità a -2

La priorità dello swap si imposta con:

```bash
swapon --priority -2 /swapfile
```

Puoi verificare:

```bash
swapon --show
```

Vedrai una colonna chiamata PRIO.


## Renderlo permanente (fstab)

Apri /etc/fstab:

```bash
nano /etc/fstab
```

Aggiungi questa riga:

```
/swapfile none swap sw,pri=-2 0 0
```

Salva e chiudi.


# [ENGLISH] ZRAM Optimization (4 GB + Swappiness=20) on Sony Xperia 10 III with SailfishOS

##Goal: optimize ZRAM on SailfishOS using a custom script and a systemd service.

###This guide explains how to create a script that reconfigures ZRAM (size, compression algorithm, swap priority) and how to automate it through a systemd service.
It has been tested on the Sony Xperia 10 III running SailfishOS.

Create the ZRAM script (4 GB ZRAM)
We will create a script that sets up 4 GB of ZRAM, so we’ll call it zram4.

Create the script in /usr/local/sbin/:  
`devel-su`  
`nano /usr/local/sbin/zram4`  

Recommended content:  
`#!/bin/sh`  
`# Disable current swap`  
`swapoff /dev/zram0 2>/dev/null`  
`# Reset the ZRAM device`  
`echo 1 > /sys/block/zram0/reset`  
`# Set compression algorithm (not critical)`  
`echo lz4 > /sys/block/zram0/comp_algorithm`  
`# Set ZRAM size (4 GB)`  
`echo 4294967296 > /sys/block/zram0/disksize`  
`# Recreate swap`  
`mkswap /dev/zram0`  
`# Enable swap with priority 5`  
`swapon /dev/zram0 -p 5`  
`# Set final swappiness`  
`sysctl -w vm.swappiness=20`  

Make the script executable:  
`chmod +x /usr/local/sbin/zram4`  

Create the systemd service:  
`nano /etc/systemd/system/zram-override.service`  

Content:  
`[Unit]`  
`Description=Override ZRAM parameters after boot`  
`After=multi-user.target`  
  
`[Service]`  
`Type=oneshot`  
`ExecStartPre=/usr/bin/sleep 10`  
`ExecStart=/usr/local/sbin/zram4`  
  
`[Install]`  
`WantedBy=multi-user.target`  

Why the 10‑second delay?
SailfishOS and the Android layer (droid-hal) initialize ZRAM very early during boot.
The delay ensures that our script overrides the final values, avoiding conflicts.

Enable the service:  
`systemctl daemon-reload`  
`systemctl enable zram-override.service`  
`systemctl start zram-override.service`  
  
After rebooting the phone, wait at least 10 seconds after logging in, then run: `swapon --show` or `zramctl`. So you can check active ZRAM and size (4 GB in this example).
  
Now, check swappiness (should be 20):  
`cat /proc/sys/vm/swappiness`  
  
Done. Your smartphone now has more ZRAM available — and uses it more efficiently.

BETA: ONLY FOR SAILFISHOS WITH AT LEAST 4GB OF RAM:  
`devel-su`  
`curl -fsSL --retry 3 https://raw.githubusercontent.com/RootGPT-YouTube/ZRAM-4Gb-on-Sony-Xperia-10-III-with-SailfishOS/main/install.sh | bash`
