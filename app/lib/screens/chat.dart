import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_bubbles/chat_bubbles.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:conversationalist/services/location_helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutterfire_ui/firestore.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:maps_launcher/maps_launcher.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../services/firestore_helper.dart';

class Chat extends StatefulWidget {
  const Chat({Key? key}) : super(key: key);

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  late Query<Object?> _messagesQuery;
  late final username = Hive.box('box').get('username');
  final TextEditingController _controller = TextEditingController();
  Color color = Colors.grey;
  late DateTime? latestDateTime;
  bool canGetLocation = true;


  @override
  void initState() {
    super.initState();
    Timer.periodic(
      const Duration(seconds: 5),
          (timer) {
        canGetLocation = true;
      },
    );
  }

  getMessagesQuery(String docId) {
    _messagesQuery = FirestoreHelper.getMessagesQuery(docId);
    setState(() {});
  }

  String getLocationUrl(String lat, String lon) {
    return Uri(scheme: 'https', host: 'maps.googleapis.com', port: 443, path: '/maps/api/staticmap', queryParameters: {
      'center': '$lat, $lon',
      'zoom': '18',
      'size': '700x500',
      'maptype': 'roadmap',
      'key': dotenv.env['GOOGLE_MAPS_API_KEY']!,
      'markers': 'color:red|$lat,$lon'
    }).toString();
  }

  @override
  Widget build(BuildContext context) {
    Map<dynamic, dynamic> args = ModalRoute.of(context)!.settings.arguments as Map<dynamic, dynamic>;
    latestDateTime = Hive.box('box').get(args["docId"], defaultValue: null);
    final chatName = args["name"];
    getMessagesQuery(args["docId"]);
    return Scaffold(
        appBar: AppBar(
          title: Text(chatName),
          actions: [
            if (args["type"] == "private")
              FutureBuilder(
                future: FirestoreHelper.fetchLink(args["docId"]),
                builder: (BuildContext context, AsyncSnapshot snapshot) {
                  if (snapshot.hasData) {
                    return IconButton(
                        onPressed: () {
                          Share.share(snapshot.data);
                        },
                        icon: const Icon(Icons.link));
                  } else {
                    return Container();
                  }
                },
              ),
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (BuildContext dialogContext) {
                    return AlertDialog(
                      title: Text(AppLocalizations.of(context)!.leaveChatPrompt),
                      content: SingleChildScrollView(
                        child: ListBody(
                          children: <Widget>[
                            Text(AppLocalizations.of(context)!.rejoinLater),
                          ],
                        ),
                      ),
                      actions: <Widget>[
                        TextButton(
                          child:  Text(AppLocalizations.of(context)!.cancel),
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                          },
                        ),
                        TextButton(
                          child:  Text(AppLocalizations.of(context)!.yes),
                          onPressed: () {
                            FirestoreHelper.leaveChat(args["docId"], username);
                            Navigator.of(dialogContext).pop();
                            Navigator.of(context).pop();
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            )
          ],
        ),
        body: FutureBuilder(
              future: FirestoreHelper.getChatroomLocation(args["docId"], args["type"]),
              builder: (roomContext, roomSnapshot) {
                if (roomSnapshot.hasData) {

                  return Stack(
                    children: [
                      FirestoreListView<Map<String, dynamic>>(
                        padding: const EdgeInsets.only(bottom: 65),
                        query: _messagesQuery as Query<Map<String, dynamic>>,
                        reverse: true,
                        itemBuilder: (context, snapshot) {
                          Map<String, dynamic> data = snapshot.data();

                          Timestamp messageTimestamp = data["timestamp"];
                          DateTime messageDateTime = messageTimestamp.toDate();

                          if (latestDateTime == null || messageDateTime.isAfter(latestDateTime!)) {
                            latestDateTime = messageDateTime;
                            Hive.box('box').put(args["docId"], latestDateTime);
                            FirestoreHelper.setRead(args["docId"], username);
                          }

                          if (args["type"] == "georestricted" && canGetLocation == true) {
                            var chatroomData = roomSnapshot.data as Map<String, dynamic>;
                            _verifyLocation(context, chatroomData["pos"].latitude, chatroomData["pos"].longitude, chatroomData["radius"]);
                            canGetLocation = false;
                          }

                          bool isSender = data['from'] == username;
                          StatelessWidget widget;
                          return Column(
                            children: [
                              Row(
                                mainAxisAlignment: isSender ? MainAxisAlignment.end : MainAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(right: 10, left: 23, bottom: 8, top: 8),
                                    child: Text(data['from']),
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(right: 23, bottom: 8, top: 8),
                                    child: Text(DateFormat("hh:mm").format(data['timestamp'].toDate())),
                                  ),
                                ],
                              ),
                              if (data["imageUrl"] != null && data["imageUrl"] != "")
                                Row(mainAxisAlignment: isSender ? MainAxisAlignment.end : MainAxisAlignment.start, children: [
                                  Container(
                                    constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
                                    margin: const EdgeInsets.only(right: 10, left: 10, bottom: 8, top: 8),
                                    child: FutureBuilder(
                                      future: _getConnectivityResult(),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          if (snapshot.data == ConnectivityResult.wifi || snapshot.data == ConnectivityResult.none) {
                                            widget = _renderPicture(data["imageUrl"]);

                                          } else if (snapshot.data == ConnectivityResult.mobile) {
                                              if (!Hive.box('box').get('images', defaultValue: []).contains(data["imageUrl"])) {
                                                widget = IconButton(
                                                  icon: const Icon(Icons.download_rounded),
                                                  onPressed: () {
                                                    var images = Hive.box('box').get('images', defaultValue: []);
                                                    images.add(data["imageUrl"]);
                                                    Hive.box('box').put('images', images);
                                                    setState(() {});
                                                  },
                                                );
                                              } else {
                                                widget = _renderPicture(data["imageUrl"]);
                                              }
                                          } else {
                                            widget = Container();
                                          }
                                          return widget;
                                        }
                                        return Container();
                                      },
                                    ),
                                  )
                                ])
                              else if (data["lon"] != null && data["lon"] != "")
                                Row(
                                  mainAxisAlignment: isSender ? MainAxisAlignment.end : MainAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onLongPress: () {
                                        Share.share("${data["lat"]}, ${data["lon"]}");
                                      },
                                      onTap: () {
                                        MapsLauncher.launchCoordinates(double.parse(data["lat"]), double.parse(data["lon"]));
                                      },

                                      child: Container(
                                        constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
                                        margin: const EdgeInsets.only(right: 10, left: 10, bottom: 8, top: 8),
                                        child: CachedNetworkImage(
                                          imageUrl: getLocationUrl(data["lat"], data["lon"]),
                                          imageBuilder: (context, imageProvider) => Container(
                                            decoration: BoxDecoration(
                                            borderRadius: const BorderRadius.all(Radius.circular(15)),
                                              image: DecorationImage(
                                                  image: imageProvider, fit: BoxFit.cover),
                                            ),
                                          ),
                                          progressIndicatorBuilder: (context, url, downloadProgress) =>
                                              CircularProgressIndicator(value: downloadProgress.progress),
                                          errorWidget: (context, url, error) => const Icon(Icons.error),
                                        ),
                                      ),
                                    )
                                  ],
                                )
                              else if (data["fileUrl"] != null && data["fileUrl"] != "")
                                Row(
                                    mainAxisAlignment: isSender ? MainAxisAlignment.end : MainAxisAlignment.start,
                                    children: [
                                      GestureDetector(
                                        child: Container(
                                            constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200),
                                            margin: const EdgeInsets.only(right: 10, left: 10, bottom: 8, top: 8),
                                            child: ElevatedButton.icon(
                                              icon: const Icon(Icons.download_rounded),
                                              onPressed: () async {
                                                String filePath = await _downloadFile(data["fileUrl"], data["fileName"]);
                                                OpenFile.open(filePath);
                                              },
                                              label: Text(data["fileName"]),
                                            )
                                        ),
                                          onLongPress: () async {
                                            String filePath = await _downloadFile(data["fileUrl"], data["fileName"]);
                                            Share.shareFiles([filePath]);
                                          }
                                      )

                                    ]
                                )
                              else
                                GestureDetector(
                                  onLongPress: () { Share.share(data["content"]); },
                                  child: BubbleSpecialThree(
                                    text: data["content"],
                                    color: isSender ? Theme.of(context).colorScheme.secondary : const Color(0xFFA9B0B2),
                                    tail: true,
                                    isSender: isSender,
                                    textStyle: TextStyle(
                                      fontSize: 16,
                                      color: Theme.of(context).colorScheme.onSecondary,
                                    ),

                                  ),
                                )

                            ],
                          );
                        },
                      ),
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Container(
                          color: Theme.of(context).bottomAppBarColor,
                          padding: const EdgeInsets.only(left: 10, bottom: 10, top: 10),
                          height: 60,
                          width: double.infinity,
                          child: Row(
                            children: <Widget>[
                              GestureDetector(
                                onTap: () async {
                                  if (args["type"] == "georestricted") {
                                    var chatroomData = roomSnapshot.data as Map<String, dynamic>;
                                    bool result = await _verifyLocation(context, chatroomData["pos"].latitude, chatroomData["pos"].longitude, chatroomData["radius"]);
                                    if (result) return;
                                  }
                                  showModalBottomSheet(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return Container(
                                        height: 200,
                                        child: Center(
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              ElevatedButton(
                                                  onPressed: () async {
                                                    FilePickerResult? result = await FilePicker.platform.pickFiles(withData: true);
                                                    if (result != null) {
                                                      Uint8List? fileBytes = result.files.first.bytes;
                                                      String fileName = result.files.first.name;
                                                      FirestoreHelper.uploadFile(fileBytes!, fileName, username, args["docId"]);
                                                    }
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                      shape: const CircleBorder(), padding: const EdgeInsets.all(20), elevation: 0),
                                                  child: const Icon(Icons.file_copy)),
                                              const SizedBox(width: 20),
                                              ElevatedButton(
                                                  onPressed: () async {
                                                    var image = await ImagePicker().pickImage(source: ImageSource.camera);
                                                    if (image != null) {
                                                      await FirestoreHelper.sendImage(args["docId"], username, image.path);
                                                      setState((){});
                                                    }
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                      shape: const CircleBorder(), padding: const EdgeInsets.all(20), elevation: 0),
                                                  child: const Icon(Icons.camera_alt)),
                                              const SizedBox(width: 20),
                                              ElevatedButton(
                                                  onPressed: () {
                                                    Navigator.pushNamed(context, '/map', arguments: args["docId"]);
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                      shape: const CircleBorder(), padding: const EdgeInsets.all(20), elevation: 0),
                                                  child: const Icon(Icons.my_location)),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                                child: Container(
                                  height: 30,
                                  width: 30,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.secondary,
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    color: Theme.of(context).colorScheme.onSecondary,
                                    size: 20,
                                  ),
                                ),
                              ),
                              const SizedBox(
                                width: 15,
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _controller,
                                  onChanged: (value) {
                                    if (value.isNotEmpty) {
                                      setState(() {
                                        color = Theme.of(context).colorScheme.secondary;
                                      });
                                    } else {
                                      setState(() {
                                        color = Colors.grey;
                                      });
                                    }
                                  },
                                  decoration: InputDecoration(
                                    hintText: AppLocalizations.of(context)!.writeMessage,
                                    border: InputBorder.none,
                                    filled: true,
                                    enabled: true,
                                  ),
                                ),
                              ),
                              const SizedBox(
                                width: 15,
                              ),
                              FloatingActionButton(
                                onPressed: () async {
                                  if (args["type"] == "georestricted") {
                                    var chatroomData = roomSnapshot.data as Map<String, dynamic>;
                                    bool result = await _verifyLocation(context, chatroomData["pos"].latitude, chatroomData["pos"].longitude, chatroomData["radius"]);
                                    if (result) return;
                                  }

                                  if (_controller.text.isNotEmpty) {
                                    FirestoreHelper.addMessage(args["docId"], _controller.text, username);
                                    _controller.clear();
                                    setState(() {
                                      color = Colors.grey;
                                    });
                                  }
                                },
                                backgroundColor: color,
                                child: Icon(
                                  Icons.send,
                                  color: Theme.of(context).colorScheme.onSecondary,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                } else {
                  return Container();
                }
              })
        );
  }

  _getConnectivityResult() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult;
  }

  _downloadFile(String fileUrl, String fileName) async {
    final fileRef = FirebaseStorage.instance.refFromURL(fileUrl);

    final appDocDir = await getApplicationDocumentsDirectory();
    final directoryPath = "${appDocDir.path}/${fileRef.name}";
    final directory = Directory(directoryPath);
    final filePath = "${appDocDir.path}/${fileRef.name}/$fileName";

    if (!(await directory.exists())) {
      await directory.create();

      final file = File(filePath);
      await fileRef.writeToFile(file);
    }

    return filePath;
  }

  _renderPicture(String imageUrl) {
    return GestureDetector(
      onLongPress: () async {
        File image = await DefaultCacheManager().getSingleFile(imageUrl);
        Share.shareFiles([image.path]);
      },
      child: CachedNetworkImage(
        cacheManager: DefaultCacheManager(),
        imageUrl: imageUrl,
        progressIndicatorBuilder: (context, url, downloadProgress) =>
            CircularProgressIndicator(value: downloadProgress.progress),
        errorWidget: (context, url, error) => const Icon(Icons.error),
      ),
    );
  }

  _verifyLocation(context, roomLat, roomLon, radius) async {
    var position = await LocationHelper.getCurrentPosition();
    if (position != null) {
      bool isInRange = LocationHelper.userInRange(
          position.latitude,
          position.longitude,
          roomLat,
          roomLon,
          radius);
      if (!isInRange) {
        Navigator.pushReplacementNamed(context, '/home');
        return Future.value(true);
      }
    }
    return Future.value(false);
  }
}
