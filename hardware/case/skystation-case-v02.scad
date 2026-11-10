// =====================================================================
//  SkyStation Case v0.2  —  parametrico (OpenSCAD)
//  Console de 2 andares:
//    ANDAR DE BAIXO (deck): leitor de DVD slim com bandeja pela frente,
//      bateria, alto-falante e entrada de ar
//    ANDAR DE CIMA (tray): placa Samsung (i5-4200U), SSD 2,5", plaquinha
//      USB + botao, antenas Wi-Fi/Bluetooth nas laterais
//    TAMPA: dock da tela 14" removivel (modo dev) ou tampa do modo TV
//  Impressora: Anycubic Kobra X (mesa 260x260)  |  Material: PETG
//
//  Eixos: X = largura (esq -> dir, olhando de frente)
//         Y = profundidade (frente -> fundo)      Z = altura
//  Fundo (Y max) = lado das portas da placa (VGA/HDMI/USB/P2 + exaustao)
//
//  Posicoes de portas/furos ESTIMADAS pela foto e medidas de DVD, bateria
//  e alto-falante sao TIPICAS. Tudo marcado [MEDIR] deve ser trocado
//  pelas medidas reais antes da impressao final.
// =====================================================================

PART = "assembly";
SHOW_LID = true;
$fn = 48;

// ---------- placa ----------
board_w    = 200;
board_d    = 220;
pcb_t      = 1.6;
standoff_h = 8;      // espaco p/ componentes do lado de baixo + ar
comp_h     = 20;     // componente mais alto acima da PCB (cooler)
notch_x0   = 92;     // [MEDIR] inicio do recorte em L (da esquerda)
notch_y1   = 118;    // [MEDIR] fim do recorte em L (da frente)
// furos de fixacao [x,y] a partir do canto frente-esquerda da placa [MEDIR]
board_holes = [[99,210],[195,199],[163,126],[103,122],[88,102],[26,23],[64,10]];  // H1,H2,H4,H5,H6,H7,H8

// ---------- caixa ----------
wall    = 2.4;
floor_t = 2.4;
side_m  = 10;        // margem lateral (onde ficam os parafusos da tampa)
clr     = 1.0;
lip     = 1.6;       // aba que segura o painel por fora
panel_t = 2.0;
gap     = 0.4;       // folga do trilho
fz      = lip + panel_t + gap + 1.6;   // profundidade da zona do painel
port_gap= 0.8;       // distancia PCB -> painel traseiro

W = board_w + 2*clr + 2*side_m + 2*wall;
inner_h = standoff_h + pcb_t + comp_h + 4;
H = floor_t + inner_h;
D = fz + clr + board_d + port_gap + fz;
lid_t = 2.4;
corner_r = 6;

bx0 = wall + side_m + clr;           // origem da placa na caixa
by0 = fz + clr;
pcb_z   = floor_t + standoff_h;
pcb_top = pcb_z + pcb_t;
lid_screws = [[wall+side_m/2, D*0.18],[wall+side_m/2, D*0.82],
              [W-wall-side_m/2, D*0.18],[W-wall-side_m/2, D*0.82]];

// ---------- portas traseiras (x da placa, z acima do topo da PCB) [MEDIR]
// [x_centro, z_centro, largura, altura, raio]
rear_ports = [
  [ 91.5, 4.5, 19, 10, 2.0], // P1 VGA
  [118, 3.0, 16,  7, 1.0],   // P2 HDMI
  [140, 3.5, 15,  8, 1.0],   // P3 USB
  [157, 3.0,  7,  7, 3.49],  // P4 fone (P2)
];
exhaust_x = [2, 80];   // saida do dissipador [MEDIR]
exhaust_z = [-1, 13];

// ---------- plaquinha USB + botao (frente) ----------
sub_w = 75; sub_d = 30;   // [MEDIR]
sub_x = 118;              // x na placa
sub_h = 5;                // altura dos pinos
sub_usb_x = [138, 163];   // centros das USB [MEDIR]
sub_btn_x = sub_x + 12;   // botao (x na placa) [MEDIR]
sub_btn_y = 18;           // botao (y a partir da frente da placa) [MEDIR]
sub_holes = [[sub_x+6, 22],[sub_x+sub_w-6, 8]];

// ---------- SSD 2.5" ----------
ssd = [100, 70, 7];
ssd_pos = [bx0 + notch_x0 + 1, by0 + 40];   // conector SATA ~y=70 [CONFERIR]
ssd_z = floor_t + standoff_h - 4;    // [CONFERIR com o conector SATA]

// ---------- cooler / energia ----------
fan_c = [42, 168]; fan_r = 30;       // [MEDIR]
dc_y = 185; dc_d = 8.5;              // plug de energia, lateral direita [MEDIR]

// ---------- dock da tela ----------
dock_len = 150; dock_d = 22; dock_h = 16;
slot_len = 122; slot_w = 9; slot_depth = 14; tilt = 10;
dock_y  = D - 42;
cable_slot = [34, 8];
cable_y = D - 17;

// ---------- ANDAR DE BAIXO (v0.2) ----------
dvd   = [128, 127, 9.5];    // leitor slim (SU-208FB) [MEDIR: 9,5 ou 12,7 de altura]
bat   = [205, 50, 21];      // bateria do notebook [MEDIR]
spk   = [40, 16, 12];       // alto-falante (larg, prof, alt) [MEDIR]
bay_h = max(dvd[2]+1, bat[2]) + 2;       // altura livre do andar
H2    = floor_t + bay_h;                 // altura do andar de baixo
dvd_x = wall + 12;                       // livre das colunas de parafuso
dvd_z = floor_t + 1;                     // apoiado em nervuras de 1 mm
bat_pos = [(W-bat[0])/2, dvd[1] + 5];    // atravessado, atras do leitor
spk_pos = [dvd_x + dvd[0] + 14, wall];   // frente-direita, som para a frente
strap_y = 96;                            // cinta que prende o leitor
strap_bx = [dvd_x - 6.5, dvd_x + dvd[0] + 6.5];
// passagem de cabos entre os andares (DVD, bateria, som) [CONFERIR]
cable_pass = [bx0 + notch_x0 + 12, by0 + 31.5, 76, 7];
// antenas Wi-Fi/BT: filme entra entre a parede lateral e uma nervura
ant_y = 70; ant_len = 70; ant_h = 16;

// ---------- tela ----------
scr_w = 340; scr_h = 200; scr_t = 5.5;   // [MEDIR espessura]
bez = 7; flip = 4; chin = 12; fr_depth = scr_t + 3;
FW = scr_w + 2*bez; FH = scr_h + bez + chin;

// ---------- parafusos ----------
insert_d = 4.2;  m3 = 3.4;  boss_d = 9;

// =====================================================================
module rbox(s, r){ hull() for(x=[r,s[0]-r], y=[r,s[1]-r]) translate([x,y,0]) cylinder(r=r,h=s[2]); }
module rrect2d(w,h,r){ offset(r) offset(-r) square([w,h],center=true); }
module vents(r, h, pitch=5.5, w=3){ intersection(){ cylinder(r=r,h=h);
  for(i=[-floor(r/pitch):floor(r/pitch)]) translate([i*pitch-w/2,-r-1,0]) cube([w,2*r+2,h]); } }

// ---------------- BANDEJA ----------------
module tray(){
  difference(){
    union(){
      difference(){
        rbox([W,D,H], corner_r);
        translate([wall,wall,floor_t]) cube([W-2*wall, D-2*wall, H]);
      }
      // blocos laterais das zonas de painel (frente e fundo)
      for(y=[0, D-fz]) for(x=[0, W-wall-2]) translate([x, y, 0]) cube([wall+2, fz, H]);
      for(c=lid_screws) translate([c[0],c[1],0]) cylinder(d=boss_d, h=H);
      for(h=board_holes) translate([bx0+h[0],by0+h[1],0]) cylinder(d=7, h=pcb_z);
      for(h=sub_holes)   translate([bx0+h[0],by0+h[1],0]) cylinder(d=7, h=floor_t+sub_h);
      // v0.2: nervuras das antenas (MAIN a direita, AUX a esquerda), longe do dissipador
      for(x=[wall+2.2, W-wall-2.2-1.2]) translate([x, ant_y, floor_t-0.01]) cube([1.2, ant_len, ant_h]);
      for(dy=[-1.6, ssd[1]+0.4]) translate([ssd_pos[0], ssd_pos[1]+dy, 0]) cube([ssd[0], 1.2, ssd_z+2]);
      translate([ssd_pos[0], ssd_pos[1], 0]) for(x=[10, ssd[0]-20]) translate([x,0,0]) cube([10, ssd[1], ssd_z]);
    }
    // aberturas frente/fundo
    for(y=[-1, D-lip-1]) translate([wall+2, y, floor_t]) cube([W-2*wall-4, lip+2+5, H]);
    // trilhos dos paineis
    for(y=[lip, D-lip-panel_t-gap]) translate([wall+0.6, y, floor_t]) cube([W-2*wall-1.2, panel_t+gap, H]);
    // insertos
    for(c=lid_screws)  translate([c[0],c[1],H-10]) cylinder(d=insert_d, h=11);
    for(h=board_holes) translate([bx0+h[0],by0+h[1],floor_t]) cylinder(d=insert_d, h=pcb_z);
    for(h=sub_holes)   translate([bx0+h[0],by0+h[1],floor_t]) cylinder(d=insert_d, h=sub_h+1);
    // entrada de ar: sob o cooler + sob CPU/VRM
    translate([bx0+fan_c[0], by0+fan_c[1], -1]) vents(fan_r+4, floor_t+2);
    translate([bx0+58, by0+128, -1]) for(i=[0:7]) translate([i*6,0,0]) cube([3,40,floor_t+2]);
    // plug de energia
    translate([W-wall-3, by0+dc_y, pcb_top+5]) rotate([0,90,0]) cylinder(d=dc_d, h=wall+4);
    // v0.2: insertos por baixo (parafusos M3x30 que sobem do andar de baixo)
    for(c=lid_screws) translate([c[0],c[1],-0.01]) cylinder(d=insert_d, h=8);
    // v0.2: passagem de cabos para o andar de baixo
    translate([cable_pass[0], cable_pass[1], -1]) cube([cable_pass[2], cable_pass[3], floor_t+2]);
  }
}

// ---------------- ANDAR DE BAIXO (v0.2) ----------------
module rib_frame(p, s, h, t=1.6, open=0.45){   // moldura de nervuras com cantos; lados abertos
  for(c=[[0,0,1,1],[s[0],0,-1,1],[0,s[1],1,-1],[s[0],s[1],-1,-1]]) translate([p[0]+c[0], p[1]+c[1], floor_t-0.01]) {
    translate([c[2]<0?-s[0]*(1-open)/2:-t*0+(-t), c[3]<0?0:-t, 0]) cube([s[0]*(1-open)/2+t, t, h]);
    translate([c[2]<0?0:-t, c[3]<0?-s[1]*(1-open)/2:-t, 0]) cube([t, s[1]*(1-open)/2+t, h]);
  }
}
module deck(){
  difference(){
    union(){
      difference(){
        rbox([W,D,H2], corner_r);
        translate([wall,wall,floor_t]) cube([W-2*wall, D-2*wall, H2]);
      }
      // colunas dos parafusos que unem os andares
      for(c=lid_screws) translate([c[0],c[1],0]) cylinder(d=boss_d, h=H2);
      // leitor: nervuras de apoio, guias laterais, batentes de fundo, torres da cinta
      for(x=[14, dvd[0]/2, dvd[0]-14]) translate([dvd_x+x-2, wall, floor_t-0.01]) cube([4, dvd[1]-6, 1]);
      for(x=[dvd_x-2.1, dvd_x+dvd[0]+0.5]) translate([x, wall+6, floor_t-0.01]) cube([1.6, dvd[1]-30, dvd[2]]);
      for(x=[dvd_x, dvd_x+dvd[0]-10]) translate([x, dvd[1]+0.6, floor_t-0.01]) cube([10, 2, 6]);
      for(x=strap_bx) translate([x, strap_y, 0]) cylinder(d=8, h=dvd_z+dvd[2]+0.3);
      // bateria e alto-falante: molduras
      rib_frame(bat_pos, [bat[0],bat[1]], 8);
      rib_frame([spk_pos[0], spk_pos[1]+0.3], [spk[0],spk[1]], spk[2]*0.6, 1.4, 0.3);
    }
    // boca do leitor (a bandeja e o botao de ejetar ficam na frente)
    translate([dvd_x-0.6, -1, dvd_z-0.5]) cube([dvd[0]+1.2, wall+2, dvd[2]+1.3]);
    // grade do alto-falante
    for(i=[0:floor(spk[0]/4.4)-1]) translate([spk_pos[0]+1+i*4.4, -1, floor_t+1.5]) cube([2.2, wall+2, spk[2]-1]);
    // parafusos M3x30 por baixo (cabeca embutida)
    for(c=lid_screws) translate([c[0],c[1],-1]) { cylinder(d=m3, h=H2+2); cylinder(d=6.4, h=1+3.2); }
    for(x=strap_bx) translate([x, strap_y, dvd_z+dvd[2]-7]) cylinder(d=insert_d, h=9);
    // entrada de ar: fundo livre atras da bateria + laterais
    for(i=[0:15]) translate([20+i*6, bat_pos[1]+bat[1]+8, -1]) cube([3, D-(bat_pos[1]+bat[1])-22, floor_t+2]);
    for(x=[-1, W-wall-1]) for(i=[0:6]) translate([x, D-50+i*5.5, floor_t+4]) cube([wall+2, 2.6, bay_h-8]);
    // rebaixo dos pes de borracha (12 mm)
    for(p=[[18,16],[W-18,16],[18,D-16],[W-18,D-16]]) translate([p[0],p[1],-0.01]) cylinder(d=12.6, h=0.8);
  }
}
module dvd_strap(){
  L = strap_bx[1]-strap_bx[0];
  difference(){
    hull() for(x=[0,L]) translate([x,0,0]) cylinder(d=10, h=3);
    for(x=[0,L]) translate([x,0,-1]) cylinder(d=m3, h=5);
  }
}

// ---------------- PAINEIS DE PORTAS ----------------
module io_blank(){ translate([wall+0.8, 0, floor_t]) cube([W-2*wall-1.6, panel_t, inner_h]); }
module rear_io(){
  difference(){
    io_blank();
    for(p=rear_ports) translate([bx0+p[0], -1, pcb_top+p[1]]) rotate([-90,0,0])
      linear_extrude(panel_t+2) rrect2d(p[2], p[3], p[4]);
    for(x=[exhaust_x[0]:4:exhaust_x[1]-2]) translate([bx0+x, -1, pcb_top+exhaust_z[0]]) cube([2.4, panel_t+2, exhaust_z[1]-exhaust_z[0]]);
  }
}
module front_io(){
  difference(){
    io_blank();
    for(x=sub_usb_x) translate([bx0+x, -1, floor_t+sub_h+pcb_t+3.5]) rotate([-90,0,0])
      linear_extrude(panel_t+2) rrect2d(15, 8, 1);
    for(i=[0:5]) translate([wall+side_m+16+i*7, -1, floor_t+inner_h/2-1.5]) cube([4, panel_t+2, 3]);
  }
}

// ---------------- TAMPA ----------------
logo_pos = [W/2-12, 62];
module logo2d(){ text("SkyStation", size=14, font="Liberation Sans:style=Bold", halign="center", valign="center"); }
module lid(){
  difference(){
    union(){
      rbox([W,D,lid_t], corner_r);
      translate([W/2-dock_len/2, dock_y-dock_d/2, lid_t-0.01]) rbox([dock_len, dock_d, dock_h], 4);
    }
    translate([W/2, dock_y, lid_t+dock_h+0.01]) rotate([-tilt,0,0])
      translate([-slot_len/2, -slot_w/2, -slot_depth]) cube([slot_len, slot_w, slot_depth+6]);
    translate([W/2, cable_y, -5]) linear_extrude(20) rrect2d(cable_slot[0], cable_slot[1], 3.9);
    for(c=lid_screws) translate([c[0],c[1],-1]) { cylinder(d=m3, h=10); translate([0,0,lid_t-0.6]) cylinder(d=6.4, h=5); }
    translate([bx0+fan_c[0], by0+fan_c[1], -4]) vents(fan_r+2, 10);
    translate([bx0+sub_btn_x, by0+sub_btn_y, -5]) cylinder(d=10.6, h=20);
    translate([logo_pos[0], logo_pos[1], lid_t-0.6]) linear_extrude(1) logo2d();
  }
}
module lid_logo(){ translate([logo_pos[0], logo_pos[1], lid_t-0.6]) linear_extrude(0.6) offset(-0.12) logo2d(); }

btn_stem = H - (floor_t+sub_h+pcb_t+4.5);   // ate o topo do botao tatil (~4.5 mm)
module button(){
  cylinder(d=10, h=lid_t+1.2);
  translate([0,0,-1.2]) cylinder(d=14, h=1.2);
  translate([0,0,-btn_stem]) cylinder(d=4, h=btn_stem);
}

// ---------------- TAMPA DO MODO TV ----------------
module tv_cap(){
  translate([W/2-dock_len/2, dock_y-dock_d/2, lid_t+dock_h]) rbox([dock_len, D-(dock_y-dock_d/2)-wall-3, 2.4], 4);
  translate([W/2, dock_y, lid_t+dock_h+0.01]) rotate([-tilt,0,0])
    translate([-(slot_len-0.6)/2, -(slot_w-0.6)/2, -slot_depth+0.5]) cube([slot_len-0.6, slot_w-0.6, slot_depth]);
  // tampao da passagem do cabo
  translate([W/2, cable_y, 0]) linear_extrude(lid_t+dock_h) rrect2d(cable_slot[0]-0.6, cable_slot[1]-0.6, 3.6);
}

// ---------------- MOLDURA DA TELA ----------------
splice_bot = [-55,-20,20,55];  splice_top = [-30,30];
module frame_full(){
  difference(){
    rbox([FW, FH, fr_depth], 5);
    translate([bez+flip, chin+flip, -1]) cube([scr_w-2*flip, scr_h-2*flip, 10]);
    translate([bez-0.5, chin-0.5, 2]) cube([scr_w+1, scr_h+1, 20]);
    for(dx=splice_bot) translate([FW/2+dx, chin/2, fr_depth-8]) cylinder(d=insert_d, h=10);
    for(dx=splice_top) translate([FW/2+dx, FH-bez/2, fr_depth-6]) cylinder(d=insert_d, h=10);
    translate([FW/2-20, -1, 2]) cube([40, chin, fr_depth]);   // saida do cabo eDP
  }
}
module frame_left(){  intersection(){ frame_full(); translate([-1,-1,-1]) cube([FW/2+1, FH+2, 50]); } }
module frame_right(){ intersection(){ frame_full(); translate([FW/2,-1,-1]) cube([FW/2+1, FH+2, 50]); } }
module foot(){
  difference(){
    union(){
      translate([FW/2-70, 0, fr_depth]) cube([140, chin, 3]);
      translate([FW/2-(slot_len-0.8)/2, -slot_depth, fr_depth]) cube([slot_len-0.8, slot_depth+chin, slot_w-0.8]);
    }
    for(dx=splice_bot) translate([FW/2+dx, chin/2, fr_depth-1]) { cylinder(d=m3, h=20); translate([0,0,slot_w-0.8-1.8]) cylinder(d=6.4,h=5);}
    translate([FW/2-20, -slot_depth-1, fr_depth-1]) cube([40, slot_depth+chin+2, 4.5]); // canal do cabo
  }
}
module top_splice(){
  difference(){
    translate([FW/2-42, FH-bez, fr_depth]) cube([84, bez, 3]);
    for(dx=splice_top) translate([FW/2+dx, FH-bez/2, fr_depth-1]) cylinder(d=m3, h=10);
  }
}

// ---------------- MONTAGEM ----------------
module board_dummy(){
  color("RoyalBlue") translate([bx0,by0,pcb_z]) linear_extrude(pcb_t) difference(){
    square([board_w, board_d]); translate([notch_x0,-1]) square([board_w, notch_y1+1]); }
  color("Silver") translate([bx0+fan_c[0],by0+fan_c[1],pcb_top]) cylinder(r=fan_r,h=comp_h-6);
  color("Peru") translate([bx0+2,by0+board_d-14,pcb_top]) cube([78,14,12]);
  color("DimGray") translate([ssd_pos[0],ssd_pos[1],ssd_z]) cube(ssd);
  color("SeaGreen") translate([bx0+sub_x, by0, floor_t+sub_h]) cube([sub_w,sub_d,pcb_t]);
}
FM = [[1,0,0,0],[0,0,1,0],[0,1,0,0],[0,0,0,1]];   // moldura em pe (y->z, z->y)
module screen_parts(){
  frame_left(); frame_right(); foot(); top_splice();
}
module deck_dummy(){
  color("Silver") translate([dvd_x, 0, dvd_z]) cube(dvd);
  color("#222") translate([dvd_x, -0.2, dvd_z]) cube([dvd[0], 2, dvd[2]]);
  color("DarkOrange") translate([bat_pos[0], bat_pos[1], floor_t]) cube(bat);
  color("Gold") translate([spk_pos[0], spk_pos[1]+0.3, floor_t]) cube(spk);
  color("#3d4455") translate([strap_bx[0], strap_y, dvd_z+dvd[2]+0.3]) dvd_strap();
}
module assembly(screen=true, show_board=false, explode=0){
  color("#232733") deck();
  deck_dummy();
  translate([0,0,H2+explode]) upper(screen, show_board);
}
module upper(screen=true, show_board=false){
  color("#2b2f3a") tray();
  color("#3d4455") translate([0, lip+gap/2, 0]) front_io();
  color("#3d4455") translate([0, D-lip-panel_t-gap/2, 0]) rear_io();
  if(show_board) board_dummy();
  if(SHOW_LID){ color("#2b2f3a") translate([0,0,H]) lid();
  color("#2ec4ff") translate([0,0,H]) lid_logo(); }
  if(screen){
    translate([W/2, dock_y, H+lid_t+dock_h]) rotate([-tilt,0,0])
      translate([-FW/2, -(fr_depth+(slot_w-0.8)/2), 0.5]) multmatrix(FM){
        color("#2b2f3a") screen_parts();
        color("#0b0d12") translate([bez, chin, 2]) cube([scr_w, scr_h, scr_t]);
      }
  } else if(SHOW_LID) color("#2ec4ff") translate([0,0,H]) tv_cap();
}

// ---------------- SELETOR (orientado p/ impressao) ----------------
if(PART=="assembly")     assembly(true);
if(PART=="assembly_tv")  assembly(false);
if(PART=="assembly_open") assembly(false, true);
if(PART=="assembly_explode") assembly(false, true, 45);
if(PART=="deck_open")    { color("#232733") deck(); deck_dummy(); }
if(PART=="deck")         deck();
if(PART=="dvd_strap")    dvd_strap();
if(PART=="tray")         tray();
if(PART=="lid")          lid();
if(PART=="logo")         lid_logo();   // mesma origem da tampa: importe junto como 2a cor
if(PART=="rear_io")      rotate([90,0,0]) translate([0,0,-floor_t]) rear_io();
if(PART=="front_io")     rotate([90,0,0]) translate([0,0,-floor_t]) front_io();
if(PART=="button")       translate([0,0,lid_t+1.2]) rotate([180,0,0]) button();
if(PART=="tv_cap")       translate([0,0,-H]) tv_cap();
if(PART=="frame_left")   frame_left();
if(PART=="frame_right")  frame_right();
if(PART=="foot")         foot();
if(PART=="top_splice")   top_splice();
if(PART=="dims") echo(W=W, D=D, H=H, H2=H2, total=H2+H+lid_t, FW=FW, FH=FH);
