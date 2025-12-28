# Craig-O-Clean Web App

A Progressive Web App (PWA) for device optimization, ready for deployment on Android devices and the web.

## Features

- **Device Health Monitoring** - Real-time analysis of device performance
- **Cache Cleaning** - Remove temporary files and cached data
- **Memory Optimization** - Free up RAM for better performance
- **Speed Boost** - Optimize system resources
- **Battery Saver** - Extend battery life with power management
- **Deep Clean** - Comprehensive device optimization
- **Offline Support** - Works without internet connection (PWA)
- **Installable** - Add to home screen on Android/iOS

## Quick Start

### Local Development

```bash
# Navigate to the web app directory
cd web-app

# Option 1: Using Node.js server
node server.js

# Option 2: Using npx serve
npx serve -s . -l 3000

# Option 3: Using Python
python -m http.server 3000
```

Open http://localhost:3000 in your browser.

## Deployment

### Vercel (Recommended)

```bash
# Install Vercel CLI
npm i -g vercel

# Deploy
cd web-app
vercel
```

Or connect your GitHub repo to Vercel for automatic deployments.

### Netlify

```bash
# Install Netlify CLI
npm i -g netlify-cli

# Deploy
cd web-app
netlify deploy --prod
```

Or drag and drop the `web-app` folder to [Netlify Drop](https://app.netlify.com/drop).

### Firebase Hosting

```bash
# Install Firebase CLI
npm i -g firebase-tools

# Login and initialize
firebase login
firebase init hosting

# Deploy
cd web-app
firebase deploy
```

### GitHub Pages

1. Push the `web-app` folder to your repository
2. Go to Settings → Pages
3. Select the branch and folder
4. Your app will be live at `https://username.github.io/repo-name/`

### Docker

```dockerfile
FROM nginx:alpine
COPY . /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

```bash
docker build -t craig-o-clean .
docker run -p 8080:80 craig-o-clean
```

## Generating App Icons

1. Open `icons/generate-icons.html` in a web browser
2. Click "Generate All Icons"
3. Right-click each icon and save with the suggested filename
4. Save all icons to the `/icons` folder

Alternatively, use the SVG icon at `icons/icon.svg` with an online converter.

## Project Structure

```
web-app/
├── index.html          # Main HTML file
├── manifest.json       # PWA manifest for Android installability
├── sw.js              # Service Worker for offline support
├── css/
│   └── styles.css     # All styles (mobile-first)
├── js/
│   └── app.js         # Application logic
├── icons/
│   ├── icon.svg       # Vector icon source
│   └── generate-icons.html  # Icon generator tool
├── server.js          # Node.js development server
├── vercel.json        # Vercel deployment config
├── netlify.toml       # Netlify deployment config
├── firebase.json      # Firebase deployment config
└── package.json       # NPM package configuration
```

## PWA Features

- **Installable**: Add to home screen prompt on Android
- **Offline-first**: Works without internet connection
- **Push Notifications**: (Ready for backend integration)
- **Background Sync**: (Ready for backend integration)
- **App Shortcuts**: Quick actions from home screen icon

## Browser Support

- Chrome 80+
- Firefox 75+
- Safari 14+
- Edge 80+
- Samsung Internet 12+

## Testing PWA

1. Open Chrome DevTools (F12)
2. Go to Application → Manifest to verify PWA configuration
3. Go to Application → Service Workers to check SW status
4. Use Lighthouse (Audits tab) to test PWA score

## Android Installation

1. Open the deployed URL in Chrome on Android
2. Tap the "Add to Home Screen" banner or menu option
3. The app will be installed as a standalone application

## License

MIT License - See LICENSE file for details.
