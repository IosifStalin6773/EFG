import json,re
mags=json.load(open('tools/cargadores/mags.json')); grpw=json.load(open('tools/cargadores/grpw.json')); mm_=json.load(open('tools/cargadores/modelmap.json'))
calname={'9x19':'9x19','762x51':'7.62x51','12g':'12/70','556x45':'5.56x45','300blk':'.300 BLK','762x39':'7.62x39','366tkm':'.366 TKM','545x39':'5.45x39','762x54r':'7.62x54R','45acp':'.45 ACP','68x51':'6.8x51','9x39':'9x39','9x18':'9x18','338lm':'.338 LM','127x55':'12.7x55','57x28':'5.7x28','46x30':'4.6x30','762x25':'7.62x25','9x21':'9x21','20g':'20/70'}
traders={'prapor','therapist','fence','skier','peacekeeper','mechanic','ragman','jaeger'}
def esc(s): return s.replace('\\','\\\\').replace('"','\\"')
out=[];seen=set()
for m in mags:
  uid='mag_'+re.sub(r'_(\d+)_round(_drum)?_magazine$',r'_\1',m['key'])
  uid=uid[:58]
  i=2
  while uid in seen: uid=uid[:55]+'_'+str(i); i+=1
  seen.add(uid)
  base=re.sub(r'\s*\d+-round (drum )?magazine','',m['name']).strip()
  kind='Tambor' if ('drum' in m['name'].lower() or m['cap']>=60) else 'Cargador'
  name=f"{kind} {base} ({m['cap']})"
  tr=[]
  for part in m['trader'].split(';'):
    mm=re.match(r'\s*(\w+)\s+LL(\d)',part)
    if mm and mm.group(1).lower() in traders: tr.append(f'{{"{mm.group(1).lower()}", {mm.group(2)}}}')
  price=int(round((1500+m['cap']*140)*(1.8 if m['cap']>=50 else 1)/100)*100)
  cals=', '.join(f'"{c}"' for c in m['cals'])
  out.append(f'\t{{id = "{uid}", name = "{esc(name)}", group = "{m["group"]}", calibers = {{{cals}}}, capacity = {m["cap"]}, w = {m["w"]}, h = {m["h"]}, weight = {m["weight"]}, ergo = {m["ergo"]}, price = {price}, icon = "{m["icon"]}", model = "{("models/weapons/arc9/darsu_eft/mods/"+mm_[m["key"]]+".mdl") if mm_[m["key"]] else "models/items/arc9/att_cardboard_box.mdl"}", traders = {{{", ".join(tr)}}}}},')
pistol=['glock','usp','m1911','fn57','pm','aps','tt','sr1mp','m9a3','p226','mp443','pl15']
s='''-- Generado con datos de la wiki de EFT (content/data_static/efg/eft_items.json).
-- Un cargador vale para un arma si comparte calibre y grupo (M.weaponGroups);
-- las armas sin grupo aceptan cualquier cargador de su calibre y tipo.

local M = ix.efg.mags

M.data = {
'''+'\n'.join(out)+'''
}

-- clase del arma -> grupo de cargadores
M.weaponGroups = {
'''+'\n'.join(f'\t{k} = "{v}",' for k,v in sorted(grpw.items()))+'''
}

-- grupos de pistola: solo valen para armas secundarias si el arma no tiene grupo
M.pistolGroups = {'''+', '.join(f'{g} = true' for g in pistol)+'''}
'''
open('plugins/efg_mags/sh_data.lua','w').write(s)
print(len(out))
