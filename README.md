# series-DL

Automatically handle downloading torrents for the latest episodes of your favorite shows.

## Dependencies

```bash
pip install requests
```

## Configure

```bash
cp config.inc{.example,}
```

Edit `config.inc` and set your choices of:
- torrent client (written for [Vuze/Azureus](http://www.vuze.com/) but should work with any client able to start torrents from command line such as `azureus file.torrent`)
- resolution
- list of shows

## Run

- You can run it manually using:

```bash
./download.sh
```

- Or let it run automatically for instance with a cronjob:

```bash
crontab -e
# add a line such as:
# 00   *    * * *    DISPLAY=:0.0 <PATH TO THIS DIRECTORY>/download.sh >> /home/roux/dev/series-DL/logDL.txt 2>&1
```

