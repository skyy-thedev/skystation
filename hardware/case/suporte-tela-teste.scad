// SkyStation - suporte de bancada p/ TESTE da tela 14" (v0.1)
// 2 pes que seguram o painel nu em pe + 1 presilha de alivio do cabo eDP.
// Ranhura larga (8 mm) forrada com EVA/fita dupla-face espuma: serve p/ paineis de 3 a 6 mm.
PART = "pe";       // pe | presilha | conjunto
$fn = 40;
slot  = 8;         // largura da ranhura (painel + espuma)
tilt  = 12;        // inclinacao p/ tras
base  = [70, 80, 3];
front = 8;         // altura da aba da frente (cobre pouco da tela)
back  = 45;        // altura do encosto traseiro
wl    = 3;         // espessura das paredes
len   = 50;        // comprimento do pe (ao longo da borda da tela)

module pe(){
  // base
  translate([-base[0]/2+len/2, -25, 0]) cube(base);
  // berco inclinado
  translate([0, 10, base[2]]) rotate([-tilt,0,0]) {
    cube([len, wl, front]);                                 // aba frontal
    translate([0, 0, -1]) cube([len, wl*2+slot, wl+1]);     // fundo da ranhura
    translate([0, wl+slot, 0]) cube([len, wl, back]);       // encosto
    // nervuras do encosto
    for(x=[4, len-4-wl]) translate([x, wl+slot, 0]) hull(){
      cube([wl, wl, back*0.8]); translate([0, 22, -6]) cube([wl, 1, 1]); }
  }
  // reforco base->nervuras
  for(x=[4, len-4-wl]) translate([x, 10+wl*2+slot-2, base[2]-0.01]) cube([wl, 26, 6]);
}

module presilha(){ // cola no verso do painel (fita dupla-face) perto do conector
  difference(){
    cube([40, 22, 7]);
    translate([5, -1, 2.2]) cube([30, 24, 3.2]);   // canal do cabo (flat) 30 x 3.2
  }
}

if(PART=="pe") pe();
if(PART=="presilha") presilha();
if(PART=="conjunto"){
  pe(); translate([200,0,0]) pe();
  color("#0b0d12") translate([-70, 10+3+1.5, 3+3]) rotate([-tilt,0,0]) cube([340, 5, 200]);
}
