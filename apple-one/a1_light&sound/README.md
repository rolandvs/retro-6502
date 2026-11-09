# A-ONE Light & Sound Board

Sample program to test the use of the speaker. Apart from the Apple II beep, this program sounds the **Ode to Joy** part of the ninth symphony of Beethoven and the famous **Nokia ring tone**.

## Nokia Ring Tone
The Nokia tune is a fragment of Francisco Tárrega’s Gran Vals (1902).

# CLOCK
The main clock frequency can be adjusted for all the different systems. The N-values and note lengths are calculated from the given clock frequency. The use of `.assert` guards that D4 fits 8 bit. 

THe assumption is a CPU clock of `1MHz`. An original Apple-1 design uses `14.31818/14=1,0227MHz`.

## Change The Clock
Change `CLOCK` and run `ca65 ode1.s -o ode1.o` and `ld65 -t none -S '$0300' ode1.o -o ode1.bin`.

As usual the program origin is `$0300`. Zero-page addresses remain outside the used ones by the WozMon `$24–$2B`.


