%include "x86inc.asm"
%include "transform_1_3_ssse3_x86-a.inc"


extern pshuffq_zero
extern pshuffd_zero
extern partial_bufferfly_8_t8
extern partial_bufferfly_inverse_8_t8
extern pshuffd_w
extern partial_bufferfly_8_t8_1
extern partial_bufferfly_8_t8_2

SECTION .rodata align=16

SECTION .text align=16

%macro			CALCULATE_E_O_PARTIAL_BUFFER_FLY8_SSSE3				5
%if %4 == E_O_FLAGS
	MATRIX_TRANSPOSE_SRC_SSSE3  0, 0, %5
	MOV r0, (7*SIZE_OF_ONE_EO)
	MOV K, 0
%%CALCULATE_E_O_PARTIAL_BUFFER_FLY8_SSSE3_K:
	CALCULATE_ONE_E_O_PARTIAL_BUFFER_FLY_SSSE3 %1, %2, TEMP_SRC, 0
	ADD K, SIZE_OF_ONE_EO
	SUB r0, SIZE_OF_ONE_EO
	CMP K, SIZE_OF_ONE_EO * 4
	JL %%CALCULATE_E_O_PARTIAL_BUFFER_FLY8_SSSE3_K
%else
	MOV r0, ( 3*SIZE_OF_ONE_EO)
	MOV K, 0
%%CALCULATE_E_O_PARTIAL_BUFFER_FLY8_SSSE3_K:
	CALCULATE_ONE_E_O_PARTIAL_BUFFER_FLY_SSSE3 %1, %2, %3, 0
	ADD K, SIZE_OF_ONE_EO
	SUB r0, SIZE_OF_ONE_EO
	CMP K, SIZE_OF_ONE_EO * 2
	JL %%CALCULATE_E_O_PARTIAL_BUFFER_FLY8_SSSE3_K
%endif
%endmacro

%macro			CALCULATE_DST_PARTIAL_BUFFER_FLY8_SSSE3					3
%if 8 == DCT_STEP
	%define		CDPBF8_DST						 TEMP_SRC
	%define		CDPBF8_STRIDE					 8
%else
	%define		CDPBF8_DST						 DST
	%define		CDPBF8_STRIDE					 LINE_LENGTH
%endif

%if %2 == FOUR_1_FLAGS
	%define		CDPBF8_START					 0
	%define		CDPBF8_INCREASE				 	 4
%elif %2 == FOUR_2_FLAGS
	%define		CDPBF8_START					 2
	%define		CDPBF8_INCREASE				 	 4
%elif %2 == TWO_FLAGS
	%define		CDPBF8_START					 1
	%define		CDPBF8_INCREASE				 	 2
%endif

	MOV K, SIZE_OF_INT16_T*CDPBF8_STRIDE*CDPBF8_START
	LEA TCOEFF, [partial_bufferfly_8_t8_1+(SIZE_OF_ONE_EO*2)*CDPBF8_START]
%%CALCULATE_DST_PARTIAL_BUFFER_FLY8_SSSE3_K:
	CLEAR_XMMR1_AND_XMMR2_SSSE3

%if %2 == FOUR_1_FLAGS
	MUL_AND_ADD_ONE_LINE_NUM_PARTIAL_BUFFER_FLY_SSSE3  0,  1, %1, 0
%elif %2 == FOUR_2_FLAGS
	MUL_AND_ADD_ONE_LINE_NUM_PARTIAL_BUFFER_FLY_SSSE3  0,  1, %1, 0
%elif %2 == TWO_FLAGS
	MUL_AND_ADD_ONE_LINE_NUM_PARTIAL_BUFFER_FLY_SSSE3  0,  3, %1, 0
	MUL_AND_ADD_ONE_LINE_NUM_PARTIAL_BUFFER_FLY_SSSE3  1,  2, %1, 1
%endif
	ADD_OFFSET_AND_SHIFT_XMMR1_AND_XMMR2_SSSE3
	STORE_EIGHT_INT16_T_SSSE3 [CDPBF8_DST+K], XMMR1, %3
	ADD K, SIZE_OF_INT16_T*CDPBF8_STRIDE*CDPBF8_INCREASE
	ADD TCOEFF, ((SIZE_OF_ONE_EO*2)*CDPBF8_INCREASE)
	CMP K, SIZE_OF_INT16_T*CDPBF8_STRIDE*8
	JL %%CALCULATE_DST_PARTIAL_BUFFER_FLY8_SSSE3_K
	%undef		CDPBF8_START
	%undef		CDPBF8_INCREASE
%endmacro

%macro			CALCULATE_ONE_LINE_DST_PARTIAL_BUFFER_FLY8_SSSE3				4
	MOV SRC, r1m
	IMUL SRC, SIZE_OF_INT16_T
	IMUL SRC, J
	ADD SRC, %1
	CALCULATE_E_O_PARTIAL_BUFFER_FLY8_SSSE3 E,    O,    TEMP_SRC, E_O_FLAGS,       %3
	CALCULATE_E_O_PARTIAL_BUFFER_FLY8_SSSE3 EE,   EO,   E,        EE_EO_FLAGS,     %3
%if 8 == DCT_STEP
	MOV DST, LINE_LENGTH * SIZE_OF_INT16_T
%else
	MOV DST, SIZE_OF_INT16_T
%endif
	IMUL DST, J
	ADD DST, %2
	MOVDQA XSHUFFDW, [pshuffd_w]
	CALCULATE_DST_PARTIAL_BUFFER_FLY8_SSSE3 EE, FOUR_1_FLAGS, %4
	CALCULATE_DST_PARTIAL_BUFFER_FLY8_SSSE3 EO, FOUR_2_FLAGS, %4
	CALCULATE_DST_PARTIAL_BUFFER_FLY8_SSSE3 O,  TWO_FLAGS,    %4
%if 8 == DCT_STEP
	MATRIX_TRANSPOSE_TMP_COEFF_SSSE3  0
%endif
%endmacro

%macro			CALCULATE_ONE_LINE_DST_DCT8_SSSE3				4
%if 1 == DCT_STEP
	MOV SRC, LINE_LENGTH * SIZE_OF_INT16_T
	IMUL SRC, J
	ADD SRC, %1
	LOAD_EIGHT_INT16_T_SSSE3 XMMR1, [SRC                    ], %3
	MOV DST, SIZE_OF_INT32_T
	IMUL DST, J
	ADD DST, %2
	MOV K, 0
	MOV r2, 0
%%CALCULATE_ONE_LINE_DST_DCT8_SSSE3_K:
	MOVDQA XMMR0, XMMR1
	PMADDWD XMMR0, [partial_bufferfly_8_t8+K]
	MOVHLPS XMMR7, XMMR0
	PADDD XMMR0, XMMR7
	MOVDQA XMMR7, XMMR0
	PSRLDQ XMMR7, 4
	PADDD XMMR0, XMMR7
	PADDD XMMR0, XOFFSET
	PSRAD XMMR0, XSHIFT
	MOVD r0, XMMR0
	MOV [DST+r2], r0
	ADD r2, LINE_LENGTH*SIZE_OF_INT32_T
	ADD K, LINE_LENGTH*   SIZE_OF_INT16_T
	CMP K, LINE_LENGTH* 8*SIZE_OF_INT16_T
	JL %%CALCULATE_ONE_LINE_DST_DCT8_SSSE3_K
%else
	MOV DST, SIZE_OF_INT32_T
	IMUL DST, J
	ADD DST, %2
	MOV K, 0
	LEA r2, [partial_bufferfly_8_t8_2]
%%CALCULATE_ONE_LINE_DST_DCT8_SSSE3_K:
	PXOR XMMR1, XMMR1
	PXOR XMMR2, XMMR2
	MOV r0, SIZE_OF_INT16_T
	IMUL r0, J
	ADD r0, %1
	MOV r1, 0
%%CALCULATE_ONE_LINE_DST_DCT8_SSSE3_LOOP:
	LOAD_EIGHT_INT16_T_SSSE3 XSPACE1, [r0], %3
	LOAD_EIGHT_INT16_T_SSSE3 XSPACE3, [r0+LINE_LENGTH*SIZE_OF_INT16_T], %3
	MOVDQA XSPACE2, XSPACE1
	PUNPCKLWD XSPACE1, XSPACE3
	PUNPCKHWD XSPACE2, XSPACE3
	PMADDWD XSPACE1, [r2+r1]
	PMADDWD XSPACE2, [r2+r1]
	PADDD XMMR1, XSPACE1
	PADDD XMMR2, XSPACE2
	ADD r1, SIZE_OF_INT16_T*8
	ADD r0, LINE_LENGTH*SIZE_OF_INT16_T*2
	CMP r1, SIZE_OF_INT16_T*8*4
	JL %%CALCULATE_ONE_LINE_DST_DCT8_SSSE3_LOOP
	PADDD XMMR1, XOFFSET
	PSRAD XMMR1, XSHIFT
	PADDD XMMR2, XOFFSET
	PSRAD XMMR2, XSHIFT
	STORE_EIGHT_INT16_T_SSSE3 [DST+K], XMMR1, %4
	STORE_EIGHT_INT16_T_SSSE3 [DST+K+16], XMMR2, %4
	ADD r2, SIZE_OF_INT16_T*8*4
	ADD K, LINE_LENGTH*   SIZE_OF_INT32_T
	CMP K, LINE_LENGTH* 8*SIZE_OF_INT32_T
	JL %%CALCULATE_ONE_LINE_DST_DCT8_SSSE3_K
%endif

%endmacro



%macro X265_TR_QUANT_X_TR_8x8_HELP_SSSE3			4
cglobal %1, 0, 7
	%define				SIZE_OF_ONE_EO				 (2*8)
	%define				SIZE_OF_INT16_T				 2
	%define				SIZE_OF_INT32_T				 4
	%define				LINE_LENGTH					 8
	%define				LINE_SIZE_INT16_T			 (LINE_LENGTH*SIZE_OF_INT16_T)
	%define				NUM_OF_E_O					 4
	%define				NUM_OF_EE_EO				 2
	%define				NUM_OF_ALL_E_O				((NUM_OF_E_O+NUM_OF_EE_EO)*2)
	%define				SIZE_OF_ALL_E_O				(NUM_OF_ALL_E_O*SIZE_OF_ONE_EO)
	%define				SIZE_OF_E					(NUM_OF_E_O*SIZE_OF_ONE_EO)
	%define				SIZE_OF_O					(NUM_OF_E_O*SIZE_OF_ONE_EO)
	%define				SIZE_OF_E_O					(SIZE_OF_E+SIZE_OF_O)
	%define				SIZE_OF_EE					(NUM_OF_EE_EO*SIZE_OF_ONE_EO)
	%define				SIZE_OF_EO					(NUM_OF_EE_EO*SIZE_OF_ONE_EO)
	%define				SIZE_OF_EE_EO				(SIZE_OF_EE+SIZE_OF_EO)
	%define				TEMP_COEFF_SIZE				(LINE_SIZE_INT16_T*LINE_LENGTH)
	%define				TEMP_SRC_SIZE				(SIZE_OF_INT16_T*8*LINE_LENGTH)
	%define				TEMP_COEFF					r6
	%define				TEMP_SRC					(TEMP_COEFF+TEMP_COEFF_SIZE)
	%define				E							(TEMP_SRC+TEMP_SRC_SIZE)
	%define				EE							E+SIZE_OF_E_O
	%define				O							E+SIZE_OF_E
	%define				EO							EE+SIZE_OF_EE
	%define				J							r5
	%define				K							r4
	%define				SRC							r3
	%define				DST							r3
	%define				TCOEFF						r2
	%define				XSPACE1						XMMR0
	%define				XSPACE2						XMMR7
	%define				XSPACE3						XMMR3
	%define				XSHUFFDW					XMMR4
	%define				XOFFSET						XMMR6
	%define				XSHIFT						XMMR5
	%define				DCT_STEP					%2
	%define				E_O_FLAGS					1
	%define				EE_EO_FLAGS					2
	%define				EEE_EEO_FLAGS				3
	%define				FOUR_1_FLAGS				1
	%define				FOUR_2_FLAGS				2
	%define				TWO_FLAGS					4
	%define				SIZE_OF_STACK				(SIZE_OF_ALL_E_O+TEMP_SRC_SIZE+TEMP_COEFF_SIZE)

	mov r6, esp
	and r6, 0xFFFFFFF0
	sub r6, SIZE_OF_STACK

	MOV r2, r3m
	SUB r2, 6
	GET_XOFFSET_AND_XSHIFT_SSSE3 r2
	MOV J, 0
%%X265_TR_QUANT_X_TR_8x8_HELP_SSSE3_J1:
	CALCULATE_ONE_LINE_DST_PARTIAL_BUFFER_FLY8_SSSE3 r0m, TEMP_COEFF, %3, MOVDQA
	ADD J, 8
	CMP J, 8
	JL %%X265_TR_QUANT_X_TR_8x8_HELP_SSSE3_J1

	MOV r2, 9
	GET_XOFFSET_AND_XSHIFT_SSSE3 r2
	MOV J, 0
%%X265_TR_QUANT_X_TR_8x8_HELP_SSSE3_J2:
	CALCULATE_ONE_LINE_DST_DCT8_SSSE3 TEMP_COEFF, r2m, MOVDQA, %4
	ADD J,  DCT_STEP
	CMP J,  8
	JL %%X265_TR_QUANT_X_TR_8x8_HELP_SSSE3_J2

	RET
%endmacro


%macro STORE_EIGHT_INT32_T_INVERSE_8_SSSE3					5
	STORE_16_BYTES_SSSE3 [%3+(SIZE_OF_ONE_EO*%4)   ], %1, %5
	STORE_16_BYTES_SSSE3 [%3+(SIZE_OF_ONE_EO*%4)+16], %2, %5
%endmacro

%macro MUL_ONE_LINE_NUM_PARTIAL_BUFFER_FLY_INVERSE_SSSE3		5
%if SECOND_ND == %4
	LOAD_EIGHT_INT16_T_SSSE3 XMMR1, [SRC+LINE_SIZE_INT16_T*%1], %5
	LOAD_EIGHT_INT16_T_SSSE3 XSPACE3, [SRC+LINE_SIZE_INT16_T*%2], %5
%else
	LOAD_EIGHT_INT32_T_SSSE3 XMMR1, (SRC+LINE_SIZE_INT32_T*%1), XMMR2, %5
	LOAD_EIGHT_INT32_T_SSSE3 XSPACE3, (SRC+LINE_SIZE_INT32_T*%2), XMMR2, %5
%endif
	MOVDQA XMMR2, XMMR1
	PUNPCKLWD XMMR1, XSPACE3
	PUNPCKHWD XMMR2, XSPACE3

	PMADDWD XMMR1, [TCOEFF+%1*SIZE_OF_ONE_EO*%3]
	PMADDWD XMMR2, [TCOEFF+%1*SIZE_OF_ONE_EO*%3]
%endmacro

%macro			CALCULATE_ONE_O_PARTIAL_BUFFER_FLY_INVERSE8_SSSE3		4
%if %2 == O_FLAGS
	CLEAR_XMMR1_AND_XMMR2_SSSE3
	MUL_AND_ADD_ONE_LINE_NUM_PARTIAL_BUFFER_FLY_INVERSE_SSSE3  1,  7, 8, %3, %4
	MUL_AND_ADD_ONE_LINE_NUM_PARTIAL_BUFFER_FLY_INVERSE_SSSE3  3,  5, 8, %3, %4
%elif %2 == EO_FLAGS
	MUL_ONE_LINE_NUM_PARTIAL_BUFFER_FLY_INVERSE_SSSE3 2, 6, 8, %3, %4
%elif %2 == EE_FLAGS
	MUL_ONE_LINE_NUM_PARTIAL_BUFFER_FLY_INVERSE_SSSE3 0, 4, 8, %3, %4
%endif
	STORE_EIGHT_INT32_T_SSSE3 XMMR1, XMMR2, %1, MOVDQA
%endmacro

%macro			CALCULATE_O_PARTIAL_BUFFER_FLY_INVERSE8_SSSE3			4
	MOV K, 0
	LEA TCOEFF, [partial_bufferfly_inverse_8_t8]
%%CALCULATE_O_PARTIAL_BUFFER_FLY_INVERSE8_SSSE3_LABEL_K:
	CALCULATE_ONE_O_PARTIAL_BUFFER_FLY_INVERSE8_SSSE3 %1, %2, %3, %4
	ADD TCOEFF, SIZE_OF_ONE_EO
	ADD K, SIZE_OF_ONE_EO
%if %2 == O_FLAGS
	CMP K, SIZE_OF_ONE_EO * 4
%elif %2 == EO_FLAGS
	CMP K, SIZE_OF_ONE_EO * 2
%elif %2 == EE_FLAGS
	CMP K, SIZE_OF_ONE_EO * 2
%endif
	JL %%CALCULATE_O_PARTIAL_BUFFER_FLY_INVERSE8_SSSE3_LABEL_K

%endmacro

%macro			CALCULATE_ALL_E_AND_O_PARTIAL_BUFFER_FLY_INVERSE8_SSSE3 		2
	CALCULATE_O_PARTIAL_BUFFER_FLY_INVERSE8_SSSE3  O,    O_FLAGS,    %1, %2
	CALCULATE_O_PARTIAL_BUFFER_FLY_INVERSE8_SSSE3  EO,   EO_FLAGS,   %1, %2

	CALCULATE_O_PARTIAL_BUFFER_FLY_INVERSE8_SSSE3  EE,   EE_FLAGS,   %1, %2
	CALCULATE_E_PARTIAL_BUFFER_FLY_INVERSE_SSSE3   EE,   EO,   E,     2
%endmacro

%macro			CALCULATE_DST_PARTIAL_BUFFER_FLY_INVERSE8_SSSE3				3
	MOV EO_ADDRESS1, (%1*16)
	MOV EO_ADDRESS2, SIZE_OF_ONE_EO*3+(%1*16)
	CALCULATE_ONE_DST_PARTIAL_BUFFER_FLY_INVERSE8_SSSE3 XMMR1, XMMR2
	ADD EO_ADDRESS1, SIZE_OF_ONE_EO
	SUB EO_ADDRESS2, SIZE_OF_ONE_EO
	CALCULATE_ONE_DST_PARTIAL_BUFFER_FLY_INVERSE8_SSSE3 XMMR3, XMMR7

	PUNPCK 1, 3, 0, DQ
	PUNPCK 2, 7, 0, DQ
	PUNPCK 1, 2, 0, QDQ
	PUNPCK 3, 7, 0, QDQ
%if FIRST_ST == %2
	STORE_EIGHT_INT16_T_SSSE3 [DST+LINE_SIZE_INT16_T*(%1*4+0)], XMMR1, %3
	STORE_EIGHT_INT16_T_SSSE3 [DST+LINE_SIZE_INT16_T*(%1*4+1)], XMMR2, %3
	STORE_EIGHT_INT16_T_SSSE3 [DST+LINE_SIZE_INT16_T*(%1*4+2)], XMMR3, %3
	STORE_EIGHT_INT16_T_SSSE3 [DST+LINE_SIZE_INT16_T*(%1*4+3)], XMMR7, %3
%else
	STORE_EIGHT_INT16_T_SSSE3 [DST], XMMR1, %3
	STORE_EIGHT_INT16_T_SSSE3 [DST+r0], XMMR2, %3
	ADD DST, r1
	STORE_EIGHT_INT16_T_SSSE3 [DST], XMMR3, %3
	STORE_EIGHT_INT16_T_SSSE3 [DST+r0], XMMR7, %3
%endif
%endmacro


%macro			CALCULATE_DST_PARTIAL_BUFFER_FLY_INVERSE8_SSSE3				2
	MOVDQA XSHUFFDW, [pshuffd_w]
	CALCULATE_DST_PARTIAL_BUFFER_FLY_INVERSE8_SSSE3 0, %1, %2
%if SECOND_ND == %1
	ADD DST, r1
%endif
	CALCULATE_DST_PARTIAL_BUFFER_FLY_INVERSE8_SSSE3 1, %1, %2
%endmacro

%macro			CALCULATE_ONE_LINE_DST_PARTIAL_BUFFER_FLY_INVERSE8_SSSE3		5
%if FIRST_ST == %3
	MOVDQA XSHUFFDW, [pshuffd_w]
	MOV SRC, %1
%else
	LEA SRC, [%1]
%endif
	CALCULATE_ALL_E_AND_O_PARTIAL_BUFFER_FLY_INVERSE8_SSSE3 %3, %4

%if FIRST_ST == %3
	MOV r2, 7
	GET_XOFFSET_AND_XSHIFT_SSSE3 r2
	LEA DST, [%2]
%else
	MOV r2, 20
	SUB r2, r3m
	GET_XOFFSET_AND_XSHIFT_SSSE3 r2
	MOV r0, r1m
	ADD r0, r0
	MOV r1, r0
	ADD r1, r1
	MOV DST, %2
%endif
	CALCULATE_DST_PARTIAL_BUFFER_FLY_INVERSE8_SSSE3 %3, %5
%endmacro

%macro X265_TR_QUANT_X_ITR_8x8_HELP_SSSE3		3
cglobal %1, 0, 7
	%define				SIZE_OF_ONE_EO				 (4*8)
	%define				SIZE_OF_INT16_T				 2
	%define				SIZE_OF_INT32_T				 4
	%define				LINE_LENGTH					 8
	%define				LINE_SIZE_INT16_T			(LINE_LENGTH*SIZE_OF_INT16_T)
	%define				LINE_SIZE_INT32_T			(LINE_LENGTH*SIZE_OF_INT32_T)
	%define				NUM_OF_E_O					 4
	%define				NUM_OF_EE_EO				 2
	%define				NUM_OF_ALL_E_O				((NUM_OF_E_O+NUM_OF_EE_EO)*2)
	%define				SIZE_OF_ALL_E_O				(NUM_OF_ALL_E_O*SIZE_OF_ONE_EO)
	%define				SIZE_OF_E					(NUM_OF_E_O*SIZE_OF_ONE_EO)
	%define				SIZE_OF_O					(NUM_OF_E_O*SIZE_OF_ONE_EO)
	%define				SIZE_OF_E_O					(SIZE_OF_E+SIZE_OF_O)
	%define				SIZE_OF_EE					(NUM_OF_EE_EO*SIZE_OF_ONE_EO)
	%define				SIZE_OF_EO					(NUM_OF_EE_EO*SIZE_OF_ONE_EO)
	%define				SIZE_OF_EE_EO				(SIZE_OF_EE+SIZE_OF_EO)
	%define				SIZE_OF_MTB					3*16
	%define				TEMP_BLOCK_SIZE				(LINE_SIZE_INT16_T*LINE_LENGTH)
	%define				SIZE_OF_TEMP_DST			SIZE_OF_ONE_EO * 8
	%define				MTB							r6
	%define				MTB1						MTB
	%define				MTB2						MTB1+16
	%define				MTB3						MTB2+16
	%define				TEMP_BLOCK					(MTB+SIZE_OF_MTB)
	%define				TEMP_DST					(TEMP_BLOCK+TEMP_BLOCK_SIZE)
	%define				E							TEMP_DST+SIZE_OF_TEMP_DST
	%define				EE							E+SIZE_OF_E_O
	%define				O							E+SIZE_OF_E
	%define				EO							EE+SIZE_OF_EE
	%define				K							r5
	%define				SRC							r4
	%define				DST							r4
	%define				TCOEFF						r3
	%define				EO_ADDRESS1					r3
	%define				EO_ADDRESS2					r2
	%define				XSPACE1						XMMR0
	%define				XSPACE2						XMMR7
	%define				XSPACE3						XMMR3
	%define				XSHUFFDW					XMMR4
	%define				XOFFSET						XMMR6
	%define				XSHIFT						XMMR5
	%define				FORWARD						1
	%define				BACKWARD					2
	%define				O_FLAGS						1
	%define				EO_FLAGS					2
	%define				EE_FLAGS					3
	%define				FIRST_ST					1
	%define				SECOND_ND					2
	%define				SIZE_OF_STACK				(SIZE_OF_ALL_E_O+SIZE_OF_TEMP_DST+TEMP_BLOCK_SIZE+SIZE_OF_MTB)
	mov r6, esp
	and r6, 0xFFFFFFF0
	sub r6, SIZE_OF_STACK

	CALCULATE_ONE_LINE_DST_PARTIAL_BUFFER_FLY_INVERSE8_SSSE3 r2m, TEMP_BLOCK, FIRST_ST, %2, MOVDQA
	CALCULATE_ONE_LINE_DST_PARTIAL_BUFFER_FLY_INVERSE8_SSSE3 TEMP_BLOCK, r0m, SECOND_ND, MOVDQA, %3

	RET
%endmacro

X265_TR_QUANT_X_TR_8x8_HELP_SSSE3 tr_quant_x_tr_8x8_ssse3, 1, MOVDQA, MOVDQA
X265_TR_QUANT_X_ITR_8x8_HELP_SSSE3 tr_quant_x_itr_8x8_ssse3, MOVDQA, MOVDQA


