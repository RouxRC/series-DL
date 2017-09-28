# series-DL

**#LifeHacking :-)**

Automatically handle downloading from EZTV and ThePirateBay the latest episodes of your list of favorite shows, get matching subs on Addic7ed and rename all files cleanly in your ToWatch directory.

Optionnally always download first episodes of new shows.

Meant for use under Linux with Vuze/Azureus torrent client, but should also work under MacOsX and with any torrent client that handles starting magnet links from command line.


## Dependencies

```bash
pip install requests
```


## Configure

```bash
cp config.inc{.example,}
```

Edit `config.inc` and set your choices of:
- torrent client (written for Aria2c but should work with any client able to start magnet links from command line such as `aria2c "magnet:xxxxxx"`)
- Achieved torrents and ReadyToWatch directories
- resolution and subtitles language
- whether you want to discover first episodes of new shows
- list of shows


## Run

- To search for new torrents and start them:

```bash
./download.sh
```

- To catch up episodes of a specific show:

```bash
./download.sh "Game of Thrones"
# optionnally bypass the general resolution choice adding a second random argument
./download.sh "Powers" 1
# or for an anime or any show without SxxEyy pattern:
./download.sh "Naruto Shippuuden #NOSEASON"
```

- To download new episodes subtitles and rename the video altogether:

```bash
./getSubs.py
```

- To cleanup achieved torrents and move resulting video into your ready directory:

```bash
./rotate.sh
# Add an extra argument to start downloading subs and renaming afterwards as well, for instance:
./rotate.sh 1
```

- Or let it all run automatically for instance with cronjobs:

```bash
crontab -e
# add lines such as:
#  00  */8  * * *    DISPLAY=:0.0 <THIS DIR PATH>/download.sh >> <THIS DIR PATH>/logDL.txt  2>&1
# */15  *   * * *                 <THIS DIR PATH>/rotate.sh 1 >> <THIS DIR PATH>/logRot.txt 2>&1
```

