	global  line

	section .text

%macro	intprt	1
	and	%1, 0x7FFF0000
%endmacro

%macro	round	1
	lea	%1, [%1+0x8000]
	intprt	%1
%endmacro

%macro	frcprt	1
	and	%1, 0x0000FFFF
%endmacro

%macro	rfrcprt	1
	frcprt	%1
	neg	%1
	lea	%1, [%1+0x10000]
%endmacro

;draw line endpoint at (x, y) and save xpx to x
;arguments:
;1 - x (in register)
;2 - y (in register)
;3 - rfrcprt for x0, frcprt for x1
%macro	endpnt	3
	;calculate xend
	mov	ebx, %1		;ebx = x (for later)
	round	%1		;x <- round(x) = xend = xpx
	;calculate yend
	mov	eax, %1		;eax = xend
	sub	eax, ebx	;eax = xend - x
	imul	eax, r11d	;edx:eax = slope * (xend - x)
	shr	eax, 16		;shift result back to place
	lea	%2, [%2+eax]	;y <- y + slope * (xend - x) = yend
	;calculate xgap
	lea	ecx, [ebx+0x8000]	;ecx = x + 0.5
	%3	ecx			;ecx = (r)frcprt(x + 0.5) = xgap
	;calculate ypx, xpx
	mov	edx, %2		;edx = yend
	intprt	edx		;edx = intprt(yend) = ypx
	mov	ebx, %1		;ebx = xpx
	;calculate first bufpos
	test	r13d, r13d	;if steep
	mov	eax, ebx	;eax = xpx
	cmovnz	ebx, edx	;xpx <-> ypx
	cmovnz	edx, eax	;xpx <-> ypx
				;now edx = ycoord, ebx = xcoord
	shr	ebx, 16		;shift xcoord to place
	shr	edx, 16		;shift ycoord to place

	imul	edx, r12d	;edx = ycoord * [stride]		:move ycoord pixels "up"
	lea	edx, [edx+ebx]	;edx = ycoord * [stride] + xpx	:move xcoord pixels "right"

	lea	rdx, [rdx+rdi]	;rdx += canvas			:make bufpos absolute
	;calculate the base color for this endpoint (will be used like color in main loop)
	imul	ecx, r9d	;ecx = xgap * [color]
	round	ecx		;ecx = round(xgap * [color])
	shr	ecx, 16		;ecx = round(xgap * [color]) >> 16 = basecolor
	;calculate first color
	mov	ebx, %2		;ebx = yend
	rfrcprt	ebx		;ebx = rfrcprt(yend)
	imul	ebx, ecx	;ebx = rfrcprt(yend) * basecolor
	round	ebx		;ebx = round(rfrcprt(yend) * basecolor)
	shr	ebx, 16		;ebx = round(rfrcprt(yend) * basecolor) >> 16 = firstcolor
	;paint first pixel
	mov	[rdx], bl
	;calculate second bufpos
	mov	rax, rdx	;rax = rdx = old_bufpos
	lea	rdx, [rdx+r12]	;rdx = old_bufpos + [stride], which is old_bufpos moved "up" by 1px
	inc	rax		;rax = old_bufpos + 1, which is old_bufpos moved "right" by 1px
	test	r13d, r13d	;if steep => rdx <- rax
	cmovnz	rdx, rax	;rdx = bufpos
	;check if out of bounds
	cmp	rdx, r10
	jae	%%end
	;calculate second color
	sub	ecx, ebx	;ecx = basecolor - firstcolor = secondcolor
	;paint second pixel
	mov	[rdx], cl
%%end:
%endmacro

line:
;	prologue
	push	rbp
	mov	rbp, rsp
	push	r12
	push	r13
	push	r14
	push	r15
	push	rbx

;rdi:		bmp -> canvas
;rsi:		x0 -> xpx0
;r14<-rdx:	y0 -> y
;r15<-rcx:	x1 -> xpx1
;r8:		y1
;r9:		color	

;r10:		fend
;r11:		slope
;r12:		stride
;r13:		steep

;	body

;	read file metadata
	;calculate stride
	mov	ebx, [rdi+18]	;rbx = width
	lea	ebx, [ebx+3]	;rbx = width + 3
	and	ebx, ~3		;rbx = (width + 3)&(~3) = stride
	mov	r12, rbx	;r12 = stride

	;read size and calculate fend
	mov	ebx, [rdi+2]	;rbx = fsize
	lea	r10, [rdi+rbx]	;r10 = bmp + fsize = fend

	;add offset to bmp, now becomes canvas
	mov	ebx, [rdi+10]	;ebx = offset
	lea	rdi, [rdi+rbx]	;rdi = rdi + offset = canvas

;	move to free the 32bit registers
	mov	r14, rdx
	mov	r15, rcx

;	calculate steep
	mov     eax, r8d
	sub     eax, r14d
	mov	ebx, eax
	neg	ebx
	cmovns	eax, ebx	;eax = abs(y1-y0)

	mov	ebx, r15d
	sub     ebx, esi
	mov	ecx, ebx
	neg	ecx
	cmovns	ebx, ecx	;ebx = abs(x1-x0)

	xor	r13d, r13d
	cmp	eax, ebx
	mov	ecx, 1
	cmovg	r13d, ecx	;r13 = steep

;	swap endpoints if needed

	;if steep:	x <-> y
	jng	no_steep
	xchg	esi, r14d	;x0 <-> y0
	xchg	r15d, r8d	;x1 <-> y1
	;endif
no_steep:

	cmp	esi, r15d
	;if x0>x1:	_0 <-> _1
	jng	x0gx1
	xchg	esi, r15d	;x0 <-> x1
	xchg	r14d, r8d	;y0 <-> y1
	;endif
x0gx1:

;	calculate slope
	;prepare rdx options
	xor	rdx, rdx	;rdx = 0 when dy >= 0
	mov	rbx, -1		;rbx = 0xFFFF...FFFF when dy < 0

	;calculate dx and dy
	mov	rax, r8		;rax = y1
	sub	rax, r14	;rax = y1 - y0 = dy
	mov	rcx, r15	;rcx = x1
	sub	rcx, rsi	;rcx = x1 - x0 = dx

	shl	rax, 16		;move dy left for the correct precision after division

	;fill rdx with sign of rax
	cmovs	rdx, rbx	;if signed rdx = 0xFFFF...FFFF
	;divide
	idiv	rcx		;rax = dy/dx = slope
	;save slope
	mov	r11d, eax

;	handle first endpoint
	endpnt	esi, r14d, rfrcprt

;	handle second endpoint
	endpnt	r15d, r8d, frcprt

;	main loop (for x from xpx0+1 to xpx1-1)
	shr	esi, 16		;shift x to be regular int
	shr	r15d, 16	;shift xpx1 to be regular int

	test	r13d, r13d	;if steep
	jnz	steep_loop
loop:
	;move to next point
	inc	esi			;x++
	lea	r14d, [r14d+r11d]	;move y to next intersection

	;do until x < x1
	cmp	esi, r15d
	jae	end

	;calculate first bufpos
	mov	ecx, r14d	;ecx = y
	intprt	ecx		;ecx = intprt(y) = ypx
	shr	ecx, 16		;shift ypx to place

	imul	ecx, r12d	;ecx = ypx * [stride]		:move ypx pixels "up"
	lea	ecx, [ecx+esi]	;ecx = ypx * [stride] + xpx	:move xpx pixels "right"

	lea	rcx, [rcx+rdi]	;rcx = bufpos			:make bufpos absolute
	;calculate first color
	mov	edx, r14d	;edx = y
	rfrcprt	edx		;edx = rfrcprt(y)
	imul	edx, r9d	;edx = rfrcprt(y) * [color]
	round	edx		;edx = round(rfrcprt(y) * [color])
	shr	edx, 16		;edx = round(rfrcprt(y) * [color]) >> 16 = firstcolor
	;paint first pixel
	mov	[rcx], dl
	;calculate second bufpos
	lea	rcx, [rcx+r12]	;rcx = old_bufpos + [stride] = bufpos	:move 1px "up"
	;check if out of bounds
	cmp	rcx, r10
	jae	loop
	;calculate second color
	neg	edx		;edx = -firstcolor
	lea	edx, [edx+r9d]	;edx = [color] - firstcolor = secondcolor
	;paint second pixel
	mov	[rcx], dl

	jmp	loop

steep_loop:
	;move to next point
	inc	esi			;x++
	lea	r14d, [r14d+r11d]	;move y to next intersection

	;do until x < x1
	cmp	esi, r15d
	jae	end

	;calculate first bufpos
	mov	edx, r14d	;edx = y
	intprt	edx		;edx = intprt(y) = ypx
	shr	edx, 16		;shift ypx to place

	mov	ecx, esi	;ecx = x = xpx

	imul	ecx, r12d	;ecx = xpx * [stride]		:move xpx pixels "up"
	lea	ecx, [ecx+edx]	;ecx = xpx * [stride] + ypx	:move ypx pixels "right"

	lea	rcx, [rcx+rdi]	;rcx = bufpos			:make bufpos absolute
	;calculate first color
	mov	edx, r14d	;edx = y
	rfrcprt	edx		;edx = rfrcprt(y)
	imul	edx, r9d	;edx = rfrcprt(y) * [color]
	round	edx		;edx = round(rfrcprt(y) * [color])
	shr	edx, 16		;edx = round(rfrcprt(y) * [color]) >> 16 = firstcolor
	;paint first pixel
	mov	[rcx], dl
	;calculate second bufpos
	inc	rcx		;rcx = old_bufpos + 1 = bufpos	:move 1px "right"
	;check if out of bounds
	cmp	rcx, r10
	jae	steep_loop
	;calculate second color
	neg	edx		;edx = -firstcolor
	lea	edx, [edx+r9d]	;edx = [color] - firstcolor = secondcolor
	;paint second pixel
	mov	[rcx], dl

	jmp	steep_loop

end:
;	epilogue
	pop	rbx
	pop	r15
	pop	r14
	pop	r13
	pop	r12
	pop	rbp
	ret
