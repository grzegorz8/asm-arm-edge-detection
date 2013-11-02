.section    .rodata
.line_fmt:
    .ascii  "[%d, %d] - [%d, %d]\012\000"

.text
.deg_to_rad:
    .word   1016003125

.fmt:
    .ascii "%d\012\000"
.fmtp:
    .word   .fmt

.line_fmtp:
    .word   .line_fmt

.globl sobel
.globl hough_transform
.globl print_paths

#
# Funkcja aplikująca operator Sobela do każdego piksela obrazka.
#
# Wejście
# r0 - tablica z obrazkiem pgm
# r1 - liczba wierszy
# r2 - liczba kolumn
# r3 - tablica z "odpowiedzią"
# stos0 - próg
# Wyjście
# void
#
sobel:
    stmfd   sp!, {r4-r11, lr}

    mov     r4, r0  @ r4 - tablica z obrazkiem pgm
    mov     r5, r1  @ r5 - liczba wierszy
    mov     r6, r2  @ r6 - liczba kolumn
    mov     r7, r3  @ r7 - tablica z "odpowiedzią"
    @ r8 - i, r9 - j
    
    @ for (int i = 1; i < HEIGHT - 1; ++i)
    @     for (int j = 1; j < WIDTH - 1; ++j)
    @         ...

    mov     r8, #1      @ i := 1
    b       i_loop_cond

i_loop_body:
    mov     r9, #1      @ j := 1
    b       j_loop_cond

j_loop_body:

    ldr     r0, [sp, #36]
    push    {r0}    @ próg na stos jako 5 parametr
    mov     r0, r4  @ tablica z obrazkiem
    mov     r1, r6  @ liczba kolumn
    mov     r2, r8  @ i
    mov     r3, r9  @ j
    bl      apply_masks
    add     sp, #4  @ "zdjęcie" ze stosu progu

    mla     r1, r8, r6, r9
    str     r0, [r7, r1, LSL #2]
    add     r9, r9, #1

j_loop_cond:
    sub     r0, r6, #1
    cmp     r9, r0
    blt     j_loop_body

    add     r8, r8, #1
i_loop_cond:
    sub     r0, r5, #1
    cmp     r8, r0
    blt     i_loop_body

    ldmfd   sp!, {r4-r11, lr}
    mov     pc, lr

#
# Funkcja pomocnicza. Aplikuje operator Sobela do jednej
# Wejście:
# r0 - tablica z obrazkiem pgm
# r1 - liczba kolumn
# r2 - i
# r3 - j
# stos0 - próg
#
# Wyjście
# r0 - wartość dla komórki (i,j) z użyciem operatora Sobela
#
#  maska 1        maska 2
#  -1  0 +1        +1 +2 +1
#  -2  0 +2         0  0  0
#  -1  0 +1        -1 -2 -1
#
apply_masks:
    stmfd   sp!, {r5-r10,lr}

    ldr     r10, [sp, #28]  @ próg

    # akumulatory dla maski 1 i 2 #
    mov     r8, #0
    mov     r9, #0

    ##### górny rząd #####
    sub     r5, r2, #1
    mla     r6, r5, r1, r3

    # (i-1,j-1) #
    sub     r5, r6, #1
    ldr     r7, [r0, r5, LSL #2]
    sub     r8, r8, r7  @ maska 1
    add     r9, r9, r7  @ maska 2

    # (i-1,j) #
    ldr     r7, [r0, r6, LSL #2]
    add     r9, r9, r7, LSL #1  @ maska 2

    # (i-1,j+1) #
    add     r5, r6, #1
    ldr     r7, [r0, r5, LSL #2]
    add     r8, r8, r7  @ maska 1
    add     r9, r9, r7  @ maska 2

    ##### środkowy rząd #####
    mla     r6, r2, r1, r3

    # (i,j-1) #
    sub     r5, r6, #1
    ldr     r7, [r0, r5, LSL #2]
    sub     r8, r8, r7, LSL #1  @ maska 1

    # (i,j) - nieużywany #
    #ldr     r7, [r0, r6, LSL #2]
    #add     r4, r4, r7

    # (i,j+1) #
    add     r5, r6, $1
    ldr     r7, [r0, r5, LSL #2]
    add     r8, r8, r7, LSL #1  @ maska 1

    ##### dolny rząd #####
    add     r5, r2, #1
    mla     r6, r5, r1, r3

    # (i+1,j-1) #
    sub     r5, r6, #1
    ldr     r7, [r0, r5, LSL #2]
    sub     r8, r8, r7  @ maska 1
    sub     r9, r9, r7  @ maska 2

    # (i+1,j) #
    ldr     r7, [r0, r6, LSL #2]
    sub     r9, r9, r7, LSL #1  @ maska 2

    # (i+1,j+1) #
    add     r5, r6, #1
    ldr     r7, [r0, r5, LSL #2]
    add     r8, r8, r7  @ maska 1
    sub     r9, r9, r7  @ maska 2


    # abs(r8)
    cmp     r8, #0
    neglt   r8, r8
    # abs(r9)
    cmp     r9, #0
    neglt   r9, r9

    add     r0, r8, r9

    cmp     r0, r10
    movlt   r0, #0
    movge   r0, #200

    ##### epilog #####
    ldmfd   sp!, {r5-r10,lr}
    mov     pc, lr



#
# Wejście:
# r0 - tablica z wartościami wyliczonymi algorytmem Sobela
# r1 - liczba wierszy
# r2 - liczba kolumn
# r3 - akumulator (nieużywany)
# stos0 - liczba rozważanych kątów
# stos1 - krok (kąty)
# stos2 - połowa przekątnej
# stos3 - lista punktów na krawędziach
#
hough_transform:
    STMFD   sp!, {r4-r11, lr}
    
    MOV     r4, r0
    MOV     r5, r1
    MOV     r6, r2
    MOV     r7, r3
    LDR     r11, [sp, #36]
        
    @ r8 - x, r9 - y, r10 - a (numer kąta)

    MOV     r8, #0
    B       x_loop_cond

x_loop_body:
    MOV     r9, #0
    B       y_loop_cond

y_loop_body:
    MOV     r10, #0

    MLA     r0, r8, r6, r9
    LDR     r0, [r4, r0, LSL #2]
    CMP     r0, #175
    ADDLT   r9, r9, #1
    BLT     y_loop_cond

    B       a_loop_cond

a_loop_body:
    LDR     r3, [sp, #44]   @ przekątna
    MOV     r2, r5, LSR #1  @ center_y
    MOV     r1, r6, LSR #1  @ center_x
    MOV     r0, r11         @ liczba kątów

    PUSH    {r0-r3}
    MOV     r0, r8          @ x
    MOV     r1, r9          @ y
    MOV     r2, r10         @ a (numer kąta)
    LDR     r3, [sp, #56]   @ krok kąta (zwiększone o 16 przez push!)

    BL      hough_single_cell
    ADD     sp, sp, #16     @ zdejmujemy ze stosu
    
    PUSH    {r0}

    MOV     r0, #3
    MOV     r1, #4
    BL      calloc

    POP     {r1}

    @ R0 - wskaźnik do nowego obiektu, R1 - pozycja w tablicy
    LDR     r3, [sp, #48]           @ tablica z listami
    LDR     r2, [r3, r1, LSL #2]    @ wsk. do ostatniego elem. na liście dla (kąt, r)

    STR     r8, [r0]        @ x
    STR     r9, [r0, #4]    @ y
    STR     r2, [r0, #8]    @ next

    STR     r0, [r3, r1, LSL #2]    @ last = current

    MOV     r0, r1  @ numer pozycji w tablicy wraca do R0

    @ w R0 jest pozycja w tablicy, którą należy zwiększyć
    @LDR     r1, [r7, r0, LSL #2]
    @ADD     r1, r1, #1
    @STR     r1, [r7, r0, LSL #2]

    ADD     r10, r10, #1
a_loop_cond:
    CMP     r10, r11
    BLT     a_loop_body

    ADD     r9, r9, #1
y_loop_cond:
    CMP     r9, r6      @ y < kolumn
    BLT     y_loop_body

    ADD     r8, r8, #1
x_loop_cond:
    CMP     r8, r5      @ x < wierszy 
    BLT     x_loop_body

    MUL     r0, r8, r9

    @ epilog @
    LDMFD   sp!, {r4-r11, lr}
    MOV     pc, lr

#
# Wejście:
# r0 - współrzędna x
# r1 - współrzędna y
# r2 - numer kąta
# r3 - krok
# stos0 - liczba kątów
# stos1 - środek x
# stos2 - środek y
# stos3 - przekątna
#
# Wyjście:
# r0 - pozycja do zwiększenia
#
hough_single_cell:
    STMFD   sp!, {r4-r11, lr}
    SUB     sp, sp, #12

    MOV     r8, r0      @ x
    MOV     r9, r1      @ y
    MOV     r10, r2     @ kąt
    MOV     r11, r3     @ krok

    MUL     r0, r10, r11    @ r0 - numer kąta * krok = kąt w stopniach
 
    FLTS    f4, r0          @ kąt w stopniach jako float
    LDFS    f0, .deg_to_rad @ pi / 180
    MUFS    f4, f4, f0      @ kąt w radianach

    STFS    f4, [sp, #4]    @ niezbędny trik
    LDR     r4, [sp, #4]

    @ obliczenie i zapisanie na stos cos(kąt w radianach)
    MOV     r0, r4
    BL      cosf
    STFS    f0, [sp, #4]
    LDFS    f0, [sp, #4]

    @ obliczenie i zapisanie na stos sin(kąt w radianach)
    MOV     r0, r4
    BL      sinf
    STFS    f0, [sp, #8]

    @ (x - center_x) * cosf(rads)
    LDR     r0, [sp, #52]   @ center_x
    SUB     r0, r8, r0      @ x - center_x
    FLTS    f0, r0

    LDFS    f1, [sp, #4]
    MUFS    f3, f0, f1      @ f3 = f0 * cosf(rads)

    @ (y - center_y) * sinf(rads)
    LDR     r0, [sp, #56]   @ center_y
    SUB     r0, r9, r0
    FLTS    f0, r0

    LDFS    f1, [sp, #8]
    MUFS    f2, f0, f1      @ f2 = f0 * sinf(rads)

    ADFS    f0, f2, f3      @ promień okręgu

    @ pos = round(r + przekątna) * liczba_kątów + numer_kąta
    FIX     r0, f0          @ zaokrąglenie promienia, bez specyfikatora: do najbliższego
    
    LDR     r1, [sp, #60]   @ długość przekątnej
    LDR     r2, [sp, #48]   @ liczba kątów
    ADD     r0, r0, r1      @ r + przekątna : wiersz
    MUL     r1, r0, r2      @ offset do danego wiersza
    ADD     r0, r1, r10     @ pozycja w tablicy
    
    ADD     sp, sp, #12
    LDMFD   sp!, {r4-r11, lr}
    MOV     pc, lr

#
# Liczy odległość między punktami w metryce miejskiej
#
# r0 - x1
# r1 - y1
# r2 - x2
# r3 - y2
#
dist:
    STMFD   sp!, {lr}

    SUB     r0, r0, r2
    CMP     r0, #0
    NEGLT   r0, r0

    SUB     r1, r1, r3
    CMP     r1, #0
    NEGLT   r1, r1

    ADD     r0, r0, r1

    LDMFD   sp!, {lr}
    MOV     pc, lr

#
# Wejście:
# r0 - liczba wierszy
# r1 - liczba kolumn
# r2 - tablica list
# r3 - minimalna długość linii
# stos - maksymalna przerwa
#
print_paths:
    STMFD   sp!, {r4-r11, lr}

    PUSH    {r0-r3}

    MOV     r11, #0
    B       row_loop_cond
row_loop_body:
    MOV     r10, #0
    B       col_loop_cond

col_loop_body:

    LDR     r5, [sp, #4]    @ kolumny
    LDR     r6, [sp, #8]    @ początek tablicy
    MLA     r4, r5, r11, r10
    LDR     r4, [r6, r4, LSL #2]    @ wskaźnik do listy

    MOV     r5, #0  @ first_set
    MOV     r6, #0  @ first_x
    MOV     r7, #0  @ first_y
    MOV     r8, #0  @ last_x
    MOV     r9, #0  @ last_y
    MOV     r12, #0 @ number

    B       while_cond
while_body:
    CMP     r5, #0      @ if (first_set == 0)
    BNE     first_set_1
first_set_0:    @ czyli ten aktualny punkt będzie początkiem nowej linii
    MOV     r5, #1
    LDR     r6, [r4, #0]
    MOV     r8, r6
    LDR     r7, [r4, #4]
    MOV     r9, r7
    MOV     r12, #1
    B       first_set_end
first_set_1:    @ czyli już mamy jakąś rozpoczętą linię, rozważamy czy ją przedłużyć
 
    MOV     r0, r8
    MOV     r1, r9
    LDR     r2, [r4, #0]
    LDR     r3, [r4, #4]
    PUSH    {r12}
    BL      dist
    POP     {r12}
    
    LDR     r1, [sp, #52]   @ maksymalna przerwa
        
    CMP     r0, r1
    BGE     too_far
 
not_too_far:    @ nowy punkt nie jest zbyt odległy od linii
    ADD     r12, r12, #1

    LDR     r8, [r4, #0]
    LDR     r9, [r4, #4]
    B       too_far_end

too_far:        @ nowy punkt jest zbyt odległy
    LDR     r0, [sp, #12]   @ minimalna długość linii
    CMP     r12, r0
    
    @ wypisujemy starą linię, jeśli jest odpowiednio długa
    LDRGE   r0, .line_fmtp
    MOVGE   r1, r9
    MOVGE   r2, r8
    MOVGE   r3, r7
    PUSHGE  {r6}
    BLGE    printf
    POPGE   {r6}
    
    @ zaznaczamy, że nie ustaliliśmy jeszcze początku nowej linii
    MOV     r5, #0
    MOV     r6, #0
    MOV     r7, #0
    MOV     r8, #0
    MOV     r9, #0
    MOV     r12, #0
too_far_end:
first_set_end:

    LDR     r4, [r4, #8]    @ head = head->next
while_cond:     @ while head->next != NULL
    LDR     r0, [r4, #8]
    CMP     r0, #0
    BNE     while_body

    @ sprawdzamy number >= threshold na koniec listy
    @ może się zdarzyć, że linia kończy się wraz z ostatnim punktem na liście
    LDR     r0, [sp, #12]   @ minimalna długość linii
    CMP     r12, r0
    
    LDRGE   r0, .line_fmtp
    MOVGE   r1, r9
    MOVGE   r2, r8
    MOVGE   r3, r7
    PUSHGE  {r6}
    BLGE    printf
    POPGE   {r6}
    
    ADD     r10, r10, #1
col_loop_cond:
    LDR     r12, [sp, #4]
    CMP     r10, r12
    BLT     col_loop_body

    ADD     r11, r11, #1
row_loop_cond:
    LDR     r12, [sp, #0]
    CMP     r11, r12
    BLT     row_loop_body

    ADD     sp, #16
    LDMFD   sp!, {r4-r11, lr}
    MOV     pc, lr
