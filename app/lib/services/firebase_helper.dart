import 'package:conversationalist/services/firestore_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class FirebaseHelper {
  static signIn(String email, String password) async {
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      var box = Hive.box('box');
      String username = await FirestoreHelper.getUsernameByUid(
          FirebaseAuth.instance.currentUser!.uid);
      box.put('username', username);
    } on FirebaseAuthException catch (_) {
      rethrow;
    }
  }

  static signUp(String email, String password, String username) async {
    try {
      if (await FirestoreHelper.checkIfUsernameExists(username)) {
        throw Exception('Username already exists');
      } else {
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);

        FirestoreHelper.addUsername(username, userCredential.user!.uid);
        FirestoreHelper.addFcmToken(userCredential.user!.uid);
      }
    } on FirebaseAuthException catch (_) {
      rethrow;
    }
  }

  static signOut() async {
    FirestoreHelper.clearFcmToken(FirebaseAuth.instance.currentUser!.uid);
    await FirebaseAuth.instance.signOut();
    var box = Hive.box('box');
    box.delete('username');
  }

  static convert(String email, String password) async {
    final credential =
        EmailAuthProvider.credential(email: email, password: password);

    await FirebaseAuth.instance.currentUser!.linkWithCredential(credential);
  }

  static signInAnonymous(String username) async {
    if (await FirestoreHelper.checkIfUsernameExists(username)) {
      throw Exception('Username already exists');
    } else {
      final userCredential = await FirebaseAuth.instance.signInAnonymously();

      FirestoreHelper.addUsername(username, userCredential.user!.uid);
      FirestoreHelper.addFcmToken(userCredential.user!.uid);

      Hive.box('box').put('username', username);
    }
  }
}
