import 'package:flutter/material.dart';
import 'ble_manager.dart';

class ImmobiliserPage extends StatefulWidget {
  final BLEManager bleManager;

  const ImmobiliserPage({Key? key, required this.bleManager}) : super(key: key);

  @override
  _ImmobiliserPageState createState() => _ImmobiliserPageState();
}

class _ImmobiliserPageState extends State<ImmobiliserPage> {
  final TextEditingController _controller = TextEditingController();
  int _newImmobiliserCode = 0;

  // Function to show an error dialog
  void _showErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(errorMessage),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Immobiliser'),
      ),
      body: Column(
        children: [
          // Top card to display current immobiliser code
          SizedBox(
            width: double.infinity,
            child: Card(
              margin: const EdgeInsets.all(10),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: StreamBuilder<int>(
                  stream: widget.bleManager.immobiliserStream,
                  initialData: widget.bleManager.latestImmobiliserCode,
                  builder: (context, snapshot) {
                    String text = snapshot.data! == 0
                        ? 'No data yet'
                        : snapshot.data!.toString();
                    TextStyle? style = snapshot.data! == 0
                        ? TextStyle(fontSize: 16)
                        : TextStyle(fontSize: 32, fontWeight: FontWeight.bold);
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Current Immobiliser Code',
                          style: TextStyle(fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 10),
                        Text(
                          text,
                          style: style,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),

          // Card with numeric input box for entering a new immobiliser code
          SizedBox(
            width: double.infinity,
            child: Card(
              margin: const EdgeInsets.all(10),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Write Immobiliser Code',
                      style: TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _controller,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'New Code',
                      ),
                      onChanged: (value) {
                        // Update the immobiliser code as the user types
                        setState(() {
                          _newImmobiliserCode = int.tryParse(value) ?? 0;
                        });
                      },
                    ),
                    SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () {
                        // Write the new immobiliser code
                        widget.bleManager
                            .writeNewImmobiliserCode(_newImmobiliserCode);

                        // Clear the input box
                        _controller.clear();

                        // Remove the focus to hide the keyboard
                        FocusScope.of(context).unfocus();
                      },
                      child: Text('Write'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // New bottom box for reading immobiliser code from 1984
          SizedBox(
            width: double.infinity,
            child: Card(
              margin: const EdgeInsets.all(10),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Read Immobiliser Code from 1984',
                      style: TextStyle(fontSize: 18),
                    ),
                    SizedBox(height: 10),
                    StreamBuilder<int>(
                      stream: widget.bleManager.c1984CodeStream,
                      initialData: -100000,
                      builder: (context, snapshot) {
                        if (snapshot.data! == -100000) {
                          return SizedBox.shrink();
                        }
                        if (snapshot.data! == -100002) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            widget.bleManager.reset1984ImmobiliserCodeRead();
                            _showErrorDialog(
                                "1984 already mobilised. Power cycle it and try again.");
                          });
                          return SizedBox.shrink();
                        }
                        if (snapshot.data! == -100003) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            widget.bleManager.reset1984ImmobiliserCodeRead();
                            _showErrorDialog("Code not detected.");
                          });
                          return SizedBox.shrink();
                        }
                        if (snapshot.data! <= 0) {
                          return LinearProgressIndicator(
                            value: (snapshot.data! * -1) / 100,
                            backgroundColor: Colors.grey[300],
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.blue),
                          );
                        } else {
                          return Text(snapshot.data!.toString(),
                              style: TextStyle(
                                  fontSize: 32, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center);
                        }
                      },
                    ),
                    SizedBox(height: 10),
                    StreamBuilder<int>(
                        stream: widget.bleManager.c1984CodeStream,
                        initialData: -100000,
                        builder: (context, snapshot) {
                          if (snapshot.data! == -100000) {
                            return ElevatedButton(
                              onPressed: () {
                                widget.bleManager.readImmobiliserCodeFrom1984();
                              },
                              child: Text('Read'),
                            );
                          }
                          if (snapshot.data! > 0) {
                            return ElevatedButton(
                              onPressed: () {
                                widget.bleManager
                                    .reset1984ImmobiliserCodeRead();
                              },
                              child: Text('Reset'),
                            );
                          }
                          return ElevatedButton(
                            onPressed: () {
                              widget.bleManager.reset1984ImmobiliserCodeRead();
                            },
                            child: Text('Cancel'),
                          );
                        })
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
