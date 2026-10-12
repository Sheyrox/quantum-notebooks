operation ConstOracle(qs: Qubit[]) : Unit {
    // f(x) = 1 pour tout x → phase globale (−1)^1 = −1 sur chaque état.
    // Astuce : |−⟩ est eigenvecteur de X avec eigenvalue −1.
    // On prépare une ancilla dans |−⟩ et on lui applique X :
    // X|−⟩ = −|−⟩ → phase globale −1 sur le registre, sans toucher qs.
    use aux = Qubit();
    within {
        X(aux);
        H(aux);
    } apply {
        X(aux);
    }
}

operation BalancedOracle(qs: Qubit[]) : Unit {
    // f(x) = x mod 2 = bit de poids 0 = qs[0] (little-endian).
    // Phase kickback via CNOT : quand qs[0] = |1⟩, l'ancilla |−⟩ reçoit
    // un flip X qui lui donne le facteur (−1), kické sur qs[0].
    use aux = Qubit();
    within {
        X(aux);
        H(aux);
    } apply {
        CNOT(qs[0], aux);
    }
}

operation ConstantDeutschJosza(): Result[] {
    // Circuit : H⊗n → ConstOracle → H⊗n → mesure
    // Si f est constante, on mesure toujours |0⟩⊗n.
    use qs = Qubit[3];
    within {
        ApplyToEachA(H, qs);
    } apply {
        ConstOracle(qs);
    }
    return MResetEachZ(qs);
}

operation BalancedDeutschJosza(): Result[] {
    // Circuit : H⊗n → BalancedOracle → H⊗n → mesure
    // Si f est balancée, on ne mesure jamais |0⟩⊗n.
    use qs = Qubit[3];
    within {
        ApplyToEachA(H, qs);
    } apply {
        BalancedOracle(qs);
    }
    return MResetEachZ(qs);
}
