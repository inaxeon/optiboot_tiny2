# Makefile for AVR Mega-0 (4809), Tiny-0, and Tiny-1 version of Optiboot
# Bill Westfield, 2019
# $Id$
#
# Edit History
# Sep-2019 refactor from the normal AVR Makefile.
# * Copyright 2013-2019 by Bill Westfield.  Part of Optiboot.
# * This software is licensed under version 2 of the Gnu Public Licence.
# * See optiboot.c for details.

HELPTEXT = "\n"
#----------------------------------------------------------------------
#
# program name should not be changed...
PROGRAM    = optiboot_x
MF:= $(MAKEFILE_LIST)

# defaults
MCU_TARGET = atmega1624

ifdef BIGBOOT
LDSECTIONS  = -Wl,-section-start=.text=0 \
	      -Wl,--section-start=.application=0x400 \
	      -Wl,--section-start=.version=0x3fe
else
LDSECTIONS  = -Wl,-section-start=.text=0 \
	      -Wl,--section-start=.application=0x200 \
	      -Wl,--section-start=.version=0x1fe
endif

BAUD_RATE=115200

#AVRGCCROOT =
AVRDUDE_CONF =

# export symbols to recursive makes (for ISP)
export

#
# End of build environment code.


CC         = $(AVRGCCROOT)avr-gcc
RCC        = $(abspath $(CC))
#$(info wildcard ("$(wildcard $(CC))",""))
ifndef PRODUCTION
$(info Using Compiler at: ${RCC})
endif


# If we have a PACKS directory specified, we should use it...
ifdef PACKS
PACK_OPT= -I "$(PACKS)/include/" -B "$(PACKS)/gcc/dev/$*"
ifndef PRODUCTION
$(info   and Chip-defining PACKS at ${PACKS})
endif
endif


OPTIMIZE = -Os -fno-split-wide-types -mrelax

# Override is only needed by avr-lib build system.

override CFLAGS  = -g -Wall $(OPTIMIZE)
override LDFLAGS = $(LDSECTIONS) -Wl,--relax -nostartfiles -nostdlib

OBJCOPY        = $(AVRGCCROOT)avr-objcopy
OBJDUMP        = $(AVRGCCROOT)avr-objdump
SIZE           = $(AVRGCCROOT)avr-size

include parse_options.mk

.PRECIOUS: optiboot_%.elf

ifndef PRODUCTION
LISTING= $(OBJDUMP) -S 
else
LISTING= @true
endif



#---------------------------------------------------------------------------
# "Chip-level Platform" targets.
# A "Chip-level Platform" compiles for a particular chip, but probably does
# not have "standard" values for things like clock speed, LED pin, etc.
# Makes for chip-level platforms should usually explicitly define their
# options like: "make atmega4809 UARTTX=A4 LED=D0"
#---------------------------------------------------------------------------
#
# Mega0, tiny0, tiny1 don't really have any chip-specific requirements.
#
# Note about fuses:
#  The fuses are defined in the source code.  There are 9!
#  Be sure to use a programmer that will program the fuses from the object file.
#
#---------------------------------------------------------------------------
#

HELPTEXT += "\n-------------\n\n"


optiboot_%.hex: optiboot_%.elf
	$(OBJCOPY) -j .text -j .data -j .version --set-section-flags .version=alloc,load -O ihex $< $@
	@echo Bare Bootloader size
	$(SIZE) $@
#
# Note that the .application section is not normally copied to the
#  .hex file.  The .application section is useful for detecting growth
#  beyond 512 bytes, and for being a target for starting the
#  application, and for referencing certain otherwise-unused variables
#  so they aren't optimized away, but all of that happens during
#  compilation or link, and the code doesn't need to to actually be
#  present in the binary/hex files (where it might interfere with easy
#  merging with a real application.)
# (including it in the .application may be useful for debugging, though)
#	$(OBJCOPY) -j .text -j .data -j .version --set-section-flags .version=alloc,load -j .application -O ihex $< $@

optiboot_%.elf:	optiboot_x.c FORCE
	$(CC) $(CFLAGS) $(CPU_OPTIONS) $(LED_OPTIONS) $(UART_OPTIONS) $(COMMON_OPTIONS) $(LDFLAGS) $(PACK_OPT) -mmcu=$* -o $@ $<
	@echo Bootloader size with skeleton App
	@$(SIZE) $@
	$(LISTING) $@ > optiboot_$*.lst


#---------------------------------------------------------------------------
# "Board-level Platform" targets.
# A "Board-level Platform" implies a manufactured platform with a particular
# AVR_FREQ, LED, and so on.  Parameters are not particularly changable from
# the "make" command line.
# Most of the board-level platform builds should envoke make recursively
#  appropriate specific options
#---------------------------------------------------------------------------

AVRDUDE = avrdude $(PROGRAMMER)
PROGRAMMER = -c atmelice_updi
FUSES      = -U fuse0:w:0x00:m -U fuse1:w:0x00:m -U fuse2:w:0x02:m -U fuse5:w:0xC4:m -U fuse6:w:0x06:m -U fuse7:w:0x00:m -U fuse8:w:0x02:m


HELPTEXT += "attiny1624"
attiny1624:
	$(MAKE) -f $(MF) optiboot_attiny1624.hex UARTTX=B2 TIMEOUT=2 LED=A1

flash_t1624: attiny1624
	$(AVRDUDE) -p t1624 -U flash:w:optiboot_attiny1624.hex:i

fuse_t1624:
	$(AVRDUDE) -p t1624 $(FUSES)

#---------------------------------------------------------------------------
#
# Generic build instructions
#

FORCE:

isp: $(TARGET) FORCE
	"$(MAKE)" -f Makefile.isp isp TARGET=$(TARGET)

isp-stk500: $(PROGRAM)_$(TARGET).hex
	$(STK500-1)
	$(STK500-2)

#windows "rm" is dumb and objects to wildcards that don't exist
clean:
	@touch  __temp_.o __temp_.elf __temp_.lst __temp_.map
	@touch  __temp_.sym __temp_.lss __temp_.eep __temp_.srec
	@touch __temp_.bin __temp_.hex __temp_.tmp.sh
	rm -rf *.o *.elf *.lst *.map *.sym *.lss *.eep *.srec *.bin *.hex *.tmp.sh

version:
	$(CC) --version | head -1
	@grep "define OPTIBOOT_...VER" $(PROGRAM).c 

clean_asm:
	rm -rf *.lst

%.lst: %.elf FORCE
	$(OBJDUMP) -h -S $< > $@

%.srec: %.elf FORCE
	$(OBJCOPY) -j .text -j .data -j .version --set-section-flags .version=alloc,load -O srec $< $@

%.bin: %.elf FORCE
	$(OBJCOPY) -j .text -j .data -j .version --set-section-flags .version=alloc,load -O binary $< $@

help:
	@echo -e $(HELPTEXT)
