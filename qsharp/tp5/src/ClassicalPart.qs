import Std.Convert.IntAsDouble;
import Std.Random.DrawRandomInt;
import Std.Math.Max;
import Std.Math.ExpModI;
import PhaseEstimation.EstimateFrequency;
import Std.Math.BitSizeI;
import Std.Math.GreatestCommonDivisorI;
import Std.Math.AbsI;
import Std.Math.ContinuedFractionConvergentI;

operation FactorSemiprimeInteger(number : Int) : ((Int, Int), Int) {
    // TODO

    if (number % 2 == 0) {
        return ((number / 2, 2), 1);
    }

    mutable foundFactors = false;
    mutable factors = (1, 1);
    mutable attempt = 0;

    repeat {
        let g = DrawRandomInt(1, number - 1);
        let gcd = GreatestCommonDivisorI(g, number);
        if (gcd == 1) {
            let period = EstimatePeriod(g, number);
            (foundFactors, factors) = MaybeFactorsFromPeriod(number, g, period);
        } else {
            foundFactors = true;
            factors = (gcd, number / gcd);
        }
        attempt += 1;
    } until foundFactors fixup {
        //Message($"Not found, attempt: {attempt}");
    }
    return (factors, attempt);
}

function MaybeFactorsFromPeriod(
    modulus : Int,
    generator : Int,
    period : Int
) : (Bool, (Int, Int)) {
    // TODO

    if (period % 2 == 0) {
        let h = ExpModI(generator, period / 2, modulus);

        if (h != modulus - 1) {
            let f1 = GreatestCommonDivisorI(h - 1, modulus);
            let f2 = GreatestCommonDivisorI(h + 1, modulus);
            let f = Max([f1, f2]);
            if (f > 1 and f < modulus) {
                return (true, (f, modulus / f));
            }
        }
    }

    return (false, (1, 1))
}

function PeriodFromFrequency(modulo: Int, frequency: Int, bitsPrecision: Int, currentDivisor: Int) : Int {
    // TODO

    mutable (num, period) = ContinuedFractionConvergentI((frequency, 1 <<< bitsPrecision), modulo);
    num = AbsI(num);
    period = AbsI(period);
    let finalPeriod = period * currentDivisor / GreatestCommonDivisorI(currentDivisor, period);
    return finalPeriod;
}

operation EstimatePeriod(generator: Int, modulo: Int): Int {
    // TODO
    if (GreatestCommonDivisorI(generator, modulo) == 1) {
        let bitSize = BitSizeI(modulo);
        let frequency = EstimateFrequency(generator, modulo, bitSize);
        if (frequency != 0) {
            return PeriodFromFrequency(modulo, frequency, 2 * bitSize + 1, 1);
        }
        return 1;
    }

    return -1;
}

operation Test1(): Unit {
    let p1 = PeriodFromFrequency(15, 128, 9, 1);
    Message($"p1 : {p1}");
    // attendu : 4 (car 128/512 = 1/4, période 4)
    let p2 = PeriodFromFrequency(15, 256, 9, 1);
    Message($"p2 : {p2}");
    // attendu : 2 (car 256/512 = 1/2, diviseur de 4)
    let p3 = PeriodFromFrequency(15, 384, 9, 1);
    Message($"p3 : {p3}");
    // attendu : 4 (car 384/512 = 3/4, période 4)
    let p4 = PeriodFromFrequency(15, 0, 9, 1);
    Message($"p4 : {p4}");
    // attendu : 0 ou 1 (cas dégénéré ; EstimatePeriod filtre ce cas en amont)
    let p5 = PeriodFromFrequency(15, 128, 9, 2);
    Message($"p5 : {p5}");
    // attendu : 4 (lcm(2, 4) = 4 ; combinaison avec un diviseur précédent)
}

operation Test2(): Unit {
    let p1 = EstimatePeriod(2, 15);
    Message($"p1 : {p1}");

    let p2 = EstimatePeriod(7, 15);
    Message($"p2 : {p2}");

    let p3 = EstimatePeriod(2, 21);
    Message($"p3 : {p3}");
}

operation test3(): Unit {
    let (ok1, (a1, b1)) = MaybeFactorsFromPeriod(15, 2, 4);
    // attendu : (true, (5, 3)) car 2ˆ2 mod 15 = 4
    let (ok2, (a2, b2)) = MaybeFactorsFromPeriod(15, 4, 2);
    // attendu : (true, (5, 3)) car 4ˆ1 mod 15 = 4
    let (ok3, (a3, b3)) = MaybeFactorsFromPeriod(21, 2, 6);
    // attendu : (true, (7, 3)) car 2ˆ3 mod 21 = 8
    let (ok4, _) = MaybeFactorsFromPeriod(15, 7, 4);
    // attendu : (true, ...) car 7ˆ2 mod 15 = 49 mod 15 = 4
    let (ok5, _) = MaybeFactorsFromPeriod(15, 2, 3);
    // attendu : (false, (1, 1)) car r impair
    let (ok6, _) = MaybeFactorsFromPeriod(15, 14, 2);
    // attendu : (false, (1, 1)) car 14ˆ1 mod 15 = 14 = N-1 (cas trivial)
    Message($"(ok1, (a1, b1)) : {(ok1, (a1, b1))}
             (ok2, (a2, b2)) : {(ok2, (a2, b2))}
             (ok3, (a3, b3)) : {(ok3, (a3, b3))}
             (ok4, (a4, b4)) : {(ok4, ())}
             (ok5, (a5, b5)) : {(ok5, ())}
             (ok6, (a6, b6)) : {(ok6, ())}");
}

operation factortest1(): Unit {
    let (a, b) = FactorSemiprimeInteger(15);
    Message($"(a, b) : ({a},{b})");
    // attendu : (5, 3) ou (3, 5)
    let (a, b) = FactorSemiprimeInteger(21);
    Message($"(a, b) : ({a},{b})");
    // attendu : (3, 7) ou (7, 3) ou (3, 7) par chemin classique
    let (a, b) = FactorSemiprimeInteger(35);
    // attendu : (5, 7) ou (7, 5)
    Message($"(a, b) : ({a},{b})");
}

operation factortest2(): Unit {
       let (a, b) = FactorSemiprimeInteger(341);
    // attendu : (397, 89) ou (89, 397)
    Message($"(a, b) : ({a},{b})");
}


operation factor15(): Int {
    let ((_,_), attempt) = FactorSemiprimeInteger(15);
    return attempt;
}

operation factor21(): Int {
    let ((_,_), attempt) = FactorSemiprimeInteger(21);
    return attempt;
}

operation factor35(): Int {
    let ((_,_), attempt) = FactorSemiprimeInteger(35);
    return attempt;
}