# This program will fill the screen with color that changes at every pixel
# Top left corner will be black RGB 12'h000 and increase with each pixel
# in the row. At the end of a row, it will go to next row down and 
# continue the color increasing. If the color overflows (goes beyond
# white (12'hFFF) it will go back to black and increase again
#
# coordinates are given in row major format
# (col,row) = (x,y)
# Paul Hummel

.equ VG_ADDR, 0x11000120
.equ VG_COLOR, 0x11000140
.equ BG_COLOR, 0x0          #black
.equ COLUMNS 160
.equ ROWS 120

main:
    li sp, 0x10000     #initialize stack pointer
    li s2, VG_ADDR     #load MMIO addresses 
    li s3, VG_COLOR    

    # fill screen using default color
    #call draw_background  # must not modify s2, s3

    li s0, COLUMNS
    li s1, ROWS

    li a0, 0		# X coordinate
    li a1, 0		# Y coordinate
    li a3, 0x0   	# color red (RGB 12'hF00)
    
COL_LOOP: 
    bge  a0, s0 NEXT_ROW
    call draw_dot       # must not modify s2, s3
    addi  a3, a3, 1	# change color by 1 
    addi a0, a0, 1	# next column
    j    COL_LOOP
NEXT_ROW:
    li   a0, 0		# restart at column 0
    addi a1, a1, 1	# next row
    blt  a1, s1, COL_LOOP

done:	j done # continuous loop

# draws a horizontal line from (a0,a1) to (a2,a1) using color in a3
# Modifies (directly or indirectly): t0, t1, a0
draw_horizontal_line:
	addi sp,sp,-4
	sw ra, 0(sp)
draw_horiz1:
	call draw_dot  # must not modify: a0, a1, a2, a3
	addi a0,a0,1
	ble a0,a2, draw_horiz1
	lw ra, 0(sp)
	addi sp,sp,4
	ret

# draws a vertical line from (a0,a1) to (a0,a2) using color in a3
# Modifies (directly or indirectly): t0, t1, a1
draw_vertical_line:
	addi sp,sp,-4
	sw ra, 0(sp)
draw_vert1:
	call draw_dot  # must not modify: a0, a1, a2, a3
	addi a1,a1,1
	ble a1,a2,draw_vert1
	lw ra, 0(sp)
	addi sp,sp,4
	ret

# Fills the 60x80 grid with one color using successive calls to draw_horizontal_line
# Modifies (directly or indirectly): t0, t1, t4, a0, a1, a2, a3
draw_background:
	addi sp,sp,-4
	sw ra, 0(sp)
	li a3, BG_COLOR	# use default color
	li a1, 0	# a1= row_counter
	li t4, ROWS 	# max rows
	li a2, COLUMNS 	# total number of columns
	addi a2, a2, -1 # last column index
start:	li a0, 0
	call draw_horizontal_line  # must not modify: t4, a1, a3
	addi a1,a1, 1
	bne t4,a1, start	#branch to draw more rows
	lw ra, 0(sp)
	addi sp,sp,4
	ret

# draws a dot on the display at the given coordinates:
# 	(X,Y) = (a0,a1) with a color stored in a3
# 	(col, row) = (a0,a1)
# Modifies (directly or indirectly): t0, t1
draw_dot:
	andi t0,a0,0xFF	# select bottom 8 bits (col)
	andi t1,a1,0x7F	# select bottom 7 bits  (row)
	slli t1,t1,8	#  {a1[6:0],a0[7:0]} 
	or t0,t1,t0	    # 15-bit address
	sw t0, 0(s2)	# write 15 address bits to register
	sw a3, 0(s3)	# write color data to frame buffer
	ret
