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
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Current Immobiliser Code:',
                          style: TextStyle(fontSize: 18),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 10),
                        Text(
                          snapshot.data!.toString(),
                          style: TextStyle(
                              fontSize: 32, fontWeight: FontWeight.bold),
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
                      'Enter New Immobiliser Code:',
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
