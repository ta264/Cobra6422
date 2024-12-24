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
  int _newImmobiliserCode = 0;

  @override
  void dispose() {
    _controller.dispose();
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
                            'Current Immobiliser Code',
                            style: TextStyle(fontSize: 18),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
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
                      const Text(
                        'Write Immobiliser Code',
                        style: TextStyle(fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
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
                      const SizedBox(height: 10),
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
                        child: const Text('Write'),
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
                            if (snapshot.data! == -100000) {
                              return ElevatedButton(
                                onPressed: _showCableWarningDialog,
                                child: const Text('Read'),
                              );
                            }
                            if (snapshot.data! > 0) {
                              return ElevatedButton(
                                onPressed: () {
                                  widget.bleManager
                                      .reset1984ImmobiliserCodeRead();
                                },
                                child: const Text('Reset'),
                              );
                            }
                            return ElevatedButton(
                              onPressed: () {
                                widget.bleManager
                                    .reset1984ImmobiliserCodeRead();
                              },
                              child: const Text('Cancel'),
                            );
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
