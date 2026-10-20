/// The plugin file browser receives both values through its URL: the mobile
/// app is the only owner of the language and theme choice, so the browser
/// itself exposes no switch.
String remoteFilesPath({required String languageCode, required bool dark}) {
  return Uri(
    path: '/dsh-mobile/files',
    queryParameters: {'lang': languageCode, 'theme': dark ? 'dark' : 'light'},
  ).toString();
}
