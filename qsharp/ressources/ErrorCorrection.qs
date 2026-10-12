// ─────────────────────────────────────────────────────────────────────────────
// ErrorCorrection.qs  —  Correction d'erreurs quantiques
// ─────────────────────────────────────────────────────────────────────────────
//
// Section 4 prédite : deux codes progressifs.
//
// Code 1 — Répétition 3 qubits (bit-flip only)
//   Simple à comprendre, corrige les erreurs X mais pas Z.
//   Encodage : |0⟩_L = |000⟩,  |1⟩_L = |111⟩
//
// Code 2 — Code de Shor 9 qubits (bit-flip + phase-flip)
//   Compose le code de répétition dans les deux bases.
//   Encodage :
//     |0⟩_L = (|000⟩ + |111⟩)^⊗3 / 2√2
//     |1⟩_L = (|000⟩ - |111⟩)^⊗3 / 2√2
//
// Le pattern within { mesure syndromes } apply { corrige } est exactement
// le même qu'en TP1 pour le phase kickback : on mesure sans détruire le
// qubit logique, puis on corrige.
//
// ─────────────────────────────────────────────────────────────────────────────

namespace Shor {

    import Std.Diagnostics.Fact;
    import Std.Diagnostics.DumpMachine;

    // =========================================================================
    // ── CODE DE RÉPÉTITION 3 QUBITS (bit-flip) ────────────────────────────────
    // =========================================================================

    // -------------------------------------------------------------------------
    // Encode3  :  |ψ⟩ ⊗ |00⟩  →  code de répétition
    //
    // Si le qubit logique est α|0⟩ + β|1⟩ dans qs[0], après encodage :
    //   α|000⟩ + β|111⟩
    //
    // On utilise CNOT(qs[0], qs[1]) et CNOT(qs[0], qs[2]).
    // qs[1] et qs[2] doivent être dans |0⟩ avant l'appel.
    // -------------------------------------------------------------------------
    operation Encode3(qs : Qubit[]) : Unit is Adj {
        Fact(Length(qs) == 3, "Encode3 attend exactement 3 qubits");
        // qs[0] = qubit logique (α|0⟩ + β|1⟩)
        // qs[1], qs[2] = ancillas d'encodage, doivent être |0⟩
        CNOT(qs[0], qs[1]);
        CNOT(qs[0], qs[2]);
        // Résultat : α|000⟩ + β|111⟩
    }

    // -------------------------------------------------------------------------
    // DetectError3  :  mesure le syndrome sans détruire le qubit logique
    //
    // Syndromes (parités de paires) :
    //   s1 = qs[0] ⊕ qs[1]  (parité de la paire 0-1)
    //   s2 = qs[1] ⊕ qs[2]  (parité de la paire 1-2)
    //
    //   (s1, s2) = (0, 0) → pas d'erreur
    //   (s1, s2) = (1, 0) → erreur sur qs[0]
    //   (s1, s2) = (1, 1) → erreur sur qs[1]
    //   (s1, s2) = (0, 1) → erreur sur qs[2]
    //
    // Les ancillas de syndrome sont allouées puis libérées ici (within/apply).
    // On retourne (s1, s2) comme paire de Bool.
    // -------------------------------------------------------------------------
    operation DetectError3(qs : Qubit[]) : (Bool, Bool) {
        Fact(Length(qs) == 3, "DetectError3 attend 3 qubits");

        use anc1 = Qubit();
        use anc2 = Qubit();

        // Mesure non-destructive via ancillas
        // anc1 accumule qs[0] ⊕ qs[1]
        CNOT(qs[0], anc1);
        CNOT(qs[1], anc1);
        // anc2 accumule qs[1] ⊕ qs[2]
        CNOT(qs[1], anc2);
        CNOT(qs[2], anc2);

        let s1 = MResetZ(anc1) == One;
        let s2 = MResetZ(anc2) == One;

        return (s1, s2);
    }

    // -------------------------------------------------------------------------
    // CorrectError3  :  applique X sur le qubit erroné selon le syndrome
    // -------------------------------------------------------------------------
    operation CorrectError3(syndrome : (Bool, Bool), qs : Qubit[]) : Unit {
        Fact(Length(qs) == 3, "CorrectError3 attend 3 qubits");
        let (s1, s2) = syndrome;
        if      s1 and not s2 { X(qs[0]); }
        elif    s1 and s2     { X(qs[1]); }
        elif not s1 and s2    { X(qs[2]); }
        // (false, false) → pas d'erreur, on ne fait rien
    }

    // -------------------------------------------------------------------------
    // Decode3  :  inverse de Encode3  (Adjoint automatique via "is Adj")
    // -------------------------------------------------------------------------
    operation Decode3(qs : Qubit[]) : Unit is Adj {
        Adjoint Encode3(qs);
    }

    // =========================================================================
    // ── CODE DE SHOR 9 QUBITS ────────────────────────────────────────────────
    // =========================================================================
    //
    // Idée : composer deux niveaux de répétition.
    //   Niveau 1 (phase-flip) :  |0⟩_L → (|+⟩|+⟩|+⟩)
    //                             |1⟩_L → (|-⟩|-⟩|-⟩)
    //   Niveau 2 (bit-flip)  :  chaque |±⟩ est encodé en répétition 3 qubits
    //                            dans la base X.
    //
    // Encodage final (9 qubits, qs[0] = qubit logique) :
    //   |0⟩_L = 1/(2√2) · (|000⟩+|111⟩) ⊗ (|000⟩+|111⟩) ⊗ (|000⟩+|111⟩)
    //   |1⟩_L = 1/(2√2) · (|000⟩-|111⟩) ⊗ (|000⟩-|111⟩) ⊗ (|000⟩-|111⟩)
    //
    // Layout du registre (qs[0] = qubit logique, 8 ancillas) :
    //   bloc 0 : qs[0], qs[1], qs[2]
    //   bloc 1 : qs[3], qs[4], qs[5]
    //   bloc 2 : qs[6], qs[7], qs[8]
    //
    // Tous les qs[1..8] doivent être dans |0⟩ avant l'encodage.
    // ─────────────────────────────────────────────────────────────────────────

    // -------------------------------------------------------------------------
    // Encode9  :  encode le qubit logique qs[0] dans 9 qubits
    // -------------------------------------------------------------------------
    operation Encode9(qs : Qubit[]) : Unit is Adj {
        Fact(Length(qs) == 9, "Encode9 attend exactement 9 qubits");

        // ── Niveau 1 : répétition de phase (dans la base X) ──────────────
        // On copie qs[0] vers qs[3] et qs[6] avec des CNOT,
        // puis on met les trois qubits de tête dans la base X avec H.
        CNOT(qs[0], qs[3]);
        CNOT(qs[0], qs[6]);
        H(qs[0]);
        H(qs[3]);
        H(qs[6]);

        // ── Niveau 2 : répétition de bit dans chaque bloc ─────────────────
        // Bloc 0 : (qs[0], qs[1], qs[2])
        CNOT(qs[0], qs[1]);
        CNOT(qs[0], qs[2]);
        // Bloc 1 : (qs[3], qs[4], qs[5])
        CNOT(qs[3], qs[4]);
        CNOT(qs[3], qs[5]);
        // Bloc 2 : (qs[6], qs[7], qs[8])
        CNOT(qs[6], qs[7]);
        CNOT(qs[6], qs[8]);
    }

    // -------------------------------------------------------------------------
    // DetectError9  :  mesure des 8 syndromes (6 bit-flip + 2 phase-flip)
    //
    // Syndromes bit-flip (un par paire dans chaque bloc) :
    //   s_b[0] = qs[0]⊕qs[1],  s_b[1] = qs[1]⊕qs[2]   (bloc 0)
    //   s_b[2] = qs[3]⊕qs[4],  s_b[3] = qs[4]⊕qs[5]   (bloc 1)
    //   s_b[4] = qs[6]⊕qs[7],  s_b[5] = qs[7]⊕qs[8]   (bloc 2)
    //
    // Syndromes phase-flip (parités dans la base X entre blocs) :
    //   s_p[0] = X-parité(bloc0) ⊕ X-parité(bloc1)
    //   s_p[1] = X-parité(bloc1) ⊕ X-parité(bloc2)
    //
    // Retourne (bitSyndromes : Bool[], phaseSyndromes : Bool[]).
    // -------------------------------------------------------------------------
    operation DetectError9(qs : Qubit[]) : (Bool[], Bool[]) {
        Fact(Length(qs) == 9, "DetectError9 attend 9 qubits");

        // ── Syndromes bit-flip ────────────────────────────────────────────
        use bAnc = Qubit[6];
        // Bloc 0
        CNOT(qs[0], bAnc[0]); CNOT(qs[1], bAnc[0]);   // s_b[0] = qs[0]⊕qs[1]
        CNOT(qs[1], bAnc[1]); CNOT(qs[2], bAnc[1]);   // s_b[1] = qs[1]⊕qs[2]
        // Bloc 1
        CNOT(qs[3], bAnc[2]); CNOT(qs[4], bAnc[2]);
        CNOT(qs[4], bAnc[3]); CNOT(qs[5], bAnc[3]);
        // Bloc 2
        CNOT(qs[6], bAnc[4]); CNOT(qs[7], bAnc[4]);
        CNOT(qs[7], bAnc[5]); CNOT(qs[8], bAnc[5]);

        mutable bitSynd = [false, size = 6];
        for i in 0..5 {
            set bitSynd w/= i <- (MResetZ(bAnc[i]) == One);
        }

        // ── Syndromes phase-flip ──────────────────────────────────────────
        // On mesure la X-parité de chaque bloc via des ancillas préparées en |+⟩.
        // X-parité d'un bloc (q0, q1, q2) = CNOT dans la base X
        //   = H·(q0⊕q1⊕q2)·H mesuré en Z sur une ancilla en |+⟩
        use pAnc = Qubit[3];
        ApplyToEach(H, pAnc);   // |+⟩^⊗3

        // Chaque pAnc[i] accumule la X-parité du bloc i
        for j in 0..2 { CNOT(pAnc[0], qs[j]); }   // bloc 0
        for j in 3..5 { CNOT(pAnc[1], qs[j]); }   // bloc 1
        for j in 6..8 { CNOT(pAnc[2], qs[j]); }   // bloc 2

        ApplyToEach(H, pAnc);

        // Syndrome phase = parité entre blocs consécutifs
        let xp0 = MResetZ(pAnc[0]) == One;
        let xp1 = MResetZ(pAnc[1]) == One;
        let xp2 = MResetZ(pAnc[2]) == One;

        let phaseSynd = [xp0 != xp1, xp1 != xp2];   // différences entre blocs

        return (bitSynd, phaseSynd);
    }

    // -------------------------------------------------------------------------
    // CorrectError9  :  applique les corrections selon les syndromes
    // -------------------------------------------------------------------------
    operation CorrectError9(bitSyndromes : Bool[], phaseSyndromes : Bool[],
                             qs : Qubit[]) : Unit {
        Fact(Length(qs) == 9, "CorrectError9 attend 9 qubits");
        Fact(Length(bitSyndromes) == 6, "6 syndromes bit-flip attendus");
        Fact(Length(phaseSyndromes) == 2, "2 syndromes phase-flip attendus");

        // ── Correction bit-flip dans chaque bloc ─────────────────────────
        // Bloc 0 (qs[0..2]) : syndromes [0] et [1]
        CorrectError3((bitSyndromes[0], bitSyndromes[1]), qs[0..2]);
        // Bloc 1 (qs[3..5]) : syndromes [2] et [3]
        CorrectError3((bitSyndromes[2], bitSyndromes[3]), qs[3..5]);
        // Bloc 2 (qs[6..8]) : syndromes [4] et [5]
        CorrectError3((bitSyndromes[4], bitSyndromes[5]), qs[6..8]);

        // ── Correction phase-flip entre blocs ────────────────────────────
        // Si phaseSyndromes[0] = true  → erreur Z sur le bloc 0 ou 1
        // Si phaseSyndromes[1] = true  → erreur Z sur le bloc 1 ou 2
        // Table de vérité identique aux syndromes bit-flip (mais pour Z) :
        let ps0 = phaseSyndromes[0];
        let ps1 = phaseSyndromes[1];
        // (ps0=T, ps1=F) → erreur sur bloc 0 → Z sur qs[0]
        // (ps0=T, ps1=T) → erreur sur bloc 1 → Z sur qs[3]
        // (ps0=F, ps1=T) → erreur sur bloc 2 → Z sur qs[6]
        if      ps0 and not ps1 { Z(qs[0]); }
        elif    ps0 and ps1     { Z(qs[3]); }
        elif not ps0 and ps1    { Z(qs[6]); }
    }

    // =========================================================================
    // ── TESTS ─────────────────────────────────────────────────────────────────
    // =========================================================================

    // Test du code 3 qubits avec injection d'erreur sur qs[1]
    operation TestRepetitionCode() : Unit {
        use qs = Qubit[3];
        Message("=== Test code de répétition 3 qubits ===");

        // Prépare le qubit logique en |+⟩ = H|0⟩
        H(qs[0]);
        Message("Avant encodage (qubit logique en |+⟩) :");
        DumpMachine();

        // Encodage
        Encode3(qs);
        Message("Après encodage (α|000⟩ + β|111⟩) :");
        DumpMachine();

        // Injection d'erreur bit-flip sur qs[1]
        X(qs[1]);
        Message("Après erreur X sur qs[1] :");
        DumpMachine();

        // Détection
        let syndrome = DetectError3(qs);
        let (s1, s2) = syndrome;
        Message($"Syndrome : ({s1}, {s2})  — erreur attendue sur qs[1] → (true, true)");

        // Correction
        CorrectError3(syndrome, qs);
        Message("Après correction :");
        DumpMachine();

        // Décodage et vérification
        Decode3(qs);
        Message("Après décodage (doit retrouver |+⟩) :");
        DumpMachine();

        ResetAll(qs);
    }

    // Test du code de Shor 9 qubits avec erreur X sur qs[4] et Z sur qs[0]
    operation TestShorCode() : Unit {
        use qs = Qubit[9];
        Message("=== Test code de Shor 9 qubits ===");

        // Qubit logique en |+⟩
        H(qs[0]);

        // Encodage
        Encode9(qs);
        Message("Après encodage 9 qubits :");
        DumpMachine();

        // Injection d'erreurs : bit-flip sur qs[4], phase-flip sur qs[0]
        X(qs[4]);
        Z(qs[0]);
        Message("Après erreurs X(qs[4]) et Z(qs[0]) :");

        // Détection
        let (bSynd, pSynd) = DetectError9(qs);
        Message($"Syndromes bit-flip : {bSynd}");
        Message($"Syndromes phase-flip : {pSynd}");

        // Correction
        CorrectError9(bSynd, pSynd, qs);

        // Décodage
        Adjoint Encode9(qs);
        Message("Après correction et décodage (doit retrouver |+⟩) :");
        DumpMachine();

        ResetAll(qs);
    }

}
