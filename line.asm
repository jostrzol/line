	global  line

	section .text

%macro	intprt	1
	and	%1, 0xFFFF0000
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
;1 - x
;2 - y
;3 - rfrcprt for x0, frcprt for x1
;esi - steep
;leaves: eax = yend
%macro	endpnt	3
	;calculate xend
	mov	ebx, %1		;ebx = x
	mov	edi, ebx	;edi = x (for later)
	round	ebx		;ebx = round(x) = xend = xpx
	;calculate yend
	mov	eax, ebx	;eax = xend
	sub	eax, edi	;eax = xend - x
	imul	dword[slope]	;edx:eax = slope * (xend - x)
	shrd	eax, edx, 16	;shift result back to place
	add	eax, %2		;eax = y + slope * (xend - x) = yend
	;calculate xgap
	lea	ecx, [edi+0x8000]	;ecx = x + 0.5
	%3	ecx			;ecx = rfrcprt(x + 0.5) = xgap
	;calculate ypx, xpx
	mov	%1, ebx		;save ebx = xpx to x
	mov	edx, eax	;edx = yend
	intprt	edx		;edx = intprt(yend) = ypx
	;calculate first bufpos
	test	esi, esi	;if steep
	mov	edi, ebx	;edi = xpx
	cmovnz	ebx, edx	;xpx <-> ypx
	cmovnz	edx, edi	;xpx <-> ypx
				;now edx = ycoord, ebx = xcoord
	shr	ebx, 16		;shift xcoord to place
	shr	edx, 16		;shift ycoord to place

	imul	edx, [stride]	;edx = ycoord * [stride]	:move ycoord pixels "up"
	lea	edx, [edx+ebx]	;edx = ycoord * [stride] + xpx	:move xcoord pixels "right"

	add	edx, [canvas]	;edx = bufpos			:make bufpos absolute
	;calculate the base color for this endpoint (will be used like color in main loop)
	imul	ecx, [color]	;ecx = xgap * [color]
	round	ecx		;ecx = round(xgap * [color])
	shr	ecx, 16		;ecx = round(xgap * [color]) >> 16 = basecolor
	;calculate first color
	mov	ebx, eax	;ebx = yend
	rfrcprt	ebx		;ebx = rfrcprt(yend)
	imul	ebx, ecx	;ebx = rfrcprt(yend) * basecolor
	round	ebx		;ebx = round(rfrcprt(yend) * basecolor)
	shr	ebx, 16		;ebx = round(rfrcprt(yend) * basecolor) >> 16 = firstcolor
	;paint first pixel
	mov	[edx], bl
	;calculate second bufpos
	mov	edi, edx	;edi = edx = old_bufpos
	add	edx, [stride]	;edx = old_bufpos + [stride], which is old_bufpos moved "up" by 1px
	inc	edi		;edi = old_bufpos + 1, which is old_bufpos moved "right" by 1px
	test	esi, esi	;if steep => edx <- edi
	cmovnz	edx, edi	;edx = bufpos
	;check if out of bounds
	cmp	edx, [fend]
	jae	%%end
	;calculate second color
	sub	ecx, ebx	;ecx = basecolor - firstcolor = secondcolor
	;paint second pixel
	mov	[edx], cl
%%end:
%endmacro

line:
;	prologue
	push	ebp
	mov	ebp, esp
	sub	esp, 16
	push	ebx
	push	esi
	push	edi

%define	bmp	ebp+8
%define	x0	ebp+12
%define	y0	ebp+16
%define	x1	ebp+20
%define	y1	ebp+24
%define	color	ebp+28

%define	slope	ebp-4
%define	canvas	ebp-8
%define	stride	ebp-12
%define	fend	ebp-16

;	body

;	read file metadata
	mov	eax, [bmp]
	
	;read canvas pointer
	mov	ebx, [eax+10]
	lea	ebx, [eax+ebx]
	mov	[canvas], ebx

	;calculate stride
	mov	ecx, [eax+18]
	lea	ecx, [ecx+3]
	and	ecx, ~3
	mov	[stride], ecx

	;read size and calculate fend
	mov	edx, [eax+2]	;edx = fsize
	lea	edx, [eax+edx]	;edx = [bmp] + fsize = fend
	mov	[fend], edx

;	calculate steep
	mov     eax, [y1]
	sub     eax, [y0]
	mov	ebx, eax
	neg	ebx
	cmovns	eax, ebx	;eax = abs(y1-y0)

	mov	ebx, [x1]
	sub     ebx, [x0]
	mov	ecx, ebx
	neg	ecx
	cmovns	ebx, ecx	;ebx = abs(x1-x0)

	xor	esi, esi
	cmp	eax, ebx
	mov	ecx, 1
	cmovg	esi, ecx	;esi = steep

;	swap endpoints if needed
	;load coords
	mov	eax, [x0]
	mov	ebx, [y0]
	mov	ecx, [x1]
	mov	edx, [y1]

	;if steep:	x <-> y
	jng	no_steep
	xchg	eax, ebx	;x0 <-> y0
	xchg	ecx, edx	;x1 <-> y1
	;endif
no_steep:

	cmp	eax, ecx
	;if x0>x1:	_0 <-> _1
	jng	x0gx1
	xchg	eax, ecx	;x0 <-> x1
	xchg	ebx, edx	;y0 <-> y1
	;endif
x0gx1:
	;save coords
	mov	[x0], eax
	mov	[y0], ebx
	mov	[x1], ecx
	mov	[y1], edx

;	calculate slope
	sub	edx, ebx	;edx = y1 - y0 = dy
	sub	ecx, eax	;ecx = x1 - x0 = dx

	;the division will be performed on unsigned values
	;only dy can be negative, so if it is - negate it
	;and remember that it was negative for later
	xor	ebx, ebx	;ebx = 0
	mov	edi, 1		;edi = 1
	mov	eax, edx
	neg	eax		;eax = -edx
	cmovns	edx, eax	;if negative => edx <- eax
	cmovns	ebx, edi	;and ebx = 1
	;the most dy/dx can be here is one due to the swaps before.
	;if it is one, there will be floating point error, so handle this
	;situation separately
	cmp	edx, ecx
	mov	eax, 0x10000
	je	after_div
	;divide
	xor	eax, eax
	div	ecx		;eax = dy/dx
	;shift slope to place
	shr	eax, 16
after_div:
	;negate back if division result should be negative
	mov	edx, eax
	neg	edx
	test	ebx, ebx
	cmovnz	eax, edx
	;correct slope: if dx == 0 => slope = 1
	test	ecx, ecx
	mov	edx, 0x10000
	cmovz	eax, edx
	;save slope
	mov	[slope], eax

;	handle first endpoint
	endpnt	[x0], [y0], rfrcprt
	;now eax = yend0
	;save yend0 to [y0]
	mov	[y0], eax

;	handle second endpoint
	endpnt	[x1], [y1], frcprt

;	main loop (for x from xpx0+1 to xpx1-1)
	mov	eax, [x0]		;eax = x
	lea	eax, [eax+0x10000]	;eax++
	mov	ebx, [y0]		;ebx = y
	add	ebx, [slope]		;move y to next intersection
	test	esi, esi		;if steep

	mov	esi, [stride]	;load [stride] for faster access
	mov	edi, [color]	;load [color] for faster access

	jnz	steep_loop
loop:
	;calculate first bufpos
	mov	ecx, ebx	;ecx = y
	intprt	ecx		;ecx = intprt(y) = ypx
	mov	edx, eax	;edx = x = xpx

	shr	edx, 16		;shift xpx to place
	shr	ecx, 16		;shift ypx to place

	imul	ecx, esi	;ecx = ypx * [stride]		:move ypx pixels "up"
	lea	ecx, [ecx+edx]	;ecx = ypx * [stride] + xpx	:move xpx pixels "right"

	add	ecx, [canvas]	;ecx = bufpos			:make bufpos absolute
	;calculate first color
	mov	edx, ebx	;edx = y
	rfrcprt	edx		;edx = rfrcprt(y)
	imul	edx, edi	;edx = rfrcprt(y) * [color]
	round	edx		;edx = round(rfrcprt(y) * [color])
	shr	edx, 16		;edx = round(rfrcprt(y) * [color]) >> 16 = firstcolor
	;paint first pixel
	mov	[ecx], dl
	;calculate second bufpos
	lea	ecx, [ecx+esi]	;ecx = old_bufpos + [stride] = bufpos	:move 1px "up"
	;check if out of bounds
	cmp	ecx, [fend]
	jae	dont_paint
	;calculate second color
	neg	edx		;edx = -firstcolor
	lea	edx, [edx+edi]	;edx = [color] - firstcolor = secondcolor
	;paint second pixel
	mov	[ecx], dl
dont_paint:
	;move to next intersection
	add	ebx, [slope]		;y += [slope]

	lea	eax, [eax+0x10000]	;x++
	cmp	eax, [x1]		;do until x < x1
	jne	loop
	jmp	end

steep_loop:
	;calculate first bufpos
	mov	edx, ebx	;edx = y
	intprt	edx		;edx = intprt(y) = ypx
	mov	ecx, eax	;ecx = x = xpx

	shr	ecx, 16		;shift xpx to place
	shr	edx, 16		;shift ypx to place

	imul	ecx, esi	;ecx = xpx * [stride]		:move xpx pixels "up"
	lea	ecx, [ecx+edx]	;ecx = xpx * [stride] + ypx	:move ypx pixels "right"

	add	ecx, [canvas]	;ecx = bufpos			:make bufpos absolute
	;calculate first color
	mov	edx, ebx	;edx = y
	rfrcprt	edx		;edx = rfrcprt(y)
	imul	edx, edi	;edx = rfrcprt(y) * [color]
	round	edx		;edx = round(rfrcprt(y) * [color])
	shr	edx, 16		;edx = round(rfrcprt(y) * [color]) >> 16 = firstcolor
	;paint first pixel
	mov	[ecx], dl
	;calculate second bufpos
	inc	ecx		;ecx = old_bufpos + 1 = bufpos	:move 1px "right"
	;check if out of bounds
	cmp	ecx, [fend]
	jae	dont_paint_steep
	;calculate second color
	neg	edx		;edx = -firstcolor
	lea	edx, [edx+edi]	;edx = [color] - firstcolor = secondcolor
	;paint second pixel
	mov	[ecx], dl
dont_paint_steep:
	;move to next intersection
	add	ebx, [slope]		;y += [slope]

	lea	eax, [eax+0x10000]	;x++
	cmp	eax, [x1]		;do until x < x1
	jne	steep_loop

end:
;	epilogue
	pop	edi
	pop	esi
	pop	ebx
	mov	esp, ebp
	pop	ebp
	ret