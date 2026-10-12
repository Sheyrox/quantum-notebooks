// # Sample
// Getting started
//
// # Description
// This is a minimal Q# program that can be used to start writing Q# code.

import Std.Math.InverseModI;
import Std.Convert.IntAsBigInt;
import Std.Arithmetic.ApplyIfLessOrEqualL;
import Std.Arithmetic.IncByI;
import Std.Math.MinD;
import Std.Diagnostics.DumpMachine;
import Std.Diagnostics.Fact;

// If qs contains a ket >= modulo, it crashes
operation AddConstantModulo(c: Int, modulo: Int, qs: Qubit[]): Unit is Adj + Ctl {
    // TODO
    use carry = Qubit();

    IncByI(c, qs + [carry]);
    Adjoint IncByI(modulo, qs + [carry]);

    Controlled IncByI([carry], (modulo, qs));

    ApplyIfLessOrEqualL(X, IntAsBigInt(c), qs, carry);
}

operation MultiplyConstantModulo(c: Int, modulo: Int, qs: Qubit[]): Unit is Adj + Ctl {
    // TODO

    use aux = Qubit[Length(qs)];

    for i in 0..Length(qs) - 1 {
        let shift = (c * 2^i) % modulo;
        Controlled AddConstantModulo([qs[i]], (shift, modulo, aux));
    }

    for j in 0..Length(qs) - 1 {
        SWAP(qs[j], aux[j]);
    }

    let inverse = InverseModI(c, modulo);
    for i in 0..Length(qs) - 1 {
        let shiftC = (inverse <<< i) % modulo;
        Controlled AddConstantModulo([qs[i]], ((modulo - shiftC), modulo, aux));
    }
}


operation test(): Result[] {
    use qs = Qubit[3];
    //ApplyToEach(H, qs);
    // 4 * 2 = 8 % 7 + 1
    X(qs[2]);
    MultiplyConstantModulo(2, 7, qs);
    return MResetEachZ(qs);
}

operation TestBasicMultiplication(): Result[] {
    use qs = Qubit[3];
    // Test: 3 * 5 = 15 % 7 = 1
    X(qs[0]); // |001⟩ = 1
    X(qs[1]); // |011⟩ = 3
    MultiplyConstantModulo(5, 7, qs);
    return MResetEachZ(qs);
}

operation TestZeroInput(): Result[] {
    use qs = Qubit[3];
    // Test: 0 * c = 0 pour tout c
    // |000⟩ reste |000⟩
    MultiplyConstantModulo(3, 7, qs);
    return MResetEachZ(qs);
}

operation TestMultiplyByOne(): Result[] {
    use qs = Qubit[3];
    // Test: 5 * 1 = 5 % 7 = 5
    X(qs[0]); // |001⟩
    X(qs[2]); // |101⟩ = 5
    MultiplyConstantModulo(1, 7, qs);
    return MResetEachZ(qs);
}

operation Test5QubitBasic1(): Result[] {
    use qs = Qubit[5];
    // Test: 15 * 3 = 45 % 31 = 14
    // 15 = |01111⟩
    X(qs[0]); X(qs[1]); X(qs[2]); X(qs[3]); // |01111⟩ = 15
    MultiplyConstantModulo(3, 31, qs);
    return MResetEachZ(qs);
}

operation TestAddCycle() : Unit {
    // Doit faire un cycle complet : N additions de 1 mod N → identité
    use qs = Qubit[3];
    X(qs[0]);                          // qs = 1
    for _ in 1..7 {
        AddConstantModulo(1, 7, qs);
    }
    DumpMachine();
    ResetAll(qs);
}

operation TestMulFermat() : Unit {
    // Petit Fermat : g^(p-1) = 1 mod p pour p premier et g coprime
    // Pour p=7, g=3 : 3^6 mod 7 = 729 mod 7 = 1. On vérifie en appliquant *3 six fois.
    use qs = Qubit[3];
    X(qs[0]);                          // qs = 1
    for _ in 1..6 {
        MultiplyConstantModulo(3, 7, qs);
    }
    DumpMachine();                     // attendu : qs = |100> = 1 (Fermat OK)
    ResetAll(qs);
}

operation TestMulInverse() : Unit {
    // c * c^(-1) = 1 mod N, donc Mul(c) suivi de Mul(c^(-1)) = identité
    // Pour c=5, N=7 : c^(-1) = 3 (car 5*3 = 15 = 1 mod 7)
    use qs = Qubit[3];
    X(qs[1]);                          // qs = 2
    MultiplyConstantModulo(5, 7, qs);  // qs = 10 mod 7 = 3
    MultiplyConstantModulo(3, 7, qs);  // qs = 9 mod 7 = 2
    DumpMachine();                     // attendu : |010> = 2 (retour à l'origine)
    ResetAll(qs);
}

operation TestMulAdjointStrong() : Unit {
    // Test de l'adjoint sur un état superposé (pas juste un état de base)
    use qs = Qubit[3];
    H(qs[0]); H(qs[1]);                // superposition de 0, 1, 2, 3
    MultiplyConstantModulo(3, 7, qs);
    Adjoint MultiplyConstantModulo(3, 7, qs);
    DumpMachine();                     // attendu : superposition uniforme sur {0,1,2,3}
    ResetAll(qs);
}

// Mfw I cannot use Reset when a function is Adj

// ⡠⠒⢦⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⡼⠉⠙⢦
// ⡇⠀⡔⠛⠲⡄⠀⠀⠀⢀⣀⣀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠹⣤⠒⠚⢧⡀
// ⠱⣼⠀⢀⡠⠧⠤⣀⢠⠃⠀⠀⡇⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⣰⠀⠀⣦⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ ⣀⣀⡀⠀⠀⣿⣆⠀⠀⡇
// ⠀⢹⢀⡎⠀⠀⠀⢈⠏⠀⢠⠚⠀⠀⠀⠀⠀⠀⠀⠀⢀⣤⡾⠟⠛⠛⠛⠻⣶⣶⢤⣀⠀⠀⠀⠀⠀⠀⠀⣯⠀⠀⢱⠀⢠⢧⠛⠒⢦⡇
// ⠀⠈⣾⠀⠀⡔⠋⠁⠀⢀⡏⠀⠀⠀⠀⠀⠀⠀⡠⠞⠛⣋⣀⣀⠀⠀⠀⣤⣤⣀⠀⠈⠙⢦⡀⠀⠀⠀⠀⠈⢣⠀⢸⢀⠞⠸⣄⠀⠀⢱
// ⠀⠀⠘⡆⠀⠃⠀⠀⠀⢸⡄⠀⠀⠀⠀⠀⣠⠎⣠⠴⣿⣿⠟⠀⠀⠀⠀⠘⣿⣿⠑⢦⡀⠀⠙⢦⡀⠀⠀⠀⢸⠀⠀⡁⠀⠀⡜⠇⠀⢸
// ⠀⠀⠀⢣⠀⠀⠀⠙⢄⢀⠇⠀⠀⠀⠀⡼⠁ ⠈⠀ ⠈⣁⠴⠚⠉⠉⠉⠙⠢⢄⠀⠀⠀⠀⠀⠈⢣⡀⠀⠀⢸⢀⡏⠁⠀⠈⠀⠀⡰⠃
// ⠀⠀⠀⠀⠣⡀⠀⠀⢸⠋⠀⠀⠀⠀⣸⠁⠀⠀⠀⢀⡞⠁⠀⠀⠀⠀⠀⠀⠀⠀ ⠱⣄⠀⠀⠀⠀⠀ ⢧⠀⠀⠀⠻⣇⠀⠀⢀⡴⠊
// ⠀⠀⠀⠀⠀⠈⠉⠉⠁⠀⠀⠀⠀⢠⡏⠀⠀⠀⢀⠎⠀⢀⣾⣿⣆⠀⣰⣿⣦⠀⠀⠘⣆⠀⠀⠀⠀⢸⡇⠀⠀⠀⠈⠉⠉⠉
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⠁⠀⠀⠀⡎⠀⠀⣾⣿⣿⣿⣶⣿⣿⣿⡄⠀⠀⠘⡆⠀⠀⠀⠀⡇
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⠀⠀⠀⠸⠁⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣧⠀⠀⠀⢰⡀⠀⠀⠀⡇
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢸⡄⠀⢀⡇⠀⠀⠀⢿⠟⠋⠁⠀⠈⠙⠻⡏⠀⠀⠀⠀⣇⠀⠀⠀⡇
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢷⠀⢸⠀⠀⠀⡴⠃⠀⠀⠀⠀⠀⠀⠀⠘⢢⠀⠀⠀⢸⡀⠀⣸⠃
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠘⡇⢸⠀⢀⡜⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠳⣄⠀⢸⠇⣶
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢧⠈⠉⡡⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀ ⠓⠊⠀⣿
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠳⠚⢧⡀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢈⡵⠦⠤⠃
// ⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠈⠛⠶⢤⣄⣀⣀⣀⣀⣀⡤⠴⠚⠁