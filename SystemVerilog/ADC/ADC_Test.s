# ADC Demo program 
# This will take a reading from the ADC input every ~50 ms, do a fast 
# approximate conversion to mV and display the value on the 7 Segment display. 
# It is recommended the 7 Segment display be configured to display values as 
# decimal for ease in testing
#
# !WARNING!     XADC pins on the Basys3 are limited to 1.8V MAX     !WARNING!
# !WARNING!     XADC pins on the Basys3 are limited to 0.0V MIN     !WARNING!
#
# v1.0 - Paul Hummel


.eqv MMIO,      0x11000000
.eqv SSEG,      0x40
.eqv ADC,       0x50
.eqv WAIT_TIME, 0x1E847     #Delay for 50 ms

MAIN: lui  sp, 0x10			#initialize sp
      li   s0, MMIO         #setup MMIO address
LOOP: lw   a0, ADC(s0)      #read from ADC
      call CONVERT          #convert ADC value into mV
      sw   a0, SSEG(s0)     #output mv to 7seg
      li   a0, WAIT_TIME    
      call DELAY            #delay to reduce 7seg flicker
      j    LOOP

# delay loop that will iterate through a loop a0 
# times before returning. 
# Delay time = 80ns x a0 + 120ns (call, ret)
DELAY:  add  t0, x0, x0      
D_LOOP: addi t0, t0, 1
        bltu t0, a0, D_LOOP
        ret

# This will do an approximate conversion from the 
# ADC value into mV. The exact value would be determined
# by ADC / 4096 x 1000. This approximation instead x 1024
# to utilize shifting for multiplication by 2

CONVERT: slli a0, a0, 10  #shift left to x 1024
         srli a0, a0, 12  #shift right to / 4096
         ret
