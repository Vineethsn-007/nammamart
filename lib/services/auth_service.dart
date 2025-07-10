import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password.trim());
      return userCredential;
    } on FirebaseAuthException {
      // Rethrow the Firebase exception so it can be caught and handled by the UI
      rethrow;
    } catch (e) {
      // Rethrow any other exceptions
      rethrow;
    }
  }

  // Register with email and password
  Future<UserCredential> registerWithEmailAndPassword(
      String email, String password) async {
    try {
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email.trim(), password: password.trim());

      // Send email verification
      await userCredential.user!.sendEmailVerification();

      return userCredential;
    } on FirebaseAuthException {
      // Rethrow the Firebase exception
      rethrow;
    } catch (e) {
      // Rethrow any other exceptions
      rethrow;
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Begin interactive sign in process
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      // Obtain auth details from request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create new credential for user
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in with credential
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      rethrow;
    }
  }


  // Reset Password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      // Check if user signed in with Google before trying to sign out
      try {
        final isGoogleSignedIn = await _googleSignIn.isSignedIn();
        if (isGoogleSignedIn) {
          await _googleSignIn.signOut();
        }
      } catch (e) {
        // Ignore errors from Google sign out to ensure we continue with the rest
        print('Google sign out error: $e');
      }
      
      // Always sign out from Firebase
      await _auth.signOut();
    } catch (e) {
      // If Firebase sign out fails, re-throw the error
      rethrow;
    }
  }
}