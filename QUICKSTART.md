# Quick Start Guide

Get a cloud browser running on Railway in 5 minutes.

## Prerequisites

- Railway.app account (free)
- GitHub account (to connect repo)

## Step 1: Create GitHub Repository

Fork or create a new repository with this content.

Or use Railway's direct deploy:

## Step 2: Deploy to Railway

### Option A: Railway CLI (Fastest)

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login
railway login

# Create new project
railway init

# Deploy
railway up
```

### Option B: Railway Dashboard (Easiest for Beginners)

1. Go to [Railway.app](https://railway.app)
2. Click "New Project"
3. Select "GitHub Repo"
4. Connect this repository
5. Select branch: `main`
6. Click "Deploy"

### Option C: Deploy Button (One Click)

(If repo has Railway deploy button configured)

## Step 3: Wait for Deployment

- Build: 2-5 minutes (first time)
- Startup: 30-60 seconds
- Total: 3-7 minutes

Watch progress:
```bash
railway logs
```

Look for ✓ "Ready" message.

## Step 4: Access the Browser

1. Copy the Railway app URL (e.g., `https://my-app.railway.app`)
2. Open in any web browser
3. Wait 10-15 seconds for desktop to load
4. Click in the window
5. Browser is ready!

## Step 5: (Optional) Attach Persistent Volume

To keep bookmarks and downloads after restart:

1. Railway Dashboard → Your Project
2. Click "Volumes" tab
3. Click "New Volume"
4. Set mount point: `/data`
5. Click "Create"
6. Railway will redeploy automatically

Done!

## Common Configurations

### Change Default Website

```bash
railway env add HOMEPAGE https://github.com
railway redeploy
```

### Higher Resolution (for 4K monitors)

```bash
railway env add WIDTH 3840
railway env add HEIGHT 2160
railway env add DPI 120
railway redeploy
```

### Smaller Resolution (for slow internet)

```bash
railway env add WIDTH 1280
railway env add HEIGHT 720
railway redeploy
```

### Different Timezone

```bash
railway env add TZ America/New_York
railway redeploy
```

## Troubleshooting

**"Can't connect"?**
- Wait 60 seconds (startup is slow on free tier)
- Check logs: `railway logs`
- Reload page: F5

**"No audio"?**
- Audio requires good internet connection
- Some corporate networks block it
- Try video without audio as fallback

**"Files disappeared after restart"?**
- Attach `/data` volume (see Step 5 above)

**"Slowness"?**
- Reduce resolution (see configurations above)
- Close browser tabs
- Check internet speed

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed help.

## Next Steps

- Read [README.md](README.md) for full documentation
- Read [ARCHITECTURE.md](ARCHITECTURE.md) to understand how it works
- Customize [Dockerfile](Dockerfile) for your needs

## Environment Variables

Quick reference:

| Variable | Example | Purpose |
|----------|---------|---------|
| `HOMEPAGE` | `https://example.com` | Start page |
| `WIDTH` | `1920` | Screen width (pixels) |
| `HEIGHT` | `1080` | Screen height (pixels) |
| `DPI` | `96` | Text size (96=normal, 120=larger) |
| `TZ` | `UTC` or `America/New_York` | Timezone |
| `LANGUAGE` | `en_US.UTF-8` | Language |

## Tips

- ✅ Bookmark your Railway app URL
- ✅ Keep `/data` volume for persistent data
- ✅ Use 1920x1080 for balanced performance
- ✅ Close unused tabs to save memory
- ✅ Reload page if connection drops
- ✅ Check logs (`railway logs`) if something's wrong

## That's It!

You now have a cloud browser running on Railway.

For advanced features and full documentation, see README.md

---

**Need help?** See [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
