.text
.set noreorder
.globl main
.ent main

#include <xc.h>

main:
    sw     zero, TRISA
    sw     zero, ANSELA
    not    t0, zero
    sw     t0, TRISB
    sw     zero, ANSELB
    sw     zero, TRISC
    sw     zero, ANSELC

    li     t0, _PORTA_RA0_MASK
    li     t1, _PORTC_RC9_MASK
    li     t5, _PORTB_RB7_MASK
    li     t6, _PORTB_RB13_MASK
    li     s0, 2         ## initial state 1 sec delay
    li     s1, 4         ## upper bound

    /* Initialize Timer1 for LED blinking */
    li     t8, 0x4E20    ## 20000 cycles for 1 ms (assuming an 8 MHz clock)
    sw     t8, TMR1       ## Load initial value to Timer1
    li     t8, 0x8000    ## Enable Timer1 and set prescaler to 1:1
    sw     t8, T1CON

    /* Enable Timer1 interrupt */
    li     t8, _T1IP(2) | _T1IF(0) | _T1IE(1)
    sw     t8, IEC0SET

    /* Enable Change Notice interrupts for PORTB */
    li     t8, _CNIEB
    sw     t8, CNENSET

    /* Enable global interrupts */
    li     t8, _IPL(2) | _GIE(1)
    sw     t8, INTCONSET

led_toggle:
    sw     t0, LATAINV
    sw     t1, LATCINV
    add    a0, s0, zero
    jal    dynamic_delay
    nop

pollS1:
    lw     t2, PORTB
    andi   t3, t2, _PORTB_RB7_MASK
    bne    t3, zero, copyS1
    nop
    beq    t3, t5, pollS2
    nop

    jal    delay
    nop

    lw     t2, PORTB
    andi   t3, t2, _PORTB_RB7_MASK
    bne    t3, zero, copyS1
    nop

    beq    s0, zero, copyS1
    nop
    addi   s0, s0, -1

copyS1:
    add    t5, t3, zero

pollS2:
    andi   t4, t2, _PORTB_RB13_MASK
    bne    t4, zero, copyS2
    nop
    beq    t4, t6, pollS1
    nop

    jal    delay
    nop

    lw     t2, PORTB
    andi   t4, t2, _PORTB_RB13_MASK
    bne    t4, zero, copyS2
    nop

    beq    s0, s1, copyS2
    nop
    addi   s0, s0, 1

copyS2:
    add    t6, t4, zero
    j      led_toggle
    nop

dynamic_delay:
    li     t7, 0x155555
    mul    t7, a0, t7
    addi   t7, t7, 1

loop_d2:
    addi   t7, t7, -1
    bne    t7, zero, loop_d2
    nop

    jr     ra
    nop

.ent _T1Interrupt
_T1Interrupt:
    /* Timer1 Interrupt Service Routine */
    /* Decrease blinking period by 0.5 seconds when S1 is pressed */
    bnez   s0, not_zero_period
    sw     t8, TMR1      ## Reset Timer1 for a 2-second period
    j      _T1Exit
    nop

not_zero_period:
    addi   s0, s0, -1   ## Decrease period by 0.5 seconds
    sw     t8, TMR1      ## Reset Timer1 for the new period

_T1Exit:
    sw     zero, IFS0CLR ## Clear the Timer1 interrupt flag
    jr     ra
    nop

.ent _CNInterrupt
_CNInterrupt:
    /* Change Notice Interrupt Service Routine for PORTB */
    jal    delay
    nop

    lw     t2, PORTB
    andi   t3, t2, _PORTB_RB7_MASK
    bne    t3, zero, S1Pressed
    nop

    lw     t2, PORTB
    andi   t4, t2, _PORTB_RB13_MASK
    beq    t4, zero, _CNExit
    nop

S1Pressed:
    jal    delay
    nop

    lw     t2, PORTB
    andi   t3, t2, _PORTB_RB7_MASK
    bne    t3, zero, _CNExit
    nop

    beq    s0, zero, _CNExit
    nop

    addi   s0, s0, -1
    j      _CNExit
    nop

_CNExit:
    sw     zero, IFS1CLR ## Clear the Change Notice interrupt flag
    jr     ra
    nop

.end main