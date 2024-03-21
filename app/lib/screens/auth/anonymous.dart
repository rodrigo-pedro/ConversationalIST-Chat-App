import 'package:conversationalist/services/firestore_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../services/firebase_helper.dart';

class Anonymous extends StatefulWidget {
  const Anonymous({Key? key}) : super(key: key);

  @override
  State<Anonymous> createState() => _AnonymousState();
}

class _AnonymousState extends State<Anonymous> {
  TextEditingController usernameController = TextEditingController();
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
                        controller: usernameController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppLocalizations.of(context)!.pleaseEnterUsername;
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.enterUsername,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: const BorderSide(),
                          ),
                        )),
                  ),
                  RawMaterialButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _loginAnonymous(context);
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
                                context, '/login');
                          }
                        },
                        child: Text(AppLocalizations.of(context)!.signWithAccount)),
                  ),
                ],
              ),
            )));
  }

  _loginAnonymous(BuildContext context) async {
    try {
      await FirebaseHelper.signInAnonymous(usernameController.text);

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
    } on Exception catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          elevation: 6.0,
          behavior: SnackBarBehavior.floating,
          content: Text(
            AppLocalizations.of(context)!.usernameExists,
          )
      )
      );
    }
  }
}
