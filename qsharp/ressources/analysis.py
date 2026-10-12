# ─────────────────────────────────────────────────────────────────────────────
# analysis.py  —  Post-processing classique et analyse de Shor (section Python)
# ─────────────────────────────────────────────────────────────────────────────
#
# Analogie exacte avec le notebook Python de TP2 (Grover analysis).
# On importe les fonctions Q# via qsharp et on trace :
#   1. Distribution des mesures QPE
#   2. Taux de succès vs nombre d'ancillas
#   3. Visualisation des fractions continues
#
# Lancer avec :  uv run python analysis.py
#                ou dans un Jupyter notebook.
# ─────────────────────────────────────────────────────────────────────────────

import numpy as np
import matplotlib.pyplot as plt
from math import gcd
from fractions import Fraction

# ─── Si vous avez le package qsharp installé ─────────────────────────────────
# import qsharp
# qsharp.init(project_root='.')
# from qsharp.code.Shor import ShorQPE, ResultArrayAsInt

# Pour ce fichier standalone, on simule QPE classiquement à des fins d'illustration.
# En TP réel, remplacez simulate_qpe() par l'appel Q# réel.

def simulate_qpe(a: int, N: int, nb_ancillas: int) -> int:
    """
    Simule (classiquement) ce que QPE retournerait.
    En vrai TP : results = ShorQPE(a, N, nb_ancillas)
                 return sum(b << k for k, b in enumerate(results) if b)
    """
    r = find_period_classical(a, N)
    if r == 0:
        return 0
    # QPE retourne m ≈ s * 2^n / r pour s aléatoire dans [0, r-1]
    two_pow_n = 1 << nb_ancillas
    s = np.random.randint(0, r)
    # Bruit gaussien autour de la valeur exacte (simule la précision finie)
    exact = s * two_pow_n / r
    m = int(round(exact)) % two_pow_n
    return m

def find_period_classical(a: int, N: int) -> int:
    """Trouve la période de a^x mod N par force brute (classique, pour référence)."""
    x = 1
    for r in range(1, N + 1):
        x = (x * a) % N
        if x == 1:
            return r
    return 0

# ─────────────────────────────────────────────────────────────────────────────
# 1. Fractions continues
# ─────────────────────────────────────────────────────────────────────────────

def continued_fractions(numerator: int, denominator: int, max_denom: int) -> int:
    """
    Retourne le meilleur dénominateur r approchant numerator/denominator
    avec r ≤ max_denom.
    Analogue exact de ContinuedFractions() dans PostProcessing.qs.
    """
    if numerator == 0:
        return 1

    # Convergentes de la fraction continue de num/den
    p_prev, p_curr = 1, numerator // denominator
    q_prev, q_curr = 0, 1
    num = numerator % denominator
    den = denominator
    best = 1

    while num != 0:
        a = den // num
        num_new = den % num
        den_new = num

        p_new = a * p_curr + p_prev
        q_new = a * q_curr + q_prev

        if q_new > max_denom:
            return best

        best = q_new
        p_prev, p_curr = p_curr, p_new
        q_prev, q_curr = q_curr, q_new
        num, den = num_new, den_new

    return best

def extract_period(m: int, nb_ancillas: int, a: int, N: int) -> int:
    """Post-processing complet : mesure → période."""
    if m == 0:
        return 0
    two_pow_n = 1 << nb_ancillas
    r = continued_fractions(m, two_pow_n, N)
    if pow(a, r, N) == 1:
        return r
    # Essai avec 2r
    if r * 2 < N and pow(a, 2 * r, N) == 1:
        return 2 * r
    return 0

def factor_from_period(r: int, a: int, N: int):
    """Calcule les facteurs depuis la période. Retourne (p, q) ou (1, N)."""
    if r == 0 or r % 2 != 0:
        return (1, N)
    half_pow = pow(a, r // 2, N)
    if half_pow == N - 1:
        return (1, N)
    f1 = gcd(half_pow - 1, N)
    f2 = gcd(half_pow + 1, N)
    if 1 < f1 < N:
        return (f1, N // f1)
    if 1 < f2 < N:
        return (f2, N // f2)
    return (1, N)

# ─────────────────────────────────────────────────────────────────────────────
# 2. Distribution des mesures QPE  (analogue du plot Grover TP2)
# ─────────────────────────────────────────────────────────────────────────────

def plot_qpe_distribution(a=7, N=15, nb_ancillas=8, n_shots=500):
    two_pow_n = 1 << nb_ancillas
    r = find_period_classical(a, N)
    measurements = [simulate_qpe(a, N, nb_ancillas) for _ in range(n_shots)]

    # Valeurs théoriques : m = s * 2^n / r pour s = 0, 1, …, r-1
    expected = [round(s * two_pow_n / r) % two_pow_n for s in range(r)]

    fig, ax = plt.subplots(figsize=(10, 4))
    counts = np.bincount(measurements, minlength=two_pow_n)
    ax.bar(range(two_pow_n), counts / n_shots, color='steelblue', alpha=0.7, label='Mesures QPE')
    for m_exp in expected:
        ax.axvline(m_exp, color='crimson', linestyle='--', linewidth=1.5,
                   label=f'm={m_exp} (s/r théorique)' if m_exp == expected[0] else None)

    ax.set_xlabel('Valeur mesurée m')
    ax.set_ylabel('Fréquence empirique')
    ax.set_title(f'Distribution QPE : a={a}, N={N}, r={r}, {nb_ancillas} ancillas')
    ax.legend()
    plt.tight_layout()
    plt.savefig('qpe_distribution.png', dpi=150)
    plt.show()
    print(f"Valeurs attendues : {expected}  (r={r})")

# ─────────────────────────────────────────────────────────────────────────────
# 3. Taux de succès vs nombre d'ancillas  (analogue de accuracy vs iterations)
# ─────────────────────────────────────────────────────────────────────────────

def plot_success_vs_ancillas(a=7, N=15, n_shots=200):
    ancilla_range = range(3, 12)
    success_rates = []

    for nb_anc in ancilla_range:
        successes = 0
        for _ in range(n_shots):
            m = simulate_qpe(a, N, nb_anc)
            r = extract_period(m, nb_anc, a, N)
            p, q = factor_from_period(r, a, N)
            if p != 1 and p != N:
                successes += 1
        success_rates.append(successes / n_shots)
        print(f"  {nb_anc} ancillas → {success_rates[-1]:.0%} succès")

    # Borne théorique : 4/π² ≈ 40% par tour, mais plusieurs tours multiplient ça
    bound = 1 - (1 - 4 / np.pi**2) ** np.array(list(ancilla_range))

    fig, ax = plt.subplots(figsize=(8, 4))
    ax.plot(list(ancilla_range), success_rates, 'o-', color='steelblue', label='Succès empirique')
    ax.axhline(4 / np.pi**2, color='gray', linestyle=':', label='Borne QPE (4/π² ≈ 40%)')
    ax.set_xlabel('Nombre d'ancillas')
    ax.set_ylabel('Taux de succès (facteur non-trivial trouvé)')
    ax.set_title(f'Shor : a={a}, N={N}  —  succès vs précision QPE')
    ax.set_ylim(0, 1.05)
    ax.legend()
    plt.tight_layout()
    plt.savefig('shor_success_vs_ancillas.png', dpi=150)
    plt.show()

# ─────────────────────────────────────────────────────────────────────────────
# 4. Visualisation des fractions continues (pédagogique)
# ─────────────────────────────────────────────────────────────────────────────

def demo_continued_fractions(a=7, N=15, nb_ancillas=8):
    """Montre comment ContinuedFractions extrait r depuis chaque mesure possible."""
    two_pow_n = 1 << nb_ancillas
    r_true = find_period_classical(a, N)

    print(f"\nFractions continues : a={a}, N={N}, r={r_true}, 2^n={two_pow_n}")
    print(f"{'m':>6}  {'m/2^n':>10}  {'r candidat':>12}  {'a^r mod N':>12}  {'succès':>8}")
    print("-" * 56)
    for m in range(two_pow_n):
        r_cand = continued_fractions(m, two_pow_n, N)
        check = pow(a, r_cand, N)
        ok = "✓" if check == 1 and r_cand == r_true else ("~" if check == 1 else "✗")
        if m % (two_pow_n // 16) == 0 or check == 1:  # n'affiche que les pertinents
            frac = Fraction(m, two_pow_n)
            print(f"{m:>6}  {str(frac):>10}  {r_cand:>12}  {check:>12}  {ok:>8}")

# ─────────────────────────────────────────────────────────────────────────────
# main
# ─────────────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    print("═" * 60)
    print("  Analyse de l'algorithme de Shor")
    print("═" * 60)

    # Exemple : N=15, a=7 (cas classique de démonstration)
    a, N = 7, 15
    r = find_period_classical(a, N)
    print(f"\nN={N}, a={a}  →  période classique r={r}")
    p, q = factor_from_period(r, a, N)
    print(f"Facteurs : {p} × {q} = {p*q}")

    print("\n── Démo fractions continues ──")
    demo_continued_fractions(a, N, nb_ancillas=8)

    print("\n── Distribution des mesures QPE ──")
    plot_qpe_distribution(a, N, nb_ancillas=8, n_shots=500)

    print("\n── Taux de succès vs ancillas ──")
    plot_success_vs_ancillas(a, N, n_shots=200)
