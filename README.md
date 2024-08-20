Allows you to program your Cobra 6422 to accept new touch keys.  

Builds in Arduino SDK.

To read touch keys, connect a 4.7k resistor between 5v and the data pin (2) and connect the data pin to the centre of the touch key.  Connect ground to the outside of the key.

Connect the Ardunio to the 'Prog' port on the Cobra.  Working from the pin nearest the edge of the cobra unit, connect:

Ground
Pin 13
Ground
Pin 12
Pin 11
Pin 10

Connect to the programmer via serial, 9600 baud and follow the prompts.
