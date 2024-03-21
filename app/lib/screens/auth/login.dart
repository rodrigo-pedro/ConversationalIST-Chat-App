import 'package:conversationalist/services/firestore_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/firebase_helper.dart';

class Login extends StatefulWidget {
  const Login({Key? key}) : super(key: key);

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  TextEditingController emailController = TextEditingController();
  TextEditingController passController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Form(
            key: _formKey,
            child: Center(
              child: ListView(
                shrinkWrap: true,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: const Text(
                      "ConversationalIST",
                      style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: TextFormField(
                        controller: emailController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppLocalizations.of(context)!
                                .pleaseEnterEmail;
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.enterEmail,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: const BorderSide(),
                          ),
                        )),
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: TextFormField(
                        controller: passController,
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppLocalizations.of(context)!
                                .pleaseEnterPassword;
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText:
                              AppLocalizations.of(context)!.enterPassword,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: const BorderSide(),
                          ),
                        )),
                  ),
                  RawMaterialButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _login(context);
                      }
                    },
                    elevation: 2.0,
                    fillColor: Theme.of(context).colorScheme.secondary,
                    padding: const EdgeInsets.all(15.0),
                    shape: const CircleBorder(),
                    child: Icon(Icons.login, color: Theme.of(context).colorScheme.onSecondary),
                  ),
                  Container(
                      padding: const EdgeInsets.all(20),
                      child: TextButton(
                          onPressed: () {
                            if (mounted) {
                              Navigator.pushReplacementNamed(
                                  context, '/signup');
                            }
                          },
                          child: Text(AppLocalizations.of(context)!.signup))),
                  Container(
                      padding: const EdgeInsets.all(20),
                      child: TextButton(
                          onPressed: () {
                            if (mounted) {
                              Navigator.pushReplacementNamed(
                                  context, '/anonymous');
                            }
                          },
                          child:  Text(AppLocalizations.of(context)!.signWithoutAccount)),
                  ),
                ],
              ),
            )));
  }

  _login(BuildContext context) async {
    try {
      await FirebaseHelper.signIn(emailController.text, passController.text);
      await FirestoreHelper.addFcmToken(FirebaseAuth.instance.currentUser!.uid);

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          elevation: 6.0,
          behavior: SnackBarBehavior.floating,
          content: Text(
            AppLocalizations.of(context)!.invalidCredentials,
          )
      )
      );
    }
  }
}
