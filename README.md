# sonarrcalendar

A nightly cron job downloads the [Sonarr](https://sonarr.tv) release calendar
and commits it here as [`Sonarr.ics`](Sonarr.ics). Google Calendar subscribes to
the raw file on GitHub, so upcoming episodes appear there without exposing the
Sonarr server.

## How it works

[`update-calendar.sh`](update-calendar.sh):

1. Downloads `/feed/v3/calendar/Sonarr.ics` from Sonarr, using the API key in `.env`.
2. Checks that the response really is an iCal file. If not, it prints the HTTP
   status and the start of the response, then stops.
3. Compares the new file with the committed one. Sonarr rewrites the `DTSTAMP`
   lines on every download, and its line endings can differ from the committed
   copy, so the comparison ignores both. If nothing else changed, the script
   exits without committing.
4. Otherwise it overwrites `Sonarr.ics`, then commits and pushes to `main`.

## Setup

### 1. Clone the repo

```sh
git clone https://github.com/joegualdarrama/sonarrcalendar.git
cd sonarrcalendar
```

### 2. Add the API key

Create a `.env` file next to the script. It's in `.gitignore`, so it won't be
committed.

```sh
echo 'SONARR_API_KEY=your-key-here' > .env
chmod 600 .env
```

The key is under **Settings → General → Security → API Key** in Sonarr. The
Sonarr address is set in `FEED_URL` in the script; change it if your server is
somewhere else.

> **Keep the key out of the repo.** The repo is public, and the key gives full
> access to Sonarr. Deleting it in a later commit doesn't help, because it
> stays in git history.

### 3. Let git push without prompting

Cron can't answer a login prompt, so git needs saved GitHub credentials. With
the GitHub CLI installed and logged in:

```sh
gh auth setup-git
```

### 4. Test it

```sh
DRY_RUN=1 ./update-calendar.sh   # download and compare only: no pull, commit or push
./update-calendar.sh             # real run: commits and pushes if the calendar changed
```

If you get `Permission denied`, the file has lost its executable bit, which
happens when it's re-saved or replaced. Fix it on disk and in git:

```sh
chmod +x update-calendar.sh
git update-index --chmod=+x update-calendar.sh
```

### 5. Schedule it

Run `crontab -e` and add the line below, changing the path to where you cloned
the repo:

```cron
45 23 * * * /home/joe/code/sonarrcalendar/update-calendar.sh >> /home/joe/.local/state/sonarrcalendar.log 2>&1
```

Create the log directory once with `mkdir -p ~/.local/state`. This runs every
night at 23:45.

## Subscribe in Google Calendar

1. In Google Calendar, go to **Other calendars → + → From URL**.
2. Enter:
   ```
   https://raw.githubusercontent.com/joegualdarrama/sonarrcalendar/main/Sonarr.ics
   ```
3. Click **Add calendar**.

Google checks subscribed calendars only every 12–24 hours, and you can't make it
refresh sooner, so new episodes can take up to a day to appear.

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| `response is not an iCal file` with an HTML login page | A login page in front of Sonarr is intercepting the request. Point `FEED_URL` straight at Sonarr, or exclude `/feed/*` from the login. |
| `response is not an iCal file` with the Sonarr web page | Sonarr runs under a sub-path. Add it to `FEED_URL` (e.g. `.../sonarr/feed/...`). |
| `missing config: .../.env` | Create `.env` (step 2). |
| Push fails with an auth or prompt error | Run `gh auth setup-git` (step 3). |
| Nothing new in Google Calendar | Check `git log` for recent commits, then wait for Google's refresh. |

Check the log at `~/.local/state/sonarrcalendar.log` for what each run did.
