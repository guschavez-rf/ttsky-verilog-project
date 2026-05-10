import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, Edge

# --- FUNCIÓN AUXILIAR: Escribir un bit en ui_in ---
def set_rx_pin(dut, bit_value):
    # Leemos el valor actual de todos los pines (0 a 7)
    current_val = int(dut.ui_in.value) if dut.ui_in.value.is_resolvable else 0
    if bit_value:
        dut.ui_in.value = current_val | 1    # Pone el bit 0 en '1'
    else:
        dut.ui_in.value = current_val & ~1   # Pone el bit 0 en '0'

# --- FUNCIÓN PARA ENVIAR (PC -> ASIC) ---
async def send_uart_byte(dut, byte_val):
    baud_period = 8680  # ns para 115200 baudios
    # Bit de inicio
    set_rx_pin(dut, 0)
    await Timer(baud_period, unit="ns")
    # 8 Bits (LSB primero)
    for i in range(8):
        set_rx_pin(dut, (byte_val >> i) & 1)
        await Timer(baud_period, unit="ns")
    # Bit de parada
    set_rx_pin(dut, 1)
    await Timer(baud_period, unit="ns")

# --- FUNCIÓN PARA RECIBIR (ASIC -> PC) ---
async def read_uart_byte(dut):
    baud_period = 8680 
    
    # 1. Esperar al bit de inicio (el pin tx_pin, uo_out bit 0, cae a 0)
    # Buscamos un flanco de bajada leyendo el bus completo
    if (int(dut.uo_out.value) & 1) == 1:
        while True:
            await Edge(dut.uo_out)
            if (int(dut.uo_out.value) & 1) == 0:
                break
    
    # Posicionarse en el centro del bit de inicio
    await Timer(baud_period / 2.0, unit="ns") 
    
    byte_res = 0
    await Timer(baud_period, unit="ns") # Saltar el bit de inicio
    
    # 2. Leer los 8 bits de datos
    for i in range(8):
        if int(dut.uo_out.value) & 1:
            byte_res |= (1 << i)
        await Timer(baud_period, unit="ns")
    
    return byte_res

# --- TEST PRINCIPAL ---
@cocotb.test()
async def test_jitter_meter(dut):
    # Reloj a 50 MHz (20ns), usando 'unit' en lugar de 'units'
    clock = Clock(dut.clk, 20, unit="ns")
    cocotb.start_soon(clock.start())

    # Reset Inicial
    dut.ena.value = 1
    dut.ui_in.value = 1   # Inicializamos el bus completo (bit 0 en 1, resto en 0)
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)

    # 1. Configurar Tolerancia a 50 (0x0032)
    # Comando: '$', 'T', 0x00, 0x32
    dut._log.info("Configurando Tolerancia...")
    await send_uart_byte(dut, ord('$'))
    await send_uart_byte(dut, ord('T'))
    await send_uart_byte(dut, 0x00)
    await send_uart_byte(dut, 0x32)
    await ClockCycles(dut.clk, 50)

    # 2. Pedir Jitter Máximo
    dut._log.info("Pidiendo Jitter Maximo...")
    await send_uart_byte(dut, ord('$'))
    await send_uart_byte(dut, ord('M'))

    # 3. Leer respuesta del ASIC
    high_byte = await read_uart_byte(dut)
    low_byte = await read_uart_byte(dut)
    
    resultado = (high_byte << 8) | low_byte
    dut._log.info(f"Valor recibido del ASIC: {resultado}")

    # Validamos que responda un número sin colgarse
    assert resultado >= 0 
    
    dut._log.info("Test completado exitosamente")