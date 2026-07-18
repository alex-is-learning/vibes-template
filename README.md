# vibes

A page that scatters your images at random across the screen. No grid, no captions, no dates — just a wall of things you liked.

Live examples: [Sophia](https://girl.surgery/website_vibes/), who wrote the original, plus [Xavi](https://www.xavicf.com/vibes), [Guzey](https://guzey.com/vibes/), [Catherine](https://catherinebrewer.github.io/vibes/), and [mine](https://alexanderlarge.com/vibes).

This is the GitHub Pages version, built so you never have to open a terminal. **The `images/` folder is the page.** Drag a file in and it appears. Delete one and it comes down. There's no draft state and no publish button.

## Setup

1. Click **Use this template → Create a new repository** at the top of this page.
2. Name it `vibes`. It has to be **public** — GitHub Pages on a private repo is a paid feature, and this page is public regardless.
3. In your new repo: **Settings → Pages → Source → GitHub Actions**. (Not "Deploy from a branch" — this template deploys from the Action.)
4. Go to the **Actions** tab and enable workflows if it asks.
5. Open `images/`, delete the three sample gradients, drag your own in.

Your page is at `https://<your-username>.github.io/vibes/`, live about a minute after each change.

If you named the repo `<your-username>.github.io` instead, it serves at the root. Both work — the paths are relative.

## Adding images

On github.com: open the `images/` folder → **Add file → Upload files** → drag them on → **Commit changes**. That's it. Works from your phone's browser too.

To remove one: click it → the bin icon → commit.

Everything after that is automatic. The Action converts what you uploaded, rebuilds the list the page reads, and deploys. Watch it in the **Actions** tab if you're curious; ignore it if you're not.

## Alternative: a desktop folder that syncs itself

If you'd rather never open github.com at all: point Claude Code at this repo (once you've cloned your own copy) and ask it to run `scripts/install-local-sync.sh`. It sets up a `vibes-inbox` alias on your Desktop, wired to a nightly job — drag a photo in and it goes live overnight, drag one out and it comes down, with no commit/upload step in between. `scripts/local-sync.sh` is what runs each night; run it yourself anytime you don't want to wait. `scripts/uninstall-local-sync.sh` turns it back off without touching your photos. This needs a terminal and git push access to your repo, so it's the Claude-Code path, not the four-click one above — either flow can be used, and you can switch between them (the installer moves anything already in `images/` into the inbox first).

## What it does to your images, and why

Every upload gets re-encoded to WebP: resized so the longest edge is 1400px, quality 82. The compressed version replaces the original in the repo. Two reasons, and the first is the one that matters:

**It strips the metadata.** An iPhone photo carries the GPS coordinates of the spot it was taken. This page is public, and so is the repo behind it — so an untouched holiday photo is a public file with your location history in it. The re-encode drops EXIF as a side effect. This is why the Action commits the converted file *over* the original rather than converting on the way out: an original left sitting in the repo is still a public original.

It goes one step further than that, because it has to. Replacing the file isn't enough on its own — the commit you made when you uploaded is still in the repo's history, so a plain `git clone` would hand anyone the untouched original, GPS and all. I tested this rather than assumed it, and that is exactly what happened. So the Action rewinds to the commit you pushed from and rebuilds your upload as a single commit that only ever contained the converted files. The original ends up referenced by nothing and a clone can't reach it.

Honest limit: git objects that nothing references still sit on GitHub's servers until their garbage collection gets to them, and until then someone who already knew the exact commit hash could still fetch one. Nobody gets that hash by accident. But if a particular photo's location is genuinely sensitive, strip it before it ever leaves your machine — don't make a GitHub Action the only thing standing between it and the internet.

**It makes the page loadable.** The images on my own page are 61MB as they came off the phone, and 4.3MB published — a 14× cut, for a page that looks identical, because it draws them 250–500px wide. GitHub Pages does no image optimisation of its own and has a 100GB/month bandwidth limit, so uncompressed genuinely costs you here.

You lose nothing worth keeping. Your originals are still wherever they were; this repo is a display case, not storage.

Two consequences worth knowing:

- **If a file can't be read, it's deleted rather than left alone,** and the run goes red to tell you which. That looks aggressive, but an undecodable file is one whose metadata can't be stripped either — and leaving it means a public file with your coordinates in it. You still have the original; re-save it as a JPEG and upload it again. The same applies to anything that isn't an image, like a video that came along for the ride off your camera roll.
- **Animated GIFs become a single still frame.** Nobody's fixed this yet.

## Making it yours

Everything lives in `index.html`:

- **The text.** There's a marked placeholder near the top. Write whatever you want — the layout routes images around any text, so anything you add stays readable.
- **Image size.** Change `goal_pixels` (default `500*300`). Bigger number, bigger images.
- **Search engines.** It ships with `<meta name="robots" content="noindex, nofollow">`, so it won't turn up in search results. Delete that line if you'd rather it did.
- **Compression.** `MAX_EDGE` and `QUALITY` in `scripts/vibes.py`.

## When it breaks

**Page loads but is empty, or alerts about a missing JSON.** The Action hasn't run or it failed. Check the **Actions** tab.

**Action fails on permissions.** Settings → Actions → General → Workflow permissions → **Read and write**.

**Nothing deploys.** Settings → Pages → Source must be **GitHub Actions**.

**A photo is sideways.** Shouldn't happen — the script honours the EXIF orientation flag. If one slips through, open an issue.

## Credit

The placement algorithm and the original two-file version are [sophiawisdom's gist](https://gist.github.com/sophiawisdom/c1b16fcaca017d1aec2358c6fb619697) — go there if you'd rather run it locally against a folder of screenshots. This template adds the GitHub Pages plumbing, the compression, and the metadata stripping, so the whole thing runs off drag-and-drop.

The placement is deliberately crude: throw each image at a random spot, retry if it overlaps, make the page taller if it can't fit. Everyone's version of this page is a bit rough and it's better for it. Please don't add a lightbox.
