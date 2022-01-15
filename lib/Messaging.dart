import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dialogflow/dialogflow_v2.dart';

class MessagingClient {
  String nameID;

  Firestore get firestoreInstance {
    return Firestore.instance;
  }

  DocumentReference get db {
    firestoreInstance.collection("conversations").document(nameID);
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
            .document(nameID)
            .collection("allMessages")
            .getDocuments())
        .documents;
  }

  Stream<QuerySnapshot> get allMessagesStream {
    return firestoreInstance
        .collection("conversations")
        .document(nameID)
        .collection("allMessages")
        .snapshots();
  }

  void send({String text, bool isUser}) {
    firestoreInstance
        .collection("conversations")
        .document(nameID)
        .collection("allMessages")
        .document()
        .setData({
      "timestamp": Timestamp.now(),
      "message": text,
      "isUser": isUser
    }).then((value) => print("data sent"));
  }
}

List<Widget> messageBuilder(List<DocumentSnapshot> list) {
  list.sort((DocumentSnapshot a, DocumentSnapshot b) =>
      (a.data["timestamp"] as Timestamp)
          .compareTo(b.data["timestamp"] as Timestamp));
  return list
      .map((DocumentSnapshot e) => Message.fromSnapshot(e).toWidget())
      .toList();
}

StreamBuilder messageList() {
  var messagingClient = MessagingClient("Saad Mufti");
  return StreamBuilder(
      stream: messagingClient.allMessagesStream,
      builder: (BuildContext context, snapshot) {
        if (!snapshot.hasData) return LinearProgressIndicator();
        return Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: ListView(
              children: messageBuilder(
                  snapshot.data.documents as List<DocumentSnapshot>),
              shrinkWrap: true,
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
        ),
      ),
    );
  }

  Message({this.isUser, this.message, this.timestamp, this.id});

  static Message fromSnapshot(DocumentSnapshot snapshot) {
    return Message(
        id: snapshot.documentID,
        message: snapshot.data["message"],
        timestamp: snapshot.data["timestamp"],
        isUser: snapshot.data["isUser"]);
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

TextEditingController inputController =
    TextEditingController(text: "Say Something...");

void userSend(Dialogflow df, MessagingClient client) {
  if (inputController.text.isNotEmpty) {
    var text = inputController.text;
    client.send(text: text, isUser: true);
    inputController.clear();
    df
        .detectIntent(text)
        .then((value) => client.send(text: value.getMessage(), isUser: false));
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
                  child: EditableText(
                      backgroundCursorColor: Color.fromARGB(21, 32, 43, 1),
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
