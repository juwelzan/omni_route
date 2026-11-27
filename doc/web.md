# OmniRoute on the Web

## 1. Clean path URLs

```dart
void main() {
  OmniRoute.usePathUrls();   // must run before runApp
  runApp(const MyApp());
}
```

URLs look like `https://example.com/students/101` instead of `/#/students/101`.
This uses Flutter's own `usePathUrlStrategy()`; it does nothing on non-web
platforms.

What then works without extra code (verified in a browser with the example app):

| Behaviour | Notes |
|---|---|
| Direct access / refresh on any URL | needs the server fallback below |
| Browser back / forward | `OmniRouter` syncs URLs cleanly (`push` adds history; `replace`, guard `redirect`, `pop`, and `go(..., replaceHistory: true)` use `replaceState` so back cannot return to Login/closed screens) |
| Query parameters | `p.query('tab')`, kept in the address bar |
| Trailing slash | `/students/` redirects to `/students` (query kept) |
| URL encoding | path params are decoded for you; `OmniRoute.to<T>()` encodes |
| Unknown URL | `OmniApp(notFound: ...)` page |
| Tab title | each screen's `title` (defaults to a title formatted from `routePath`); off with `OmniApp(setTitles: false)` |

**Things that do not survive a refresh:** `extra` objects and in-memory Bloc
state (e.g. a logged-in flag). Put anything a page needs after reload in the
path or query, and persist auth yourself. Never put tokens or secrets in URLs.

## 2. Server fallback (required)

With path URLs, the browser asks the server for `/students/101` on refresh.
That file doesn't exist, so the server must return `index.html` for unknown
paths and let Flutter route. Real files (`main.dart.js`, `assets/…`) must
still be served normally.

### Nginx
```nginx
location / {
  root /var/www/app;
  try_files $uri $uri/ /index.html;
}
```

### Apache (`.htaccess` next to `index.html`)
```apache
FallbackResource /index.html
```
or, with mod_rewrite:
```apache
RewriteEngine On
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule ^ index.html [L]
```

### Firebase Hosting (`firebase.json`)
```json
{ "hosting": { "public": "build/web",
  "rewrites": [{ "source": "**", "destination": "/index.html" }] } }
```

### Netlify (`web/_redirects`, copied into the build)
```
/*  /index.html  200
```

### Vercel (`vercel.json`)
```json
{ "rewrites": [{ "source": "/(.*)", "destination": "/index.html" }] }
```

### GitHub Pages
No rewrite support. Copy `index.html` to `404.html` after building
(`cp build/web/index.html build/web/404.html`). Pages still answers deep
links with HTTP 404 status, which some crawlers dislike.

## 3. Deploying under a subdirectory

For `https://example.com/myapp/…`:

```bash
flutter build web --base-href /myapp/
```

Routes stay written as `/students/:id` in your code; Flutter adds `/myapp`.
Point the fallback at the subdirectory's index:

```nginx
location /myapp/ {
  alias /var/www/myapp/;
  try_files $uri $uri/ /myapp/index.html;
}
```

## 4. Offline / restricted networks
By default Flutter loads its renderer (CanvasKit) from Google's CDN. If your
users or CI can't reach it, build with `--no-web-resources-cdn`.
