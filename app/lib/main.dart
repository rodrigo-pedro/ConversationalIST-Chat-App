import 'dart:async';
import 'dart:convert';

import 'package:conversationalist/screens/auth/anonymous.dart';
import 'package:conversationalist/screens/auth/convert.dart';
import 'package:conversationalist/screens/auth/login.dart';
import 'package:conversationalist/screens/auth/signup.dart';
import 'package:conversationalist/screens/chat.dart';
import 'package:conversationalist/screens/geoRoom.dart';
import 'package:conversationalist/screens/home.dart';
import 'package:conversationalist/screens/mapScreen.dart';
import 'package:conversationalist/services/firestore_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';
import 'firebase_options.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();
const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
  'default_notification_channel_id',
  'Notification',
  importance: Importance.max,
  priority: Priority.high,
  ticker: 'ticker',
);
const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidDetails);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await FirebaseMessaging.instance.getToken();

  await Hive.initFlutter();
  await Hive.openBox('box');

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');

    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
    }

    bool isInChat = false;
    String chatRoomId = '';

    // hack to get route and chatRoomId
    Navigator.popUntil(navigatorKey.currentState!.context, (route) {
      if (route.settings.name == '/chat') {
        isInChat = true;
        dynamic args = route.settings.arguments as Map<String, dynamic>;
        chatRoomId = args['docId'];
      }
      return true;
    });

    // don't show notification if user is the same chat as notification
    if (isInChat && chatRoomId == message.data['chatroomId']) {
      return;
    }

    showNotification(message);
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
    print("onMessageOpenedApp: $message");

    Navigator.pushNamed(navigatorKey.currentState!.context, '/chat', arguments: {
      'name': message.data['chatroomName'],
      'docId': message.data['chatroomId'],
      'type': message.data['type'],
    });
  });

  _initDynamicLink();

  var android = const AndroidInitializationSettings('@mipmap/ic_launcher');
  var initialSetting = InitializationSettings(android: android);
  flutterLocalNotificationsPlugin.initialize(initialSetting, onSelectNotification: selectNotification);

  await dotenv.load(fileName: ".env");

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      themeMode: ThemeMode.system,
      theme: ThemeData(
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            primary: Colors.tealAccent,
            onPrimary: Colors.black87,
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: Colors.tealAccent,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            primary: Colors.tealAccent,
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: Colors.tealAccent,
          backgroundColor: Colors.grey.shade800,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: Colors.tealAccent,
            ),

          ),
          iconColor: Colors.tealAccent,
          floatingLabelStyle: TextStyle(
            color: Colors.tealAccent,
          ),

        )
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', ''), Locale('pt', '')],
      initialRoute: defineInitialRoute(),
      routes: {
        '/login': (context) => const Login(),
        '/signup': (context) => const Signup(),
        '/home': (context) => const Home(),
        '/chat': (context) => const Chat(),
        '/map': (context) => const MapScreen(),
        '/geo': (context) => const Geo(),
        '/convert': (context) => const Convert(),
        '/anonymous': (context) => const Anonymous(),
      },
    );
  }

  defineInitialRoute() {
    final FirebaseAuth auth = FirebaseAuth.instance;

    final User? user = auth.currentUser;
    if (user == null) {
      return '/login';
    }
    return '/home';
  }
}

_initDynamicLink() {
  FirebaseDynamicLinks.instance.onLink.listen((dynamicLinkData) async {
    final Uri deepLink = dynamicLinkData.link;
    String chatroomId = deepLink.queryParameters['chatroomId']!;
    String chatroomName = deepLink.queryParameters['chatroomName']!;

    if (FirebaseAuth.instance.currentUser != null) {
      String username = Hive.box("box").get('username');

      if (!(await FirestoreHelper.checkUserInChatroom(chatroomId, username))) {
        showDialog<void>(
          context: navigatorKey.currentState!.overlay!.context,
          barrierDismissible: true,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(AppLocalizations.of(navigatorKey.currentContext!)!.joinChatPrompt),
              actions: <Widget>[
                TextButton(
                  child: Text(AppLocalizations.of(navigatorKey.currentContext!)!.cancel),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                TextButton(
                  child: Text(AppLocalizations.of(navigatorKey.currentContext!)!.yes),
                  onPressed: () async {
                    FirestoreHelper.joinChatroom(chatroomId, username);
                    Navigator.of(context).pop();
                    Navigator.pushNamed(navigatorKey.currentState!.context, '/chat',
                        arguments: {'name': chatroomName, 'docId': chatroomId, 'type': 'private'});
                  },
                ),
              ],
            );
          },
        );
      } else {
        Navigator.pushNamed(navigatorKey.currentState!.context, '/chat', arguments: {'name': chatroomName, 'docId': chatroomId, 'type': 'private'});
      }
    }
  }).onError((error) {
    print(error);
  });
}

void selectNotification(String? payload) {
  if (payload != null) {
    dynamic data = jsonDecode(payload);

    Navigator.pushNamed(navigatorKey.currentState!.context, '/chat', arguments: {
      'name': data['chatroomName'],
      'docId': data['chatroomId'],
      'type': data['type'],
    });
  }
}

Future<void> showNotification(RemoteMessage message) async {
  if (message.data["chatroomLat"] != null && message.data["chatroomLat"] != "") {
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

    bool isInRange = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        double.parse(message.data["chatroomLat"]),
        double.parse(message.data["chatroomLon"])) <=
        double.parse(message.data["chatroomRadius"]);

    if (isInRange == false) {
      return;
    }
  }

  String payload = jsonEncode(message.data);

  await flutterLocalNotificationsPlugin.show(0, message.data["title"], message.data["body"], platformChannelSpecifics, payload: payload);
}

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();


  print("Handling a background message: ${message.messageId}");

  if (message.data["chatroomLat"] != null && message.data["chatroomLat"] != "") {
    showNotification(message);
  }

}
