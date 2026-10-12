// ─────────────────────────────────────────────────────────────────────────────
// PostProcessing.qs  —  Post-processing classique de Shor
// ─────────────────────────────────────────────────────────────────────────────
//
// Tout ce fichier est classique (pas de qubits). On l'écrit en Q# pour rester
// dans le même projet, mais ce sont des fonctions pures que vous pouvez aussi
// écrire en Python (et c'est ce que la section analyse Python demandera).
//
// Pipeline complet :
//
//   mesure m  ──→  fraction  m/2^n
//              ──→  fractions continues  →  candidat r  (dénominateur)
//              ──→  vérification  a^r ≡ 1 mod N ?
//              ──→  calcul  GCD(a^{r/2} ± 1, N)
//              ──→  facteurs p, q
//
// ─────────────────────────────────────────────────────────────────────────────

namespace Shor {

    import Std.Diagnostics.Fact;
    import Std.Math.AbsI;

    // =========================================================================
    // 1. Algorithme des fractions continues
    // =========================================================================
    //
    // Entrée :  numérateur p, dénominateur q  (fraction p/q = m/2^n)
    // Sortie :  dénominateur r du meilleur rationnel approchant p/q
    //           avec dénominateur ≤ N.
    //
    // L'algorithme d'Euclide généralisé produit la suite de convergentes
    //   p_k/q_k  qui s'approchent de p/q.  On s'arrête dès que q_k > N
    // ou que la convergente est suffisamment proche.
    //
    // Exemple :  m=64, 2^n=256  →  p/q = 64/256 = 1/4
    //   Fractions continues : [0; 4]  →  convergentes : 0/1, 1/4
    //   Dénominateur retourné : 4  (= période de 7^x mod 15)  ✓
    //
    // Exemple pathologique : m=65, 2^n=256  →  p/q = 65/256
    //   Pas une fraction simple — l'algorithme retourne le meilleur candidat
    //   dont le dénominateur ≤ N.
    // ─────────────────────────────────────────────────────────────────────────
    function ContinuedFractions(numerator : Int, denominator : Int, maxDenom : Int) : Int {
        Fact(denominator > 0, "dénominateur doit être > 0");
        Fact(maxDenom > 0,    "maxDenom doit être > 0");

        // Algorithme de fraction continue :
        // On cherche les convergentes de la fraction numerator/denominator.
        // h_{-1}=1, h_0=a_0 ;  k_{-1}=0, k_0=1
        // h_i = a_i · h_{i-1} + h_{i-2}
        // k_i = a_i · k_{i-1} + k_{i-2}

        mutable p_prev = 1;          // h_{-1}
        mutable p_curr = numerator / denominator;  // h_0 = a_0
        mutable q_prev = 0;          // k_{-1}
        mutable q_curr = 1;          // k_0

        mutable num = numerator % denominator;
        mutable den = denominator;
        mutable best = 1;            // meilleur dénominateur trouvé

        // On itère tant que le reste est non nul et le dénominateur ≤ maxDenom
        while num != 0 {
            let a = den / num;       // prochain quotient partiel
            let num_new = den % num;
            let den_new = num;

            let p_new = a * p_curr + p_prev;
            let q_new = a * q_curr + q_prev;

            if q_new > maxDenom {
                // On dépasse la limite : on s'arrête, best = q_curr
                return best;
            }

            set best   = q_new;
            set p_prev = p_curr;
            set p_curr = p_new;
            set q_prev = q_curr;
            set q_curr = q_new;
            set num    = num_new;
            set den    = den_new;
        }

        return best;
    }

    // =========================================================================
    // 2. Extraction de la période depuis une mesure QPE
    // =========================================================================
    //
    // Entrée :  m         (entier mesuré par QPE, little-endian → Int)
    //           nbAncillas (nombre d'ancillas → on divise par 2^nbAncillas)
    //           a, N      (pour vérifier que a^r ≡ 1 mod N)
    //
    // Sortie :  r (période) si on en trouve une valide, 0 sinon.
    //
    // La mesure m approche s·2^n / r pour un entier s.
    // ContinuedFractions extrait le dénominateur r de la fraction m/2^n.
    // On vérifie ensuite que a^r ≡ 1 mod N.
    // ─────────────────────────────────────────────────────────────────────────
    function ExtractPeriod(m : Int, nbAncillas : Int, a : Int, N : Int) : Int {
        let twoPowN = 1 <<< nbAncillas;

        if m == 0 {
            return 0;   // mesure nulle → pas d'info sur la période
        }

        // Candidat r = dénominateur de la meilleure approximation de m/2^n
        let rCandidate = ContinuedFractions(m, twoPowN, N);

        // Vérification : a^r ≡ 1 mod N ?
        if ModPow(a, rCandidate, N) == 1 {
            return rCandidate;
        }

        // Parfois la période est un multiple du candidat — on essaie 2r
        // (cas fréquent quand s est pair et r est pair)
        let rDouble = 2 * rCandidate;
        if rDouble < N and ModPow(a, rDouble, N) == 1 {
            return rDouble;
        }

        return 0;   // période non trouvée pour cette mesure
    }

    // =========================================================================
    // 3. Calcul des facteurs depuis la période
    // =========================================================================
    //
    // Données le bon r (période de a^x mod N) :
    //   - r doit être pair
    //   - a^{r/2} mod N ≠ N-1  (sinon a^{r/2} ≡ -1 mod N → cas dégénéré)
    //
    // Facteurs candidats : GCD(a^{r/2} - 1, N) et GCD(a^{r/2} + 1, N).
    // Au moins l'un d'eux doit être un facteur non-trivial de N.
    //
    // Retourne (p, q) avec p·q = N, ou (1, N) si r est dégénéré.
    // ─────────────────────────────────────────────────────────────────────────
    function FactorFromPeriod(r : Int, a : Int, N : Int) : (Int, Int) {
        // Cas dégénérés
        if r == 0        { return (1, N); }
        if r % 2 != 0    { return (1, N); }    // r impair → recommencer

        let halfPow = ModPow(a, r / 2, N);
        if halfPow == N - 1 { return (1, N); } // a^{r/2} ≡ -1 mod N → dégénéré

        let factor1 = GCD(halfPow - 1, N);
        let factor2 = GCD(halfPow + 1, N);

        // On retourne le premier facteur non-trivial trouvé
        if factor1 != 1 and factor1 != N {
            return (factor1, N / factor1);
        }
        if factor2 != 1 and factor2 != N {
            return (factor2, N / factor2);
        }

        return (1, N);  // cas rare mais possible : on rééssaie avec un autre a
    }

    // =========================================================================
    // 4. Algorithme de Shor complet (boucle quantique + classique)
    // =========================================================================
    //
    // On répète QPE jusqu'à obtenir un facteur non-trivial.
    // En pratique, la probabilité de succès par tour est ≥ 4/π² ≈ 40%,
    // donc on converge en quelques tours en moyenne.
    //
    // Paramètres recommandés pour tester :
    //   N=15, a=7  → r=4 → facteurs 3 et 5
    //   N=21, a=4  → r=3 (impair, dégénéré) → recommencer avec a=8 → r=2 → facteurs 3 et 7
    //   N=35, a=6  → r=2 → facteurs 5 et 7
    // ─────────────────────────────────────────────────────────────────────────
    operation Shor(N : Int, a : Int, nbAncillas : Int) : (Int, Int) {
        Fact(N > 2,          "N doit être > 2");
        Fact(a > 1 and a < N,"a doit être dans ]1, N[");
        Fact(GCD(a, N) == 1, "GCD(a, N) doit être 1 (sinon facteur trivial)");

        // Vérification triviale préliminaire : GCD(a, N) pourrait déjà donner un facteur
        let trivial = GCD(a, N);
        if trivial != 1 { return (trivial, N / trivial); }

        mutable attempts = 0;
        mutable factor = (1, N);

        repeat {
            set attempts += 1;
            Message($"  Tour {attempts} : QPE en cours…");

            // ── Phase quantique ────────────────────────────────────────────
            let results = ShorQPE(a, N, nbAncillas);
            let m = ResultArrayAsInt(results);
            Message($"    mesure m = {m}");

            // ── Post-processing classique ──────────────────────────────────
            let r = ExtractPeriod(m, nbAncillas, a, N);
            Message($"    période estimée r = {r}");

            if r != 0 {
                let (p, q) = FactorFromPeriod(r, a, N);
                Message($"    facteurs candidats : {p} × {q}");
                if p != 1 and p != N {
                    set factor = (p, q);
                }
            }

        } until (factor != (1, N) or attempts >= 10);

        return factor;
    }

}
