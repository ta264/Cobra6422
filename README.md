Allows you to program your Cobra 6422 to accept new touch keys, pair to a 1984 immobiliser unit and discover the code required to mobilise a 1984 immobiliser.

Builds in Arduino SDK.  Requires an Arudino UNO R4 WIFI or equivalent 5v device with BLE support.

Install the 'OneWire' library via the Ardunio library manager and then the code should compile.

To read touch keys, connect a 4.7k resistor between 5v and the data pin (2) and connect the data pin to the centre of the touch key.  Connect ground to the outside of the key.

Connect the Ardunio to the 'Prog' port on the Cobra.  Working from the pin nearest the edge of the cobra unit, connect:

Ground
Pin 13
Pin 12
Pin 11
Pin 10
Pin 9

(These can be configured in cobra_6422.ino.  Note this has changed from the initial version)

Install the Android app 'Jolly Programmer' (or build it from the jolly_programmer_frontend directory).

Please note that this is still a work in progress.  Not everything has been tested and it may brick your 6422 unit.
