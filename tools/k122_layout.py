"""Reduce the working tree to the source layout of the build that reproduces
the D-124 fault: the D-122 probe as extended in K122, without the D-124 in-loop
probes or the D-126 getDustT recomputation. D-126 established that ANY change
to memory layout suppresses the fault, so experiments that need it to fire must
start from exactly this source and vary only compiler flags."""
import sys
p='source/update_mod.f90'; s=open(p).read(); n=0
for tag in ("! D-124: a hand evaluation", "! D-124: same check on the electron half.",
            "! D-126: rebuild the electron half"):
    if tag not in s: continue
    i=s.rfind("\n",0,s.index(tag))+1
    j=s.index("end if\n",i)+len("end if\n")
    if tag.startswith("! D-126"):
        j=s.index('minval(gasDustColl_d)\n',i)+len('minval(gasDustColl_d)\n')
    s=s[:i]+s[j:]; n+=1
s=s.replace("""            ! D-126: recomputation of the collisional term at the probe point
            real    :: kTchk, psichk, etachk, xichk, vmchk, collchk
""","")
open(p,'w').write(s)
p='source/common_mod.f90'; s=open(p).read()
s=s.replace("""    ! D-124: which term of setDustGasCollHeatCool blows the gas-grain
    ! collisional heating up by ~1e19 over a hand evaluation.
    integer             :: nCollBlow = 0
    integer, parameter  :: maxCollBlow = 12
""","")
open(p,'w').write(s)
print(f"reduced to K122 layout ({n} probe blocks removed)")
