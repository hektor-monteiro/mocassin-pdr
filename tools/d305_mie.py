"""BHmie (Bohren & Huffman), the same algorithm ph_mod.f90 ports."""
import numpy as np


def bhmie(x, refrel):
    y = x * refrel
    xstop = x + 4.0 * x ** 0.3333 + 2.0
    nstop = int(xstop)
    nmx = int(max(xstop, abs(y))) + 15
    # downward recurrence for the logarithmic derivative
    d = np.zeros(nmx + 1, dtype=complex)
    for n in range(nmx - 1, 0, -1):
        en = n + 1.0
        d[n] = (en / y) - (1.0 / (d[n + 1] + en / y))
    psi0, psi1 = np.cos(x), np.sin(x)
    chi0, chi1 = -np.sin(x), np.cos(x)
    xi1 = complex(psi1, -chi1)
    qsca, gsca, qext = 0.0, 0.0, 0.0
    an1 = bn1 = 0
    for n in range(1, nstop + 1):
        en = float(n)
        fn = (2.0 * en + 1.0) / (en * (en + 1.0))
        psi = (2.0 * en - 1.0) * psi1 / x - psi0
        chi = (2.0 * en - 1.0) * chi1 / x - chi0
        xi = complex(psi, -chi)
        an = (((d[n] / refrel + en / x) * psi - psi1) /
              ((d[n] / refrel + en / x) * xi - xi1))
        bn = (((d[n] * refrel + en / x) * psi - psi1) /
              ((d[n] * refrel + en / x) * xi - xi1))
        qsca += (2.0 * en + 1.0) * (abs(an) ** 2 + abs(bn) ** 2)
        gsca += fn * (an.real * bn.real + an.imag * bn.imag)
        if n > 1:
            enm = en - 1.0
            gsca += ((enm * (enm + 2.0) / (enm + 1.0)) *
                     (an1.real * an.real + an1.imag * an.imag +
                      bn1.real * bn.real + bn1.imag * bn.imag))
        qext += (2.0 * en + 1.0) * (an.real + bn.real)
        an1, bn1 = an, bn
        psi0, psi1 = psi1, psi
        chi0, chi1 = chi1, chi
        xi1 = complex(psi1, -chi1)
    qsca *= 2.0 / (x * x)
    qext *= 2.0 / (x * x)
    gsca *= 2.0 / (qsca * x * x) if qsca > 0 else 0.0
    return qext, qsca, gsca
