import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dialogflow/dialogflow_v2.dart';
import 'package:auto_size_text/auto_size_text.dart';

final ScrollController _controller = ScrollController();

void _scrollDown() {
  _controller.animateTo(
      _controller.position.maxScrollExtent + 100,
      curve: Curves.easeOut,
      duration: const Duration(milliseconds: 500)
    );
}

class MessagingClient {
  String nameID;

  FirebaseFirestore get firestoreInstance {
    return FirebaseFirestore.instance;
  }

  DocumentReference get db {
    firestoreInstance.collection("conversations").doc(nameID);
  }

  MessagingClient(String name) {
    this.nameID = name;
  }

/*  Future<List<DocumentSnapshot>> get userMessages async {
    (await db.collection("User").getDocuments()).documents;
  }

  Future<List<DocumentSnapshot>> get botMessages async {
    (await db.collection("Bot").getDocuments()).documents;
  }*/

/*  Future<List<DocumentSnapshot>> get allMessages async {
    var combined = (await userMessages) + (await botMessages);
    combined.sort((a, b) => (a.data["Timestamp"] as Timestamp)
        .compareTo(b.data["Timestamp"] as Timestamp));
    return combined;
  }*/
  Future<List<DocumentSnapshot>> get messages async {
    return (await firestoreInstance
            .collection("conversations")
            .doc(nameID)
            .collection("allMessages")
            .get())
        .docs;
  }

  Stream<QuerySnapshot> get allMessagesStream {
    return firestoreInstance
        .collection("conversations")
        .doc(nameID)
        .collection("allMessages")
        .snapshots();
  }

  void send({String text, bool isUser}) {
    firestoreInstance
        .collection("conversations")
        .doc(nameID)
        .collection("allMessages")
        .doc()
        .set({
      "timestamp": Timestamp.now(),
      "message": text,
      "isUser": isUser
    }).then((value) => print("data sent"));
  }
}

List<Widget> messageBuilder(List<DocumentSnapshot> list) {
  list.sort((DocumentSnapshot a, DocumentSnapshot b) =>
      (a["timestamp"] as Timestamp).compareTo(b["timestamp"] as Timestamp));
  return list
      .map((DocumentSnapshot e) => Message.fromSnapshot(e).toWidget())
      .toList();
}

StreamBuilder messageList(MessagingClient messagingClient) {
  return StreamBuilder(
      stream: messagingClient.allMessagesStream,
      builder: (BuildContext context, snapshot) {
        if (!snapshot.hasData) return LinearProgressIndicator();
        if(_controller.hasClients) {
          _scrollDown();
        }
        return Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: ListView(
              children:
                  messageBuilder(snapshot.data.docs as List<DocumentSnapshot>),
              shrinkWrap: true,
              controller: _controller,
            ));
      });
}

class Message {
  bool isUser;
  String message;
  Timestamp timestamp;
  String id;

  Card get card {
    return Card(
        color: this.isUser ? Color(0xffC4E1FB) : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        child: Padding(
          padding: EdgeInsets.all(18),
          child: Text(
            this.message,
            style: TextStyle(fontSize: 17),
            overflow: TextOverflow.ellipsis,
          ),
        ));
  }

  Message({this.isUser, this.message, this.timestamp, this.id});

  static Message fromSnapshot(DocumentSnapshot snapshot) {
    return Message(
        id: snapshot.id,
        message: snapshot["message"],
        // message: snapshot.data["message"],
        timestamp: snapshot["timestamp"],
        isUser: snapshot["isUser"]);
  }

  Row toWidget() {
    if (this.isUser) {
      return Row(
        children: [
          Spacer(),
          card,
        ],
      );
    } else {
      return Row(
        children: [
          card,
          Spacer(),
        ],
      );
    }
  }
}

TextEditingController inputController = TextEditingController();

void userSend(Dialogflow df, MessagingClient client) {
  if (inputController.text.isNotEmpty) {
    var text = inputController.text;
    client.send(text: text, isUser: true);
    inputController.clear();
    df.detectIntent(text).then((value) {
      client.send(text: value.getMessage(), isUser: false);
      print("Sent??");
    });
  }
}

Widget bottomMessageBar(
    BuildContext context, MessagingClient client, Dialogflow df) {
  return Container(
      color: Color(0xffFFFFFF),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
              child: Padding(
                  padding: EdgeInsets.all(20),
                  child: TextField(
                      // backgroundCursorColor: Color.fromARGB(21, 32, 43, 1),
                      decoration: InputDecoration(hintText: "Say something..."),
                      focusNode: FocusNode(),
                      cursorColor: Color.fromARGB(21, 32, 43, 1),
                      controller: inputController,
                      style: Theme.of(context)
                          .textTheme
                          .bodyText2
                          .apply(fontSizeFactor: 1.4),
                      onSubmitted: (text) {
                        userSend(df, client);
                      }))),
          Padding(
              padding: EdgeInsets.all(20),
              child: IconButton(
                icon: Icon(
                  Icons.send,
                  size: 35,
                ),
                onPressed: () {
                  userSend(df, client);
                },
              )),
        ],
      ));
}
