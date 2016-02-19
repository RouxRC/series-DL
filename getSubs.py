#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os, sys, re
import requests

ROOT_URL = "http://www.addic7ed.com/"

re_cleaner = re.compile(r'[^a-z\d]')
cleaner = lambda x: re_cleaner.sub('', x.lower())

def try_get(page, ref="", headers=False, retries=3):
    r = requests.get("%s%s" % (ROOT_URL, page), headers={'Referer': "%s%s" % (ROOT_URL, ref)})
    if r.status_code != 200:
        if retries:
            return try_get(page, ref=ref, headers=headers, retries=retries-1)
        return None if not headers else None, None
    if headers:
        return r.content, r.headers
    text = re_clean_lines.sub(' ', r.content.replace('&amp;', '&').replace('&nbsp;', ' '))
    return text

def err(typ, season, name, urlseason, episode=None):
    print >> sys.stderr, "ERROR: can't get %s for%s season %s of %s: %s%s" % (typ, " episode %s of" % episode if episode else "", season, name, ROOT_URL, urlseason)


re_clean_lines = re.compile(r'[\s\t\n\r]+')
re_line_shows = re.compile(r'<tr> *<td class="version">.*?</tr> *<tr><td class="newsDate">.*?</tr>', re.I)
re_show = re.compile(r'<a href="/show/(\d+)">([^<]+)</a>', re.I)
re_eps = re.compile(r'<td class="newsDate">(\d+) (?:Season|Temporada)s?, (-?\d+) Epis\S+s? *</td>', re.I)
def get_all_shows():
    html = try_get("shows.php")
    if not html:
        print >> sys.stderr, "ERROR: addic7ed.com seems unavailable"
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
              "seasons": int(new_eps[i][0]) if new_eps else 1,
              "episodes": int(new_eps[i][1]) if new_eps else 1,
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

team_eqs = {
  "lol": "dimension",
  "sys": "dimension",
  "xii": "immerse",
  "asap": "immerse",
  "2hd": "evolve",
  "remarkable": "excellence"
}
team_eq = lambda x: team_eqs[x] if x in team_eqs else x
re_split_team = re.compile(r'\W+')
rewrite_teams = lambda x: x.replace('DD5.1', 'DD51').replace('H.264', 'H264')
str_list = lambda x: " ".join(x) if type(x) == list else x
team_infos = lambda text: [team_eq(x) for x in re_split_team.split(rewrite_teams(str_list(text)).lower()) if x not in ["", "colored", "works", "with", "versions"]]
re_extra_teams = re.compile(r'(preair|(?:compatible|works)? with .*)', re.I)

re_filename = lambda lang: re.compile(r'^.*filename="(.*)\.%s\..*"$' % lang)
re_clean_ep = re.compile(r' - 0?(\d+)x(\d+ - )')
clean_name = lambda name, lang: re_clean_ep.sub(r' - \1\2', (re_filename(lang).sub(r'\1', name)))

re_year = re.compile(r'\((\d{4})\)')
re_rmyear = re.compile(r'\d{4}$')
rmyear = lambda x: re_rmyear.sub('', x)
re_clean_metas = re.compile(r'\.?\[[^\]]*\]', re.I)
re_clean_html = re.compile(r'\s*<[^>]+>\s*')
re_versions = re.compile(r'Version (.*?), [\d.]+ MBs.*?</td>.*?class="newsDate"[^>]*> *(.*?) *</td>.*?(class="language".*?) </table>')
re_subs = lambda lang: re.compile(r'class="language">%s<.*?<b>Completed.*?href="(/original/\d+/\d+)"(?:.*?</a><a class="buttonDownload" href="(/updated/\d+/\d+/\d+)")?' % lang)
def dl_sub_and_rename(path, vid, shows, lang):
    name, season, episode, metas, ext = re_vid.search(vid).groups()
    season = int(season)
    episode = int(episode)
    metas = set(team_infos(re_clean_metas.sub('', metas)))
    matches = []
    for show in shows:
        if show["key"].startswith(cleaner(name)) and season <= show["seasons"] and episode <= show["episodes"]:
            matches.append(show)
    if not len(matches):
        for show in shows:
            if show["key"].startswith(rmyear(cleaner(name))) and season <= show["seasons"] and episode <= show["episodes"]:
                matches.append(show)
    if not len(matches):
        print >> sys.stderr, "WARNING: could not match %s with any show from addic7ed" % vid
        return
    match = sorted(matches, key=lambda x: x["year"], reverse=True)[0]
    urlseason = "season/%s/%s" % (match["id"], season)
    listeps = try_get(urlseason, ref="shows.php")
    if not listeps:
        err("page", season, name, urlseason)
        return
    re_find_url_ep = re.compile(r'"/(serie/[^/"]*/%s/%s/[^"]*)"' % (season, episode))
    urlep = re_find_url_ep.search(listeps)
    if not urlep:
        err("url", season, name, urlseason, episode)
        return
    urlep = urlep.group(1)
    listsubs = try_get(urlep, ref=urlseason)
    if not listsubs:
        err("page", season, name, urlep, episode)
        return
    subs = []
    others = set()
    for version in re_versions.findall(listsubs):
        for sub in re_subs(lang).findall(version[2]):
            version = set(team_infos(version[0]) + team_infos(re_extra_teams.findall(re_clean_html.sub('', version[1]))))
            score = len([x for x in version if x in metas])
            if score:
                subs.append({
                  "version": version,
                  "score": score,
                  "url": sub[1] if sub[1] else sub[0]
                })
            else:
                others.add(".".join(version))
    if not subs:
        print >> sys.stderr, "WARNING: no good sub found for", vid, ROOT_URL+urlep, ":", " / ".join(others)
        return
    sub = sorted(subs, key=lambda x: (x["score"], 1 if "updated" in x["url"] else 0),reverse=True)[0]
    subtext, subheaders = try_get(sub["url"], ref=urlep, headers=True)
    if not subtext or not subheaders or 'content-disposition' not in subheaders:
        print >> sys.stderr, "ERROR: could not download sub at %s%s for %s" % (ROOT_URL, sub["url"], vid)
        return
    name = clean_name(subheaders['content-disposition'], lang)
    with open(os.path.join(path, "%s.srt" % name), "w") as f:
        f.write(subtext)
    os.rename(os.path.join(path, vid), os.path.join(path, "%s.%s" % (name, ext)))

re_lang = re.compile(r'SUBS_LANG="?(\w+)"?[\s\r\n]+')
re_ready = re.compile(r'READY_DIR="?(.*?)"?[\s\r\n]+')
def get_config():
    path = os.path.dirname(os.path.abspath(__file__))
    try:
        with open(os.path.join(path, "config.inc")) as f:
            conf = f.read()
    except Exception as e:
        print >> sys.stderr, "ERROR: cannot open %s/config.inc file" % path
        print >> sys.stderr, type(e), e
        return None, None
    try:
        return re_lang.search(conf).group(1).title(), re_ready.search(conf).group(1)
    except Exception as e:
        print >> sys.stderr, "ERROR: SUBS_LANG or READY_DIR is missing from %s/config.inc file" % path
        print >> sys.stderr, type(e), e
        return None, None

if __name__ == "__main__":
    subs_lang, vids_dir = get_config()
    if not subs_lang:
        exit(1)
    if not os.path.isdir(vids_dir):
        print >> sys.stderr, "ERROR: %s is not a directory" % vids_dir
        exit(1)
    shows = get_all_shows()
    if not shows:
        exit(1)
    for vid in ls_vids_dir(vids_dir):
        dl_sub_and_rename(vids_dir, vid, shows, subs_lang)
