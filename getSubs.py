#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os, sys, re
import requests

ROOT_URL = "http://www.addic7ed.com/"

re_cleaner = re.compile(r'[^a-z\d]')
cleaner = lambda x: re_cleaner.sub('', x.lower())

def try_get(page, retries=3):
    r = requests.get("%s%s" % (ROOT_URL, page))
    if r.status_code != 200:
        if retries:
            return try_get(page, retries-1)
        return None
    return re_clean_lines.sub(' ', r.content.replace('&amp;', '&').replace('&nbsp;', ' '))

def err(typ, season, name, urlseason, episode=None):
    print >> sys.stderr, "ERROR: can't get %s for%s season %s of %s: %s%s" % (typ, " episode %s of" % episode if episode else "", season, name, ROOT_URL, urlseason)


re_clean_lines = re.compile(r'[\s\t\n\r]+')
re_line_shows = re.compile(r'<tr> *<td class="version">.*?</tr> *<tr><td class="newsDate">.*?</tr>', re.I)
re_show = re.compile(r'<a href="/show/(\d+)">([^<]+)</a>', re.I)
re_eps = re.compile(r'<td class="newsDate">(\d+) Seasons?, (\d+) Episodes? *</td>', re.I)
def get_all_shows():
    html = try_get("shows.php")
    if not html:
        print >> sys.stderr, "ERROR: addic7ed.com seems unavailable", r.__dict__
        return None
    shows = []
    for row in re_line_shows.findall(html):
        new_shows = re_show.findall(row)
        new_eps = re_eps.findall(row)
        for i, show in enumerate(new_shows):
            year = re_year.search(show[1])
            shows.append({
              "id": int(show[0]),
              "name": show[1],
              "key": cleaner(show[1]),
              "seasons": int(new_eps[i][0]),
              "episodes": int(new_eps[i][1]),
              "year": year.group(1) if year else 0
            })
    return shows

re_vid = re.compile(r'^(.*)\.s(\d+)e(\d+)\.(.*)\.(mkv|mp4|avi)$', re.I)
def ls_vids_dir(path):
    vids = []
    for vid in os.listdir(vids_dir):
        if not os.path.isfile(os.path.join(vids_dir, vid)):
            continue
        if not re_vid.match(vid):
            continue
        vids.append(vid)
    return vids

re_year = re.compile(r'\((\d{4})\)')
re_clean_extras = re.compile(r'(webrip\.|x264-|[hlp]dtv\.|\d+p\.|\.?\[[^\]]*\])', re.I)
def dl_sub_and_rename(path, vid, shows):
    metas = re_vid.search(vid)
    name, season, episode, extra, ext = metas.groups()
    season = int(season)
    episode = int(episode)
    extra = re_clean_extras.sub('', extra)
    matches = []
    for show in shows:
        if show["key"].startswith(cleaner(name)) and season <= show["seasons"] and episode <= show["episodes"]:
            matches.append(show)
    if not len(matches):
        print >> sys.stderr, "WARNING: could not match %s with any show from addic7ed" % vid
        return
    match = sorted(matches, key=lambda x: x["year"], reverse=True)[0]
    urlseason = "season/%s/%s" % (match["id"], season)
    listeps = try_get(urlseason)
    if not listeps:
        err("page", season, name, urlseason)
        return
    re_find_url_ep = re.compile(r'"/(serie/[^/"]*/%s/%s/[^"]*)"' % (season, episode))
    urlep = re_find_url_ep.search(listeps)
    if not urlep:
        err("url", season, name, urlseason, episode)
        return
    urlep = urlep.group(1)
    listsubs = try_get(urlep)
    if not listsubs:
        err("page", season, name, urlep, episode)
        return
    print name, season, episode, extra, ext, match
    # TODO
    # - subs = { language, 100%, link(like http://www.addic7ed.com/original/EPID/SUBID), blob_infos_rip }
    # - sub = subs.filter(best matching infos_rip with blob_infos_rip)
    # - good_name = curl -I 'LINK' -H 'Referer: http://www.addic7ed.com/' | grep "Content-Disposition" | sed 's/^.*="//' | sed 's/"//'
    # - download sub curl 'LINK' -H 'Referer: http://www.addic7ed.com/'
    # - rename video + sub
    pass

if __name__ == "__main__":
    vids_dir = sys.argv[1] if len(sys.argv) > 1 else ""
    if not os.path.isdir(vids_dir):
        print >> sys.stderr, "ERROR: %s is not a directory" % vids_dir
        exit(1)
    shows = get_all_shows()
    if not shows:
        exit(1)
    for vid in ls_vids_dir(vids_dir):
        dl_sub_and_rename(vids_dir, vid, shows)
