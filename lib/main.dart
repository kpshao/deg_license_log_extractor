import 'dart:io';
import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const Scaffold(
          body: FormApp(),
        ));
  }
}

class Record {
  final String computerName;
  final String ip;
  final DateTime loginTime;
  final DateTime logoutTime;
  final String userName;

  Record(
      {required this.computerName,
      required this.ip,
      required this.loginTime,
      required this.logoutTime,
      required this.userName});

  factory Record.fromJson(Map<String, dynamic> json) {
    var loginTime = DateTime.parse(json['loginTime']! + 'Z');
    var logoutTime = json['logoutTime'] == null || json['logoutTime'].isEmpty
        ? DateTime.now()
        : DateTime.parse(json['logoutTime'] + 'Z');

    return Record(
        computerName: json['computerName']!,
        ip: json['computerName']!,
        loginTime: loginTime.toLocal(),
        logoutTime: logoutTime.toLocal(),
        userName: json['userName']);
  }

  Map toJson() => {
        'computerName': computerName,
        'ip': ip,
        'loginTime': DateFormat('yyyy-MM-dd HH:mm:ss').format(loginTime),
        'logoutTime': DateFormat('yyyy-MM-dd HH:mm:ss').format(logoutTime),
        'userName': userName
      };
}

class StatisticsResponse {
  final int status;
  final List<Record> data;

  StatisticsResponse(this.status, this.data);

  factory StatisticsResponse.fromJson(Map<String, dynamic> json) {
    var list = json['data'] as List;
    List<Record> records = list.map((e) => Record.fromJson(e)).toList();
    return StatisticsResponse(json['status']!, records);
  }

  Map toJson() => {'status': status, 'data': data};
}

class FormApp extends StatefulWidget {
  const FormApp({super.key});

  @override
  State<FormApp> createState() => _FormAppState();
}

class TimeSeriesPoint {
  final DateTime time;
  final DateTime time1;
  final DateTime time2;
  final int count;

  TimeSeriesPoint(this.time, this.time1, this.time2, this.count);
}

class _FormAppState extends State<FormApp> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  var _downloading = false;
  var _finished = false;
  var _showError = false;
  var _message = '';
  var _host = '';
  var _password = '';
  // List<Record> _logStatistics = [];

  List<TimeSeriesPoint> prepareChartData(List<Record> records) {
    DateTime start = DateTime.now();
    DateTime? end;

    for (Record r in records) {
      start = start.compareTo(r.loginTime) <= 0 ? start : r.loginTime;
      if (end == null) {
        end = r.logoutTime;
      } else {
        end = end.compareTo(r.logoutTime) >= 0 ? end : r.logoutTime;
      }
    }

    start = start.subtract(const Duration(minutes: 1));
    end = end!.add(const Duration(minutes: 1));
    var span =
        (end.millisecondsSinceEpoch - start.millisecondsSinceEpoch) / 500;

    var series = <TimeSeriesPoint>[];
    for (int i = 0; i < 500; i++) {
      var t1 = start.add(Duration(milliseconds: (i * span).toInt()));
      var t2 = start.add(Duration(milliseconds: ((i + 1) * span).toInt()));
      var count = 0;
      for (Record r in records) {
        var flag1 = t2.isBefore(r.loginTime);
        var flag2 = t1.isAfter(r.logoutTime);
        if (!(flag1 || flag2)) {
          count += 1;
        }
        // if (r.loginTime.isAfter(t1) && r.loginTime.isBefore(t2)) {
        //   count += 1;
        // } else if (r.logoutTime.isAfter(t1) && r.logoutTime.isBefore(t2)) {
        //   count += 1;
        // }
      }

      var cur =
          start.add(Duration(milliseconds: (i * span + span / 2).toInt()));
      series.add(TimeSeriesPoint(cur, t1, t2, count));
    }

    return series;
  }

  void _getLog() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory == null) {
      // User canceled the picker
      return;
    }

    setState(() {
      _downloading = true;
      _showError = false;
      _message = '';
      _finished = false;
    });

    try {
      var uri =
          '${_host}/rest/${_password}/statistics?product=DLYHW-PE&feature=degbasic';

      final resp = await http
          .get(Uri.parse(uri), headers: {"Accept": "application/json"});

      if (resp.statusCode == 200) {
        Map<String, dynamic> tt = jsonDecode(resp.body) as Map<String, dynamic>;
        if (tt['status'] == 0) {
          StatisticsResponse stat = StatisticsResponse.fromJson(tt);
          // _logStatistics = stat.data;

          var nowString =
              DateFormat('yyyy_MM_dd_HH_mm_ss').format(DateTime.now());
          _writeLog(stat.data, '${selectedDirectory}/log_${nowString}.csv');

          var timeTrend = prepareChartData(stat.data);
          _writeTimeTrend(
              timeTrend, '${selectedDirectory}/trend_${nowString}.csv');
          _message = 'Success!';
        } else {
          _showError = true;
          _message = 'Error[${tt['status']}]: ${tt['errMsg']}';
        }
      } else {
        _showError = true;
        _message = 'Error: http status ${resp.statusCode}';
      }
    } catch (e) {
      _showError = true;
      _message = 'Error: ${e}';
    } finally {
      setState(() {
        _finished = true;
        _downloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            TextFormField(
              decoration: const InputDecoration(
                hintText: 'Enter url of license server',
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter some text';
                } else if (!isValidUrl(value)) {
                  return 'Please enter valid url';
                }
                return null;
              },
              onChanged: (text) {
                _host = text;
              },
            ),
            const SizedBox(
              height: 10,
            ),
            TextFormField(
              decoration: const InputDecoration(
                hintText: 'Enter password',
              ),
              validator: (String? value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter some text';
                }
                return null;
              },
              onChanged: (text) {
                _password = text;
              },
            ),
            const SizedBox(
              height: 10,
            ),
            ElevatedButton(
              onPressed: _downloading
                  ? null
                  : () {
                      if (_formKey.currentState!.validate()) {
                        _getLog();
                      }
                    },
              child: const Text('Query'),
            ),
            const SizedBox(
              height: 10,
            ),
            Text(
              _finished ? _message : '',
              style: TextStyle(color: _showError ? Colors.red : Colors.green),
            ),
          ],
        ),
      ),
    );
  }

  void _writeLog(List<Record> records, String file) async {
    var logFile = File(file);
    var sink = logFile.openWrite();
    const converter = ListToCsvConverter();

    sink.write(converter.convert([
      ['computer_name', 'ip', 'user_name', 'login_time', 'logout_time']
    ]));
    sink.write('\n');

    var format = DateFormat('yyyy-MM-dd HH:mm:ss');

    for (var record in records) {
      final line = converter.convert([
        [
          record.computerName,
          record.ip,
          record.userName,
          format.format(record.loginTime),
          format.format(record.logoutTime)
        ]
      ]);
      sink.write(line);
      sink.write('\n');
    }

    await sink.flush();
    await sink.close();
  }

  void _writeTimeTrend(List<TimeSeriesPoint> points, String file) async {
    var trendFile = File(file);
    var sink = trendFile.openWrite();

    const converter = ListToCsvConverter();

    sink.write(converter.convert([
      ['time', 'time1', 'time2', 'count']
    ]));
    sink.write('\n');

    var format = DateFormat('yyyy-MM-dd HH:mm:ss');

    for (var p in points) {
      final line = converter.convert([
        [
          format.format(p.time),
          format.format(p.time1),
          format.format(p.time2),
          p.count
        ]
      ]);
      sink.write(line);
      sink.write('\n');
    }

    await sink.flush();
    await sink.close();
  }
}

bool isValidUrl(String value) {
  String pattern =
      r'(http|https)://[\w-]+(\.[\w-]+)+([\w.,@?^=%&amp;:/~+#-]*[\w@?^=%&amp;/~+#-])?';
  // r'[\w-]+(\.[\w-]+)+([\w.,@?^=%&amp;:/~+#-]*[\w@?^=%&amp;/~+#-])?';
  RegExp regExp = RegExp(pattern);

  return regExp.hasMatch(value);
}
