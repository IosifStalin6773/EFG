-- CSS base de EFG para todas las páginas DHTML (tareas, inventario web,
-- menús). Las páginas ponen /*EFG_BASE*/ dentro de su <style> y Lua lo
-- sustituye con ix.efgui.InjectCSS(html). Variables :root globales con la
-- paleta, fuentes y texturas de EFT.

ix.efgui = ix.efgui or {}

ix.efgui.css = [==[
@font-face { font-family: "Bender"; src: url("asset://garrysmod/resource/fonts/mbender.ttf"); }

:root {
	/* fondos: gris verdoso de EFT, nunca negro puro */
	--efg-bg0: #0e0f0d;
	--efg-bg1: #1c1e1b;
	--efg-bg2: #252723;
	--efg-bg3: #30332e;
	--efg-slot: #121311;
	--efg-slot-hi: #1f211d;

	/* líneas y biselado */
	--efg-line: #3a3d36;
	--efg-line2: #565a50;
	--efg-bevel-hi: rgba(255,255,255,.07);
	--efg-bevel-lo: rgba(0,0,0,.65);

	/* texto */
	--efg-text: #c8c6b4;
	--efg-text2: #9a9888;
	--efg-dim: #686a5e;

	/* acentos */
	--efg-orange: #e3722d;
	--efg-orange-hi: #f08a45;
	--efg-red: #7a1414;
	--efg-red-hi: #b8322a;
	--efg-green: #4b5320;
	--efg-green-hi: #7b8a3a;
	--efg-ok: #8fb34a;
	--efg-yellow: #c9a43a;
	--efg-blue: #4f8fb0;

	/* rareza (fondo del objeto, como los colores de EFT) */
	--efg-r-common: rgba(60,62,58,.55);
	--efg-r-uncommon: rgba(54,84,40,.55);
	--efg-r-rare: rgba(36,66,96,.55);
	--efg-r-epic: rgba(76,46,96,.55);
	--efg-r-legendary: rgba(110,92,30,.55);

	/* fuentes */
	--efg-font: "Bender", "Bahnschrift", "Arial Narrow", sans-serif;
	--efg-font-stencil: "Bender", "Bahnschrift SemiCondensed", "Bahnschrift", sans-serif;
	--efg-font-type: "Courier New", "Lucida Console", monospace;

	/* texturas */
	--efg-grunge: url("asset://garrysmod/materials/efg/ui/grunge.png");
	--efg-cell: 48px;
	--efg-shadow-in: inset 1px 1px 0 var(--efg-bevel-lo), inset -1px -1px 0 var(--efg-bevel-hi), inset 0 0 12px rgba(0,0,0,.55);
	--efg-shadow-out: inset 1px 1px 0 var(--efg-bevel-hi), inset -1px -1px 0 var(--efg-bevel-lo), 0 2px 6px rgba(0,0,0,.6);
}

* { box-sizing: border-box; margin: 0; padding: 0; }
html, body { width: 100%; height: 100%; overflow: hidden; background: transparent;
	font-family: var(--efg-font); color: var(--efg-text); font-size: 15px; user-select: none; }

/* paneles: textura grunge, bisel y borde sutil */
.efg-panel, .panel { background: var(--efg-bg1) var(--efg-grunge) repeat; border: 1px solid var(--efg-line);
	box-shadow: var(--efg-shadow-out); }
.efg-inset { background: var(--efg-slot); box-shadow: var(--efg-shadow-in); border: 1px solid #0a0b09; }

/* cabeceras con la pestaña oscura y el triángulo de EFT */
.efg-hdr, .hdr { position: relative; display: flex; align-items: center; height: 26px; padding: 0 12px 0 10px;
	background: #000; border-bottom: 1px solid rgba(255,255,255,.06);
	font-family: var(--efg-font-stencil); font-size: 13px; letter-spacing: 1.5px; text-transform: uppercase; color: var(--efg-text); }
.efg-hdr::before { content: ""; width: 0; height: 0; margin-right: 8px;
	border-left: 5px solid transparent; border-right: 5px solid transparent; border-top: 6px solid var(--efg-text2); }

/* texto secundario tipo máquina de escribir */
.efg-type { font-family: var(--efg-font-type); font-size: 13px; color: var(--efg-text2); line-height: 1.5; letter-spacing: .2px; }

/* botones: solo texto, el hover pinta el fondo (menú principal de EFT) */
.efg-link { background: none; border: 0; font-family: var(--efg-font-stencil); font-size: 22px; letter-spacing: 2px;
	text-transform: uppercase; color: var(--efg-text); padding: 6px 16px; cursor: pointer; }
.efg-link:hover { color: var(--efg-bg0); background: var(--efg-text); }

/* botones normales */
.btn, .efg-btn { background: linear-gradient(#34372f, #24261f); border: 1px solid #0a0b09; box-shadow: var(--efg-shadow-out);
	color: var(--efg-text); padding: 6px 14px; text-transform: uppercase; letter-spacing: 1px;
	font-family: var(--efg-font-stencil); font-size: 13px; cursor: pointer; }
.btn:hover, .efg-btn:hover { background: linear-gradient(#41453a, #2c2f27); color: #fff; }
.btn.on { background: var(--efg-text); color: var(--efg-bg0); box-shadow: none; }
.btn.go { background: linear-gradient(var(--efg-orange), #b8561d); color: #120c06; border-color: #5a2a0c; }
.btn.go:hover { background: linear-gradient(var(--efg-orange-hi), var(--efg-orange)); }
.btn.bad { background: linear-gradient(#4a1010, #2d0909); border-color: #1a0505; color: #e0b0a8; }
.btn.bad:hover { background: linear-gradient(var(--efg-red-hi), var(--efg-red)); color: #fff; }
.btn[disabled] { opacity: .35; pointer-events: none; }

/* celda de rejilla: oscura, hundida, hover suave */
.efg-slot { width: var(--efg-cell); height: var(--efg-cell); background: var(--efg-slot);
	box-shadow: inset 1px 1px 0 rgba(0,0,0,.8), inset -1px -1px 0 rgba(255,255,255,.04), inset 0 0 10px rgba(0,0,0,.6);
	outline: 1px solid rgba(255,255,255,.035); outline-offset: -1px; }
.efg-slot:hover { background: var(--efg-slot-hi); }

/* drag & drop visual */
.efg-slot.drop-ok { background: rgba(143,179,74,.22); outline-color: var(--efg-ok); }
.efg-slot.drop-bad { background: rgba(184,50,42,.25); outline-color: var(--efg-red-hi); }
.efg-item.dragging { opacity: .35; }
.efg-ghost { position: fixed; pointer-events: none; opacity: .85; z-index: 99; box-shadow: 0 0 0 1px var(--efg-orange), 0 6px 18px rgba(0,0,0,.8); }

::-webkit-scrollbar { width: 6px; } ::-webkit-scrollbar-thumb { background: var(--efg-line2); } ::-webkit-scrollbar-track { background: transparent; }
]==]

-- sustituye el marcador /*EFG_BASE*/ de una página por el CSS base
function ix.efgui.InjectCSS(html)
	return (html:gsub("/%*EFG_BASE%*/", function() return ix.efgui.css end, 1))
end
