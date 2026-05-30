class AppConstants {
  static const String appTitle = 'Teco Guide';
  static const String webUrl = 'https://app.tecoguide.com/login';
  static const String userAgent = 'Chrome/56.0.0.0 Mobile';
  
  // URL Filtering
  static const List<String> internalDomains = [
    'tecoguide.com',
    'accounts.google.com',
    'app.customgpt.ai',
    'openai.com',
  ];

  static const List<String> allowedExtensions = [
    'jpg', 'jpeg', 'png', 'gif', 'webp', // Images
    'pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx', 'csv', // Documents
  ];
}
