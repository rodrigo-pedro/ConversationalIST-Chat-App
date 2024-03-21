import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:hive/hive.dart';
import '../../services/firebase_helper.dart';

class Convert extends StatefulWidget {
  const Convert({Key? key}) : super(key: key);

  @override
  State<Convert> createState() => _ConvertState();
}

class _ConvertState extends State<Convert> {
  TextEditingController emailController = TextEditingController();
  String username = Hive.box('box').get('username');
  TextEditingController passController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(),
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
                        _convert(context).then((_) {
                          Navigator.pop(context);
                        });
                      }
                    },
                    elevation: 2.0,
                    fillColor: Theme.of(context).colorScheme.secondary,
                    padding: const EdgeInsets.all(15.0),
                    shape: const CircleBorder(),
                    child: Icon(Icons.arrow_right_alt_outlined,
                        color: Theme.of(context).colorScheme.onSecondary),
                  ),
                ],
              ),
            )));
  }

  Future<bool> _convert(BuildContext context) async {
    try {
      await FirebaseHelper.convert(emailController.text, passController.text);
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'weak-password':
          message = AppLocalizations.of(context)!.weakPassword;
          break;
        case 'email-already-in-use':
          message = AppLocalizations.of(context)!.accountInUse;
          break;
        case "provider-already-linked":
          message = "The provider has already been linked to the user.";
          break;
        case "invalid-credential":
          message = "The provider's credential is not valid.";
          break;
        case "credential-already-in-use":
          message =
              "The account corresponding to the credential already exists, "
              "or is already linked to a Firebase User.";
          break;
        // See the API reference for the full list of error codes.
        default:
          message = AppLocalizations.of(context)!.unableToRegister;
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          elevation: 6.0,
          behavior: SnackBarBehavior.floating,
          content: Text(message)));
    }
    return Future.value(true);
  }
}
