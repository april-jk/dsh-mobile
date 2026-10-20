/// Applies the requested path and query to a proxy start URL without dropping
/// the one-time bootstrap capability that authenticates the first request.
Uri sessionTargetUrl(Uri startUrl, String initialPath) {
  final target = Uri.parse(initialPath);
  return startUrl.replace(
    path: target.path.isEmpty ? startUrl.path : target.path,
    queryParameters: {...startUrl.queryParameters, ...target.queryParameters},
  );
}
