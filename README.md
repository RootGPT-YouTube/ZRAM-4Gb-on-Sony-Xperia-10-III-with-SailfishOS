#[ITALIANO] Ottimizzazione di ZRAM (4Gb+Swappiness=20) su Sony Xperia 10 III con SailfishOS.

Obiettivo: ottimizzare ZRAM su SailfishOS con script personalizzato e servizio systemd.

Questa guida mostra come creare uno script per riconfigurare ZRAM (dimensione, algoritmo di compressione, priorità dello swap) e come renderlo automatico tramite un servizio systemd.   È stata testata su Sony Xperia 10 III con SailfishOS.  

Creazione dello script ZRAM che genererà 4Gb di ZRAM, lo chiameremo perciò zram4.  
Creiamo lo script in /usr/local/sbin/:  
`sudo nano /usr/local/sbin/zram4`

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
`sudo chmod +x /usr/local/sbin/zram4`

Creiamo il file del servizio:  
`sudo nano /etc/systemd/system/zram-override.service`

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
`sudo systemctl daemon-reload`  
`sudo systemctl enable zram-override.service`  
`sudo systemctl start zram-override.service`  

Riavviare lo smartphone, aspettare almeno 10 secondi dopo aver effettuato l'accesso e digitare:
`swapon --show` o `zramctl` per verificare la presenza di ZRAM attivo con la giusta quantità di memoria (nel nostro caso 4Gb) e `cat /proc/sys/vm/swappiness` per verificare il corretto swappiness (nel nostro caso 20).

Fine. Adesso lo smartphone avrà più ZRAM da usare e da usare meglio.
