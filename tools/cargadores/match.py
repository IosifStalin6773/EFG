import json,re
models=open('tools/cargadores/models.txt').read().split()
mags=json.load(open('tools/cargadores/mags.json'))
hint={'ak':['mag_ak'],'ar15':['mag_stanag'],'ar10':['mag_ar10'],'fal':['mag_fal'],'m14':['mag_m14'],'vss':['mag_val2'],'9a91':['mag_vsk94'],'glock':['mag_glock'],'svd':['mag_svd'],'svt':['mag_svt'],'mosin':['mag_mosin'],'pk':['mag_pkm'],'aug':['mag_aug'],'scarh':['mag_scar17'],'scarl':['mag_stanag_fn_mk16'],'pp19':['mag_vityaz'],'mp5':['mag_mp5'],'mp7':['mag_mp7'],'mp9':['mag_mp9'],'mpx':['mag_mpx'],'ump':['mag_hk_ump'],'usp':['mag_hk_usp'],'m1911':['mag_1911'],'pm':['mag_pm'],'aps':['mag_aps'],'kedr':['mag_kedr'],'tt':['mag_tt'],'ppsh':['mag_ppsh'],'sr1mp':['mag_sr1mp'],'sr2m':['mag_sr2m'],'m9a3':['mag_m9a3'],'p226':['mag_p226'],'mp443':['mag_mp443'],'pl15':['mag_pl15'],'uzi':['mag_uzi_'],'uzipro':['mag_uzi_pro'],'g36':['mag_g36'],'axmc':['mag_axmc'],'mk18':['mag_mk18'],'trg':['mag_sako'],'sv98':['mag_sv98'],'dvl':['mag_dvl10'],'m700':['mag_m700'],'t5000':['mag_t5000'],'vpo101':['mag_vpo101'],'vpo215':['mag_vpo215'],'sks':['mag_sks'],'rpd':['mag_rpd'],'m60':['mag_m60'],'aa12':['mag_aa12'],'saiga12':['mag_saiga12']}
res={}
def toks(s): return set(t for t in re.split(r'[^a-z0-9]+',s.lower()) if t)
for m in mags:
  hs=hint.get(m['group'],[])
  cands=[x for x in models if any(x.startswith(h) for h in hs)]
  if m['group']=='uzi': cands=[x for x in cands if not x.startswith('mag_uzi_pro')]
  if m['group']=='ak': 
    cands=[x for x in cands if (('545' in x) == ('5.45' in m['name'])) or ('556' in x and '5.56' in m['name']) or ('762' in x and '7.62' in m['name'])] or cands
  if not cands: res[m['key']]=None; continue
  mt=toks(m['name'].replace('-',''))|toks(m['name'])
  cap=str(m['cap'])
  def score(x):
    xt=set(x.split('_'))
    nums=[t for t in xt if t.isdigit()]
    s=len(mt & xt)*2
    if cap in xt or x.endswith(cap): s+=5
    elif nums and cap not in nums: s-=2
    if 'drum' in xt and 'drum' not in mt: s-=3
    if 'tr' in xt or 'trdrop' in xt: s-=1
    return s
  res[m['key']]=max(cands,key=score)
json.dump(res,open('tools/cargadores/modelmap.json','w'))
for m in mags: print(f"{m['name'][:60]:60} -> {res[m['key']]}")
