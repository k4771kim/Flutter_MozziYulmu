import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_admob/firebase_admob.dart';
import 'package:http/http.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'constants/constants.dart';

void main() => runApp(MozziYulmu());
// const String testDevice = 'kGADSimulatorID';

var appId = Platform.isIOS ? appIdIOS : appIdAndroid;
var bannerId = Platform.isIOS ? bannerIdIOS : bannerIdAndroid;

class MozziYulmu extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return new MozziYulmuState();
  }
}

class MozziYulmuState extends State<MozziYulmu> {
  var mozziYulmuImage = [];
  var clapOpacity = 0.0;
  var currentPage = 0;
  final Firestore catsFirestore = Firestore.instance;

  addVotes(type) {
    var name = type == 'm' ? 'Mozzi' : type == 'y' ? 'Yulmu' : null;

    if (name != null) {
      Firestore.instance.runTransaction((Transaction tx) async {
        DocumentSnapshot postSnapshot =
            await tx.get(catsFirestore.document('Cats/' + name));
        if (postSnapshot.exists) {
          await tx.update(catsFirestore.document('Cats/' + name),
              <String, dynamic>{'votes': postSnapshot.data['votes'] + 1});
        }
      });
    }
  }

  _fetchData() async {
    print(SERVER_URL);
    final response = await get(SERVER_URL);
    if (response.statusCode == 200) {
      final map = json.decode(response.body);
      final jsonResult = map["result"];
      setState(() {
        this.mozziYulmuImage = jsonResult;
      });
    } else {
      throw Exception('Failed to load post');
    }
  }

  _onHandleEventClap() {
    setState(() {
      this.clapOpacity = 1.0;
    });
    new Timer(Duration(seconds: 1), () {
      this.setState(() {
        this.clapOpacity = 0.0;
      });
    });
    addVotes(mozziYulmuImage[currentPage][10]);
  }

  BannerAd mozziYulmuBanner;

  BannerAd createBannerAd() {
    final MobileAdTargetingInfo targetingInfo = new MobileAdTargetingInfo(
      // testDevices: testDevice != null ? <String>[testDevice] : null,
      keywords: <String>['foo', 'bar'],
      contentUrl: 'http://foo.com/bar.html',
      birthday: new DateTime.now(),
      childDirected: true,
      gender: MobileAdGender.male,
    );
    return new BannerAd(
      // Replace the testAdUnitId with an ad unit id from the AdMob dash.
      // https://developers.google.com/admob/android/test-ads
      // https://developers.google.com/admob/ios/test-ads
      // adUnitId: 'ca-app-pub-3940256099942544/2934735716',
      // adUnitId: 'ca-app-pub-3940256099942544/6300978111',
      adUnitId: bannerId,
      size: AdSize.leaderboard,
      // targetingInfo: targetingInfo,
      // targetingInfo: targetingInfo,
      listener: (MobileAdEvent event) {},
    );
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    FirebaseAdMob.instance.initialize(appId: appId);
    //   MobileAdTargetingInfo targetingInfo = new MobileAdTargetingInfo(
    // keywords: <String>['mozzi', 'yulmu'],
    // contentUrl: 'https://flutter.io',
    // birthday: new DateTime.now(),
    // childDirected: false,
    // designedForFamilies: false,
    // gender: MobileAdGender.male, // or MobileAdGender.female, MobileAdGender.unknown
    // testDevices: <String>[], // Android emulators are considered test devices
// );

    mozziYulmuBanner = createBannerAd()
      ..load()
      ..show(
        // Positions the banner ad 60 pixels from the bottom of the screen
        // Banner Position
        anchorType: AnchorType.bottom,
      );
    _fetchData();
  }

  createChild(image) {
    return mozziYulmuImage.map((image) {
      return new Image.network(SERVER_URL + image);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
        home: new Scaffold(
            appBar: new AppBar(title: new Text('Mozzi Yulmu Votes')),
            body: new Column(children: <Widget>[
              new Flexible(
                child: new Container(
                    child: new Stack(children: <Widget>[
                  PageView(
                      children: createChild(mozziYulmuImage),
                      onPageChanged: (page) {
                        setState(() {
                          this.currentPage = page;
                        });
                      }),
                  new Opacity(
                    opacity: clapOpacity,
                    child: new Center(
                      child: Image.asset(
                        'assets/clap.png',
                        color: Colors.white,
                      ),
                    ),
                  ),
                  new GestureDetector(
                    onDoubleTap: () {
                      _onHandleEventClap();
                    },
                  )
                ])),
              ),
              new Flexible(child: _buildVotesCount()),
            ])));
  }
}

Widget _buildVotesCount() {
  return new StreamBuilder(
      stream: Firestore.instance.collection('Cats').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Text('Loading...');
        return new ListView.builder(
          itemCount: snapshot.data.documents.length,
          padding: const EdgeInsets.only(top: 10.0),
          itemExtent: 55.0,
          itemBuilder: (context, index) =>
              _buildListItem(context, snapshot.data.documents[index]),
        );
      });
}

Widget _buildListItem(BuildContext context, DocumentSnapshot document) {
  return new ListTile(
    key: new ValueKey(document.documentID),
    title: new Container(
      decoration: new BoxDecoration(
        border: new Border.all(color: const Color(0x80000000)),
        borderRadius: new BorderRadius.circular(5.0),
      ),
      padding: const EdgeInsets.all(10.0),
      child: new Row(
        children: <Widget>[
          new Expanded(
            child: new Text(document['name']),
          ),
          new Text(
            document['votes'].toString(),
          ),
        ],
      ),
    ),
    onTap: () => Firestore.instance.runTransaction((transaction) async {
          DocumentSnapshot freshSnap =
              await transaction.get(document.reference);
          await transaction
              .update(freshSnap.reference, {'votes': freshSnap['votes'] + 1});
        }),
  );
}
