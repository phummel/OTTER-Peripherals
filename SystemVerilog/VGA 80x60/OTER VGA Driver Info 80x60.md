**VGA Driver 80x60 for OTTER MCU**   
written by Paul Hummel

**VGA Screen**  
The screen is broken up into blocks (“pixels”) resulting in a resolution of 80x60. The coordinates of the top-left, top-right, bottom left and bottom right blocks are: (0,0), (79,0), (0,59), (79,59) respectively as shown in Figure 1\.

![][image1]  
Figure 1: VGA Display Resolution

A VGA display works by writing a color to each pixel of the display in a continuous stream. The display starts at the top left pixel of the screen (0,0) and moves to the right, one row at a time. When the display gets to the last pixel on the bottom right (79,59), it starts over again at the top left corner (0,0). The display has to be continuously refreshed to create the illusion of motion. 

**VGA Color Data**  
Color information on the Basys3 VGA peripheral is controlled by 3 4-bit inputs, Red, Green, and Blue. While the OTTER is capable of easily using 12 bits of data, the VGA driver was originally designed for an 8-bit device. To adapt, the color information for the VGA driver is reduced to 8 bits. The 3 MSBs will control Red, the next 3 bits will control Green, and the 2 LSBs will control Blue. This results in the 8-bit color data (wd, rd) signals being represented as RRRGGGBB. Having more red bits asserted and no other bits asserted, makes the block "more red", so “full red” is "11100000", “full blue” is "00000011", and full green is "00011100". You can mix colors: white is "11111111" and black is "00000000". This 8-bit color allows for 256 different colors to be displayed on the display

The 8 bits are extended to 12 bits in the constraints file by reusing bits. For Red and Green, the 3-bit color data is expanded to 4-bit by using the LSB twice, ie 3-bit value B2B1B0 is expanded to a 4-bit value B2B1B0B0. For Blue, the 2-bit color data is expanded to 4-bit by using each bit twice. The 2-bit value B1B0 is expanded to 4-bit B1B1B0B0. 

**VGA Hardware**  
The VGA hardware driver consists of three different sub-circuits, a clock divider (vga\_clk\_div), a dual-ported memory (frameBuffer), and a VGA scanline driver (vga\_out). An overview of this circuit is shown in Figure 2\. 

![][image2]  
Figure 2: VGA Driver

This circuit allows color data (wd) for each block to be stored in a framebuffer. Each block location (80x60) corresponds to a specific address (wa) in the framebuffer. The VGA scanline driver reads from the framebuffer and refreshes the VGA display. The VGA driver scans addresses (ra2) in the framebuffer and refreshes the display with the saved color (rd2) for each pixel. The VGA driver also creates the necessary timing signals to control the connected VGA display. The horizontal sync and vertical sync (HS, VS) signals control the display resolution and refresh rate. Once data is written to the framebuffer, the VGA driver will automatically update the display as it is refreshed. 

Writing color to the screen only requires interfacing with the framebuffer which is simply a block of memory. The data written (wd1) to the framebuffer is the 8-bit color value. The address (wa1) where the data is saved will correspond to the location or pixel on the screen. 

**Framebuffer Address**  
The first block (“pixel”) in the top left corner will correspond to address 0\. The next block to the right will have address 1\. This will continue to the last block on the top row which will correspond to address 79\. The leftmost block on the 2nd row will not correspond to address 80 however. To make it simpler to address, each row will jump by a power of 2, so the leftmost block on the 2nd row will correspond to address 128\. The next block to the right will be 129, etc. The rightmost block on the 2nd row will be at address 207\. The leftmost block on the 3rd row will be 256\. So each column will increment the address by 1 while each row will increment the address by 128\. 

If every block had a consecutive address, so if the first block in row 2 had address 80 instead of 128, to have enough addresses for each block in the display, the address space would need to go from address 0 to 80x60 \-1 \= 4799\. This would require a 13-bit address. 

If the address was instead made by using the row and column value, the row must go from 0-59 which requires 6 bits, and the columns must go from 0-79 which requires 7 bits. These combined are also 13 bits. However, it is easier to organize an address by using row and column values directly. So the 13-bit address can be comprised of R5R4R3R2R1R0C6C5C4C3C2C1C0. When organizing the address in this way, the least significant bit of the row corresponds to bit 7 of the address. 27 \= 128 which is why the rows increment the address by 128\. If the address was done as consecutive values, it would require multiplication operations to calculate the address from the rows and column values. 

**Interfacing with the VGA Driver**  
The OTTER will interface with the VGA driver using multiple MMIO addresses to write data to the framebuffer of the VGA driver. The pixel address is 13-bits and will be connected to the MMIO address VGA\_ADDR\_AD. The pixel color data is 8-bits and will use a second MMIO address VGA\_COLOR\_AD. So to write color to a single block of the screen will require two store instructions. This means the OTTER WRAPPER will need 2 different MMIO addresses to identify the connections to the VGA driver, one for the pixel address and one for the pixel color. 

| Pixel Address |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | Pixel Color |  |  |  |  |  |  |  |
| ----- | :---- | :---- | :---- | :---- | :---- | :---- | :---- | :---- | :---- | :---- | :---- | :---- | :---- | :---- | :---- | ----- | :---- | :---- | :---- | :---- | :---- | :---- | :---- |
| x | x | x | x | A12 | A11 | A10 | A9 | A8 | A7 | A6 | A5 | A4 | A3 | A2 | A0 | C7 | C6 | C5 | C4 | C3 | C2 | C1 | C0 |

The multiple store instructions create a potential problem for when the data should be saved to the frame buffer. Due to how the OTTER MCU is connected to the output peripherals, data is held constant on all of the output lines until it is explicitly changed. This means that when writing to the framebuffer to change the color of a block, executing a store instruction to update the address does not change the pixel color. The pixel color will remain the same as it was previously set to. This creates the potential to affect an unintended block. The framebuffer should not save the color data until after both the address and color data have been set. To achieve this, the framebuffer includes a write enable bit (we) that the OTTER WRAPPER will manipulate. The VGA driver will be connected in the OTTER WRAPPER in a manner so that the data will only be saved in the framebuffer when pixel color is output. This means that the pixel address will have to be output first. The OTTER WRAPPER will set the write enable (we) bit high for 1 clock cycle after a store to the pixel color MMIO address so that color data will be saved to the address and not overwrite any other addresses when future store instructions to new pixel addresses are performed.

**Reading from the VGA Driver**  
The VGA screen can contain a significant amount of data for the screen. The 80x60 individual blocks are 4800 locations. This can make keeping the state of the program difficult or tedious to save in the OTTER MCU. For example, if a maze program uses the VGA driver, the maze could be created programmatically by writing wall blocks as a different color to the VGA driver. However, those wall locations may not be easily saved in the internal memory of the OTTER MCU to use when trying to determine how the user can properly move throughout the maze. The data is saved in the framebuffer though, so if the OTTER MCU was able to read the data back from the framebuffer, it would not need to be saved internally. Keeping with the maze example, the OTTER MCU could read the current color at an address in the framebuffer to determine if the user’s move is valid or if there is a wall blocking the move. The VGA driver provides this capability with RD output. RD is the 8-bit color data that is currently saved in the framebuffer for the current address (wa1). The RD will be routed in the OTTER WRAPPER as an input with an MMIO address of VGA\_READ\_AD. So any address in the framebuffer can be read by setting an address with a store command to the same MMIO address VGA\_ADDR\_AD followed by a load command from the MMIO address VGA\_READ\_AD. The store command to the VGA pixel address will not change any data in the framebuffer because the data is only saved with a store instruction to pixel color address. 

[image1]: <data:image/png;base64,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>

[image2]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAqQAAAGFCAYAAAArXuGnAABIWUlEQVR4Xu2dMagly3nnb6DsZYKHJrw4M1iTOJQT44mUOFgwzMu84SLGgVIhGJw4MohxbONghDKhYGDhoWBhQIGjN5HYZIRYeDBspoENJpjVf6brvjr/qq5z+lT3qa7q3w/+3O6q+upUdX1f13f7nHPv3UcAAAAAgIbceQEAAAAAwC0hIQUAAACAppCQAgAAAEBTSEgBAAAAoCkkpAAAAADQFBJSAAAAAGgKCSkAAAAANIWEFAAAAACaQkIKAAAAAE0hIQUAAACApixKSO8AAAAAANbGk84SbgsAAAAAUI0nnSXcFgAAAACgGk86S7gtAAAAAEA1nnSWcFsAAAAAgGo86SzhtgAAAAAA1XjSWcJtAQAAAACq8aSzhNsCAAAAAFTjSWcJtwUAAAAAqMaTzhJuCwAAAABQjSedJdwWAAAAAKAaTzpLuC10i9YSIYQQQusJavCks4TbQrd8/F//5/8hhBBCaAVpX/WNFhbiSWcJt4VuSYIJIYQQQtdJ+6pvtLAQTzpLuC10SxJMCCGEELpO2ld9o4WFeNJZwm2hW5JgQgghhNB10r7qGy0sxJPOEm4L3ZIEE0IIIYSuk/ZV32hhIZ50lnBb6JYkmBBCCCF0nbSv+kYLC/Gks4TbQrckwYQQQgih66R91TdaWIgnnSXcFrolCSaEEEIIXSftq77RwkI86SzhttAtSTAhhBBC6DppX/WNFhbiSWcJt4VuSYIJIYQQQtdJ+6pvtLAQTzpLuC10SxJMCCGEELpO2ld9o4WFeNJZwm2hW5JgQgghhNB10r7qGy0sxJPOEm4L3ZIEE0IIIYSuk/ZV32hhIZ50lnBb6JYkmBBCCCF0nbSv+kYLC/Gks4TbQrckwYQQQgih66R91TdaWIgnnSXcFrolCSaEEEIIXSftq77RwkI86SzhttAtSTAhhBBC6DppX/WNFhbiSWcJt4VuSYIJIYQQQtdJ+6pvtLAQTzpLuC10SxJMCCGEELpO2ld9o4WFeNJZwm2hW5JgQgghhNB10r7qGy0sxJPOEm4L3ZIEE0IIIYSuk/ZV32hhIZ50lnBb6JYkmBBCCCF0nbSv+kYLC/Gks4TbQrckwXR06Zqg28rXACGEetV0X4MaPOks4bbQLUkwHV26JnA78EGE0EjSPc32WViKbxQl3Ba6JQmmo0vXBG4HPogQGkm6p9k+C0vxjaKE20K3JMF0dOmawO3ABxFCI0n3NNtnYSm+UZRwW+iWJJiOLl0TuB34IEJoJOmeZvssLMU3ihJuC92SBNPRpWsCtwMfRAiNJN3TbJ+FpfhGUcJtoVuSYDq6dE3gduCDCKGRpHua7bOwFN8oSrgtdEsSTEeXrgncDnwQITSSdE+zfRaW4htFCbeFbkmC6ejSNYHbgQ8ihEaS7mm2z8JSfKMo4bbQLUkwHV26JnA78EGE0EjSPc32WViKbxQl3Ba6JQmmo0vXBG4HPogQGkm6p9k+C0vxjaKE20K3JMF0dOmawO3ABxFCI0n3NNtnYSm+UZRwW+iWJJiOLl0TuB238MFf/e73D8e3eD2E0HGle8zpNguL8Y2ihNtCtyTBdHTpmsDtuIUPXpuQqm3QX//N32bLf/biPxI7hNBxNd0boAbfKEq4LXRLEkxHl64J3I4tfPAv/vKvPvX7d3//D5/Ocwnpb//wp+Jrqz5nF5chhJBL94poj4Vr8I2ihNtCtyTBdHTpmsDtWNsHv//lDz7+409/9ulYff/Lf/46m1gufd3QXk9E/+3Xv/10rtfydgihY0v3hu+2WLgK3yhKuG0D7if1xv2f9aUXNiQJpqNL1+RWfPjw4ePLly8//bwl5+b49u3bT7oFa/tgrj9PSHNtSorbh4RUxyEx9fYIoeNqusdADb5RlHDbFfnl3bRhmGJKdU6pjdeF184xV34pPmZ/7Xs7dzQ2Kebru7LNJSTBdHTpmmzNu3fv3A8+KU4Cdf706dPvjAxvH8rOjf/Zs2ezbXLj2pq1fTDXnyek+jzob775Y9Iup1x/S+oRQsfSdO+EGnyjKOG2K3JuMXN1ubJA6O9HXnGXvtZWCalsv+eFd5/LQ5J5P53P4QnpL+7K7S8lCaajS9dkS548eTL7Gip//fr1w/GShFTnc/3GqM3cE1m3v7TPGtb2QSWbeptex+r7n/75X5OENPw893nQ3Nj0+VR9vrTUBiF0XE33TajBN4oSbrsi5xYzV5crC6juh9PPGCWoP7HySxPSMEZXjm/u5uti7u/K7eKE9Od35bZLSILp6NI12RL1X0o0A+faqT4kpDq+dNyXthOPHj36pC3ZwgfD9Qh95xJSP3YpkY37cTsvQwghabo3QA2+UZRw2xVR3/Hb9t+eVmcXOlcWCHXeJld+aULqnKv7wgsz3N+V+wkJ6Vd3n9vlnrheQxJMR5euyZZc2r/aXZKQlp645lja9v379168KvggQmgk6Z72sMPCdfhGUcJtVyQs5v0kX9zca+fKAqFOP/VkMVcemPv8qo8hRuWeNMfM2Tn3d+W2GpteJ4zlkiT3EpJgOrp0TbZCCeSl/avduYRUTy/189I+9frPnz/34ix6W//Sfmto7YPh+rm8HUIIXaLpHgI1+EZRwm03Rq93Hx07ubJAXBeO9VNvpcdlYukTUpX5F42ceOwl7u/yrxHQ64QxKxkttV1CEkxHl67Jllzav9qdS0hfvHjxcHxJv5e0EWr3+PFjL94EfBAhNJKm+zHU4BtFCbfdGL2ePgcajp1cWSCuC8e5MrEkIb3U6S79vOf9Xbmdf6npXL9hfOgKbYn6n/tcZlyuducS0qVfajpXL9Tm0qeoa+DXHh1HvpEjNIIm/4YafKMo4bYror79qWP8ev7a+iyll8XEdfoikzTX36UJqf6O6Fy7HGr7Yy+8+1yuz4SK++l8Dk9IxRqOnwTTmtq6/y2kMW+Jkky9hv7EkqPy8JlNHS9JSEPZXLIrzs1N9bdMRkWPPoLqxbqjUSXf/ry9wtX4RlHCbVcmLGiQ/yF5ry/h9TqPvxAU11+akPrrnxtHSJpd+juigftMfdxvLiEV5177HEkwramt+99CGvPWvHnzxtc4eV2vCwpJqo49IQ3l4a18L9cXoEr4a+XGtTbq39cAjS/WHY2q6b4JNfhGUcJtG6DPUa71xZ5bcu8FjUmCaU1t3f8W0phvSS6p3IJbvc5SevQRVC/WHY0q+fbJLgvL8Y2ihNtCtyTBtKa27n8LacxwO3r0EVQv1h2NKvn2yS4Ly/GNooTbQrckwbSmtu5/C2nMcDt69BFUL9YdjSr59skuC8vxjaKE20K3JMG0prbufwtpzHA7evQRVC/WHY0q+fbJLgvL8Y2ihNtCtyTBtKa27n8LacxwO3r0EVQv1h2NKvn2yS4Ly/GNooTbQrckwbSmtu5/C2nMcDt69BFUL9YdjSr59skuC8vxjaKE20K3JMG0prbufwtpzHA7evQRVC/WHY0q+fbJLgvL8Y2ihNtCtyTBtKa27n8LacxwO3r0EVQv1h2NKvn2yS4Ly/GNooTbQrckwbSmtu5/C2nMcDt69BFUL9YdjSr59skuC8vxjaKE20K3JMG0prbufwtpzHA7evQRVC/WHY0q+fbJLgvL8Y2ihNtCtyTBtKa27n8LacxwO3r0EVQv1h2NKvn2yS4Ly/GNooTbQrckwbSmtu5/C2nMcDt69BFUL9YdjSr59skuC8vxjaKE20K3JMG0prbufwtpzHA7evQRVC/WHY0q+fbJLgvL8Y2ihNtCtyTBtKa27n8LacxwO3r0EVQv1h2NKvn2yS4Ly/GNooTbQrckwbSmtu5/C2nMcDt69BFUL9YdjSr59skuC8vxjaKE20K3JMG0prbufwtpzHA7evQRVC/WHY0q+fbJLgvL8Y2ihNtCtyTBtKa27n8LacxwO3r0EVQv1h2NKvn2yS4Ly/GNooTbQrckwbSmtu5/C2nMcDt69BFUL9YdjSr59skuC8vxjaKE20K3JMG0prbufwtpzHA7evQRVC/WHY0q+fbJLgvL8Y2ihNtCtyTBtKa27n8LacxwO3r0EVQv1h2NKvn2yS4Ly/GNooTbQrckwbSmtu5/C2nM6LbyNUDji3VHo2q6r0ENnnSWcFvoliSY1tTW/SOE+hT3BjSq5Nu2z8JSPOks4bbQLUkwramt+0cI9SnuDWhUybdtn4WleNJZwm2hW5JgWlNb948Q6lPcG9Cokm/bPgtL8aSzhNtCtyTBtKa27h8h1Ke4N6BRJd+2fRaW4klnCbeFbkmCaU1t3T9CqE9xb0CjSr5t+ywsxZPOEm4L3ZIE05raun+EUJ/i3oBGlXzb9llYiiedJdwWuiUJpjW1df8IoT7FvQGNKvm27bOwFE86S7gtdEsSTGtq6/4RQn2KewMaVfJt22dhKZ50lnBb6JYkmNbU1v0jhPoU9wY0quTbts/CUjzpLOG20C1JMK2prftHCPUp7g1oVMm3bZ+FpXjSWcJtoVuSYFpTW/ePEOpT3BvQqJJv2z4LS/Gks4TbQrckwbSmtu4fIdSnuDegUSXftn0WluJJZwm3hW5JgmlNbd0/QqhPcW9Ao0q+bfssLMWTzhJuC92SBNOa2rp/hFCf4t6ARpV82/ZZWIonnSXcFrolCaY1tXX/CKE+xb0BjSr5tu2zsBRPOku4LXRLEkxrauv+EUJ9insDGlXybdtnYSmedJZwW+iWJJjW1Nb9I4T6FPcGNKrk27bPwlI86SzhttAtSTCtqa37Rwj1Ke4NaFTJt22fhaV40lnCbaFbkmBaU1v3jxDqU9wb0KiSb9s+C0vxpLOE20K3JMG0prbuHyHUp7g3oFEl37Z9FpbiSWcJt4VuSYJpTW3dP0KoT3FvQKNKvm37LCzFk84SbgvdkgTTmtq6f4RQn+LegEaVfNv2WViKJ50l3Ba6JQmmNbWkf7VFaFS5vx9de7kmvk7oOHJfWEtT/1CDJ50l3Ba6JQmmNbWkf7UFGJElcXAU7eWacN85Jlv6n/qO9li4Bl+wEm4L3ZIE05pa0r/aAozIkjg4ivZyTbjvHJMt/U99R3ssXIMvWAm3hW5JgmlNLelfbQFGZEkcHEV7uSbcd47Jlv6nvqM9Fq7BF6yE20K3JMG0ppb0r7Zbob5fvnyZHAPcgiVxcBTt5Zpsed95+/btQ//xMbRnS/9T39P+CtfiC1bCbaFbkmBaU0v6V9utUN8kpNCKJXFwFO3lmmx53yEh3S9b+p/6nvZXuBZfsBJuC92SBNOaWtK/2m6F+iYhhVYsiYOjaC/XxO87r1+/PjmvgYR0v2zpf+p72l/hWnzBSrgtdEsSTGtqSf9qG/Po0aNPZU+ePDkpL6H2seLyuYTU2wKszZI4OIr2ck089pWQhnvCu3fvTurmePr0afa+U0pI1be/NtyOLf1v8gOowReshNtCtyTBtKaW9K+2OVQe9OHDB69+QPXPnz8/OX/z5s3DcS4hDf0CbMmSODiK9nJN5uI/TkyVTM6hX5jjPuJ7ylxCqvvY3OvCbdjS/yYfgBp8wUq4LXRLEkxrakn/altCyabazL3d7vbv379/OI7twnF4AguwNUvi4CjayzU5dw8IyeNcO5XHvwjHzCWk+rnmRwNgOVv63+QvUIMvWAm3hW5JgmlNLelfbedQcql6ae5GXrJXXZyQhmS09MQVYC2WxMFRtJdrUrpviPjt+Bxz5SKXkJb6gtuxpf9Naww1+IKVcFvoliSY1pT6XyInTkTnnowGcvaB2D7052+1AWyF/Mxj4+jy2G+pHOfqA6qfe0s/l5AK/VSiC+3QGrhPrqXJb6AGX7ASbgvdkgRTK2ks5mOfdOlTTLcPb/GHOn/LPhy7HcDa7CnO0Kk8/sM9Ye5teEdt9Y5LIPwSLeYSUr7Q1J4tY3LyIajBF6yE20K3JMHUShpLDUoyQx/hCwkhmdVxLiEN50u+yQ+wlD3FGTqV33devHhxcn6O8BnT+AuUoc+5hFTwDk1btozJyQegBl+wEm4L3ZIEUytpLLVoc9BbYf72vjaD8CWn+DiuB9iKPcUZOtUa9x2he47uPfE7OjoO95b4OKBzL4PbsGVMqu+TXRaW4wtWwm2hW5JgaiWNBWBE9hRn6FTcd47JljGpvk92WViOL1gJt4VuSYKplTQWgBHZU5yhU3HfOSZbxqT6PtllYTm+YCXcFrolCaZW0lgARmRPcYZOxX3nmGwZk+r7ZJeF5fiClXBb6JYkmFpJYwEYkT3FGToV951jsmVMqu+TXRaW4wtWwm2hW5JgaiWNBWBE9hRn6FTcd47JljGpvk92WViOL1gJt4VuSYKplTQWgBHZU5yhU3HfOSZbxqT6PtllYTm+YCXcFrolCaZW0lgARmTLOKvp+1/+89cff/uHPyXlW8nH6udL9P0vf5CUXSPuO8ekxvfOSX1/t8XCVfiClXBb6JYkmFpJYwEYka3iTP2GhFLHf/03f/spUcsla//2699+aqM6/fzNN398sPO2Qf/tv/+PT+3/4i//KtvnUsWv5cd6rXg+sTSvMD+387ZLxX3nmKzhO3NS33dQhy9YCbeFbkmCqZU0FoARycXZr373+48/e/EfyXlIyHQe6v7n//6/ia3ahX6VbCppjGMpbutlejIazv/pn//149/9/T+c9J/rJzeHWPF4w/k//vRnJ2MPfWie4TX//ev/OklCQxvZ5cauxDjYqtxfd6m47xyTc/5cI/V9B3X4gpVwW+iWJJhaSWMBGJFcnKlMyaCO46eaKleSFdvoWMmdjpXAhSehSkRVpqed3j53HKS+4ieeuTahPCS+el2vD200Dyn0o/7DeHNjicvCNfA2Slpz41KZEmodK2nNtVki2cPxqPWbktT3HdThC1bCbaFbkmBqJY0FYERycRaXeb3OlWzGSV1o4z9jm6D4yatL9f72u/clhUS0NM5Ly+Inmrn6cB7etvf+pJCk+9PcufaXSvZwPGr9pqQpbqAGX7ASbgvdkgRTK2ksACOSi7O4zOvDuX7qKWD8tNB/huOQvHrdnNx+rl5Jop7I5j7bec7Wz/1nkJJNJZrxxxDmFD4L631fK9nD8aj1m5LU9x3U4QtWwm2hW5JgaiWNBWBEcnEWl8XH8dvv+hk+G6qkVMlp/NZ+bB9/lvLc6/m513mZjnNtcu28TPK3770+VvxZWO9Xij//6nXXSPawHXu9vrV+U9IUL1CDL1gJt4WL+fld3llzTvxNVPbL6XhO15IEUytpLAC9Ib+Vnj59+nDs5OLMy4JtXB5/LtNtVKenlzn7+C37YBO/BZ977fjc2ysJnvtMZ9zOn9L6a4Vj/Qzf8p9rG79eeLve2yg5zSWwS6T+YDv2en1jP1pbk5/WMGcf8oDAj6Zz5QpfRfXfRm36xBeshNvCIvz6fX332YG8PHYsOZq0NkkwtZLGAtAb7rc6V3LqZe7va2iNftWHf4v/Flpr7F62VL5+sC57vb5r+M6c1Pfn7fVq5uw9IdWx8gdnzr4ffMFKuC0swq+fzr8olItDJaQ6fvPmzcl5XB/K4uNYANcw50dz5TlU/+TJk6TM/X0N6SmiPt/p5Uu01djOSU9d5765f6lq5y75euqXiZcvX56s9YcPH2Z9wO29Xvcxb3Mkwtzja6frGYjfWZCeP39+0j4mvpb6+e7duxPbGF8zR2XuC2tpes0a5uxzCamejo6HL1gJt4VF6Prp8Xp8Hv8MxOeHS0hL5+FGlKt79OjRyTnApQRfijdMnYdNUsi//AlojNq/f/8+KXN/R/uQ3ytCgvT27duHMp3Hv2TE9xz91P0oV5c7Pxo+/5AoxvUx4fz169fZuhCbOlYsBh4/fnxynrP1c/eFtTTNuYY5+1xCKn0ZlY3ByWqdwW1hEXrEHq5h/JlSOdVPpuPw2ZBA6TOkNSTB1Eoai/nYp5/a3HX86tWrTzedUBc2CLcLZZ4UAJxDfpPzpxglKnNtlLjGyWtgT3GGTuVrGRLSGD+Py3RPius9kcrZHonc/P366N6ew23dzglluTV0toxJ9X1XR+hjTo7XK3/oG1+wEm4LiwnXUD/nnpaGt+vFoZ6QTj726ad+69VbaHFZ3FbHOWljAFhC8J0Yf1sw10aUnsyr3P0d7UO+Zkpm/Am4twll+uUkfuIXfknWLyWhj5ztkcjNPy7z+IrfnYh/wfMks9Rv6KvEljE5vX4Nc/b+hDSHHmypzfe8oit8wUq4LSxG1zA4jpfHPwNLE9KHoOxJ5mOffnOOy8Nxrgygljk/jMk9IdV5eHqfw/0c7Usx+uX30oTUj8+VHZHc/HNlQsmn18XXMX7Xy9vFZZ685ghrvxM5uTJxSUIq1GZJvrA/fMFKuC0sJvxJJ7+WOv9hpnxpQnopyW93raSxxIS36uNyHetmE2/+KgtPUAOl5ABgDve3UObn7pPxU50ce4qzPSlcSy+/pXx95xLSeI1zb8uHL0LFZbmPbxwNv75x2bNnz5J6v9Y69+sdyh2//jG5c/eFtaS+7+qYs48TUj0B1bHyBUfl8Tuv/XGyWmdwW7gKXUf/htwvpnK/xqXPkHrbJSTB1Eoai6OyuDx8yzK+YYWnqFL4zTj+cDvApbi/xWV6OzbU6Wf8eeacYnTu/o76SUjD2uu+Eo7jX4Ljt50Dfn5Uctcgd51evHiRvWbhqal/BMvbeVn4bO/cnqAy94W1NM2jhjl7f0Ia5wueI/TNyWqdwW3hKu7v8p/zuL87/fyo0Nv7Kp/TtSTB1EoaixM+o+VlOXRDkwCuRb6V8y9tinECEtrJN8OxK2ZPcbYn6bq0vjZ+39E7M/G35mP0RM+T1YDWPH5LWcfuB0ckdw28TPft+LsCjq+R8D5yZXpYofXyZFZs6XeTX9dw7wUTIQ9w9GVoJaT6knQup+gPX7ASbgvdkgRTK2ksACOypzjbk3RdWl8b7jv7JvjI2mzpd9OYoQZfsBJuC92SBFMraSwAI7KnONuTdF1aXxvuO/skvNW+1fps6XfTuKEGX7ASbgvdkgRTK2ksACOypzjbk3RdWl8b7jvHZEu/m/waavAFK+G20C1JMLWSxgIwInuKsz1J16X1teG+c0y29LvJr6EGX7ASbgvdkgRTK2ksACOypzjbk3RdWl8b7jvHZEu/m/waavAFK+G20C1JMLWSxgIwInuKsz1J16X1teG+c0y29LvJr6EGX7ASbgvdkgRTK2ksACOypzjbk3RdWl8b7jvHZEu/m/waavAFK+G20C1JMLWSxgIwInuKsz1J16X1teG+c0y29LvJr6EGX7ASbgvdkgRTK2ksACOypzjbk3RdWl8b7jvHZEu/m/waavAFK+G20C1JMLWSxgIwInuKsz1J16X1teG+c0y29LvJr6EGX7ASbgvdkgRTK2ksACOypzjbk3RdWl8b7jvHZEu/m/waavAFK+G20C1JMLWSxgIwInuKsz1J16X1teG+c0y29LvJr6EGX7ASbguL+MoL/sz9Xb5cZV6eK7uWJJhaSWPZknfv3n18+fKlFwMsxn1VvqV/dSjl2FOc7Um6Lq2vja9lDWv2Bduypd9Nfn0t2tu/8MII3/t1Hl7zx1bXL75gJdwWFpG7fnNOrDJ3wLm215AEUytpLFvx6NGjcM28CmAxsR8Fvyr97+09xdmeFK6Xl99SufW6ljX7gm3Z0u8mv76Wkr3XhXPlCL/I1PeLL1gJt4VFBAfystx19bLQzsuvJQmmVtJYtkD9KiF9+/btZq8BxyL2I/cpnfuT0j3F2Z6k69L62vj61bBmX7AtW/rd5NfXoqejc/Yq/0l0nGunsv6flPqClXBbWMS3d6eO9MPpXI4YnE3kHC4+97prSIKplTSWyL8+vnjx4uQ8rg9l4smTJw/1QW/evDlpK0hI4RzuR+LZs2efjoOfhZ9zqE42Xub+jvabkLoffPjwIakLT8T1y25c5+1ivP758+fJ6+jn48ePP/18/fr1SXtXD2icr169SsrCdQtz8XcYcnPU9VL8hfr4nS8pXiePW9nGqMx9YS1N46lB9t+zsvAENLDG6+yXk9U6g9vCIuRo7li/jI7j8jhB/WYqC6yxDkkwtZLGEvBNX8fS+/fvP53rBhfq9TN+IhVuUg4JKZwj+JmXxbhvOrm6PcXZnhSut5ffUr5eSmRC0iN0zwltQtIUE5/78bm28S8u3j537omxP4nfIyHJjvF5xYRE9RK7OGGP94RQH5M7d19YS9Pa1RAeUsXo/OfRecgjpP6fiDonq3UGt4XF6BreR8dxee44nP/IzpWk1pAEUytpLOZjn36GDUE3HD05CHXxphGjLy55X4KEFM4h/3Af8fO5MqGnMP4kRuwpzvakcL29/JbytfTzmNx9R2UhMYxtz/mS1/mX4jz59fa5/veKj9Pn5U9QA+fsnFDm1y6H6t0X1tK0NrV4H34eiD87utZrt8cXrITbwmJix4mv59xxOA/fsJf0VNXbLCUJplbSWMzHPv3Ub8zh2/GhLG4bfjN2OSSkcI6c7/j5XNnck3mxpzjbk8L19vJbytfMz2NU53+pI/aZ2PacL3mdkqi4b0+qvH2u/72icYanmf5Lm/5CRZiLFD8Fjtueux5x2SXXRvXuC2tpev1a1Ed48ln6XKmjdvGT1D7xBSvhtrCY4GCeVMqRgkPFTqXPneo3IUdt58q7k/nYw+eA4rL4px8Lv3EFSEjhHHN+6MRl2mh1Hm+kjvv5CPJN+Bp5n63kazWH6vxt8rgstj3Xt9eNnJCGGBHnxuz1c3Z+HpfNvUsWE67fTpTjy7vv6nJt/DOmAf9IYJ/4gpVwW7iK4Iz6vEiu3Mty+Aedl5JsEq2kscSEt+rjch3rRh3eug9lMW4TICGFc+R8x8/9M6Q6LiWjYk9xVqtwjby8V/n6KnmK7y/xZxk9SRTuC/FxfO73H+9n5IRUaKz+uVB/4CBCu/g8Tmjjcufc9fJz94W1NK3NGqifuaejKvvaC+/SL033yclqncFt4SrmHNfL9bnRXLtAqe4cSTC1ksbiqCwu17fnde43LCm+ucV24dgF4OR8w79dH74ZHXC/yvWhc/f3XhXm5+W9ytcqrJcUPoahZNLrwv1m7lv2IfkKfuMf6fDXVQIav5U9YkIqxcl+XK6/qpKbU4i3+AtMwtt5WfhLBeE6xuskVOa+sJameaxBeAc11194giopMX24fnGjbjlZrTO4LVyFfvO598K7z2XS3Llz7wULSIKplTQWRxuBP32KN4eAnizEN3PZhA/Kq31OAM6cb6hMG5s+7xbOhfzM/SrXx57irFaay2jzyaF7SrzmuTr/83K+7vIPtQvJVFzvbfU64a+IhPNS+5yf7ZkQKzmUjMbfFXBya5Try8u0B8TXP2ZLH55iZC3uvcC4v/ucuEo6HgNfsBJuC92SBFMraSwAI7KnOKuV5jLafGC/aH1yf7mili19eIoRqMEXrITbQrckwdRKGgvAiOwpzmqluYw2H9gf4a32rdZnSx+exg01+IKVcFvoliSYWkljARiRPcVZrTSX0eYDx2NLH55iBGrwBSvhttAtSTC1ksYCMCJ7irNaaS6jzQeOx5Y+PMUI1OALVsJtoVuSYGoljQVgRPYUZ7XSXEabDxyPLX14ihGowReshNtCtyTB1EoaC8CI7CnOaqW5jDYfOB5b+vAUI1CDL1gJt4VuSYKplTQWgBHZU5zVSnMZbT5wPLb04SlGoAZfsBJuC92SBFMraSwAI7KnOKuV5jLafOB4bOnDU4xADb5gJdwWuiUJplbSWABGZE9xVivNZbT5wPHY0oenGIEafMFKuC10SxJMraSxAIzInuKsVprLaPOB47GlD08xAjX4gpVwW+iWJJhaSWMBGJE9xVmtNJfR5gPHY0sfnmIEavAFK+G20C1JMLWSxgIwInuKs1ppLqPNB47Hlj48xQjU4AtWwm3hIn78Z33lhXefy1TnqPyLSb+cpLL7qE0tSTC1ksayFrm+3r179/Hly5deDLA5e4qzWmkuo80HjseWPjzFCNTgC1bCbeEivneXd9Q5Bw5l99NxTrUkwdRKGstaeF+PHj16uGYAt2ZPcVarEEde3qu4JxyTLX14ihGowReshNvCxfi10xPPnAP/KCq7j45jgu29lS8hCaZW0lgCb9++/c7ZPn5+uullOv/w4cPD+bNnzx6O4750/P79+0/t43KAW7GnOKuV5jLafOB4bOnDU4xADb5gJdwWLkbX7id2rrfr9TN+O1/nSkrF/XSeo9b5k2BqJY0l8q+PL168ODmP60OZiJ9+Sq9fv07aChJSaMWe4qxWIc68vFdxTzgmW/rwFCNQgy9YCbeFi9HnQePrF47jJ6Jxubi385hf3M3XXUISTK2ksQSePHlycq5jSU86xatXrx7q9VNPUL2tQ0IKrdhTnNUqxJeX9yruCcdkSx+eYgRq8AUr4bawiPj6XXJ8b+cx4W37a0mCqZU0FvOxTz+VhOpYSejjx48f6pS0xu0Cc4nnXDnA1uwpzmqluYw2HzgeW/rwFCNQgy9YCbeFRej63d99flr6tZWLb6JjcW/nMbXOnwRTK2ks5mMPP8PnR+OygNvNlZGQQiv2FGe10lxGmw8cjy19eIoRqMEXrITbwiKCwyoZ1TfvA3r7PXwTP/6c6f1UlkPl+nNQzsPG0ZPMxz59USkuD8e5ssBc4jlXDrA18jvftHpViFUv71XcE47Jlj48xQjU4AtWwm1hET+8m27qXnH3OUn18vtMmZjrYwlJMLWSxhIT3qqPy3X89OnTh7fuQ1n4bGk4974ECSm0Yk9xVqsQX17eq7gnHJMtfXiKEajBF6yE28Ji5pw2V34flceKn6JeSxJMraSxOCpTAhrQn3nydvpCk8qCRNwmrvN2ALdgT3FWqxA/Xt6ruBccky19eIoRqMEXrITbQrckwdRKGgvAiOwpzmqluYw2HzgeW/rwFCNQgy9YCbeFbkmCqZU0FoAR2VOc1UpzGW0+cDy29OEpRqAGX7ASbgvdkgRTK2ksACOypzirleYy2nzgeGzpw1OMQA2+YCXcFrolCaZW0lgARmRPcVYrzWW0+cDx2NKHpxiBGnzBSrgtdEsSTK2ksYxO/AWtlqwxDvUR/kOWvmymP9EFefYUZ7XSXEabDxyPLX14ihGowReshNtCtyTB1Eoay8hofmskgmtQe61lL718+fLhLx/sZW57ZE9xVquw9l7eq2pjAU4J/8Rk72zpw1OMQA2+YCXcFrolCaZW0lhGRf/2dE/zqx1LbK9EtLa/0dlTnNVKcxltPrAevVzPLX14ihGowReshNtCtyTB1Eoay4iEhC1I6GdIUuN5x+309DFGZU+ePHmo19vl4elkqIt59OhR8rqBeBxen/sHAnHSGdu4Aude+/nz5yfl3mY0ND/3914V1tTLe9UefS83JpUprkR8H4hjLeDxF//jkEuIbX0sfj53bwh4+72gcbkvrKXpGkANvmAl3Ba6JQmmVtJYRkXJZTw/Heu/Tfl/mIrf7vLroXMlciL+ZwDxedy29jymVO9PSHNtS+ehbGQ0P/f3XhXWz8t71R59T2N6/fp1UhYf65dRoXY6jz8yE7cNyeuleHzmzmNy8R/j53thSx+erhnU4AtWwm2hW5JgaiWNZVRyCem5+ao+fkrq7XPnIaH1ulAWNjEdv3jxIqkX556Qivi4VJcry9WPjubs/t6rNJfR5rM3wr9NjgnnuY//6Lz0GW5vXyLXthS/uXtbD2zpw1OMQA2+YCXcFrolCaZW0lhGJXfT9g3E/wWqtDQhDe29H+/PbUOZxlCTkAbbnALe9xHQnN3fe1VYTy/vVXv1R4+Z8BctFG+5Xya9vesS/D4VUJliO3dvcBuv3ytb+vB0zaEGX7ASbgvdkgRTK2kso5K7accJ6dwTkaUJaekJaUyuPpTlNh19vMDHH4gT0tw8nHP1I6I5u7/3Ks1ltPnsEY0rfETH481/mQ1rIjxWQ/0l5J6+CpXNJaT6c29xmdfvlS19eFoPqMEXrITbQrckwdRKGsuonEtI/Qmk0HlNQhrens+h+rnPqOWSSp37+AM+9kte+2hozu7vvSr4gpf3qr36Y0gOPR79XiLi+NTP8DRVhM+YXkqurcd3TPza4bwHtvTh6ZpADb5gJdwWuiUJplbSWEbFNxEdxwmpP3nIfXPWr0/p3G1z32o/dx4S1jB2rw/kEtL4/JInKLmykdD83N97VVhfL+9Ve/a9cK311NPL/UtNYR76Gb6NH86lN2/ePJSViPuaOw9PbvXa4V4V18f4+V7QuNwX1tJ0zaAGX7ASbgvdkgRTK2kso6Ibtz8R9c+BhSch8XXQRhTs/G263Hn8ZCT+k1Dxk1YRbEOi6mMRwVb95MYfkK2PJZ7L3GufKxuJPcVZrcK6enmv2vN9R7/MzcWGykOd5hC3C9+sD2Xh8+nx/aFEnOTmEtnSvcHf9p8bf2u29OHp+kANvmAl3Ba6JQmmVtJYAEZkT3FWK81ltPn0hv+S1+McWrOlD08xAjX4gpVwW+iWJJhaSWMBGJE9xVmtNJfR5tMbYQ387fpzhC8mzelIbOnD05pADb5gJdwWuiUJplbSWABGZE9xVivNZbT59IqSyNIXCGGeLX14ihGowReshNtCtyTB1EoaC8CI7CnOaqW5jDYfOB5b+vAUI1CDL1gJt4VuSYKplTQWgBHZU5zVSnMZbT5wPLb04SlGoAZfsBJuC92SBFMraSwAI7KnOKuV5jLafOB4bOnDU4xADb5gJdwWuiUJplbSWOB26Ju6/iddVFb7Z1r0uTb96Rf4jj3FWa00l9HmA585dy3O1ffElj48xQjU4AtWwm2hW5JgaiWNBbZH19kVqElIw986lNRH+Anbbn63VlhjL+9V3He+49y1GOmb+Fv68BQjUIMvWAm3hW5JgqmVNBbYHr/OOg9/MLsmIVU/8b8j9X95eGT2FGe10lxGmw985kjXYksfnmIEavAFK+G20C1JMLWSxnJ0wr/ZzP27zVjxn3oJ7eL63HnAn3KoPv43oXFCqv8U5fZz+LhCGWy7+d1awae8vFe19FG9tn+8Jf43v/F/W4vjOhD/HVJp6S+TsW14hyOui18/lMU/Y1SW+5elUvyLqu4/4R2UXD+3Qq/tvrCWprlBDb5gJdwWuiUJplbSWI5O+L/x8X9i0Xl8bcImFNcrgY3P43r/V35OXBcnpPHGeAlzSTRsu/ndWmFdvbxXtfRRjxmh8/CvfHWsdxriOo8x/+XU/4vTHN6X3ye8PpQJjVv/njRX58fhPMxJCamPuwUag/vCWpquHdTgC1bCbaFbkmBqJY3l6ISE9BxxG2+vc9+UvE1ASWf8hCYkpJ70Xkp4ohoEn9lTnNUqrK2X96rWfuqvH85z94Jz71gsiTu18y81xrY69qTR6wPhSarIjTsuCwlpazQG94W1NK0D1OALVsJtoVuSYGoljeXo5G7mQmWuuC5G57m35R29veblen09+VC5Nr8lyCZ+UruXjWcP7CnOahX8z8t7VWsf1euHdyXimAxva8f4/SE8YXVdQq5dXLakXsfhnhO/He8Se7kvaAzuC2tpmi/U4AtWwm2hW5JgaiWN5ej4hiN0rieZXpY7DuelhDQ8/fSnHyJ+/bk2c/g4QpmP/YjsKc5qpbmMNp+WxE8X47Hk7gVxkhrWISZXNofale4TuX68Pjfu3McQYkhI4SJ8wUq4LXRLEkytpLEcndwmpPNznyOL0fm5jWYu0Yw/QxpvlJeQa+tjPyp7irNaBf/z8l6V89tbE2IyHoufizj24+Nc/TnULn4XxF8v109ufLmP9/h5/EspCSlchC9YCbeFbkmCqZU0lqMzl5BK+ryXfoYNIHxONNd+7jOk8d8KdYk4IQ123v8coa36CJvOpbajo+vg/t6rwrp6ea/ag4+Gz4aGL/4EwrUOXzCM7w/hWPHqb5Nf8ktgsNdrxm/9B3LXxcuCzdy4dc8K9yv/pbo1GoP7wlqa5g81+IKVcFvoliSYWkljOTq6eef+dEvYcMJNXQlfaOftdR7+rmhcJrRxhA3MJfT6vrmozhPcOeJE9FKbI7CnOKtVWF8v71V7ue94HAfiXxL9F9aQ7MWf3VZbf4dkjmAfnpTGY8iNx8uUKHtZICTRues7Z3NLtvThad5Qgy9YCbeFbkmCqZU0FoAR2VOc1UpzGW0+e0Vji9/u1rn/uSW4ji19eIoRqMEXrITbQrckwdRKGgvsE61NSTwNLbOnOKtVWHMv71V7vu+Eb93HugS3cRGv28bkdJ2hBl+wEm4L3ZIEUytpLAAjsqc4q5XmMtp89s4lnwmFZWzpw1OMQA2+YCXcFrolCaZW0lgARmRPcVYrzWW0+cDx2NKHpxiBGnzBSrgtdEsSTK2ksQCMyJ7irFaay2jzgeOxpQ9PMQI1+IKVcFvoliSYWkljARiRPcVZrTSX0eYDx2NLH55iBGrwBSvhttAtSTC1ksYCMCJ7irNaaS6jzQeOx5Y+PMUI1OALVsJtoVuSYGoljQVgRPYUZ7XSXEabDxyPLX14ihGowReshNtCtyTB1EoaC8CI7CnOaqW5jDYfOB5b+vAUI1CDL1gJt4VuSYKplTQWgBHZU5zVSnMZbT5wPLb04SlGoAZfsBJuC92SBFMraSwAI7KnOKuV5jLafOB4bOnDU4xADb5gJdwWuiUJplbSWABGZE9xVivNZbT5wPHY0oenGIEafMFKuC10SxJMraSxAIzInuKsVprLaPOB47GlD08xAjX4gpVwW+iWJJhaSWMBGJE9xVmtNJfR5gPHY0sfnmIEavAFK+G20C1JMLWSxgIwInuKs1ppLqPNB47Hlj48xQjU4AtWwm2hW5JgaiWNBWBE9hRntdJcRpsPHI8tfXiKEajBF6yE20K3JMHUShoLwIjsKc5qpbmMNh84Hlv68BQjUIMvWAm3hW5JgqmVNBaAEdlTnNVKcxltPnA8tvThKUagBl+wEm4L3ZIEUytpLAAjsqc4q5XmMtp84Hhs6cNTjEANvmAl3Ba6JQmmVtJYAEZkT3FWK81ltPnA8djSh6cYgRp8wUq4LXRLEkytpLEAjMie4qxWmsto84HjsaUPTzECNfiClXBb6JYkmFpJYwEYkT3FWa00l9HmA8djSx+eYgRq8AUr4bbQLUkwtZLGAjAie4qzWmkuo80HjseWPjzFCNTgC1bCbaFbkmBqJY0FYET2FGe10ly2mk/oO9a5Nl6/VNx3jskavjOnyTehBl+wEm4L3ZIEUytpLAAjsqc4q5Xmcov5/OabP378/pc/SMrXfm3uO8dkbT+KNcUI1OALVsJtoVuSYGoljQVgRPYUZ7XSXG4xn/g15o7XEPedY7K2H8WaYgRq8AUr4bbQLUkwtZLGAjAie4qzWmkuW89H/f/2D39KykNdUO4J6lJtcd959+7dx7dv33ox7IgtfXjyT6jBF6yE20K3JMHUShoLwIjsKc5qpblsPZ9L+7+0XUlb3HeePn26Sb+jEa6T68WLF950ddbwnTlN86ghuSaTvogbDY0vWAm3hW5JgqmVNBaAEdlTnNVKc9lyPv/40599kpfntMY4trjvkJBeRrhO8dNkJaPBx9Yi19cavjOnafw1yP5+ktDPb6fyX05la1A7zu3wBSvhttAtSTC1ksYCMCJ7irNaaS5bzifXd1ymYyWsP3vxH9m2S+X3HSVJL1++/Pj48eOTunAuPX/+PLL4TKhTQkVCehml66Ty9+/fP5y/efPm4Rq7jZ/HZbGN1jWud19YS9Pr1TBn/9VdWhcSVekXUfmPprIYnd9Piq/N/nhYqQtwW+iWJJhaSWMBGJE9xVmtNJct5/Or3/3+bJnO9S18b3eN/L6jJEkJp8pDAhPmHBKkcB7Q8ZMnTz4d66fXQ55zCWkgrEd4kurXN9fHJfXuC2tpGl8Nc/Y/vzuti1/ry+lYCaq4j+oCOle5yCW3+8EXrITbQrckwdRKGgvAiOwpzmqluYw2n5hckuTncVlIlrzOyyAld62FXz8d+1Npr3cuqXdfWEvT+GvI2Ycnnt9M5yEBjflhVHYfHQd0rnJBQgq7IwmmVtJYAEZkT3FWK81ltPnEKEmSYsKcXXFdrj2UmftS04cPH07a5a5lXHZtvfvCWprmUUNyTe6+S0QD+ixp7nVCWS7hlM39dJyr3w++YCXcFrolCaZW0lgARmRPcVYrzWU0xYTPgMZ4m5hcH7kySMk9IdX5s2fPkjInLru2fkdyLim7JiHV+f10nKvfD75gJdwWuiXZcFpJYwEYkT3FWa00l9EUo8+NLklI/ctPItcvpOQS0levXiVlOtffdvWy+Dj+pn74AlRc77gPNJYzVxaX5760JEJZrl7n99MxCSnsjmTDaSWNBWBE9hRntdJcRptPzFxCGr60JDyR0nH4wpPebg7XCMr4dQz49fPz169fJ/X6xSA+93pHZe4La2l6/Rrm7FWuRDI+1xed4vPYNj4Onzm9n87jz5vuD1+wEm4L3ZIEUytpLAAjsqc4q5XmMtp8YnIJqYj/7FOc/Ig4CZWt+vB+IWUuIRXhegZCEurlAV+bnG28rjp3X1hL01hqmLPPfZEpvi4/sbr7qVxSAhp/hlSsMdZteFipC3Bb6JYkmFpJYwEYkT3FWa00l9HmA8djSx+eYgRq8AUr4bbQLUkwtZLGAjAie4qzWmkuo80HjseWPjzFCNTgC1bCbaFbkmBqJY0FYET2FGe10lxGmw8cjy19eIoRqMEXrITbQrckwdRKGgvAiOwpzmqluYw2HzgeW/rwFCNQgy9YCbeFbkmCqZU0FoAR2VOc1UpzGW0+cDy29OEpRqAGX7ASbgvdkgRTK2ksACOypzirleYy2nzgeGzpw1OMQA2+YCXcFrolCaZW0lgARmRPcVYrzWW0+cDx2NKHpxiBGnzBSrgtdEsSTK2ksQCMyJ7irFaay2jzgeOxpQ9PMQI1+IKVcFvoliSYWkljARiRPcVZrTSX0eYDx2NLH55iBGrwBSvhttAtSTC1ksYCMCJ7irNaaS63mM/ca/z71/+16hi47xyTtfwnp8k/oQZfsBJuC92SBFMraSwAI7KnOKuV5rL1fEqvEZfPtVki7jvHZA3fmdPkv1CDL1gJt4VuSYKplTQWgBHZU5zVSnPZcj6h7/g15l5vrnyJuO8ckzV8Z05TjEANvmAl3Ba6JQmmVtJYAEZkT3FWK81ly/n83d//w6efl7zGr373+6RsqbjvHJNL/OtaTTECNfiClXBb6JYkmFpJYwEYkT3FWa00l63mE/dbeg3V/ct//jopv0bcd9ry6NGjB5+KtSZPnz71oqJ/1WqaQy2/uMtclz/ry7jRCvzIC3aBL1gJt4VuSYKplTQWgBHZU5zVSnPZaj6h71i5Nr/55o9J+bXivtOOsMYx79+/z5bXkOsr51traRp/DUo61ce9lX87la/JV16wC3zBSrgtdEsSTK2ksQCMyJ7irFaayy3mE7+GH+tt/SC3W6rcfefJkycP8/zw4cNJm3Ac6uPyoLdv3z6U5+pz5e/evXs4fv369UmbEXnx4kVyLQJKSv0avnnzpngNnVAW27x8+fKk3n1hLU2vV4Psv/DCCT05deJ5/jgq/+VdmnCGsak8ttsXDyt1AW4L3ZIEUytpLAAjsqc4q5Xmcov5xJ8P9eNYbrdUft8JT+j0M6xd3EbHz549+/j48eOHBCduozode/Kjt6ZFeIs6rsvZj45f1xLPnz//1DYkqW6b6+eSeveFtTSNr4Yl9mobktD76TygpHMuIRW5hHUf+IKVcFvoliSYWkljARiRPcVZrTSX0ebjaxWS0bgsPo4/k6hj70OEsnC9YpSslur9fEQ0Rz0lvQS11RNSL8sd58rm6t0X1tK0ptcSnlxeghJKb/vDqCyXcMbtc/X7wBeshNtCtyTB1EoaC8CI7CnOaqW5jDYfXysnLtNx/HZyuB45LamP8fMR0Rz9y0Z+feInok5cdm29+8JamsZ/Lfd3efv42iiRjMucUJZLOOP2ufp94AtWwm2hW5JgaiWNBWBE9hRntdJcRpOvlROX6Vif94zPczYB1ent/Tly9n4+Irl5x6hu64R0R3JyZQElkCSkMW4L3ZJsOK2ksQCMyJ7irFaay2jz8bXyLxXFbXQcPyGN337PEa5XTPyRgFy9n4+K5jn3tn18nXPtSmviH6PIXU+VuS+spWlNa5C9vlGf4+d33yWk+uyov9ZPorI4eQ3E7UlIYVckwdRKGgvAiOwpzmqluYw2n5jwbXclOOEb9nGbUBeTaxO+xOTn4UtTuS9EBfx8VMKXlfQEWddUiv8uqbcLT6a9Pj7XZ01zXxzTWvqTbfeFtTSNp5bQT/jCUvyt+Ji4zfem85j43O1DQiu7ffGwUhfgttAtSTC1ksYCMCJ7irNaaS6jzceJ/+yTiNvo2BPSUB6kBMqJ6+MnsPHrxGVHIr42kn+pTLx69eqkjRPKw8cj4ja63jqPP7Oqc/eFtTSNZQ2+uTu9Nrk/+STiNvpS01xd+PumMWuOdz0eVuoC3Ba6JQmmVtJYAEZkT3FWK81ltPmc45I20Bdb+vAUI1CDL1gJt4VuSYKplTQWgBHZU5zVSnMZbT5OmGP4LKL/ySHony19ePIfqMEXrITbQrckwdRKGgvAiOwpzmqluYw2nxz6jKcS0tzbx9A/W/rwFCNQgy9YCbeFbkmCqZU0FoAR2VOc1UpzGW0+cDy29OEpRqAGX7ASbgvdkgRTK2ksACOypzirleYy2nzgeGzpw1OMQA2+YCXcFrolCaZW0lgARmRPcVYrzWW0+cDx2NKHpxiBGnzBSrgtdEsSTK2ksQCMyJ7irFaay2jzgeOxpQ9PMQI1+IKVcFvoliSYWkljARiRPcVZrTSX0eYDx2NLH55iBGrwBSvhttAtSTC1ksYCMCJ7irNaaS6jzQeOx5Y+PMUI1OALVsJtoVuSYGoljQVgRPYUZ7XSXLacz7n+Q730b7/+bVK/VNx3jknJx2o1+SfU4AtWwm2hW5JgaiWNBWBE9hRntdJctprPr373+4+//cOfiv3HdaV2l4r7zjFZw3fmNMUI1OALVsJtoVuSYGoljQVgRPYUZ7XSXLaej/cfn//71/+VLb9W3HeOyRq+M6cpRqAGX7ASbgvdkgRTK2ksAD2w1Ff3FGe10ly2nk+pfz1FjdvF59fI11L/nUmaw9tDn5R8rFZTjEANvmAl3Ba6JQmmVtJYAHrAfVX/ZlJlXh7YU5zVKszTy9dUqX9PSL1+qXzNSEhvS/An14cPH7zp1eTWcw3fmdM0hxqS6zFpTX7pBbvCF6yE20K3JMHUShoLQA/EvqrjWDn2FGe1CvP08jVV6v8v/vKvLmp3qXzNSEhvS+56lmLpGnJ9reE7c5rGX0POfo1+Y9bsa318wUq4LXRLEkytpLEAtEQ+GCtXric3OV91m5g9xVmtwjy9fA359Q+vE7/e97/8wUPdb775Y9LHUvmahYQ0HsPz588f6uP2bpsr8/nAKblr8uLFi6Tcr+Pbt29P6pxQFtvonYy43n1hLU2vV0POPtevX5fvWV3MV1FZbLNPHlbqAtwWuiUJplbSWABaIh+U4rcLde6bX85X58rFnuKsVmGeXt6rfM1CMuo+cO44V6bj+GlryUeOSu56+HXy89evXyf1ziX17gtraRpvDTl7lf3czuN2X9u59xEnpMLr94UvWAm3hW5JgqmVNBaAlsgH3Q/9/P3790mZyNkG9hRntQrz9PJe5WsWEtIYnT979uzhOC53ltTDd3ETS09Ivc2bN2+Sstxxrmyu3n1hLU3zqCG5Jn/WfdxgKnNU9mV0HHNvZV6/L3zBSrgtdEsSTK2ksQC0RD7ofujnpbJcudhTnNUqzNPLe5WvWe4zpPHaxu3d1suCnQu+I3c9Hj16lFxHZ41694W1NK1zDTn7uN/76DhGZXoSGo5j7q3M6/eFL1gJt4VuSYKplTQWgJbIB90P/bxUlisXoe7W8hhbQ/4aIyhm7YQUysxdo7lrHjh3nS+p35GcXJlQuRLOL6ZjJ9SH4xjesofdk2w4raSxALREPuh+6OfhTzw5OdvAreMsjMXLUSpfs7m37MMXYuI6HcefLw5luWPIM3eNVB5+MdBx7m38+DheB1/D3GtsGR/q+66OOXuV30fH8ZeYQlnuOJyX6veFL1gJt4VuSYKplTQWgJbIB90Pda63EIU2PW+jRCX+O6ThPObWcRbG4uUola+3khmtd/hm/bt3707axMfxl2vCX1+I69WH2/rrHZ0QM69evfoUX+Ga5a6j1iLYzF1XfdY095a/1ifYhzL3hbU0jacG2euJ5g/vPieg4elm3G84D0npXL3Ql6H0d0e9/kd3aVK7Dx5W6gLcFrolCaZW0lgAWiIfzPlhKA91cZu4ztvFbdzft1QYg5ejVL5WSkiVID158mR2Lf08buf1ITmS/KMAkI8f/4VOhOQ/tyYilD9+/PjhPBBs/S8euC+spWksNSTX5O5zcuqEb9ZL31qdCHVKSO+n40CwVfn+eFipC3Bb6JYkmFpJYwEYkVvHmV7v1q/Zq7jvHJMt42OKP6jBF6yE20K3JMHUShoLwIjcOs70erd+zV7FfeeYbBkfU/xBDb5gJdwWuiUJplbSWABG5NZxpte79Wv2Ku47x2TL+JjiD2rwBSvhttAtSTC1ksYCMCK3jjO93q1fs1dx3zkmW8bHFH9Qgy9YCbeFbkmCqZU0FoARuXWc6fVu/Zq9ivvOMdkyPqb4gxp8wUq4LXRLEkytpLEAjMit40yvd+vX7FXcd47JlvExxR/U4AtWwm2hW5JgaiWNBWBEbh1ner1bv2av4r5zTLaMjyn+oAZfsBJuC92SBFMraSwAI3LrONPr3fo1exX3nWOyZXxM8Qc1+IKVcFvoliSYWkljQWhUub9vqRav2at8ndBx5L6wlqb+oQZPOku4LXRLEkwIob6luCa2EWqjKf6gBk86S7gtdEsSTAihvqW4JrYRaqMp/qAGTzpLuC10SxJMCKG+pbgmthFqoyn+oAZPOku4LXRLEkwIob6luCa2EWqjKf6gBk86S7gtdEsSTAihvqW4JrYRaqMp/qAGTzpLuC10SxJMCKG+pbgmthFqoyn+oAZPOku4LXRLEkwIob6luCa2EWqjKf6gBk86S7gtdEsSTAihvqW4JrYRaqMp/qAGTzpLuC10SxJMCKG+pbgmthFqoyn+oAZPOku4LXRLEkwIob6luCa2EWqjKf6gBk86S7gtdEsSTAihvqW4JrYRaqMp/qAGTzpLuC10SxJMCKG+pbgmthFqoyn+oAZPOku4LXRLEkwIob6luCa2EWqjKf6gBk86S7gtdEsSTAihvqW4JrYRaqMp/qAGTzpLuC10SxJMCKG+pbgmthFqoyn+oAZPOku4LXRLEkwIob6luCa2EWqjKf5qeIjhSD85afEZb/PVaXXHeNJZwm2hW5JgQgj1LcU1sY1QG03xV0POXsmmyr+NyjwJvZ/KcvZ94UlnCbeFbkmCCSHUtxTXxDZCbTTFXw1z9j+/O63zhDSwxhja4klnCbeFbkmCCSHUtxTXxDZCbTTFXw1z9uEpaWAuIf3ibr6PPvCks4TbQrckwYQQ6luKa2IboTaa4q+GnP03d5/L48+SziWkQnU/9sJu8KSzhNtCtyTBhBDqW4prYhuhNprir4aHGDZ9GTeaykoJ6b0XdoMnnSXcFrolCSaEUN9SXBPbCLXRFH815OznykoJab940lnCbaFbkmBCCPUtxTVCqBs5c2VervNcQppr2xeedJZwW+iWZDNDCCGE0HXSvuob7ULm7FX+tZ3HCWn40tOcfT940lnCbaFbkmBCCCGE0HXSvuob7ULm7HPfsnfFf6e0XzzpLOG20C1JMCGEEELoOmlf9Y0WFuJJZwm3hW5JggkhhBBC10n7qm+0sBBPOku4LXRLEkwIIYQQuk7aV32jhYV40lnCbaFbkmBCCCGE0HXSvuobLSzEk84SbgvdkgQTQgghhK6T9lXfaGEhnnSWcFvoliSYEEIIIXSdtK/6RgsL8aSzhNtCtyTBhBBCCKHrpH3VN1pYiCedJdwWuiUJJoQQQghdJ+2rvtHCQjzpLOG20C1JMCGEEELoOmlf9Y0WFuJJZwm3hW5JggkhhBBC10n7qm+0sBBPOku4LXRLEkwIIYQQuk7aV32jhYV40lnCbaFbkmBCCCGE0HXSvuobLSzEk84SbgvdkgQTQgghhK6T9lXfaGEhnnSWcFvoliSYEEIIIXSdtK/6RgsL8aSzhNtCtyTBhBBCCKHrpH3VN1pYiCedJdwWuiUJJoQQQghdJ+2rvtHCQjzpLOG20C1JMCGEEELoOmlf9Y0WFuJJZwm3hW5JggkhhBBC10n7qm+0sBBPOku4LXRLEkwIIYQQuk7aV32jhYV40lnCbaFbkmBCCCGE0HXSvuobLSzEk84SbgsAAAAAUI0nnSXcFgAAAACgGk86S7gtAAAAAEA1nnSWcFsAAAAAgGo86SzhtgAAAAAA1XjSWcJtAQAAAACq8aSzhNsCAAAAAFTjSWcJtwUAAAAAqMaTzhJuCwAAAABQjSedJdwWAAAAAKAaTzpLuC0AAAAAQDWedJZwWwAAAACAajzpLOG2AAAAAADVeNJZwm0BAAAAAKrxpLOE2wIAAAAAVONJZwm3BQAAAACoxpPOEm4LAAAAAFCNJ50l3BYAAAAAoBpPOku4LQAAAABANZ50lnBbAAAAAIBqPOks4bYAAAAAANV40lnCbQEAAAAAqvGks4TbAgAAAADU8v8B5fHipH6pqsUAAAAASUVORK5CYII=>