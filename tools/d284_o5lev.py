"""D-284. Standalone optically thin 5-level O I solve: 16o.dat as-is vs Cloudy's (Barklem 2007) electron rates.

Levels, A values and every collider block are read from dataPDR/16o.dat and
interpolated linearly with clamped ends, as find_Ccoeff does. For sampled cells
of runs/d283-pn150k it solves at the coolant-table temperature and compares
with pdrCoolSp (the check that this stands in for the coupled solve), then swaps
only the 1D/1S electron rates for Barklem's partitioned Upsilons
(cloudy-c25.00/data/stout/o/o_1/o_1.coll).

    ~/miniforge3/envs/astro/bin/python tools/d284_o5lev.py     # from the repo root
"""
import sys, numpy as np
sys.path.insert(0,'tools'); import d260_roellig as R
H,C,KB=6.62607e-27,2.99792e10,1.380649e-16
L=[l.rstrip('\n') for l in open('dataPDR/16o.dat')]
def after(tag,start=0):
    for i in range(start,len(L)):
        if L[i].startswith(tag): return i+1
nl=int(L[after('!NUMBER OF ENERGY LEVELS')].split()[0]); i0=after('!LEVEL')
E=np.array([float(L[i0+k].split()[1]) for k in range(nl)]); g=np.array([float(L[i0+k].split()[2]) for k in range(nl)])
nr=int(L[after('!NUMBER OF RADIATIVE')]); i0=after('!TRANS + UP')
A=np.zeros((nl,nl))
for k in range(nr):
    s=L[i0+k].split(); A[int(s[1])-1,int(s[2])-1]=float(s[3])
coll={}; pos=0
while True:
    j=after('!COLLISIONS BETWEEN',pos)
    if j is None: break
    pid=int(L[j].split()[0]); nt=int(L[after('!NUMBER OF COLL TRANS',j)]); ntemp=int(L[after('!NUMBER OF COLL TEMPS',j)])
    kt=after('!COLL TEMPS',j); T=np.array(L[kt].split(),float); kr=after('!TRANS + UP',j)
    rows=[L[kr+k].split() for k in range(nt)]
    coll[pid]=(T,[(int(r[1])-1,int(r[2])-1,np.array(r[3:3+ntemp],float)) for r in rows]); pos=kr+nt
def interp(Tt,T,v):  # linear, clamped (find_Ccoeff)
    return np.interp(Tt,T,v)
# Cloudy Barklem electron Upsilons (lower,upper 1-based) on TEMP grid 1000..50000
TB=np.array([1000,3000,5000,8000,12000,20000,50000.])
UPS={(1,4):[8.61E-04,1.91E-02,5.44E-02,1.12E-01,1.83E-01,3.03E-01,5.54E-01],(2,4):[5.16E-04,1.14E-02,3.26E-02,6.69E-02,1.10E-01,1.82E-01,3.33E-01],
     (3,4):[1.72E-04,3.82E-03,1.09E-02,2.23E-02,3.67E-02,6.06E-02,1.11E-01],(1,5):[1.22E-02,1.48E-02,2.10E-02,3.03E-02,4.01E-02,5.44E-02,8.05E-02],
     (2,5):[7.35E-03,8.90E-03,1.26E-02,1.82E-02,2.41E-02,3.26E-02,4.83E-02],(3,5):[2.45E-03,2.97E-03,4.20E-03,6.05E-03,8.03E-03,1.09E-02,1.61E-02],
     (4,5):[5.55E-02,7.16E-02,8.83E-02,1.07E-01,1.26E-01,1.53E-01,2.28E-01]}
def cool(T,dens,elec_rates='file'):
    """dens: dict partner id -> density (4 e,5 H,6 He,7 H+, 2/3 H2 para/ortho). per O atom, erg/s"""
    q=np.zeros((nl,nl))
    for pid,(Tg,rows) in coll.items():
        n=dens.get(pid,0.)
        if n<=0: continue
        for u,l,v in rows:
            if pid==4 and elec_rates=='cloudy' and u>=3: continue
            q[u,l]+=n*interp(T,Tg,v)
    if elec_rates=='cloudy':
        for (lo,up),ups in UPS.items():
            q[up-1,lo-1]+=dens[4]*8.629e-6*np.interp(T,TB,ups)/(g[up-1]*np.sqrt(T))
    dE=(E[:,None]-E[None,:])*H*C
    for u in range(nl):
        for l in range(u):
            q[l,u]=q[u,l]*g[u]/g[l]*np.exp(-dE[u,l]/(KB*T))
    M=(q+A.T*0).copy(); R_=np.zeros((nl,nl))
    for i in range(nl):
        for j in range(nl):
            if i!=j: R_[j,i]=q[i,j]+A[i,j]   # rate i->j
    Mat=R_-np.diag(R_.sum(0)); Mat[0,:]=1.; b=np.zeros(nl); b[0]=1.
    p=np.linalg.solve(Mat,b)
    return sum(p[u]*A[u,l]*dE[u,l] for u in range(nl) for l in range(u))
run='runs/d283-pn150k'; n=41**3
d=R.read_run(run)
t=open(run+'/output/grid0.out').read().split(); off=7+123
idx=np.where(np.array(t[off:off+3*n:3],float)>0)[0]
cs=np.loadtxt(run+'/output/pdrCoolSp.out')[:n][idx]
raw=np.array(open(run+'/output/pdrGrid.out').read().split(),float)[:n*45].reshape(n,45)[idx]
nh=np.loadtxt(run+'/output/grid1.out')[idx,2]; ab=raw[:,12:45]; S=R.SPEC
Te=d['Tgas']; Tg=np.clip(np.where(raw[:,6]>0,raw[:,6],Te),1.,2e4)
tab=20000.**(np.arange(16)/15.)
Tn=tab[np.argmin(abs(np.log(tab[None,:]/Tg[:,None])),axis=1)]
r=d['r']; rng=np.random.default_rng(1)
print(' r[pc]    Te     Tn   | pdrCoolSp/nO  file-solve  cloudy-rates-solve | file/cloudy  | same, at Te')
sel=[]
for lo,hi in [(0.08,0.10),(0.10,0.12),(0.12,0.13),(0.13,0.14),(0.14,0.15),(0.16,0.2),(0.25,0.4)]:
    c_=np.where((r>=lo)&(r<hi))[0]; sel+=list(rng.choice(c_,min(3,len(c_)),replace=False))
for c in sel:
    nO=ab[c,S.index('O')]*nh[c]
    dens={4:ab[c,S.index('e-')]*nh[c],5:ab[c,S.index('H')]*nh[c],6:ab[c,S.index('He')]*nh[c],7:ab[c,S.index('H+')]*nh[c]}
    h2=ab[c,S.index('H2')]*nh[c]; T=Tn[c]
    fp=1/(1+9*np.exp(-170.5/T)); dens[2]=h2*fp; dens[3]=h2*(1-fp)
    a=cool(T,dens,'file'); b=cool(T,dens,'cloudy')
    a2=cool(min(Te[c],2e4),dens,'file'); b2=cool(min(Te[c],2e4),dens,'cloudy')
    print('%.3f %7.0f %7.0f | %.3e  %.3e  %.3e | %5.2f | %.3e %.3e %5.2f'%(r[c],Te[c],T,cs[c,3]/nO,a,b,a/b,a2,b2,a2/b2))
