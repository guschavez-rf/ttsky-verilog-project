![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Jitter Meter with UART Interface

This project is a high-precision digital Jitter Meter designed for the **Tiny Tapeout** platform using the Sky130 PDK. The system measures the time deviation of an input signal relative to an ideal reference and allows metric management via UART commands.

## Technical Specifications

- **Clock Frequency:** 50 MHz.
- **Communication:** UART at 115200 baud (8N1).
- **Dimensions:** 1x1 Tile (Tiny Tapeout).
- **Precision:** 15-bit measurement registers.
- **Statistics:** 12-bit counters with **saturation logic at 4095** to prevent overflows.

## System Architecture

The design has been optimized to maximize the use of the 1x1 Tile area, reducing routing congestion through:
1. **Capture Engine:** Signal synchronization and edge-to-edge time measurement.
2. **Jitter Calculation:** Optimized absolute value implementation to reduce hold buffer requirements.
3. **Register Bank:** Efficient memory management for Ideal, Tolerance, and error metric parameters.
4. **UART Controller:** Finite State Machine (FSM) that interprets a serial command protocol.

## Command Protocol (UART)

The chip listens for commands using the format: `$[COMMAND_CHARACTER][OPTIONAL_DATA]`.

### Write Commands (Configuration)
| Command | Function | Additional Data |
| :--- | :--- | :--- |
| `$I` | Set Ideal Time | 2 Bytes (MSB, then LSB) |
| `$T` | Set Tolerance | 2 Bytes (MSB, then LSB) |
| `$R` | Reset Metrics | None |

### Read Commands (The chip responds with 2 bytes)
| Command | Function | Chip Response |
| :--- | :--- | :--- |
| `$M` | Read Max Jitter | [MSB][LSB] (15 bits) |
| `$S` | Read Total Samples | [MSB][LSB] (Saturated at 4095) |
| `$G` | Read Error Counter | [MSB][LSB] (Saturated at 4095) |

## Pin Configuration

| Pin | Name | Type | Description |
| :--- | :--- | :--- | :--- |
| `ui_in[0]` | RX | Input | UART Data Input |
| `ui_in[1]` | sig_in | Input | Signal under test |
| `ui_in[3]` | gate | Input | Measurement Enable (High = ON) |
| `ui_in[4]` | ref_clk | Input | External Reference Clock |
| `uo_out[0]` | TX | Output | UART Data Output |

## How to Test

1. **Simulation:** Run `make test` to execute the `cocotb` testbench.
2. **Hardening:** The GitHub Actions workflow will automatically generate the GDS files using OpenLane/LibreLane.
3. **Real Usage:** Connect a USB-to-Serial adapter at 115200 baud to the designated pins and send configuration commands to start measuring jitter in your signals.

---
**Author:** Gustavo Ismael Chavez Mamani  
*Project developed for Tiny Tapeout.*