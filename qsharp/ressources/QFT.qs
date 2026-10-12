// ─────────────────────────────────────────────────────────────────────────────
// QFT.qs  —  Quantum Fourier Transform (repris de TP3, inchangé)
// ─────────────────────────────────────────────────────────────────────────────
// Aucune modification nécessaire par rapport à TP3 : QPE dans Shor utilise
// exactement le même QFT. Le mot-clé "is Adj" vous donne IQFT gratuitement
// via "Adjoint QFT(qs)".
// ─────────────────────────────────────────────────────────────────────────────

namespace Shor {

    import Std.Math.PI;
    import Std.Convert.IntAsDouble;
    import Std.Arrays.SwapReverseRegister;

    // -------------------------------------------------------------------------
    // Controlled-Rk gate
    //   Rk = [[1, 0], [0, exp(i·2π/2^k)]]
    // Le contrôle est ctrl, la cible est target.
    // -------------------------------------------------------------------------
    operation ControlledRk(k : Int, ctrl : Qubit, target : Qubit) : Unit is Adj {
        let angle = 2.0 * PI() / IntAsDouble(1 <<< k);
        Controlled R1([ctrl], (angle, target));
    }

    // -------------------------------------------------------------------------
    // QFT  —  Quantum Fourier Transform sur n qubits (little-endian Q#)
    //
    // Circuit (indices 0-based, qs[0] = LSB) :
    //   Pour j de 0 à n-1 :
    //     H(qs[j])
    //     Pour k de j+1 à n-1 :
    //       Controlled-R_{k-j+1}(qs[k], qs[j])
    //   SwapReverseRegister  ←  réconcilie l'ordre little-endian avec la
    //                           convention big-endian des références QFT.
    //
    // "is Adj" permet d'écrire "Adjoint QFT(qs)" pour obtenir l'IQFT.
    // -------------------------------------------------------------------------
    operation QFT(qs : Qubit[]) : Unit is Adj {
        let n = Length(qs);
        for j in 0..n - 1 {
            H(qs[j]);
            for k in j + 1..n - 1 {
                ControlledRk(k - j + 1, qs[k], qs[j]);
            }
        }
        SwapReverseRegister(qs);
    }

}
