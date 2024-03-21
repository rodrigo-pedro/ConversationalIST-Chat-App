import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:conversationalist/services/firestore_helper.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutterfire_ui/firestore.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';


class Search extends StatefulWidget {
  const Search({Key? key}) : super(key: key);

  @override
  State<Search> createState() => _SearchState();
}

class _SearchState extends State<Search> {
  late Query<Object?> _publicChatroomsQuery;
  final TextEditingController _controller = TextEditingController();
  String username = "";

  getUsername() {
    var box = Hive.box('box');
    return box.get('username');
  }

  getChatroomQuery() {
    _publicChatroomsQuery = FirestoreHelper.getPublicChatrooms();
    setState(() {});
  }

  @override
  initState() {
    username = getUsername();
    getChatroomQuery();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(10),
          child: TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.searchForChatroom,
              icon: const Icon(Icons.search),
            ),
            onChanged: (value) {
              setState(() {});
            },
          ),
        ),
        Expanded(
            child: FirestoreListView<Map<String, dynamic>>(
          query: _publicChatroomsQuery as Query<Map<String, dynamic>>,
          itemBuilder: (context, snapshot) {
            Map<String, dynamic> data = snapshot.data();

            if (data['users'].contains(username) || (_controller.text.isNotEmpty && !data['name'].contains(_controller.text))) {
              return Container();
            }

            if (data["type"] == "georestricted") {
              return FutureBuilder(
                future: Geolocator.getCurrentPosition(),
                // a previously-obtained Future<String> or null
                builder: (BuildContext context, AsyncSnapshot<Position> snapshotGeo) {
                  if (snapshotGeo.hasData) {
                    bool isInRange = Geolocator.distanceBetween(
                            snapshotGeo.data!.latitude, snapshotGeo.data!.longitude, double.parse(data["lat"]), double.parse(data["lon"])) <=
                        data["radius"];

                    if (isInRange) {
                      return ListTile(
                      title: Text(data['name']),
                      leading: const Icon(Icons.map),
                      onTap: () {
                        showDialog<void>(
                            context: context,
                            builder: (BuildContext dialogContext) {
                              return AlertDialog(
                                content: Text('${AppLocalizations.of(context)!.join} ${data['name']}?'),
                                actions: [
                                  TextButton(
                                    child:  Text(AppLocalizations.of(context)!.cancel),
                                    onPressed: () {
                                      Navigator.pop(context);
                                    },
                                  ),
                                  TextButton(
                                    child:  Text(AppLocalizations.of(context)!.join),
                                    onPressed: () {
                                      FirestoreHelper.joinChatroom(snapshot.reference.id, username);
                                      setState(() {});
                                      Navigator.pop(context);
                                    },
                                  ),
                                ],
                              );
                            });
                        },
                    );
                    }
                  }
                  return Container();
                },
              );
            } else {
              return ListTile(
                title: Text(data['name']),
                leading: data["type"] == "public" ? const Icon(Icons.lock_open) : const Icon(Icons.lock),
                onTap: () {
                  showDialog<void>(
                      context: context,
                      builder: (BuildContext dialogContext) {
                        return AlertDialog(
                          content: Text('${AppLocalizations.of(context)!.join} ${data['name']}?'),
                          actions: [
                            TextButton(
                              child: Text(AppLocalizations.of(context)!.cancel),
                              onPressed: () {
                                Navigator.pop(context);
                              },
                            ),
                            TextButton(
                              child: Text(AppLocalizations.of(context)!.join),
                              onPressed: () {
                                FirestoreHelper.joinChatroom(snapshot.reference.id, username);
                                setState(() {});
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        );
                      });

                  //Navigator.pushNamed(context, '/chat', arguments: [data['name'], snapshot.reference.id]);
                },
              );
            }
          },
        )),
      ],
    ));
  }
}
