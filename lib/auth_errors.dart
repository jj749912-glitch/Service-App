import 'package:supabase_flutter/supabase_flutter.dart';

String authErrorMessage(AuthException error) {
  if (error is AuthRetryableFetchException) {
    return 'Could not securely connect. Check your internet connection and retry.';
  }
  return error.message;
}
