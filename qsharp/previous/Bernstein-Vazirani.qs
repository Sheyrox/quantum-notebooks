// Q# uses little-endian notation
// E.g. |001> in Q# is 4 and |100> is 1.
// The least-significant bit is at qs[0]
operation Oracle(secret: Int, qs: Qubit[]): Unit {
    // f(x) = secret · x  (produit scalaire bit à bit mod 2).
    // Pour chaque bit i de secret : si le bit i vaut 1,
    // un CNOT(qs[i], aux) avec l'ancilla dans |−⟩ contribue
    // le facteur (−1)^{x_i} au produit de phases.
    // Le produit total est (−1)^{secret·x}, ce qui est exactement l'oracle.
    use aux = Qubit();
    within {
        X(aux);
        H(aux);
    } apply {
        mutable s = secret;
        for i in 0..Length(qs) {
            if s % 2 == 1 {
                CNOT(qs[i], aux);
            }
            set s = s / 2;
        }
    }
}

operation BernsteinVazirani(): Result[] {
    // On choisit un secret et on le récupère en une seule requête.
    // Circuit : H⊗n → Oracle(secret) → H⊗n → mesure = secret en little-endian.
    let secret = 13; // 1101 en binaire → little-endian [1,0,1,1] → qs[0]=1,qs[1]=0,qs[2]=1,qs[3]=1
    let nbQubits = 4;
    use qs = Qubit[nbQubits];
    within {
        ApplyToEachA(H, qs);
    } apply {
        Oracle(secret, qs);
    }
    return MResetEachZ(qs);
}
