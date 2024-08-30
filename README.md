Allows you to program your Cobra 6422 to accept new touch keys pair to a 1984 immobiliser unit 

Builds in Arduino SDK.  Install the 'OneWire' library via the Ardunio library manager and then the code should compile.

To read touch keys, connect a 4.7k resistor between 5v and the data pin (2) and connect the data pin to the centre of the touch key.  Connect ground to the outside of the key.

Connect the Ardunio to the 'Prog' port on the Cobra.  Working from the pin nearest the edge of the cobra unit, connect:

Ground
Pin 13
Pin 8
Pin 12
Pin 11
Pin 10
(These can be configured in cobra_6422.ino and may change in future)

Connect to the programmer via serial, 9600 baud (or just use the serial monitor in the Arduino IDE) and follow the prompts.

You may find you have to press the reset button on the Arduino to get the initial prompt to show up.  It's advisable to first dump the memory of the Cobra unit and copy the serial somewhere safe so there's a backup if anything goes wrong.

Please note that this is still a work in progress.  Not everything has been tested and it may brick your 6422 unit.
