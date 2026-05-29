// ================================================================================ //
// NEORV32 TMR validation program                                                   //
//                                                                                  //
// Description:                                                                     //
// Bare-metal reliability validation software for the NEORV32 RISC-V processor.     //
//                                                                                  //
// The program initializes DMEM with deterministic reference patterns and           //
// continuously executes arithmetic and logical ALU operations in order to          //
// generate observable activity in simulation waveforms and fault-injection         //
// experiments.                                                                     //
//                                                                                  //
// A heartbeat LED connected to GPIO bit 0 toggles periodically to indicate         //
// that the processor is alive and the main execution loop is active.               //
//                                                                                  //
// Features:                                                                        //
//   - DMEM initialization with non-zero patterns                                   //
//   - Continuous ALU activity generation                                           //
//   - Arithmetic and logical operation testing                                     //
//   - GPIO heartbeat monitoring                                                    //
//   - UART status reporting                                                        //
//                                                                                  //
// Target platform: NEORV32                                                         //
// Processor ISA: RISC-V                                                            //
// Author: Olivier Oribes                                                           //
// Year: 2026                                                                       //
//                                                                                  //
// Based on the NEORV32 project:                                                    //
// https://github.com/stnolting/neorv32                                             //
//                                                                                  //
// NEORV32 SEE mitigation project:                                                  //
// https://github.com/OlivierOribes/Neorv32_SEE                                     //
//                                                                                  //
// Licensed under the BSD-3-Clause license.                                         //
// SPDX-License-Identifier: BSD-3-Clause                                            //
// ================================================================================ //


#include <stdint.h>
#include <neorv32.h>

void delay_ms(uint32_t time_ms) {
  neorv32_aux_delay_ms(neorv32_sysinfo_get_clk(), time_ms);
}

int main() {

  // GPIO setup
  neorv32_gpio_port_set(0);
  neorv32_gpio_dir_set(0x0000000F);

  // DMEM setup
  volatile uint32_t *mem = (uint32_t*)0x80000000;
  int dmem_words = 1500;
  uint32_t a, b;
 /**********************************************************************************
 * 
 * All memory words are initialized with different value
 * used to perform different operation
 **********************************************************************************/
  for (int i = 0; i < dmem_words; i++) 
  {
    mem[i] = 0x10000000 + i;
  }

  neorv32_uart0_printf("RAM initialized\n");

  uint8_t led = 0;

  while(1) 
  {

  
    // Heartbeat LED on bit 0
    led ^= 0x01;
    neorv32_gpio_port_set(led);
    delay_ms(500);  // 0.5 seconde


    for (int i = 0; i < dmem_words; i++) 
    {

      a = 0x10000000 + i;
      b = 0x20000000 + i;

      mem[i] = a + b;
      mem[i] = a - b;
      mem[i] = a | b;
      mem[i] = a ^ b;
      mem[i] = a + ~b;

    }


    


  }

  return 0;
}
