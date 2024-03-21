import 'package:conversationalist/screens/chatList.dart';
import 'package:conversationalist/screens/search.dart';
import 'package:conversationalist/services/firebase_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String username = Hive.box('box').get('username');

  int _selectedIndex = 0;
  static const TextStyle optionStyle = TextStyle(fontSize: 30, fontWeight: FontWeight.bold);
  static final List<Widget> _widgetOptions = <Widget>[
    const ChatList(),
    const Search(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  initState() {
    super.initState();

    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? initialMessage) {
      if (initialMessage != null) {
        Navigator.pushNamed(context, '/chat', arguments: {
          'name': initialMessage.data['chatroomName'],
          'docId': initialMessage.data['chatroomId'],
          'type': initialMessage.data['type'],
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).primaryColor),
              child: Text('${AppLocalizations.of(context)!.welcome} $username'),
            ),
            if (FirebaseAuth.instance.currentUser!.isAnonymous)
              ListTile(
                title: Text(AppLocalizations.of(context)!.convertAccount),
                onTap: () {
                  Navigator.pushNamed(context, '/convert').then((_) => setState(() {}));
                },
              ),
            ListTile(
                title: Text(AppLocalizations.of(context)!.signOut),
                onTap: () {
                  FirebaseHelper.signOut();
                  Navigator.pushReplacementNamed(context, '/login');
                })
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text("ConversationalIST"),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat),
            label: AppLocalizations.of(context)!.chats,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.search),
            label: AppLocalizations.of(context)!.search,
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
    );
  }
}
