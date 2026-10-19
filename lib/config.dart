/// Public client configuration. The anon key is designed to ship inside apps;
/// all data access is protected by Row Level Security on the server.
/// Never put service-role keys or third-party API keys here.
class AppConfig {
  static const supabaseUrl = 'https://mwpqgqsogdgrxnzgmogh.supabase.co';
  static const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im13cHFncXNvZ2Rncnhuemdtb2doIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIyNzE3MDYsImV4cCI6MjEwNzg0NzcwNn0.dyo1yF73jwWw97JwlUa28TsRSfmqNKf_tNmuhujTnsU';
}
