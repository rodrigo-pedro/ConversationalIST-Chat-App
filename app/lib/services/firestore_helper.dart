import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter_platform_interface/src/types/location.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

class FirestoreHelper {
  //check if username exists
  static Future<bool> checkIfUsernameExists(String username) async {
    var doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(username)
        .get();
    return doc.exists;
  }

  //add username
  static Future<void> addUsername(String username, String uid) async {
    await FirebaseFirestore.instance
        .collection("users")
        .doc(username)
        .set({'uid': uid});
  }

  //get username by uid
  static Future<String> getUsernameByUid(String uid) async {
    var doc = await FirebaseFirestore.instance
        .collection("users")
        .where("uid", isEqualTo: uid)
        .get();
    return doc.docs[0].id;
  }

  //get chatrooms
  static Query getChatroomsByUsername(String username) {
    return FirebaseFirestore.instance
        .collection("chatrooms")
        .where("users", arrayContains: username)
        .orderBy("lastMessageTimestamp", descending: true);
  }

  static Future<QuerySnapshot<Map<String, dynamic>>> getFirstMessages(
      String docId) {
    return FirebaseFirestore.instance
        .collection("chatrooms/$docId/messages")
        .orderBy("timestamp", descending: true)
        .limit(10)
        .get();
  }

  static Query getPublicChatrooms() {
    return FirebaseFirestore.instance
        .collection("chatrooms")
        .where("type", whereIn: ["public", "georestricted"]);
  }

  //get messages
  static Query getMessagesQuery(String docId) {
    return FirebaseFirestore.instance
        .collection("chatrooms/$docId/messages")
        .orderBy("timestamp", descending: true);
  }

  static buildLink(String name, String chatroomId) async {
    final dynamicLinkParams = DynamicLinkParameters(
      link: Uri.parse(
          "https://www.conversationalist.com?chatroomId=$chatroomId&chatroomName=$name"),
      uriPrefix: "https://conversationalist.page.link",
      androidParameters: const AndroidParameters(
          packageName: "com.ist.conversationalist.conversationalist"),
    );
    var dynLink = await FirebaseDynamicLinks.instance.buildShortLink(
        dynamicLinkParams,
        shortLinkType: ShortDynamicLinkType.unguessable);
    return dynLink.shortUrl.toString();
  }

  static fetchLink(String chatroomId) async {
    var doc = await FirebaseFirestore.instance
        .collection("chatrooms")
        .doc(chatroomId)
        .get();
    return doc.get("shareLink");
  }

  static createChatroom(String name, String type, String myself) async {
    Map<String, dynamic> chatroom = <String, dynamic>{
      "name": name,
      "type": type,
      "lastMessage": "",
      "lastMessageTimestamp": Timestamp.now(),
      "users": [myself],
      "readLastMessage": []
    };

    var docRef =
        await FirebaseFirestore.instance.collection("chatrooms").add(chatroom);

    if (type == "private") {
      dynamic link = await buildLink(name, docRef.id);
      await docRef.update({"shareLink": link});
    }
  }

  static createGeorestrictedChatroom(
      String name, String myself, LatLng position, double radius) async {
    final chatroom = <String, dynamic>{
      "name": name,
      "type": 'georestricted',
      "lastMessage": "",
      "lastMessageTimestamp": Timestamp.now(),
      "users": [myself],
      "lat": position.latitude.toString(),
      "lon": position.longitude.toString(),
      "radius": radius,
      "readLastMessage": []
    };

    await FirebaseFirestore.instance.collection("chatrooms").add(chatroom);
  }

  static addMessage(String docId, String message, String myself) async {
    final messageData = <String, dynamic>{
      "from": myself,
      "content": message,
      "timestamp": Timestamp.now()
    };

    await FirebaseFirestore.instance
        .collection("chatrooms/$docId/messages")
        .add(messageData);
  }

  static leaveChat(String docId, String myself) async {
    await FirebaseFirestore.instance.collection("chatrooms").doc(docId).update({
      "users": FieldValue.arrayRemove([myself])
    });
  }

  static joinChatroom(String docId, String username) {
    FirebaseFirestore.instance.collection("chatrooms").doc(docId).update({
      "users": FieldValue.arrayUnion([username])
    });
  }

  static sendImage(String docId, String username, String imagePath) async {
    File image = File(imagePath);
    final storageRef =
        FirebaseStorage.instance.ref().child(const Uuid().v4());
    String downloadUrl = "";
    try {
      TaskSnapshot task = await storageRef.putFile(image);
      downloadUrl = await task.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      print(e.message);
    }

    final messageData = <String, dynamic>{
      "from": username,
      "imageUrl": downloadUrl,
      "timestamp": Timestamp.now(),
      "content": ""
    };

    await FirebaseFirestore.instance
        .collection("chatrooms/$docId/messages")
        .add(messageData);

    var images = Hive.box('box').get('images', defaultValue: []);
    images.add(downloadUrl);
    await Hive.box('box').put('images', images);
    return Future.value(true);
  }

  static void sendLocation(
      String docId, String username, LatLng position) async {
    final messageData = <String, dynamic>{
      "from": username,
      "content": "",
      "timestamp": Timestamp.now(),
      "lat": position.latitude.toString(),
      "lon": position.longitude.toString()
    };

    await FirebaseFirestore.instance
        .collection("chatrooms/$docId/messages")
        .add(messageData);
  }

  static getChatroomLocation(String docId, String type) async {
    if (type != "georestricted") return true;

    var doc = await FirebaseFirestore.instance
        .collection("chatrooms")
        .doc(docId)
        .get();
    return {
      "pos": LatLng(double.parse(doc.get("lat")), double.parse(doc.get("lon"))),
      "radius": doc["radius"]
    };
  }

  static addFcmToken(String uid) async {
    var fcmToken = await FirebaseMessaging.instance.getToken();

    String username = await FirestoreHelper.getUsernameByUid(uid);

    await FirebaseFirestore.instance
        .collection("users")
        .doc(username)
        .update({"fcmToken": fcmToken});
  }

  static void clearFcmToken(String uid) async {
    String username = await FirestoreHelper.getUsernameByUid(uid);
    await FirebaseFirestore.instance
        .collection("users")
        .doc(username)
        .update({"fcmToken": ""});
  }

  static checkUserInChatroom(String chatroomId, String username) async {
    var doc = await FirebaseFirestore.instance
        .collection("chatrooms")
        .doc(chatroomId)
        .get();
    return doc.get("users").contains(username);
  }

  static void uploadFile(Uint8List fileBytes, String fileName, String username, String docId) async {
    TaskSnapshot task = await FirebaseStorage.instance.ref(const Uuid().v4()).putData(fileBytes);

    final messageData = <String, dynamic>{
      "from": username,
      "fileUrl": await task.ref.getDownloadURL(),
      "fileName": fileName,
      "timestamp": Timestamp.now(),
      "content": ""
    };

    await FirebaseFirestore.instance
        .collection("chatrooms/$docId/messages")
        .add(messageData);
  }

  static checkIfRead(String chatroomId, String username) async {
    var doc = await FirebaseFirestore.instance
        .collection("chatrooms")
        .doc(chatroomId)
        .get();
    return doc.get("readLastMessage").contains(username);
  }

  static setRead(String chatroomId, String username) async {
    var doc = await FirebaseFirestore.instance
        .collection("chatrooms")
        .doc(chatroomId)
        .get();
    var readLastMessage = doc.get("readLastMessage");

    if (readLastMessage.contains(username)) {
      return;
    }

    await FirebaseFirestore.instance
        .collection("chatrooms")
        .doc(chatroomId)
        .update({"readLastMessage": FieldValue.arrayUnion([username])});
  }

}
