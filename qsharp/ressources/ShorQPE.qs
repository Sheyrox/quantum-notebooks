// ─────────────────────────────────────────────────────────────────────────────
// ShorQPE.qs  —  QPE branché sur l'oracle modulaire
// ─────────────────────────────────────────────────────────────────────────────
//
// C'est la section 2 prédite : QPE de TP3 + oracle de ModularOracle.qs.
// La structure est identique à QPEPhi de TP3 — seule la porte U change.
//
// Rappel du circuit QPE (convention little-endian, cf. TP3 section 2.2) :
//
//   ancillas[0] ──H──●─────────────── IQFT ── M
//   ancillas[1] ──H────●───────────── IQFT ── M
//   …
//   ancillas[n-1] ─H──────────●────── IQFT ── M
//                             │
//   eigenReg ──|1⟩────U^1──U^2──…──U^{2^{n-1}}
//
// Chaque ancilla[k] contrôle U^(2^k).
// Après IQFT, on lit ancillas comme un entier little-endian m.
// La phase estimée est φ̃ = m / 2^n ≈ s/r (fraction de la période).
//
// ─────────────────────────────────────────────────────────────────────────────

namespace Shor {

    import Std.Diagnostics.Fact;

    // =========================================================================
    // QPE pour Shor
    // =========================================================================
    //
    // Paramètres :
    //   a          — base (doit vérifier GCD(a, N) == 1)
    //   N          — entier à factoriser
    //   nbAncillas — précision en bits (4 à 8 pour de petits N)
    //
    // Retourne : tableau de Result[], little-endian.
    //   Convertir en entier m = Σ bk·2^k, puis φ̃ = m/2^nbAncillas.
    //
    // Test : a=7, N=15, nbAncillas=8.
    //   La période de 7^x mod 15 est r=4.
    //   QPE doit retourner des mesures proches de 0, 64, 128, 192 (sur 256).
    //   Soit en fraction : 0/4, 1/4, 2/4, 3/4.  ✓
    // ─────────────────────────────────────────────────────────────────────────
    operation ShorQPE(a : Int, N : Int, nbAncillas : Int) : Result[] {
        Fact(nbAncillas >= 1, "Il faut au moins 1 ancilla");
        Fact(a > 1 and a < N, "a doit être dans ]1, N[");
        Fact(GCD(a, N) == 1, "a et N doivent être premiers entre eux");

        // Taille du registre eigen : suffisant pour encoder {0, …, N-1}
        let nEigen = BitLength(N - 1);
        Fact(nEigen >= 1, "N doit être >= 2");

        use ancillas = Qubit[nbAncillas];
        use eigenReg = Qubit[nEigen];

        // ── Étape 1 : préparer l'eigenvecteur |1⟩ dans eigenReg ──────────────
        // L'eigenvecteur de U_a avec eigenvalue e^{2πi·s/r} est en général
        // une superposition, mais |1⟩ est une superposition uniforme de tous
        // les eigenvecteurs, ce qui suffit pour QPE (cf. TP3 appendice A).
        X(eigenReg[0]);    // |0…0⟩ → |0…01⟩ = |1⟩ en little-endian

        // ── Étape 2 : superposition sur les ancillas ─────────────────────────
        ApplyToEach(H, ancillas);

        // ── Étape 3 : portes contrôlées U_a^(2^k) ────────────────────────────
        // ancillas[k] contrôle U_a^(2^k)  (convention little-endian TP3)
        for k in 0..nbAncillas - 1 {
            ControlledUPow(a, N, k, ancillas[k], eigenReg);
        }

        // ── Étape 4 : IQFT sur les ancillas ──────────────────────────────────
        Adjoint QFT(ancillas);

        // ── Étape 5 : mesure et nettoyage ─────────────────────────────────────
        // eigenReg peut ne plus être dans |1⟩ exactement (intrication résiduelle
        // si r ne divise pas 2^nbAncillas exactement) → on reset proprement.
        let results = MResetEachZ(ancillas);
        ResetAll(eigenReg);

        return results;
    }

    // =========================================================================
    // Helpers pour lire la mesure
    // =========================================================================

    // Convertit un Result[] little-endian en Int.
    // results[0] = bit de poids 2^0, results[k] = bit de poids 2^k.
    function ResultArrayAsInt(results : Result[]) : Int {
        mutable value = 0;
        for k in 0..Length(results) - 1 {
            if results[k] == One {
                set value += 1 <<< k;
            }
        }
        return value;
    }

    // =========================================================================
    // Nombre de bits nécessaires pour représenter n (= floor(log2(n)) + 1)
    // =========================================================================
    function BitLength(n : Int) : Int {
        mutable k = 0;
        mutable v = n;
        while v > 0 {
            set k += 1;
            set v = v >>> 1;
        }
        return k;
    }

    // =========================================================================
    // Test rapide (Main)
    // =========================================================================
    @EntryPoint()
    operation Main() : Unit {
        import Std.Diagnostics.DumpMachine;

        // a=7, N=15 : période r=4, on s'attend à des mesures ∈ {0, 64, 128, 192}
        // sur 8 ancillas (2^8 = 256).
        let a = 7;
        let N = 15;
        let nbAncillas = 8;

        Message($"Shor QPE : a={a}, N={N}, nbAncillas={nbAncillas}");
        Message($"Période attendue : r=4  →  mesures attendues : 0, 64, 128, 192");
        Message("");

        // On lance plusieurs fois pour observer la distribution
        for _ in 1..8 {
            let results = ShorQPE(a, N, nbAncillas);
            let m = ResultArrayAsInt(results);
            Message($"  mesure m = {m}  →  φ̃ = {m}/{1 <<< nbAncillas}");
        }
    }

}
