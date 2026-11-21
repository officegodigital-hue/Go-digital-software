String reportRouteName(String section) =>
    Uri(path: '/reports', queryParameters: {'section': section}).toString();
