import 'package:conversationalist/services/firestore_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firebase_helper.dart';


class Signup extends StatefulWidget {
  const Signup({Key? key}) : super(key: key);

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  TextEditingController emailController = TextEditingController();
  TextEditingController usernameController = TextEditingController();
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
                            return AppLocalizations.of(context)!.pleaseEnterEmail;
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
                            return AppLocalizations.of(context)!.pleaseEnterPassword;
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!.enterPassword,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                            borderSide: const BorderSide(),
                          ),
                        )),
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
                        _signup(context);
                      }
                    },
                    elevation: 2.0,
                    fillColor:  Theme.of(context).colorScheme.secondary,
                    padding: const EdgeInsets.all(15.0),
                    shape: const CircleBorder(),
                    child: Icon(Icons.arrow_right_alt_outlined, color: Theme.of(context).colorScheme.onSecondary),
                  ),
                  Container(
                      padding: const EdgeInsets.all(20),
                      child: TextButton(
                          onPressed: () {
                            if(mounted) {
                              Navigator.pushReplacementNamed(context, '/login');
                            }
                          },
                          child: Text(AppLocalizations.of(context)!.login)
                      )
                  ),
                ],
              ),
            )
        ));
  }

  _signup(BuildContext context) async {
    try {
      await FirebaseHelper.signUp(emailController.text, passController.text, usernameController.text);

      if(mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }

    } on FirebaseAuthException catch (e) {
      String message;
      if (e.code == 'weak-password') {
        message = AppLocalizations.of(context)!.weakPassword;
      } else if (e.code == 'email-already-in-use') {
        message = AppLocalizations.of(context)!.accountInUse;
      }
      else {
        message = AppLocalizations.of(context)!.unableToRegister;
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          elevation: 6.0,
          behavior: SnackBarBehavior.floating,
          content: Text(message))
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