"""Draw docs/physics/pdr/chain.svg: the chain from the radiation field to the
molecular content inside one Monte Carlo iteration (3D build).
Run: python docs/scripts/make_chain_figure.py  (numpy and matplotlib only)."""
import os
import textwrap
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch

matplotlib.rcParams['svg.hashsalt'] = 'mocassin-pdr-docs'
matplotlib.rcParams['svg.fonttype'] = 'none'
matplotlib.rcParams['font.size'] = 9.5

STEPS = [
    ('1. MC transfer', 'energyPacketDriver',
     r'$J^{\rm ste}$ and $J^{\rm dif}$ in every cell and frequency bin; dust temperatures; packets '
     'flagged as never scattered (direct) or scattered/re-emitted (diffuse)'),
    ('2. Dust and geometry', 'dustPerCell, computeAVdust',
     r'$R_{\rm FUV}$, $A_V/N_{\rm H}$, grain area per H; exact rays to the sources: $A_V$ and the '
     r'H$_2$, C, CO columns of iteration $n-1$; snapshot of the scattering emissivity '
     r'for the diffuse walk; $\chi$, $\chi_0$'),
    ('3. H$_2$ level model', 'h2LevelModel, one sweep',
     'pumping rate per line from the direct and diffuse fields with Voigt '
     'self-shielding, line overlap and trapping; 302-level statistical '
     r'equilibrium at $T_e$ of iteration $n-1$ $\Rightarrow$ Solomon rate, H$_2$ heating'),
    ('4. MOCASSIN cell update', 'updateCell',
     r"ionisation, dust and $T_e$ of every cell, with the chemistry's channels "
     r'of iteration $n-1$; stores the photoionisation and recombination rates of '
     r'H, He, C, O, Mg and the H$_2$ photoionisation rate'),
    ('5. Chemistry', 'pdrStep',
     r'rays = direct beam + scattering sites, all at $A_V = 0$; photorates; CO with '
     r'van Dishoeck & Black shielding; H$_2$ photodissociation = Solomon rate; '
     'MOCASSIN\'s ionisation imposed; CVODE to steady state; CO cooling; heating'),
    ('6. Feedback', 'pdrToMocassin, rescaleIonToAvail',
     r'element fractions in molecules $\rightarrow$ ion stages; $n$(H$_2$) $\rightarrow$ gas opacity and '
     r'gas-grain collider; coolants and heating $\rightarrow$ next $T_e$; new abundances $\rightarrow$ '
     r'next shielding columns; second ionisation solve'),
]

W, BOX_W, X0 = 7.0, 6.4, 0.3
fig = plt.figure(figsize=(W, 9.6))
ax = fig.add_axes([0, 0, 1, 1]); ax.set_xlim(0, W); ax.set_ylim(0, 9.6); ax.axis('off')
y = 9.45
for i, (title, code, text) in enumerate(STEPS):
    lines = textwrap.wrap(text, 100)
    h = 0.42 + 0.19 * len(lines)
    y0 = y - h
    ax.add_patch(FancyBboxPatch((X0, y0), BOX_W, h, boxstyle='round,pad=0.02,rounding_size=0.08',
                                fc='#eef3f8', ec='#3b6ea5', lw=1.0))
    ax.text(X0 + 0.12, y - 0.2, title, weight='bold', va='center')
    ax.text(X0 + BOX_W - 0.12, y - 0.2, code, family='monospace', size=8.5, va='center', ha='right', color='#3b6ea5')
    for k, ln in enumerate(lines):
        ax.text(X0 + 0.12, y - 0.43 - 0.19 * k, ln, va='center', size=8.8)
    if i < len(STEPS) - 1:
        ax.annotate('', xy=(W / 2, y0 - 0.32), xytext=(W / 2, y0 - 0.04),
                    arrowprops=dict(arrowstyle='-|>', color='#555555', lw=1.2))
    y = y0 - 0.36
ax.set_ylim(y + 0.2, 9.6)
fig.set_size_inches(W, 9.6 - y - 0.2)
out = os.path.join(os.path.dirname(__file__), '..', 'physics', 'pdr', 'chain.svg')
fig.savefig(out, metadata={'Date': None}, bbox_inches='tight')
print('wrote', os.path.normpath(out), 'bottom y =', round(y, 2))
