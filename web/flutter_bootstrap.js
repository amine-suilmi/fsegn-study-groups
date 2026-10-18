{{flutter_js}}
{{flutter_build_config}}

const loading = document.getElementById('app-loading');

_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    try {
      if (loading) loading.textContent = 'Initialisation de l’application…';
      const appRunner = await engineInitializer.initializeEngine();
      if (loading) loading.textContent = 'Ouverture de l’application…';
      await appRunner.runApp();
      if (loading) loading.remove();
    } catch (error) {
      if (loading) {
        loading.textContent = 'Impossible de charger l’application. Vérifiez votre connexion puis actualisez la page.';
      }
      console.error('Flutter app startup failed:', error);
    }
  },
});
