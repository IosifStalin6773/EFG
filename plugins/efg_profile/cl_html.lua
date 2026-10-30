-- Página derecha de la pestaña PERSONAJE (copia de la pantalla OVERALL de EFT):
-- barra de resumen GENERAL / PMC / SCAV y ESTADÍSTICAS en dos columnas, más las
-- vistas HABILIDADES y LOGROS. Chromium 86: nada de inset, aspect-ratio ni :is().

local PLUGIN = PLUGIN

PLUGIN.profileHTML = [==[
<!doctype html>
<html><head><meta charset="utf-8">
<style>
/*EFG_BASE*/
html, body { margin: 0; height: 100%; overflow: hidden; background: transparent; user-select: none; }
body { font-family: var(--efg-font); color: var(--efg-text); font-size: 14px; }
#app { position: absolute; top: 0; left: 0; right: 0; bottom: 0; display: flex; flex-direction: column; }

#summary { flex: 0 0 auto; background: rgba(8,9,8,.82); border: 1px solid #0a0b09; box-shadow: 0 0 0 1px #20221e; padding: 6px 10px 12px; }
#sides { display: flex; justify-content: space-around; margin-bottom: 6px; }
#sides .s { width: 134px; height: 22px; line-height: 22px; text-align: center; letter-spacing: 1px; color: var(--efg-text2); cursor: pointer; text-transform: uppercase; font-size: 14px; }
#sides .s:hover { color: var(--efg-text); }
#sides .s.on { color: #111; background: linear-gradient(#e2e0cc, #b9b7a3); font-weight: bold; box-shadow: 0 0 6px rgba(226,224,204,.35); }
.cells { display: flex; }
.cell { flex: 1 1 0; text-align: center; padding: 6px 2px 4px; min-width: 0; }
.cell .ic { height: 20px; display: flex; justify-content: center; align-items: center; margin-bottom: 2px; }
.cell .ic svg { width: 18px; height: 18px; }
.cell .ic .box { width: 18px; height: 18px; display: flex; align-items: center; justify-content: center; }
.cell .v { font-size: 19px; color: #e6e4d2; line-height: 22px; white-space: nowrap; }
.cell .l { font-size: 11px; color: var(--efg-dim); line-height: 12px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.cells + .cells { margin-top: 12px; }

#title { flex: 0 0 auto; font-size: 21px; letter-spacing: 1px; padding: 14px 2px 8px; color: var(--efg-text); text-transform: uppercase; }
#scroll { flex: 1; min-height: 0; overflow-y: auto; overflow-x: hidden; padding-right: 6px; }
#scroll::-webkit-scrollbar { width: 6px; }
#scroll::-webkit-scrollbar-thumb { background: #4a4c45; }
#scroll::-webkit-scrollbar-track { background: rgba(0,0,0,.4); }

.grid2 { display: flex; gap: 12px; align-items: flex-start; }
.grid2 > .colw { flex: 1 1 0; min-width: 0; }
.sec { margin-bottom: 12px; background: rgba(8,9,8,.72); }
.sec .h { display: flex; align-items: center; gap: 8px; height: 26px; padding: 0 10px; background: rgba(0,0,0,.85); color: var(--efg-text); font-size: 14px; }
.sec .h .gl { color: var(--efg-text2); font-size: 13px; width: 14px; text-align: center; }
.row { display: flex; height: 19.5px; align-items: center; padding: 0 10px 0 30px; font-size: 13.5px; }
.row:nth-child(even) { background: rgba(255,255,255,.025); }
.row .k { flex: 1; color: var(--efg-text2); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.row .val { color: var(--efg-text); padding-left: 10px; white-space: nowrap; }

.skills { display: flex; flex-wrap: wrap; gap: 8px; }
.sk { width: calc(50% - 4px); display: flex; gap: 10px; align-items: center; background: rgba(8,9,8,.75); border: 1px solid #262823; padding: 8px; box-sizing: border-box; }
.sk img { width: 46px; height: 46px; background: #000; border: 1px solid #35372f; }
.sk .n { font-size: 14px; color: var(--efg-text); }
.sk .lv { font-size: 12px; color: var(--efg-text2); margin: 2px 0 5px; }
.sk .bar { height: 5px; background: #0c0d0b; border: 1px solid #2b2d27; }
.sk .bar > div { height: 100%; background: linear-gradient(#e2e0cc, #9c9a86); }
.sk .info { flex: 1; min-width: 0; }

.ach { display: flex; flex-wrap: wrap; gap: 8px; }
.a { width: calc(33.333% - 6px); box-sizing: border-box; background: rgba(8,9,8,.75); border: 1px solid #262823; padding: 10px; min-height: 74px; }
.a .n { font-size: 15px; color: var(--efg-dim); }
.a .d { font-size: 12px; color: var(--efg-dim); margin-top: 4px; }
.a.done { border-color: #5d6a39; background: rgba(40,48,22,.55); }
.a.done .n { color: #e6e4d2; }
.a.done .d { color: var(--efg-text2); }
.a .st { float: right; font-size: 11px; letter-spacing: 1px; color: var(--efg-dim); }
.a.done .st { color: var(--efg-ok); }
</style></head>
<body><div id="app"></div>
<script>
var S = { side: "overall", data: null };

var ICONS = {
	raid: '<svg viewBox="0 0 20 20"><rect x="1" y="1" width="18" height="18" fill="#2d2f2a"/><path d="M11 3a1.6 1.6 0 1 1 0 3.2 1.6 1.6 0 0 1 0-3.2zM8 7h4l2 3 2 1-1 1.4-3-1.4-1 2 2 2v4h-1.7v-3l-2.3-2-1 3-3 2-1-1.3 2.3-1.7 1.5-5-1.5 1-1 2.5-1.5-.6 1.3-3.2z" fill="#e6e4d2"/></svg>',
	survived: '<svg viewBox="0 0 20 20"><rect x="1" y="1" width="18" height="18" fill="#6c8f2a"/><path d="M7 4h2v6l1-5h2l-1 6 2-4 1.8.8-2.8 6.2H8.5L6 10l1.6-1z" fill="#111"/></svg>',
	kia: '<svg viewBox="0 0 20 20"><rect x="1" y="1" width="18" height="18" fill="#a32a22"/><circle cx="10" cy="9" r="5" fill="#111"/><rect x="7.5" y="12" width="5" height="4" fill="#111"/><circle cx="8" cy="9" r="1.3" fill="#a32a22"/><circle cx="12" cy="9" r="1.3" fill="#a32a22"/></svg>',
	mia: '<svg viewBox="0 0 20 20"><rect x="1" y="1" width="18" height="18" fill="#a32a22"/><circle cx="10" cy="9" r="5" fill="#111"/><rect x="7.5" y="12" width="5" height="4" fill="#111"/><text x="10" y="11.5" font-size="7" text-anchor="middle" fill="#a32a22">?</text></svg>',
	awol: '<svg viewBox="0 0 20 20"><rect x="1" y="1" width="18" height="18" fill="#c06a1e"/><path d="M5 4h7v3h-1.6V5.6H6.6v8.8h3.8V13H12v3H5zM12 8l4 2-4 2v-1.3H8.5V9.3H12z" fill="#111"/></svg>',
	kills: '<svg viewBox="0 0 20 20"><circle cx="10" cy="8.5" r="6" fill="#e6e4d2"/><rect x="7" y="13" width="6" height="4" fill="#e6e4d2"/><circle cx="7.6" cy="8.3" r="1.7" fill="#111"/><circle cx="12.4" cy="8.3" r="1.7" fill="#111"/><path d="M2 2l3 3M18 2l-3 3M2 18l3-3M18 18l-3-3" stroke="#e6e4d2" stroke-width="1.6"/></svg>',
	online: '<svg viewBox="0 0 20 20"><circle cx="10" cy="10" r="7.5" fill="none" stroke="#e6e4d2" stroke-width="1.8"/><path d="M10 5v5.5l3.5 2" stroke="#e6e4d2" stroke-width="1.8" fill="none"/></svg>'
};
var GLYPH = { common: "⚓", health: "✸", looting: "❂", combat: "⌖" };

function esc(s) { return String(s == null ? "" : s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }

function cellHTML(c) {
	var ic = c.icon && ICONS[c.icon] ? ICONS[c.icon] : "";
	return '<div class="cell"><div class="ic">' + ic + '</div><div class="v">' + esc(c.value) + '</div><div class="l">' + esc(c.label) + '</div></div>';
}

function sectionHTML(sec) {
	var h = '<div class="sec"><div class="h"><span class="gl">' + (GLYPH[sec.glyph] || "") + '</span>' + esc(sec.title) + '</div>';
	for (var i = 0; i < sec.rows.length; i++) {
		h += '<div class="row"><span class="k">' + esc(sec.rows[i][0]) + '</span><span class="val">' + esc(sec.rows[i][1]) + '</span></div>';
	}
	return h + '</div>';
}

function render(data) {
	if (data) S.data = data;
	var d = S.data;
	if (!d) return;

	var h = "";

	if (d.view === "overall") {
		var side = d.sides[S.side] || d.sides.overall;
		h += '<div id="summary"><div id="sides">';
		var names = [["overall", "General"], ["pmc", "PMC"], ["scav", "Scav"]];
		for (var i = 0; i < names.length; i++) {
			h += '<div class="s' + (S.side === names[i][0] ? " on" : "") + '" data-side="' + names[i][0] + '">' + names[i][1] + '</div>';
		}
		h += '</div><div class="cells">';
		for (var a = 0; a < side.row1.length; a++) h += cellHTML(side.row1[a]);
		h += '</div><div class="cells">';
		for (var b = 0; b < side.row2.length; b++) h += cellHTML(side.row2[b]);
		h += '</div></div><div id="title">Estadísticas</div><div id="scroll"><div class="grid2">';
		for (var c = 0; c < d.columns.length; c++) {
			h += '<div class="colw">';
			for (var e = 0; e < d.columns[c].length; e++) h += sectionHTML(d.columns[c][e]);
			h += '</div>';
		}
		h += '</div></div>';
	} else if (d.view === "skills") {
		h += '<div id="title">Habilidades</div><div id="scroll"><div class="skills">';
		for (var k = 0; k < d.skills.length; k++) {
			var sk = d.skills[k];
			h += '<div class="sk"><img src="' + esc(sk.icon) + '"><div class="info"><div class="n">' + esc(sk.name) + '</div>' +
				'<div class="lv">Nivel ' + sk.level + ' / ' + sk.max + (sk.need > 0 ? ' · ' + sk.into + ' / ' + sk.need + ' XP' : ' · máximo') + '</div>' +
				'<div class="bar"><div style="width:' + Math.round(sk.frac * 100) + '%"></div></div></div></div>';
		}
		h += '</div></div>';
	} else if (d.view === "achievements") {
		h += '<div id="title">Logros · ' + d.achDone + ' / ' + d.achievements.length + '</div><div id="scroll"><div class="ach">';
		for (var m = 0; m < d.achievements.length; m++) {
			var ac = d.achievements[m];
			h += '<div class="a' + (ac.done ? " done" : "") + '"><span class="st">' + (ac.done ? "CONSEGUIDO" : "BLOQUEADO") + '</span><div class="n">' + esc(ac.name) + '</div><div class="d">' + esc(ac.desc) + '</div></div>';
		}
		h += '</div></div>';
	}

	var scroll = document.getElementById("scroll");
	var top = scroll ? scroll.scrollTop : 0;
	document.getElementById("app").innerHTML = h;
	scroll = document.getElementById("scroll");
	if (scroll) scroll.scrollTop = top;
}

document.addEventListener("mousedown", function (ev) {
	var t = ev.target;
	while (t && t !== document.body) {
		if (t.getAttribute && t.getAttribute("data-side")) {
			S.side = t.getAttribute("data-side");
			if (window.efg) efg.click();
			render();
			return;
		}
		t = t.parentNode;
	}
});
</script></body></html>
]==]
