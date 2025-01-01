import 'package:flutter/material.dart';
import 'ble_manager.dart';

class ImmobiliserPage extends StatefulWidget {
  final BLEManager bleManager;

  const ImmobiliserPage({Key? key, required this.bleManager}) : super(key: key);

  @override
  ImmobiliserPageState createState() => ImmobiliserPageState();
}

class ImmobiliserPageState extends State<ImmobiliserPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _newImmobiliserCode = 0;
  bool _isEditing = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Function to show an error dialog
  void _showErrorDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(errorMessage),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Function to show the confirmation dialog
  void _showCableWarningDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cable to 1984 required!'),
        content: const Text(
            'Please ensure the additional cable is connected to the 1984 immobiliser in the engine bay before proceeding.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
              widget.bleManager.readImmobiliserCodeFrom1984(); // Trigger read
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // Function to show the Test Code dialog
  void _showTestCodeDialog() {
    final TextEditingController codeController = TextEditingController();
    final FocusNode codeFocusNode = FocusNode();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Test Immobiliser Code'),
        content: TextField(
          controller: codeController,
          focusNode: codeFocusNode,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Enter Code',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
              codeFocusNode.dispose();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final int? code = int.tryParse(codeController.text);
              if (code != null) {
                widget.bleManager.testImmobiliserCode(code);
              }
              Navigator.of(context).pop(); // Close the dialog
              codeFocusNode.dispose();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    ).then((_) {
      codeFocusNode.requestFocus();
    });
  }

  // Pull-to-refresh function
  Future<void> _refreshData() async {
    await widget.bleManager.refreshData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Immobiliser'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData, // Pull-to-refresh logic
        child: ListView(
          children: [
            // Combined card for displaying and editing immobiliser code
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
                          ? 'Reading data...'
                          : snapshot.data!.toString();
                      TextStyle? style = snapshot.data! == 0
                          ? const TextStyle(fontSize: 16)
                          : const TextStyle(
                              fontSize: 32, fontWeight: FontWeight.bold);
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Paired Immobiliser Code',
                            style: TextStyle(fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          if (_isEditing)
                            TextField(
                              controller: _controller,
                              focusNode: _focusNode,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'New Code',
                              ),
                              style: const TextStyle(
                                  fontSize: 32, fontWeight: FontWeight.bold),
                              onChanged: (value) {
                                setState(() {
                                  _newImmobiliserCode =
                                      int.tryParse(value) ?? 0;
                                });
                              },
                            )
                          else
                            Text(
                              text,
                              style: style,
                              textAlign: TextAlign.center,
                            ),
                          const SizedBox(height: 10),
                          if (_isEditing)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _isEditing = false;
                                    });
                                    _controller.clear();
                                    _focusNode.unfocus();
                                  },
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () {
                                    widget.bleManager.writeNewImmobiliserCode(
                                        _newImmobiliserCode);
                                    setState(() {
                                      _isEditing = false;
                                    });
                                    _controller.clear();
                                    _focusNode.unfocus();
                                  },
                                  child: const Text('Write'),
                                ),
                              ],
                            )
                          else
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _isEditing = true;
                                  _controller.text = text;
                                });
                                _focusNode.requestFocus();
                              },
                              child: const Text('Edit'),
                            ),
                        ],
                      );
                    },
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
                      const Text(
                        'Read Immobiliser Code from 1984',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 10),
                      StreamBuilder<int>(
                        stream: widget.bleManager.c1984CodeStream,
                        initialData: -100000,
                        builder: (context, snapshot) {
                          if (snapshot.data! == -100000) {
                            return const SizedBox.shrink();
                          }
                          if (snapshot.data! == -100002) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              widget.bleManager.reset1984ImmobiliserCodeRead();
                              _showErrorDialog(
                                  "1984 already mobilised. Power cycle it and try again.");
                            });
                            return const SizedBox.shrink();
                          }
                          if (snapshot.data! == -100003) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              widget.bleManager.reset1984ImmobiliserCodeRead();
                              _showErrorDialog("Code not detected.");
                            });
                            return const SizedBox.shrink();
                          }
                          if (snapshot.data! <= 0) {
                            return LinearProgressIndicator(
                              value: (snapshot.data! * -1) / 100,
                              backgroundColor: Colors.grey[300],
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.blue),
                            );
                          } else {
                            return Text(snapshot.data!.toString(),
                                style: const TextStyle(
                                    fontSize: 32, fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      StreamBuilder<int>(
                          stream: widget.bleManager.c1984CodeStream,
                          initialData: -100000,
                          builder: (context, snapshot) {
                            List<Widget> children = [];
                            if (snapshot.data! == -100000) {
                              children = [
                                ElevatedButton(
                                  onPressed: _showTestCodeDialog,
                                  child: const Text('Test Code'),
                                ),
                                ElevatedButton(
                                  onPressed: _showCableWarningDialog,
                                  child: const Text('Test All Codes'),
                                )
                              ];
                            } else if (snapshot.data! > 0) {
                              children = [
                                ElevatedButton(
                                  onPressed: () {
                                    widget.bleManager
                                        .reset1984ImmobiliserCodeRead();
                                  },
                                  child: const Text('Reset'),
                                )
                              ];
                            } else {
                              children = [
                                ElevatedButton(
                                  onPressed: () {
                                    widget.bleManager
                                        .reset1984ImmobiliserCodeRead();
                                  },
                                  child: const Text('Cancel'),
                                )
                              ];
                            }
                            return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: children);
                          })
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
