import 'dart:convert';
import 'package:intl/intl.dart';

class Response {
  final int status;
  final List<Event> data;

  Response(this.status, this.data);

  factory Response.fromJson(Map<String, dynamic> json) {
    var list = json['data'] as List;
    List<Event> events = list.map((e) => Event.fromJson(e)).toList();
    return Response(json['status']!, events);
  }
}

class Event {
  final String featureName;
  final String loginTime;
  final String logoutTime;

  Event(this.featureName, this.loginTime, this.logoutTime);

  Event.fromJson(Map<String, dynamic> json)
      : featureName = json['featureName']!,
        loginTime = json['loginTime']!,
        logoutTime = json['logoutTime'] ??
            DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()) {}
}

void main() {
  var jsonString = r'''
  {
    "data": [
      {
        "featureName": "degbasic",
        "featureVer": "",
        "loginTime": "2023-12-01 09:36:19"
      }
    ],
    "status": 0
  }
  ''';

  Response resp = Response.fromJson(json.decode(jsonString));
  print(resp.data[0].featureName);
  print(resp.data[0].logoutTime);
  print(resp.data[0].loginTime);
}
