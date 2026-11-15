# Voice-Controlled Pixel Flappy Pigeon (Nexys A7-100T)

Final Project Digital Logic — Verilog HDL on **Digilent Nexys A7-100T (`xc7a100tcsg324-1`)**, **Vivado 2024.2**.

## Folder Structure
- `rtl/` — Pure Verilog-2001 modules (no external IP wizards required):
  - `top.v` — Top-level integration
  - `pdm_mic.v` — Onboard PDM Mic (`MP34DT01`) driver, DC-offset removal, envelope & threshold detector, 16-LED VU meter
  - `vga_sync.v` — 640×480 @ 60Hz VGA timing generator
  - `game_engine.v` — Fixed-point physics, 3 cycling pipes (LFSR), collision, score & high-score
  - `vga_renderer.v` — On-the-fly Pixel Art renderer (sky, clouds, shaded pipes, scrolling ground, Pigeon AI sprite, live voice bar, HUD & banners)
  - `pigeon_rom.v` — Dual-frame 48×48 RGB444 sprite BRAM ROM (`pigeon_down.mem`, `pigeon_up.mem`)
  - `font_rom.v` — 8×8 bitmap font ROM
  - `bin2bcd.v` — Combinational Double-Dabble Binary-to-BCD converter
  - `seven_seg_ctrl.v` — 8-digit multiplexed 7-segment display controller
  - `audio_sfx.v` — Mono PWM audio SFX (`AUD_PWM`, `AUD_SD`)
  - `debounce.v` — Synchronizer & 20ms debouncer for `BTNC` / `BTNU`
- `mem/` — 48×48 12-bit RGB444 sprite memory initialization files (`pigeon_down.mem`, `pigeon_up.mem`)
- `constraints/` — `Nexys-A7-100T-FlappyPigeon.xdc`
- `tb/` — `tb_flappy_pigeon.v` (Behavioral simulation testbench)
- `scripts/` — `img_to_mem.py` (Optional script to convert your downloaded Pigeon AI image into `.mem` sprite files)

## Controls on Nexys A7-100T
| Input | Function |
| :--- | :--- |
| **Onboard Mic** | Speak / hum / blow above threshold to fly up; stay silent to dive down |
| `SW[3:0]` | Mic threshold sensitivity (`0000` = most sensitive, `1111` = loudest required) |
| `SW[4]` | Flight mode: `0` = Hold voice to rise (continuous), `1` = Edge-triggered flap |
| `SW[6:5]` | Difficulty: `00` = Easy, `01` = Normal, `10`/`11` = Hard |
| `SW[7]` | `1` = Disable mic trigger (use `BTNC` button only) |
| `SW[15]` | `1` = Mute 3.5mm audio SFX |
| `BTNC` | Backup manual fly/flap button + Start/Restart game |
| `BTNU` | Pause / Resume during gameplay |
| `CPU_RESETN` | Reset entire system (including High Score) |

## Output Peripherals
- **VGA (640×480 @ 60Hz):** Pixel Art Flappy Pigeon + live mic meter bar (with red threshold line) + Score/Banners
- **7-Segment (8 digits):** Left 4 digits (`AN[7:4]`) = High Score, Right 4 digits (`AN[3:0]`) = Current Score
- **LED[15:0]:** Real-time microphone VU meter
- **RGB LED16:** Blue = Idle/Ready, Green = Voice/Button active, Yellow = Paused, Red = Game Over
- **3.5mm Audio Jack (`AUD_PWM`):** Retro flap, score chime, and crash sound effects

## Vivado 2024.2 Setup Steps
1. Open **Vivado 2024.2** → **Create Project** → **RTL Project**.
2. Select Part: `xc7a100tcsg324-1` (or Board: **Nexys A7-100T**).
3. **Add Sources → Add or create design sources:**
   - Add all `.v` files inside `rtl/`
   - Also add `mem/pigeon_down.mem` and `mem/pigeon_up.mem` (Vivado automatically recognizes `.mem` files for `$readmemh`)
4. **Add Constraints:**
   - Add `constraints/Nexys-A7-100T-FlappyPigeon.xdc`
5. **Add Simulation Sources (optional for waveform/report):**
   - Add `tb/tb_flappy_pigeon.v` and set `tb_flappy_pigeon` as simulation top
   - Run **Simulation → Run Behavioral Simulation** (~7 ms run time completes all 4 self-checks)
6. **Generate Bitstream:**
   - Ensure `top` is set as Synthesis/Implementation top module
   - Click **Generate Bitstream** → **Open Hardware Manager** → **Program Device**

## Converting Your Own Pigeon AI Photo (`pigeon.jpg` / `pigeon.png`)
If you save the Pigeon AI image into this folder as `pigeon.jpg`:
```powershell
pip install pillow
python scripts/img_to_mem.py pigeon.jpg
```
This overwrites `mem/pigeon_down.mem` and `mem/pigeon_up.mem` with a 48×48 12-bit RGB444 sprite from your exact image, then just re-run **Generate Bitstream** in Vivado.
