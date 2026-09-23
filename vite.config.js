import { fileURLToPath, URL } from 'node:url';
import { defineConfig } from 'vite';

/** @param {import('vite').ViteDevServer | import('vite').PreviewServer} server */
function redirectPrivacyDirectory(server) {
  server.middlewares.use((request, response, next) => {
    const url = new URL(request.url ?? '/', 'http://localhost');
    if (url.pathname !== '/privacy') return next();
    response.writeHead(302, { Location: `/privacy/${url.search}` });
    response.end();
  });
}

export default defineConfig({
  plugins: [{
    name: 'privacy-directory',
    configureServer: redirectPrivacyDirectory,
    configurePreviewServer: redirectPrivacyDirectory,
  }],
  build: {
    rolldownOptions: {
      input: {
        landing: fileURLToPath(new URL('./index.html', import.meta.url)),
        privacy: fileURLToPath(new URL('./privacy/index.html', import.meta.url)),
      },
    },
  },
});
