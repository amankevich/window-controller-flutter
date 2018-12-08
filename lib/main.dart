import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

const String CONTROLLER = "192.168.1.180";

void main() => runApp(WindowController());

//{"status": "success", "up": "-1", "down": "-1"}
class Alarms {
  int upTime;
  int downTime;

  Alarms({this.upTime, this.downTime});

  String _getDisplayTime(int seconds) {
    int millis = seconds * 1000;
    final dateTime = DateTime.fromMillisecondsSinceEpoch(millis);
    return dateTime.hour.toString() + ":" + dateTime.minute.toString();
  }

  String getUpTime() {
    return _getDisplayTime(upTime);
  }

  String getDownTime() {
    return _getDisplayTime(downTime);
  }

  DateTime getDateTimeUp() {
    if (upTime > 0) {
      int millis = upTime * 1000;
      return DateTime.fromMillisecondsSinceEpoch(millis);
    } else {
      return null;
    }
  }

  int getAlarmSecondsSinceEpoch(int newHour, int newMinute) {
    DateTime now = DateTime.now();
    DateTime time = new DateTime(now.year, now.month, now.day, newHour, newMinute, 0, 0, 0);
    var millis = time.millisecondsSinceEpoch;
    if (millis < now.millisecondsSinceEpoch) {
      millis += 24 * 60 * 60 * 1000;
    }
    return millis ~/ 1000;
  }

  void setUpTime(int newHour, int newMinute) {
    upTime = getAlarmSecondsSinceEpoch(newHour, newMinute);
  }

  void setDownTime(int newHour, int newMinute) {
    downTime = getAlarmSecondsSinceEpoch(newHour, newMinute);
  }

  DateTime getDateTimeDown() {
    if (downTime > 0) {
      int millis = downTime * 1000;
      return DateTime.fromMillisecondsSinceEpoch(millis);
    } else {
      return null;
    }
  }

  factory Alarms.fromJson(Map<String, dynamic> json) {
    return Alarms(
        upTime: int.parse(json['up']), downTime: int.parse(json['down']));
  }
}

class WindowResponse {
  String status;
  String message;

  WindowResponse({this.status, this.message});

  factory WindowResponse.fromJson(Map<String, dynamic> json) {
    return WindowResponse(
        status: json['status'], message: json['msg']);
  }
}

Future<Alarms> fetchAlarmsFromController(Function onAlarmsReceived) async {
  final response = await http.get('http://$CONTROLLER/tasks');

  if (response.statusCode == 200) {
    // If the call to the server was successful, parse the JSON
    print(response.body);
    final alarms = Alarms.fromJson(json.decode(response.body));
    print('up: ' + alarms.getUpTime());
    print('down: ' + alarms.getDownTime());
    onAlarmsReceived(alarms);
    return alarms;
  } else {
    // If that call was not successful, throw an error.
    print('got error response: ' + response.body);
    throw Exception('Failed to load status');
  }
}

Future<bool> saveAlarmsToController(bool up, int time) async {
  String direction = up ? "up" : "down";
  final response = await http.get('http://$CONTROLLER/schedule?direction=$direction&time=$time');
  if (response.statusCode == 200) {
    // If the call to the server was successful, parse the JSON
    print(response.body);
    final windowResponse = WindowResponse.fromJson(json.decode(response.body));
    print('Message: ' + windowResponse.message);
    return true;
  } else {
    // If that call was not successful, throw an error.
    print('got error response: ' + response.body);
    throw Exception('Failed to save alarms');
  }
}

Future<bool> sendCommandToController(bool up) async {
  String direction = up ? "up" : "down";
  final response = await http.get('http://$CONTROLLER/$direction');
  if (response.statusCode == 200) {
    // If the call to the server was successful, parse the JSON
    print(response.body);
    final windowResponse = WindowResponse.fromJson(json.decode(response.body));
    print('Message: ' + windowResponse.message);
    return true;
  } else {
    // If that call was not successful, throw an error.
    print('got error response: ' + response.body);
    throw Exception('Failed to send direction command');
  }
}

class _WindowControllerState extends State<WindowController> {
  Alarms _alarms;

  void fetchAlarms() {
    fetchAlarmsFromController(onAlarmsReceived);
  }

  void onAlarmsReceived(Alarms alarms) {
    setState(() {
      _alarms = alarms;
    });
  }

  @override
  void initState() {
    super.initState();
    fetchAlarms();
  }

  @override
  Widget build(BuildContext context) {
    Text buildAlarmText(bool up) {
      if (up) {
        return Text(_alarms != null ? '${_alarms.getUpTime()}' : 'not set',
            style: TextStyle(fontWeight: FontWeight.bold));
      } else {
        return Text(_alarms != null ? '${_alarms.getDownTime()}' : 'not set',
            style: TextStyle(fontWeight: FontWeight.bold));
      }
    }

    Future sendWindowCommand(BuildContext context, bool up) async {
      final succeed = await sendCommandToController(up);
      String text;
      if (succeed) {
        if (up) {
          text = "Opening the window...";
        } else {
          text = "Closing the window...";
        }
      } else {
        text = "Error occured";
      }
      final snackBar = SnackBar(content: Text(text));
      Scaffold.of(context).showSnackBar(snackBar);
    }

    Future pickTime(BuildContext context, bool up) async {
      var dateTime;
      if (_alarms != null) {
        if (up) {
          if (_alarms.upTime > 0) {
            dateTime = _alarms.getDateTimeUp();
          }
        } else {
          if (_alarms.downTime > 0) {
            dateTime = _alarms.getDateTimeDown();
          }
        }
      }
      if (dateTime == null) {
        dateTime = DateTime.now();
      }
      var initialTime =
          TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
      TimeOfDay picked = await showTimePicker(context: context, initialTime: initialTime);
      if (picked != null) {
        setState(() {
          int time;
          if (up) {
            _alarms.setUpTime(picked.hour, picked.minute);
          } else {
            _alarms.setDownTime(picked.hour, picked.minute);
          }
        });
        int time = _alarms.getAlarmSecondsSinceEpoch(picked.hour, picked.minute);
        final saved = await saveAlarmsToController(up, time);
        final snackBar = SnackBar(content: Text(saved ? 'Alarm was saved' : "Error occured"));
        Scaffold.of(context).showSnackBar(snackBar);
      }
    }

    Row buildAlarmRow(bool up) {
      return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(up ? 'Up time: ' : 'Down time:'),
        buildAlarmText(up),
        Builder(
            builder: (context) => RaisedButton(
                child: Text('Set'), onPressed: () => pickTime(context, up)))
      ]);
    }

    return MaterialApp(
      title: 'Window remote',
      home: Scaffold(
        appBar: AppBar(
          title: Text('Window remote'),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: () {
                fetchAlarms();
              },
            )
          ],
        ),
        body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  buildAlarmRow(true),
                  buildAlarmRow(false),
                  Container(
                    padding: EdgeInsets.only(top: 32),
                    child: Column(
                      children: <Widget>[
                        Text('Remote Control', style: TextStyle(fontWeight: FontWeight.bold)),
                        Builder(builder: (context) => Column(
                            children: [
                              SizedBox(
                                width: 200,
                                child: RaisedButton(
                                    child: Text('Up (Open)'), onPressed: () => sendWindowCommand(context, true)),
                              ),
                              SizedBox(
                                width: 200,
                                child: RaisedButton(
                                    child: Text('Down (Close)'), onPressed: () => sendWindowCommand(context, false)),
                              )
                            ]
                        )),
                      ],
                    ),
                  ),
                ]
            )
        ),
      ),
    );
  }
}

class WindowController extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _WindowControllerState();
}
