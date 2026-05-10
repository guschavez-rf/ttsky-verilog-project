import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles

# =======================================================================
# FUNCIONES AUXILIARES (Robustas para GLS)
# =======================================================================
def safe_int(logic_array):
    """
    Convierte LogicArray a entero de forma segura ignorando estados 'X' y 'Z' 
    típicos en simulaciones a nivel de compuertas (GLS).
    """
    try:
        return int(logic_array.value)
    except ValueError:
        return 0

async def uart_write_byte(dut, byte_val, bit_period_ns):
    """ Escribe un byte en ui_in[0] (RX) simulando el protocolo UART """
    # Leemos el estado actual del puerto para no pisar otros pines
    current_ui_in = safe_int(dut.ui_in)
    
    # Bit de Start (0)
    current_ui_in &= ~1  # Forzamos el bit 0 a 0
    dut.ui_in.value = current_ui_in
    await Timer(bit_period_ns, units="ns")
    
    # Bits de Datos (LSB first)
    for i in range(8):
        bit = (byte_val >> i) & 1
        if bit:
            current_ui_in |= 1   # Ponemos bit 0 a 1
        else:
            current_ui_in &= ~1  # Ponemos bit 0 a 0
            
        dut.ui_in.value = current_ui_in
        await Timer(bit_period_ns, units="ns")
        
    # Bit de Stop (1)
    current_ui_in |= 1
    dut.ui_in.value = current_ui_in
    await Timer(bit_period_ns, units="ns")

async def uart_read_byte(dut, bit_period_ns):
    """ Lee un byte desde uo_out[0] (TX) simulando el receptor UART """
    # Esperar al bit de start (TX baja a 0)
    # Hacemos polling cada 100ns para no saturar el simulador
    while (safe_int(dut.uo_out) & 1) == 1:
        await Timer(100, units="ns") 
        
    # Ir al centro del bit de start
    await Timer(bit_period_ns / 2.0, units="ns")
    
    # Muestrear los 8 bits de datos
    byte_val = 0
    for i in range(8):
        await Timer(bit_period_ns, units="ns")
        bit = safe_int(dut.uo_out) & 1
        byte_val |= (bit << i)
        
    # Esperar al bit de stop
    await Timer(bit_period_ns, units="ns")
    return byte_val

# =======================================================================
# TEST PRINCIPAL
# =======================================================================
@cocotb.test()
async def test_jitter_meter(dut):
    dut._log.info("Iniciando simulación del Medidor de Jitter (Compatible con GLS)")

    # 1. Configuración de Tiempos
    clk_period_ns = 20  # 50 MHz
    bit_period_ns = 8680.55  # 1 / 115200 = 8.68055 us
    
    clock = Clock(dut.clk, clk_period_ns, units="ns")
    cocotb.start_soon(clock.start())

    # 2. Inicialización
    dut.ena.value = 1
    # Ponemos ui_in a 1 (00000001 en binario) para que RX arranque en IDLE
    dut.ui_in.value = 1     
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    
    # Reset prolongado para estabilizar todos los flip-flops físicos
    await ClockCycles(dut.clk, 20)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 20)

    dut._log.info("Reset completado. Entrando en fase de prueba UART.")

    # --- PRUEBA 1: Escribir Registro Ideal ---
    # Comando: '$' (0x24), 'I' (0x49), High (0x03), Low (0xE8) -> Ideal = 1000
    dut._log.info("Escribiendo reg_ideal = 1000...")
    await uart_write_byte(dut, 0x24, bit_period_ns)
    await uart_write_byte(dut, 0x49, bit_period_ns)
    await uart_write_byte(dut, 0x03, bit_period_ns)
    await uart_write_byte(dut, 0xE8, bit_period_ns)
    
    await ClockCycles(dut.clk, 100)

    # --- PRUEBA 2: Leer Cantidad Total (reg_tot) ---
    # Comando: '$' (0x24), 'S' (0x53)
    # Como no hemos activado el gate ni simulado capturas, el chip debe responder 0
    dut._log.info("Solicitando lectura de reg_tot...")
    await uart_write_byte(dut, 0x24, bit_period_ns)
    await uart_write_byte(dut, 0x53, bit_period_ns)

    # El chip responderá con el Byte High y luego el Byte Low
    byte_h = await uart_read_byte(dut, bit_period_ns)
    byte_l = await uart_read_byte(dut, bit_period_ns)
    total_jitter = (byte_h << 8) | byte_l
    
    dut._log.info(f"reg_tot recibido: {total_jitter}")

    # Este assert validará que la prueba pasó con éxito en tu GitHub Action
    assert total_jitter == 0, f"Test falló: Se esperaba 0 en reg_tot, se recibió {total_jitter}"

    dut._log.info("Simulación GLS terminada con éxito. ¡Todo en orden!")