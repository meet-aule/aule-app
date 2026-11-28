abstract final class Routes {
  static const loading = '/loading';
  static const signIn = '/sign-in';
  static const signInEmail = '/sign-in/email';
  static const signInCode = '/sign-in/code';
  static const signInName = '/sign-in/name';
  static const signInHelp = '/sign-in/help';
  static const start = '/start';
  static const addChild = '/add-child';
  static const addChildProfile = '/add-child/profile';
  static String addChildDone(String childId) =>
      '/add-child/done?child=$childId';
  static const progress = '/progress';
  static const resources = '/resources';
  static const notices = '/progress/notices';
  static String notice(String noticeId) => '/progress/notices/$noticeId';
  static String childProgress(String childId) => '/progress/child/$childId';
  static String sessionDetail(String childId, String sessionId) =>
      '/progress/child/$childId/session/$sessionId';
  static const family = '/family';
  static String editChild(String childId) => '/family/child/$childId';
  static const privacy = '/privacy';
  static String childPrivacy(String childId) => '/privacy/child/$childId';
  static String memories(String childId) => '/privacy/child/$childId/memories';
  static const deleteAccount = '/privacy/account/delete';

  // Built by B2 (deviceRoutes, liveRoutes); named here for everyone.
  static String deviceSetup({String? childId}) =>
      childId == null ? '/devices/setup' : '/devices/setup?child=$childId';
  static String device(String deviceId) => '/devices/$deviceId';
  static String live(String sessionId, {required String childId}) =>
      '/live/$sessionId?child=$childId';
}
