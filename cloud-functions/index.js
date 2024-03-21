/* eslint-disable indent */
/* eslint-disable max-len */
const functions = require("firebase-functions");

const admin = require("firebase-admin");
admin.initializeApp(functions.config().firebase);

// Create and Deploy Your First Cloud Functions
// https://firebase.google.com/docs/functions/write-firebase-functions

exports.pushNotification = functions.region("europe-west1")
    .firestore
    .document("chatrooms/{chatroomId}/messages/{messageId}")
    .onCreate((change, context) => {
        const message = change.data();

        // atualizar last message
        const chatroomRef = admin.firestore().doc(`chatrooms/${context.params.chatroomId}`);

        // apagar toda a gente dos reads
        chatroomRef.update({
            readLastMessage: [message.from],
        });

        if (message.content != null && message.content.length > 0) {
            chatroomRef.update({
                lastMessage: message.content,
                lastMessageTimestamp: message.timestamp,
            });
        } else if (message.lat != null) {
            chatroomRef.update({
                lastMessage: "\uD83C\uDF0D",
                lastMessageTimestamp: message.timestamp,
            });
        } else if (message.imageUrl != null) {
            chatroomRef.update({
                lastMessage: "\uD83D\uDCF8",
                lastMessageTimestamp: message.timestamp,
            });
        } else if (message.fileUrl != null) {
            chatroomRef.update({
                lastMessage: "\uD83D\uDCC4",
                lastMessageTimestamp: message.timestamp,
            });
        }


        let payload;

        admin
            .firestore()
            .collection("chatrooms")
            .doc(context.params.chatroomId)
            .get()
            .then((doc) => {
                // ir buscar tokens
                doc.data().users.forEach((user) => {
                    if (user !== message.from) {
                        admin
                            .firestore()
                            .collection("users")
                            .doc(user)
                            .get()
                            .then((userData) => {
                                if (userData.data().fcmToken != "") {
                                    payload = {};

                                    // mensagens de texto
                                    if (message.content && message.content != "") {
                                        // for every token, send a notification
                                        payload = {
                                            token: userData.data().fcmToken,
                                            data: {
                                                title: message.from,
                                                body: message.content,
                                                chatroomId: context.params.chatroomId,
                                                chatroomName: doc.data().name,
                                                type: doc.data().type,
                                            },
                                            android: {
                                                priority: "high",
                                            },
                                        };
                                    } else if (message.imageUrl) { // mensagens de imagem
                                        payload = {
                                            token: userData.data().fcmToken,
                                            android: {
                                                priority: "high",
                                            },
                                            data: {
                                                title: message.from,
                                                body: "\uD83D\uDCF8",
                                                imageUrl: message.imageUrl,
                                                chatroomId: context.params.chatroomId,
                                                chatroomName: doc.data().name,
                                                type: doc.data().type,
                                            },
                                        };
                                    } else if (message.lat) { // mensagens de localização
                                        payload = {
                                            token: userData.data().fcmToken,
                                            android: {
                                                priority: "high",
                                            },
                                            data: {
                                                title: message.from,
                                                body: "\uD83C\uDF0D",
                                                chatroomId: context.params.chatroomId,
                                                chatroomName: doc.data().name,
                                                type: doc.data().type,
                                            },
                                        };
                                    } else if (message.fileUrl) {
                                        payload = {
                                            token: userData.data().fcmToken,
                                            android: {
                                                priority: "high",
                                            },
                                            data: {
                                                title: message.from,
                                                body: "\uD83D\uDCC4",
                                                chatroomId: context.params.chatroomId,
                                                chatroomName: doc.data().name,
                                                type: doc.data().type,
                                            },
                                        };
                                    }

                                    // see if chatroom is of type georestricted
                                    if (doc.data().type === "georestricted") {
                                        payload.data.chatroomLat = String(doc.data().lat);
                                        payload.data.chatroomLon = String(doc.data().lon);
                                        payload.data.chatroomRadius = String(doc.data().radius);
                                    } else {
                                        payload.notification = {
                                            title: message.from,
                                            body: message.content,
                                        };
                                    }

                                    admin
                                    .messaging()
                                    .send(payload)
                                    .then((response) => {
                                        // Response is a message ID string.
                                        console.log("Successfully sent message:", response);
                                        return {success: true};
                                    })
                                    .catch((error) => {
                                        console.log(error);
                                        return {error: error.code};
                                    });
                                }
                            });
                    }
                });
            })
            .catch((error) => {
                console.log(error);
            });

        // mensagem de texto
        return context;
    });
