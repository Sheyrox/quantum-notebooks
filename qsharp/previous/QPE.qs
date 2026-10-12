// This is not really mandatory, but it might be useful to make U to the power of something...
// This function should also be made controllable
operation GateToPower(gate: (Qubit) => Unit is Ctl, power: Int, q: Qubit): Unit is Ctl {
    // Applique gate exactement `power` fois sur q.
    // Le mot-clé "is Ctl" permet de l'utiliser comme porte contrôlée dans QPE.
    for _ in 1..power {
        gate(q);
    }
}

operation QPE(gate: (Qubit) => Unit is Ctl, qs: Qubit[], nbAncilla: Int): Result[] {
    // Circuit QPE (convention little-endian, cf. TP3 section 2.2) :
    //
    //   ancillas[0] ──H──●──────────────── IQFT ── M   (contrôle U^{2^0})
    //   ancillas[1] ──H────●─────────────── IQFT ── M   (contrôle U^{2^1})
    //   …
    //   ancillas[n-1] ─H──────────●──────── IQFT ── M   (contrôle U^{2^{n-1}})
    //                             │
    //   qs ─────────────── U^1 ─ U^2 ─ … ─ U^{2^{n-1}}
    //
    // Après IQFT, on lit ancillas comme entier little-endian m.
    // Phase estimée : φ̃ = m / 2^nbAncilla.

    use ancillas = Qubit[nbAncilla];

    // Étape 1 : superposition des ancillas
    ApplyToEach(H, ancillas);

    // Étape 2 : portes contrôlées U^{2^k}, chaque ancilla[k] contrôle U^{2^k}
    for k in 0..nbAncilla - 1 {
        Controlled GateToPower([ancillas[k]], (gate, 1 <<< k, qs[0]));
    }

    // Étape 3 : IQFT sur les ancillas (= Adjoint QFT)
    Adjoint QFT(ancillas);

    // Étape 4 : mesure et libération
    return MResetEachZ(ancillas);
}
