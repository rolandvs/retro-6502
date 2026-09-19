# A White-Noise Generator for Apple II

by: John O'Flaherty
published in: BYTE Magazine April 1980

The program simulates the National Semiconductor **MM5837** Digital Noise Generator. The seventeen stages of the shift register form a pseudo-random circuit. 

The software on the Apple II has a cycle time of the loop that averages around 27us, so 3.54 seconds are needed before repetition will occur (2^17 = 131071).

```
MM5837     ┌───────┐                                   
           │ clock │                                   
           └───────┘                                                                         
               │                                        
   ┌───────────▼─────────────────┐                      
   ├────┐  17-stage        ┌─────┤            ┌────────┐
┌─▶│bit1│  shift register  │bit17│─────┬─────▶│ output │
│  ├────┘          ┌─────┐ └─────┤     │      └────────┘
│  │               │bit14│       │     │                
│  └───────────────┴─────┴───────┘     │                
│                     │                │                
│   ┌────────┐        │                │                
│   │        │◀────────                │                
└───│   =1   │                         │                
    │        │◀─────────────────────────                
    └────────┘                                          
```

# Code

Subroutine to generate continuous white-noise

```
            ORG         $0300
low         .BYTE       $0
high        .BYTE       $0
;
WNCONT:     SEC
            ROL         low
            ROL         high
            BCC         WN1
            LDA         $C030       ; speaker
WN1:        ROR         A
            ROR         A
            ROR         A
            EOR         high
            ASL         A
            ASL         A
            ASL         A
            JMP         WNCONT
```

Subroutine to generate a burst of white-noise

```
            ORG         $0300
low         .BYTE       $0
high        .BYTE       $0
;
BURST:      LDA         #$0
            TAY
;
WNCONT:     SEC
            ROL         low
            ROL         high
            BCC         WN1
            LDA         $C030       ; speaker
WN1:        ROR         A
            ROR         A
            ROR         A
            EOR         high
            ASL         A
            ASL         A
            ASL         A
 ;
            DEY
            TYA
            BNE         WN2
            RTS
;
WN2:        JMP         WNCONT
```

