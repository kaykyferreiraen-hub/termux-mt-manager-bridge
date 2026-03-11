# Termux → MT Manager Bridge

Browse your Termux's private directory directly inside MT Manager using FTP.

## Why
MT Manager can't access Termux internal storage due to Android SAF 
restrictions. This script runs a lightweight FTP server inside Termux 
so MT Manager can browse it natively.

## Requirements
- [Termux](https://f-droid.org/packages/com.termux/)
- [MT Manager](https://mt2.cn)
- Python 3 or higher

## Install
```bash
python3 -m pip install pyftpdlib
chmod +x saf-mt-manager.sh
./saf-mt-manager.sh
```

## MT Manager setup
1. Start the server (option 1 in menu)
2. In MT Manager sidebar → **⋮** → **Add network storage** → **FTP**
3. Host: `127.0.0.1` · Port: `8021` · Path: `/`
4. Leave user/pass blank → **Save**

## Where you start?

By default, you will always start at this directory: /data/data/com.termux

To enter your Termux Home, just open 'files' → 'home' respectively.
