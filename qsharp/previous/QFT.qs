import Std.Math.PI;
import Std.Convert.IntAsDouble;
import Std.Arrays.SwapReverseRegister;

// You want to make this function Controllable and adjointable as it's gonna be used in the QFT
operation Rk(k: Int, q: Qubit): Unit is Adj + Ctl {
    // Rk applique la phase e^{i·2π/2^k} sur |1⟩, et laisse |0⟩ intact.
    // C'est exactement R1(θ) avec θ = 2π / 2^k.
    let angle = 2.0 * PI() / IntAsDouble(1 <<< k);
    R1(angle, q);
}

// You want to make this function to be "Adjointable"
operation QFT(qs: Qubit[]): Unit is Adj {
    // Circuit QFT (indices 0-based, little-endian Q#) :
    // Pour chaque qubit j :
    //   1. H(qs[j])
    //   2. Pour chaque qubit k > j : Controlled Rk_{k-j+1}(qs[k], qs[j])
    // Puis on inverse l'ordre des qubits (SwapReverseRegister) pour
    // réconcilier la convention little-endian Q# avec la définition standard.
    let n = Length(qs);
    for j in 0..n - 1 {
        H(qs[j]);
        for k in j + 1..n - 1 {
            Controlled Rk([qs[k]], (k - j + 1, qs[j]));
        }
    }
    SwapReverseRegister(qs);
}
