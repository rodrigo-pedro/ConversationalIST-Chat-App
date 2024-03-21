import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:conversationalist/services/firestore_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutterfire_ui/firestore.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../services/location_helper.dart';

class ChatList extends StatefulWidget {
  const ChatList({Key? key}) : super(key: key);

  @override
  State<ChatList> createState() => _ChatListState();
}

enum RoomType { public, private, georestricted }

class _ChatListState extends State<ChatList> {
  late Query<Object?> _chatroomsQuery;
  RoomType? _roomType = RoomType.public;
  final TextEditingController _controller = TextEditingController();
  String username = Hive.box('box').get('username');

  getChatsOnWifi(String docId) async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.wifi) {
      FirestoreHelper.getFirstMessages(docId);
    }
  }

  getChatroomQuery() async {
    _chatroomsQuery = FirestoreHelper.getChatroomsByUsername(username);
    setState(() {});
  }

  @override
  initState() {
    getChatroomQuery();
    super.initState();
  }

  @override
  dispose() {
    _controller.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: FutureBuilder(
          future: LocationHelper.getCurrentPosition(),
          builder: (locationContext, locationSnapshot) {
            return FirestoreListView<Map<String, dynamic>>(
              query: _chatroomsQuery as Query<Map<String, dynamic>>,
              itemBuilder: (context, snapshot) {
                Map<String, dynamic> data = snapshot.data();

                return FutureBuilder(
                    future: FirestoreHelper.checkIfRead(snapshot.reference.id, username),
                    builder: (futureContext, futureSnapshot) {
                      if (futureSnapshot.hasData) {
                        if (data["type"] == "georestricted") {
                          if (locationSnapshot.data == null) {
                            return Container();
                          }

                          Position position = locationSnapshot.data as Position;

                          bool isInRange = LocationHelper.userInRange(
                              position.latitude,
                              position.longitude,
                              double.parse(data["lat"]),
                              double.parse(data["lon"]),
                              data["radius"]);

                          if (!isInRange) {
                            return Container();
                          } else {
                            getChatsOnWifi(snapshot.reference.id);
                            return ListTile(
                              title: Text(data['name']),
                              leading: const Icon(Icons.map),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _getLastMessageTimestamp(data["lastMessageTimestamp"].toDate()),
                                  (futureSnapshot.data == true || data["lastMessage"] == '')
                                      ? const Text("")
                                      : const Icon(
                                          Icons.circle,
                                          size: 20,
                                          color: Colors.green,
                                        ),
                                ],
                              ),
                              subtitle: Text(data["lastMessage"]),
                              onTap: () async {
                                if (data["type"] == "georestricted") {
                                  var currentPosition = await LocationHelper.getCurrentPosition();
                                  bool isInRange = LocationHelper.userInRange(
                                      currentPosition.latitude,
                                      currentPosition.longitude,
                                      double.parse(data["lat"]),
                                      double.parse(data["lon"]),
                                      data["radius"]);
                                  if (!isInRange) {
                                    setState(() {});
                                    return;
                                  }
                                }

                                if (mounted) {
                                  Navigator.pushNamed(context, '/chat', arguments: {
                                    'name': data['name'],
                                    'docId': snapshot.reference.id,
                                    'type': data['type']
                                  });
                                }
                              },
                            );
                          }
                        } else {
                          getChatsOnWifi(snapshot.reference.id);
                          return ListTile(
                            title: Text(data['name']),
                            leading: data["type"] == "public"
                                ? const Icon(Icons.lock_open)
                                : const Icon(Icons.lock),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _getLastMessageTimestamp(data["lastMessageTimestamp"].toDate()),
                                (futureSnapshot.data == true || data["lastMessage"] == '')
                                    ? const Text("")
                                    : const Icon(
                                        Icons.circle,
                                        size: 20,
                                        color: Colors.green,
                                      ),
                              ],
                            ),
                            subtitle: Text(data["lastMessage"]),
                            onTap: () {
                              Navigator.pushNamed(context, '/chat', arguments: {
                                'name': data['name'],
                                'docId': snapshot.reference.id,
                                'type': data['type']
                              });
                            },
                          );
                        }
                      } else {
                        return Container();
                      }
                    });
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            showDialog<void>(
              context: context,
              barrierDismissible: true,
              builder: (BuildContext context) {
                return AlertDialog(
                  scrollable: true,
                  content: StatefulBuilder(builder: (BuildContext context, StateSetter setState) {
                    return Column(mainAxisSize: MainAxisSize.min, children: [
                      TextFormField(
                        maxLengthEnforcement: MaxLengthEnforcement.enforced,
                        maxLength: 20,
                        controller: _controller,
                        decoration: InputDecoration(
                          icon: const Icon(Icons.people),
                          labelText: AppLocalizations.of(context)!.chatroomName,
                        ),
                      ),
                      ListTile(
                        title: Text(AppLocalizations.of(context)!.public),
                        leading: Radio<RoomType>(
                          value: RoomType.public,
                          groupValue: _roomType,
                          onChanged: (RoomType? value) {
                            setState(() {
                              _roomType = value;
                            });
                          },
                        ),
                      ),
                      ListTile(
                        title: Text(AppLocalizations.of(context)!.private),
                        leading: Radio<RoomType>(
                          value: RoomType.private,
                          groupValue: _roomType,
                          onChanged: (RoomType? value) {
                            setState(() {
                              _roomType = value;
                            });
                          },
                        ),
                      ),
                      ListTile(
                        title: Text(AppLocalizations.of(context)!.georestricted),
                        leading: Radio<RoomType>(
                          value: RoomType.georestricted,
                          groupValue: _roomType,
                          onChanged: (RoomType? value) {
                            setState(() {
                              _roomType = value;
                            });
                          },
                        ),
                      ),
                      ElevatedButton(
                          child: Text(AppLocalizations.of(context)!.createChatroom),
                          onPressed: () {
                            if (_controller.text.isNotEmpty) {
                              if (_roomType == RoomType.public || _roomType == RoomType.private) {
                                _createChatroom();
                                Navigator.pop(context);
                              } else {
                                Navigator.pushNamed(context, '/geo', arguments: _controller.text);
                              }
                              _controller.clear();
                            }
                          })
                    ]);
                  }),
                );
              },
            ).then((_) {
              _controller.clear();
            });
          },
          child: const Icon(Icons.add),
        ));
  }

  _createChatroom() {
    FirestoreHelper.createChatroom(_controller.text, _getRoomType(), username);
  }

  _getRoomType() {
    switch (_roomType) {
      case RoomType.public:
        return "public";
      case RoomType.private:
        return "private";
      case RoomType.georestricted:
        return "georestricted";
      default:
        return "";
    }
  }

  _getLastMessageTimestamp(timestamp) {
    var dateTimeNow = DateTime.now();

    if (DateTime(timestamp.year, timestamp.month, timestamp.day)
            .difference(DateTime(dateTimeNow.year, dateTimeNow.month, dateTimeNow.day))
            .inDays !=
        0) {
      return Text(DateFormat("dd/MM/yy").format(timestamp));
    }
    return Text(DateFormat("hh:mm").format(timestamp));
  }
}
