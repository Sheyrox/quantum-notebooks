operation MarkingOracle(qs: Qubit[], aux: Qubit) : Unit {
    // On veut marquer l'état |101⟩.
    // Q# est little-endian : qs[0] = LSB.
    // |101⟩ en little-endian signifie qs[0]=1, qs[1]=0, qs[2]=1 → entier 5.
    // ApplyControlledOnInt(5, X, qs, aux) applique X sur aux
    // si et seulement si le registre qs encode l'entier 5.
    ApplyControlledOnInt(5, X, qs, aux);
}

operation PhaseOracle(qs: Qubit[]) : Unit {
    // Phase kickback : on prépare une ancilla dans |−⟩ = X·H|0⟩,
    // on applique le MarkingOracle, et le within/apply se charge
    // de remettre l'ancilla dans |0⟩ automatiquement.
    // Résultat : le signe (−1) est "kické" sur l'état |101⟩ du registre qs.
    use aux = Qubit();
    within {
        X(aux);
        H(aux);
    } apply {
        MarkingOracle(qs, aux);
    }
}
