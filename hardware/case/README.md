# Case do SkyStation (protótipo v0.1)

Case modular impressa em 3D para a placa do notebook (Samsung, i5-4200U), pensada para a
**Anycubic Kobra X** (mesa 260×260 mm) em **PETG**.

- **Base** (227 × 233 × 36 mm, peça única): placa sobre pinos de 8 mm (entrada de ar por baixo),
  SSD 2,5" encaixado direto no conector SATA, plaquinha USB + botão na frente,
  painéis de portas **removíveis** (frente e fundo) para reimprimir só eles se um furo errar.
- **Tampa** com dock para a tela, respiro sobre o cooler e logo para inlay colorido.
- **Tela 14"** removível (modo desenvolvimento) em moldura de 2 metades + pé que encaixa no dock;
  no **modo TV** uma tampa cobre o dock e o console vai na TV pelo HDMI.
- **Suporte de bancada** (`suporte-tela-teste.scad`) para testar a tela antes do módulo definitivo.

Posições de portas e furos ainda são **estimadas pela foto** (marcadas `[MEDIR]` no `.scad`).
Medir a partir do canto R conforme `render/medidas.jpg` e atualizar os parâmetros.

Gerar uma peça:  `openscad -o base.stl -D 'PART="tray"' skystation-case.scad`
(peças: tray, lid, logo, rear_io, front_io, button, tv_cap, frame_left, frame_right, foot, top_splice)

Montagem: insertos de latão M3 (furo 4,2 mm), parafusos M3 6/10 mm, 4 pés de borracha 12 mm.
