# GitHub deployment

This repository publishes the customer website from `apps/marys_fashion_website`
and the protected inventory web app from `lib/main_inventory.dart`. The apps use
the same Supabase data but have separate URLs.

## First publication

1. Create an empty GitHub repository. A short name such as `marys-fashion` is suitable.
2. Push this project to its `main` branch.
3. In the repository, open **Settings → Secrets and variables → Actions** and add these repository secrets:
   - `SUPABASE_URL`
   - `SUPABASE_PUBLISHABLE_KEY`
4. Open **Settings → Pages** and set **Source** to **GitHub Actions**.
5. Open **Actions → Deploy Marys Fashion website**. Run the workflow if it did not start automatically after the push.

The first default address will be:

```text
https://YOUR-GITHUB-USERNAME.github.io/YOUR-REPOSITORY-NAME/
```

The inventory address is the same URL followed by `inventory/`.

For example, a repository named `marys-fashion` owned by `mary` would use
`https://mary.github.io/marys-fashion/`.

Every later push to `main` automatically rebuilds and republishes the customer
website. The workflow calculates the correct base path for both normal project
repositories and special `USERNAME.github.io` repositories.

## Custom domain later

Buy or choose the domain first, then add it under **Settings → Pages → Custom
domain** and follow GitHub's displayed DNS instructions. Do not add a `CNAME`
file before the exact domain is known. GitHub's default Pages address continues
to work while a custom domain is being prepared.

Also add the final website URL to the allowed redirect URLs in Supabase if the
site uses email links, Google sign-in, or another OAuth provider.

## Security and data

- `.env`, local SQLite files, staff passwords, uploads, and backups are ignored by Git and must not be committed.
- Only the Supabase URL and **publishable** key belong in this browser build. Never add a Supabase secret/service-role key, PayChangu secret, webhook secret, database URL, or staff password to GitHub Pages build settings.
- Product inventory remains in Supabase. GitHub stores the application source, not the live database records.
- Row Level Security must protect every Supabase table exposed to the website.

## What GitHub Pages does not host

GitHub Pages serves static files only. It will not run the Python server in
`server/`. Both web apps therefore use their direct Supabase connection. Payment
processing continues through the Supabase Edge Function rather than Pages.
