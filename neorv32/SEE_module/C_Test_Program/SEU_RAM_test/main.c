// ================================================================================ //
// NEORV32 SEU Detection and Fault Injection Validation Program                     //
//                                                                                  //
// Description:                                                                     //
// Bare-metal reliability test application for the NEORV32 RISC-V processor.        //
// The program initializes the entire DMEM with a known reference pattern           //
// (0x00000000) and continuously scans memory for unexpected modifications          //
// caused by radiation effects, SEUs (Single Event Upsets), or external             //
// fault injection experiments.                                                     //
//                                                                                  //
//                                                                                  //
// In parallel, a heartbeat LED connected to GPIO bit 0 toggles periodically        //
// to indicate that the processor is alive and the monitoring loop is active.       //
//                                                                                  //
// Features:                                                                        //
//   - Continuous DMEM integrity verification                                       //
//   - UART-based SEU reporting                                                     //                                                 //
//   - GPIO heartbeat monitoring                                                    //
//   - Compatible with FPGA fault injection campaigns                               //
//                                                                                  //
// Target platform: NEORV32                                                         //
// Processor ISA: RISC-V                                                            //
// Author: Olivier Oribes                                                           //
// Year: 2026                                                                       //
//                                                                                  //
// Based on the NEORV32 project:                                                    //
// https://github.com/stnolting/neorv32                                             //
//                                                                                  //
//                                                                                  //
// NEORV32 SEE mitigation project:                                                  //
// https://github.com/stnolting/neorv32                                             //
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
  neorv32_gpio_dir_set(0x000000FF);

  // DMEM setup
  volatile uint32_t *mem = (uint32_t*)0x80000000;
  int dmem_words = 1971;
  int seu_count = 0;


  
 /**********************************************************************************
 * DMEM INITIALIZATION
 *
 * All memory words are initialized to a deterministic reference value
 * used for runtime SEU detection.
 **********************************************************************************/
  for (int i = 0; i < dmem_words; i++) 
  {
    mem[i] = 0x00000000;
  }

  neorv32_uart0_printf("RAM initialized\n");
  neorv32_uart0_printf("Press 's' to scan, 'r' to reset RAM\n");


  uint8_t led = 0;

  while(1) 
  {

  
    // Heartbeat LED on bit 0
    led ^= 0x01;
    neorv32_gpio_port_set(led);
    delay_ms(500);  // 0.5 seconde


    if (neorv32_uart_char_received(NEORV32_UART0)) 
    {
      char cmd = neorv32_uart_char_received_get(NEORV32_UART0);
      
      if (cmd == 's')
      {
        // Check DMEM for SEU
        for (int i = 0; i < dmem_words; i++) {
          if (mem[i] != 0x00000000) 
          {
            neorv32_uart0_printf("SEU at addr 0x%X : 0x%X\n", (uint32_t)(mem + i), mem[i]);
            seu_count = seu_count + 1;
          }
        }
        neorv32_uart0_printf("Scan done. %d SEU(s) found.\n", seu_count);
        seu_count = 0;
      }

      else if (cmd == 'r')
      {
        for (int i = 0; i < dmem_words; i++) 
        {
        mem[i] = 0x00000000;
        }
        neorv32_uart0_printf("RAM reset.\n");
      }
      
      else 
      {
        neorv32_uart0_printf("Wrong entry! .\n");
        neorv32_uart0_printf("Press 's' to scan, 'r' to reset RAM\n");
      }
  
    }
  }

  return 0;
}
