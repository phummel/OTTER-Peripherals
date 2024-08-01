# This program will show the full range of 12-bit color on the
# 320x240 screen. The first 4 rows will be each color space
# First row will show 16 shades of pure red in 20x12 pixel chips
# 2nd row will show 16 shades of pure green in 20x12 pixel chips
# 3rd row will show 16 shades of pure blue in 20x12 pixel chips
# 4th row will show 16 shades of pure gray (equal RGB)
# Remaining 192 rows will show all 4096 color combinations in
# 5x3 pixel chips. Colors will start a 0x000 and increment by
# 1 for each chip. So every row of 16 chips will cover the full
# spectrum of blue (lowest color in RGB). Every 16 rows (4 x 4)
# group of rows on the screen will cover the full spectrum of 
# green (middle color in RGB). Each (4x4) group of rows will
# colver the full spectrum of red (high color in RGB)
# Paul Hummel

.equ VGA_ADDR_MMIO,  0x11000120  # draw subroutines assume this value in s0!!!
.equ VGA_COLOR_MMIO, 0x11000140
.equ BG_COLOR,       0x777       # middle gray
.equ COLUMNS,        320         # VGA screen dimensions 320 x 240
.equ ROWS,           240
.equ COLOR_ROWS,     12	         # color strips in 12 pixel rows

main:
    li sp, 0x10000        # initialize stack pointer
    li s0, VGA_ADDR_MMIO  # draw_dot speed improved by preloading
                          # address, but it must never be changed
    
    # Draw all shades of pure red on 12 rows ###########################
    # start at top right corner
    li  a0, 0           # column (x)
    li  a1, 0           # row (y)
    li  s1, COLUMNS
    li  s2, COLOR_ROWS  # fill in 12 rows
    li  s3, 0xF00       # red color mask
    li  s4, 0           # initial color (black)
    
RED_LOOP:
    slli a3, s4, 8	# move color to red space (0x_00)
    and  a3, a3, s3	# mask for color space
    addi a2, a0, 19	# 20 pixels wide
    call draw_horizontal_line
    addi s4, s4, 1      # change color by 1
    # moving to next column not needed because draw_horizontal_line
    # changes a0 to a2+1 => a0 will be a0 + 20
    # addi a0, a0, 20	# next column
    bltu a0, s1, RED_LOOP
    
    #next Row
    li   a0, 0
    addi a1, a1, 1
    bltu a1, s2, RED_LOOP  # check rows to color
    
    # Draw all shades of pure green on 12 rows #########################
    # start at next row
    li   a0, 0                # column (x)
    mv   a1, s2               # row (y)
    addi s2, s2, COLOR_ROWS   # fill in 12 more rows
    li   s3, 0x0F0            # green color mask
    li   s4, 0                # initial color (black)
    
GREEN_LOOP:
    slli a3, s4, 4	# move color to green space (0x0_0)
    and  a3, a3, s3	# mask for color space
    addi a2, a0, 19	# 20 pixels wide
    call draw_horizontal_line
    addi s4, s4, 1      # change color by 1
    # moving to next column not needed because draw_horizontal_line
    # changes a0 to a2+1 => a0 will be a0 + 20
    # addi a0, a0, 20	# next column
    bltu a0, s1, GREEN_LOOP
    
    #next Row
    li   a0, 0
    addi a1, a1, 1
    bltu a1, s2, GREEN_LOOP   # check rows to color
            
    # Draw all shades of pure blue on 12 rows #########################
    # start at next row
    li   a0, 0               # column (x)
    mv   a1, s2              # row (y)
    addi s2, s2, COLOR_ROWS  # fill in 12 more rows
    li   s3, 0x00F           # blue color mask
    li   s4, 0               # initial color (black)
    
BLUE_LOOP:
    slli a3, s4, 0	# move color to blue space (0x00_)
    and  a3, a3, s3	# mask for color space
    addi a2, a0, 19	# 20 pixels wide
    call draw_horizontal_line
    addi s4, s4, 1      # change color by 1
    # moving to next column not needed because draw_horizontal_line
    # changes a0 to a2+1 => a0 will be a0 + 20
    # addi a0, a0, 20	# next column
    bltu a0, s1, BLUE_LOOP
    
    #next Row
    li   a0, 0
    addi a1, a1, 1
    bltu a1, s2, BLUE_LOOP  # check rows to color 
 
    # Draw all shades of pure gray on 12 rows #########################
    # start at next row
    li   a0, 0               # column (x)
    mv   a1, s2              # row (y)
    addi s2, s2, COLOR_ROWS  # fill in 12 more rows
    li   s3, 0x00F           # color mask
    li   s4, 0               # initial color (black)
    
GRAY_LOOP:
    and  t0, s4, s3     # mask for single color space
    slli t1, t0, 4      # copy same color to green
    slli t2, t0, 8      # copy same color to blue
    or   a3, t1, t2     # combine color spaces into single value
    or   a3, a3, t0
    addi a2, a0, 19	# 20 rows wide
    call draw_horizontal_line
    addi s4, s4, 1      # change color by 1
    # moving to next column not needed because draw_horizontal_line
    # changes a0 to a2+1 => a0 will be a0 + 20
    # addi a0, a0, 20   # next column
    bltu a0, s1, GRAY_LOOP
    
    #next Row
    li   a0, 0
    addi a1, a1, 1
    bltu a1, s2, GRAY_LOOP  # check rows to color 
 
    # Draw all color shades on remaing 192 rows
    # each color in 5x3 chip
    # start at next row
    li   a0, 0           # column (x)
    mv   a1, s2          # row (y)
    li   a3, 0           # initial color (black)
    li   s2, ROWS        # fill rest of screen         
    
COLOR_LOOP:
    addi a2, a0, 4
    call draw_horizontal_line
    addi a0, a0, -5      # reset column for next row
    addi a1, a1, 1       # next row
    call draw_horizontal_line
    addi a0, a0, -5      # reset column for next row
    addi a1, a1, 1       # next row
    call draw_horizontal_line
    addi a1, a1, -2      # reset row
    
    addi a3, a3, 1      # change color by 1
    # moving to next column not needed because draw_horizontal_line
    # changes a0 to a2+1 => a0 will be a0 + 5
    # addi a0, a0, 5	# next column
    bltu a0, s1, COLOR_LOOP
    
    #next Row
    li   a0, 0
    addi a1, a1, 3           # draw 3 rows at a time
    bltu a1, s2, COLOR_LOOP  # check rows to color 
    
done:	j done # continuous loop

# Fills the 320x240 grid with one color using successive calls to draw_horizontal_line
# Modifies (directly or indirectly): t0, t1, t4, a0, a1, a2, a3
draw_background:
	addi sp,sp,-4
	sw ra, 0(sp)
	li a3, BG_COLOR	# use default color
	li a1, 0	# a1= row_counter
	li t4, ROWS 	# max rows
	li a2, COLUMNS 	# total number of columns
	addi a2, a2, -1 # last column index
back_start:	
        li a0, 0
	call draw_horizontal_line  # must not modify: t4, a1, a3
	addi a1,a1, 1
	bne t4,a1, back_start	   # branch to draw more rows
	lw ra, 0(sp)
	addi sp,sp,4
	ret

# draws a horizontal line from (a0,a1) to (a2,a1) using color in a3
# Modifies (directly or indirectly): t0, t1, a0
draw_horizontal_line:
	addi sp,sp,-4
	sw ra, 0(sp)
draw_horiz_loop:
	call draw_dot  # must not modify: a0, a1, a2, a3
	addi a0,a0,1
	ble a0,a2, draw_horiz_loop
	lw ra, 0(sp)
	addi sp,sp,4
	ret

# draws a vertical line from (a0,a1) to (a0,a2) using color in a3
# Modifies (directly or indirectly): t0, t1, a1
draw_vertical_line:
	addi sp,sp,-4
	sw ra, 0(sp)
draw_vert_loop:
	call draw_dot  # must not modify: a0, a1, a2, a3
	addi a1,a1,1
	ble a1,a2,draw_vert_loop
	lw ra, 0(sp)
	addi sp,sp,4
	ret

# draws a dot on the display at the given coordinates:
# 	(X,Y) = (a0,a1) with a color stored in a3
# 	(col, row) = (a0,a1)
#  !!!!! ASSUMES VGA_ADDR_MMIO is in s0  !!!!!!
# Modifies (directly or indirectly): t0, t1
draw_dot:
	# address  = row x 320 + col
	# row x 320 = (row << 2 + row) << 6
	slli t0, a1, 2
	add  t0, t0, a1
	slli t0, t0, 6
	add  t0, t0, a0	
	sw   t0, 0(s0)	    # write 17-bit framebuffer address
	sw   a3, 0x20(s0)   # write color data to frame buffer
	ret                 
