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
	mov	rbx, %1		;rbx = x (for later)
	round	%1		;x <- round(x) = xend = xpx
	;calculate yend
	mov	rax, %1		;rax = xend
	sub	rax, rbx	;rax = xend - x
	imul	r11		;edx:eax = slope * (xend - x)
	shrd	eax, edx, 16	;shift result back to place
	lea	%2, [%2+rax]	;y <- y + slope * (xend - x) = yend
	;calculate xgap
	lea	rcx, [rbx+0x8000]	;rcx = x + 0.5
	%3	rcx			;rcx = (r)frcprt(x + 0.5) = xgap
	;calculate ypx, xpx
	mov	rdx, %2		;rdx = yend
	intprt	rdx		;rdx = intprt(yend) = ypx
	mov	rbx, %1		;rbx = xpx
	;calculate first bufpos
	test	r13, r13	;if steep
	mov	rax, rbx	;rax = xpx
	cmovnz	rbx, rdx	;xpx <-> ypx
	cmovnz	rdx, rax	;xpx <-> ypx
				;now rdx = ycoord, rbx = xcoord
	shr	rbx, 16		;shift xcoord to place
	shr	rdx, 16		;shift ycoord to place

	imul	rdx, r12	;rdx = ycoord * [stride]		:move ycoord pixels "up"
	lea	rdx, [rdx+rbx]	;rdx = ycoord * [stride] + xpx	:move xcoord pixels "right"

	lea	rdx, [rdx+rdi]	;rdx += canvas			:make bufpos absolute
	;calculate the base color for this endpoint (will be used like color in main loop)
	imul	rcx, r9		;rcx = xgap * [color]
	round	rcx		;rcx = round(xgap * [color])
	shr	rcx, 16		;rcx = round(xgap * [color]) >> 16 = basecolor
	;calculate first color
	mov	rbx, %2		;rbx = yend
	rfrcprt	rbx		;rbx = rfrcprt(yend)
	imul	rbx, rcx	;rbx = rfrcprt(yend) * basecolor
	round	rbx		;rbx = round(rfrcprt(yend) * basecolor)
	shr	rbx, 16		;rbx = round(rfrcprt(yend) * basecolor) >> 16 = firstcolor
	;paint first pixel
	mov	[rdx], bl
	;calculate second bufpos
	mov	rax, rdx	;rax = rdx = old_bufpos
	lea	rdx, [rdx+r12]	;rdx = old_bufpos + [stride], which is old_bufpos moved "up" by 1px
	inc	rax		;rax = old_bufpos + 1, which is old_bufpos moved "right" by 1px
	test	r13, r13	;if steep => rdx <- rax
	cmovnz	rdx, rax	;rdx = bufpos
	;check if out of bounds
	cmp	rdx, r10
	jae	%%end
	;calculate second color
	sub	rcx, rbx	;rcx = basecolor - firstcolor = secondcolor
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
	mov     rax, r8
	sub     rax, r14
	mov	rbx, rax
	neg	rbx
	cmovns	rax, rbx	;rax = abs(y1-y0)

	mov	rbx, r15
	sub     rbx, rsi
	mov	rcx, rbx
	neg	rcx
	cmovns	rbx, rcx	;rbx = abs(x1-x0)

	xor	r13, r13
	cmp	rax, rbx
	mov	rcx, 1
	cmovg	r13, rcx	;r13 = steep

;	swap endpoints if needed

	;if steep:	x <-> y
	jng	no_steep
	xchg	rsi, r14	;x0 <-> y0
	xchg	r15, r8		;x1 <-> y1
	;endif
no_steep:

	cmp	rsi, r15
	;if x0>x1:	_0 <-> _1
	jng	x0gx1
	xchg	rsi, r15	;x0 <-> x1
	xchg	r14, r8		;y0 <-> y1
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
	mov	r11, rax

;	handle first endpoint
	endpnt	rsi, r14, rfrcprt

;	handle second endpoint
	endpnt	r15, r8, frcprt

;	main loop (for x from xpx0+1 to xpx1-1)
	shr	rsi, 16		;shift x to be regular int
	shr	r15, 16		;shift xpx1 to be regular int

	inc	rsi		;x++
	lea	r14, [r14+r11]	;move y to next intersection

	test	r13, r13	;if steep
	jnz	steep_loop
loop:
	;calculate first bufpos
	mov	rcx, r14	;rcx = y
	intprt	rcx		;rcx = intprt(y) = ypx
	shr	rcx, 16		;shift ypx to place

	imul	rcx, r12	;rcx = ypx * [stride]		:move ypx pixels "up"
	lea	rcx, [rcx+rsi]	;rcx = ypx * [stride] + xpx	:move xpx pixels "right"

	lea	rcx, [rcx+rdi]	;rcx = bufpos			:make bufpos absolute
	;calculate first color
	mov	rdx, r14	;rdx = y
	rfrcprt	rdx		;rdx = rfrcprt(y)
	imul	rdx, r9		;rdx = rfrcprt(y) * [color]
	round	rdx		;rdx = round(rfrcprt(y) * [color])
	shr	rdx, 16		;rdx = round(rfrcprt(y) * [color]) >> 16 = firstcolor
	;paint first pixel
	mov	[rcx], dl
	;calculate second bufpos
	lea	rcx, [rcx+r12]	;rcx = old_bufpos + [stride] = bufpos	:move 1px "up"
	;check if out of bounds
	cmp	rcx, r10
	jae	dont_paint
	;calculate second color
	neg	rdx		;rdx = -firstcolor
	lea	rdx, [rdx+r9]	;rdx = [color] - firstcolor = secondcolor
	;paint second pixel
	mov	[rcx], dl
dont_paint:
	;move to next intersection
	lea	r14, [r14+r11]	;y += [slope]

	inc	rsi		;x++
	cmp	rsi, r15	;do until x < x1
	jne	loop
	jmp	end

steep_loop:
	;calculate first bufpos
	mov	rdx, r14	;rdx = y
	intprt	rdx		;rdx = intprt(y) = ypx
	shr	rdx, 16		;shift ypx to place

	mov	rcx, rsi	;rcx = x = xpx

	imul	rcx, r12	;rcx = xpx * [stride]		:move xpx pixels "up"
	lea	rcx, [rcx+rdx]	;rcx = xpx * [stride] + ypx	:move ypx pixels "right"

	lea	rcx, [rcx+rdi]	;rcx = bufpos			:make bufpos absolute
	;calculate first color
	mov	rdx, r14	;rdx = y
	rfrcprt	rdx		;rdx = rfrcprt(y)
	imul	rdx, r9		;rdx = rfrcprt(y) * [color]
	round	rdx		;rdx = round(rfrcprt(y) * [color])
	shr	rdx, 16		;rdx = round(rfrcprt(y) * [color]) >> 16 = firstcolor
	;paint first pixel
	mov	[rcx], dl
	;calculate second bufpos
	inc	rcx		;rcx = old_bufpos + 1 = bufpos	:move 1px "right"
	;check if out of bounds
	cmp	rcx, r10
	jae	dont_paint_steep
	;calculate second color
	neg	rdx		;rdx = -firstcolor
	lea	rdx, [rdx+r9]	;rdx = [color] - firstcolor = secondcolor
	;paint second pixel
	mov	[rcx], dl
dont_paint_steep:
	;move to next intersection
	lea	r14, [r14+r11]	;y += [slope]

	inc	rsi		;x++
	cmp	rsi, r15	;do until x < x1
	jne	steep_loop

end:
;	epilogue
	pop	rbx
	pop	r15
	pop	r14
	pop	r13
	pop	r12
	pop	rbp
	ret
