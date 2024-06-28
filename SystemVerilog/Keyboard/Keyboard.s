# --------------------------------------------------------------------
# Program to test keyboard input with interrupts. Each interrupt is 
# counted and the current total is displayed to the LEDs (0 - 255)
# The keycode is displayed on the Seven Segment
#
# LED MMIO    0x11000020
# 7 Seg MMIO  0x11000040
# Keyboard    0x11000100
#
# Author: Joseph Callenes, Paul Hummel
# --------------------------------------------------------------------

.eqv MMIO,0x11000000 

.data 
SCANCODE: 

.text
main: li   sp, 0x10000     # initialize stack pointer
      li   s0, MMIO        # pointer for MMIO
      la   s1, SCANCODE    # pointer to scancode
    
      la    t0, ISR         # register the interrupt handler
      csrrw x0, mtvec, t0
      li    t0, 8           # enable interrupts
      csrrw x0, mstatus, t0

      add   s3, x0, x0      # initialize interrupt flag
      add   s2, x0, x0      # initialize interrupt count
      sw    s2, 0x40(s0)    # clear 7Seg
      sw    s2, 0x20(s0)    # clear LEDs
      
loop: beq   s3, x0, loop    # check for interrupt flag
      lw    t1, 0(s1)       # read saved scancode
      sw    t1, 0x40(s0)    # set 7Seg
      addi  s2, s2,  1      # increment interrupt count
      sw    s2, 0x20(s0)    # output to LEDS
      addi  s3, x0, 0       # clear interrupt flag
      j     loop

# Interrupt Service Routine for keyboard
ISR:  addi sp, sp, -4     # push t0 to stack
      sw   t0, 0(sp)
      lw   t0, 0x100(s0)  # read scancode
      sw   t0, 0(s1)      # save to SCANCODE
      addi s3, x0, 1      # set interrupt flag
      lw   t0  0(sp)      # pop t0 from stack
      addi sp, sp, 4
      mret

