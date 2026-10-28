import json,re,collections,sys
d=json.load(open('content/data_static/efg/eft_items.json'))
calmap={'9x19mm Parabellum':'9x19','7.62x51mm NATO':'762x51','12/70':'12g','5.56x45mm NATO':'556x45','.300 Blackout':'300blk','7.62x39mm':'762x39','.366 TKM':'366tkm','5.45x39mm':'545x39','7.62x54mmR':'762x54r','.45 ACP':'45acp','6.8x51mm':'68x51','9x39mm':'9x39','9x18mm Makarov':'9x18','.338 Lapua Magnum':'338lm','12.7x55mm':'127x55','5.7x28mm FN':'57x28','4.6x30mm HK':'46x30','7.62x25mm Tokarev':'762x25','9x21mm Gyurza':'9x21','20/70':'20g'}
weps="9a91 aa12 adar15 ai_axmc ak101 ak102 ak103 ak104 ak105 ak12 ak50 ak74 ak74m akm akms aks74 aks74u apb aps ash12 asval asval_mod4 aug auga1 avt cr200ds cr50ds deagle_l5 deagle_l6 deagle_xix dvl10 fn57 fn_p90 g28 g36 glock17 glock18c glock19x hk416 kedr ks23 m16a1 m16a2 m18 m18y m1911 m1a m32a1 m3super90 m45 m4a1 m590 m60e4 m60e6 m700 m7290 m870 m9a3 mcx mdr mdr556 mk18_mjolnir mk47_mutant mosin_infantry mosin_sniper mp18 mp443 mp5 mp5k mp7a1 mp7a2 mp9 mp9n mpx mr133 mr153 mr155 mr43 mts255 mxlr nl545_di nl545_gp p226r pb pd20 pkm pkp pl15 pm pp1901 ppsh41 radian rd704 rfb rpd rpk16 rsass rsh12 sa58 sag_ak545 sag_ak545short saiga12fa saiga12k saiga9 sako_trg scarh scarl scarx17 sks sp81 spear sr1mp sr25 sr2m sr3 stm9 sv98 svds svt t5000 tkpd toz106 tt33 tx15 ump usp uzi uzi_pro v40 vector45 vector9 velociraptor vpo101 vpo136 vpo209 vpo215 vsk94 vss zarya".split()
# grupos de familias (cargador -> armas)
groups={
 'ak':(['AK','AK-101','AK-103','AK-12','AK-74','AK-74 "Saiga 545"','AK-74 Delta-Tek Saiga 545','AKMS','AK-308','Saiga-308/AK-308','SLR-106/AK','RPK-16'],['ak101','ak102','ak103','ak104','ak105','ak12','ak74','ak74m','akm','akms','aks74','aks74u','rd704','mk47_mutant','vpo136','vpo209','sag_ak545','sag_ak545short','nl545_di','nl545_gp','rpk16','ak50']),
 'ar15':(['AR-15'],['adar15','hk416','m16a1','m16a2','m4a1','mcx','tx15','velociraptor','mdr556','radian','m7290']),
 'ar10':(['AR-10','HK417/G28'],['sr25','rsass','g28','mdr','spear','scarx17']),
 'fal':(['SA58/FAL','SA58/FAL/SLR'],['sa58','rfb']),
 'm14':(['M14','M1A'],['m1a']),
 'vss':(['VSS/VAL'],['vss','asval','asval_mod4','sr3']),'9a91':(['9A-91'],['9a91','vsk94']),
 'glock':(['Glock'],['glock17','glock18c','glock19x']),
 'svd':(['SVD'],['svds']),
 'svt':(['SVT-40','AVT-40'],['svt','avt']),
 'mosin':(['Mosin Rifle'],['mosin_infantry','mosin_sniper']),
 'pk':(['PK'],['pkm','pkp']),
 'aug':(['Steyr AUG'],['aug','auga1']),
 'scarh':(['FN SCAR-H'],['scarh']),'scarl':(['FN SCAR-L'],['scarl']),
 'pp19':(['PP-19-01','PP-19-01 Vityaz','Saiga-9'],['pp1901','saiga9']),
 'mp5':(['HK MP5'],['mp5','mp5k']),'mp7':(['HK MP7'],['mp7a1','mp7a2']),'mp9':(['MP9'],['mp9','mp9n']),'mpx':(['MPX'],['mpx']),
 'ump':(['HK UMP'],['ump']),'usp':(['HK USP','HK USP Tactical'],['usp']),'m1911':(['M1911A1'],['m1911','m45']),
 'p90':(['FN P90'],['fn_p90']),'fn57':(['FN Five-seveN'],['fn57']),'pm':(['PM'],['pm','pb']),'aps':(['APS'],['aps','apb']),'kedr':(['PP-91 Kedr'],['kedr']),
 'tt':(['TT'],['tt33']),'ppsh':(['PPSh-41'],['ppsh41']),'sr1mp':(['SR-1MP'],['sr1mp']),'sr2m':(['SR-2M'],['sr2m']),
 'm9a3':(['M9A3'],['m9a3']),'p226':(['P226'],['p226r']),'mp443':(['MP-443 Grach'],['mp443']),'pl15':(['PL-15'],['pl15']),
 'uzi':(['UZI'],['uzi']),'uzipro':(['UZI PRO'],['uzi_pro']),'g36':(['HK G36'],['g36']),
 'axmc':(['AI AXMC'],['ai_axmc']),'mk18':(['Mk-18'],['mk18_mjolnir']),'trg':(['Sako TRG M10'],['sako_trg']),
 'ash12':(['ASh-12'],['ash12']),'rsh12':(['RSh-12'],['rsh12']),'sv98':(['SV-98'],['sv98']),'dvl':(['DVL-10'],['dvl10']),
 'm700':(['M700'],['m700']),'t5000':(['ORSIS T-5000M'],['t5000']),'vpo101':(['VPO-101'],['vpo101']),'vpo215':(['VPO-215'],['vpo215']),
 'sks':(['SKS'],['sks']),'rpd':(['RPD'],['rpd']),'m60':(['M60'],['m60e4','m60e6']),'tkpd':(['TKPD'],['tkpd']),
 'aa12':(['AA-12'],['aa12']),'saiga12':(['SOK-12'],['saiga12fa','saiga12k']),'mxlr':(['MXLR'],['mxlr']),
}
fam2grp={}
for g,(fams,_) in groups.items():
  for f in fams: fam2grp[f]=g
mags=[];skipped=collections.Counter()
for v in d:
  if v['type']!='Magazine': continue
  fam=re.split(r' (?=[\d.]+x|\.\d|\d+ga|12ga|20ga|\d+mm|6mm)', v['name'])[0]
  cals=[calmap[c.strip()] for c in (v.get('caliber') or '').split(',') if c.strip() in calmap]
  if not cals: skipped['cal']+=1; continue
  if fam not in fam2grp: skipped[fam]+=1; continue
  try: cap=int(v.get('capacity') or 0)
  except: cap=0
  if cap<=0: skipped['cap']+=1; continue
  mags.append(dict(key=v['key'],name=v['name'],group=fam2grp[fam],cals=cals,cap=cap,w=v['w'],h=v['h'],weight=v['weight'],ergo=int(float(v.get('ergonomics') or 0)),icon=v['icon'],trader=v['trader']))
print(len(mags),skipped,file=sys.stderr)
json.dump(mags,open('tools/cargadores/mags.json','w'))
grpw={}
for g,(_,ws) in groups.items():
  for w in ws: grpw['arc9_eft_'+w]=g
json.dump(grpw,open('tools/cargadores/grpw.json','w'))
used=set(m['group'] for m in mags)
print('grupos sin cargador:',[g for g in groups if g not in used],file=sys.stderr)
