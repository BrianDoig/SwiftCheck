//
//  Combinators.swift
//  SwiftCheck
//
//  Created by Robert Widmann on 8/3/14.
//  Copyright (c) 2014 Robert Widmann. All rights reserved.
//

import Foundation
import Basis

/// Shakes up the internal Random Number generator for a given Generator with a seed.
public func variant<A, S : IntegerType>(seed: S)(m: Gen<A>) -> Gen<A> {
	return Gen(unGen: { r in
		return { n in
			return m.unGen(vary(seed)(r: r))(n)
		}
	})
}

/// Constructs a generator that depends on a size parameter.
public func sized<A>(f: Int -> Gen<A>) -> Gen<A> {
	return Gen(unGen:{ r in
		return { n in
			return f(n).unGen(r)(n)
		}
	})
}

/// Constructs a generator that always uses a given size.
public func resize<A>(n : Int)(m: Gen<A>) -> Gen<A> {
	return Gen(unGen: { r in
		return { (_) in
			return m.unGen(r)(n)
		}
	})
}

/// Constructs a random element in the range of two Integer Types
public func choose<A : SignedIntegerType>(rng: (A, A)) -> Gen<A> {
	return Gen(unGen: { s in
		return { (_) in
			let l = rng.0
			let h = rng.1
			let x = numericCast(RAND_MAX * rand()) as A
			let y = numericCast(h - l + 1) as A
			return numericCast(l + x % y)
		}
	})
}

/// Constructs a Generator that only returns values that satisfy a predicate.
public func suchThat<A>(gen: Gen<A>)(p: (A -> Bool)) -> Gen<A> {
	return suchThatOptional(gen)(p) >>- ({ mx in
		switch mx {
			case .Some(let x):
				return Gen.pure(x)
			case .None:
				return sized({ n in
					return resize(n + 1)(m: suchThat(gen)(p))
				})
		}
	})
}

/// Constructs a Generator that attempts to generate a values that satisfy a predicate.
///
/// Passing values are wrapped in `.Some`.  Failing values are `.None`.
public func suchThatOptional<A>(gen: Gen<A>)(p: A -> Bool) -> Gen<Optional<A>> {
	return sized({ n in
		return try(gen, 0, max(n, 1), p)
	})
}

/// Randomly selects and uses one of a number of given Generators.
public func oneOf<A>(gs : [Gen<A>]) -> Gen<A> {
	assert(gs.count != 0, "oneOf used with empty list")

	return choose((0, gs.count - 1)) >>- ({ x in
		return gs[x]
	})
}

/// Given a list of Generators and weights associated with them, this function randomly selects and
/// uses a Generator.
public func frequency<A>(xs: [(Int, Gen<A>)]) -> Gen<A> {
	assert(xs.count != 0, "frequency used with empty list")
	
	return choose((1, sum(xs.map() { $0.0 }))) >>- { l in
		return pick(l)(lst: xs)
	}
}

/// Selects a random value from a list and constructs a Generator that returns only that value.
public func elements<A>(xs: [A]) -> Gen<A> {
	assert(xs.count != 0, "elements used with empty list")

	return Gen.fmap({ i in
		return xs[i]
	})(choose((0, xs.count - 1)))
}

/// Takes a list of elements of increasing size, and chooses among an initial segment of the list. 
/// The size of this initial segment increases with the size parameter.
public func growingElements<A>(xs: [A]) -> Gen<A> {
	assert(xs.count != 0, "growingElements used with empty list")

	let k = Double(xs.count)
	return sized({ n in
		return elements(take(max(1, size(k)(m: n)))(xs))
	})
}

/// Generates a list of random length.
public func listOf<A>(gen: Gen<A>) -> Gen<[A]> {
	return sized({ n in
		return choose((0, n)) >>- { k in
			return vectorOf(k)(gen: gen)
		}
	})
}

/// Generates a non-empty list of random length.
public func listOf1<A>(gen: Gen<A>) -> Gen<[A]> {
	return sized({ n in
		return choose((1, max(1, n))) >>- { k in
			return vectorOf(k)(gen: gen)
		}
	})
}

/// Generates a list of a given length.
public func vectorOf<A>(k: Int)(gen : Gen<A>) -> Gen<[A]> {
	return sequence(Array<Gen<A>>(count: k, repeatedValue: gen))
}

/// Implementation Details Follow

private func vary<S : IntegerType>(k : S)(r: StdGen) -> StdGen {
	let s = r.split()
	var gen = ((k % 2) == 0) ? s.0 : s.1
	return (k == (k / 2)) ? gen : vary(k / 2)(r: r)
}

private func try<A>(gen: Gen<A>, k: Int, n : Int, p: A -> Bool) -> Gen<Optional<A>> {
	if n == 0 {
		return Gen.pure(.None)
	}
	return resize(2 * k + n)(m: gen) >>- ({ (let x : A) -> Gen<Optional<A>> in
		if p(x) {
			return Gen.pure(.Some(x))
		}
		return try(gen, k + 1, n - 1, p)
	})
}

private func pick<A>(n: Int)(lst: [(Int, Gen<A>)]) -> Gen<A> {
	let (k, x) = lst[0]
	let tl = Array<(Int, Gen<A>)>(lst[1..<lst.count])
	if n <= k {
		return x
	}
	return pick(n - k)(lst: tl)
}

private func size(k : Double)(m : Int) -> Int {
	let n = Double(m)
	return Int((log(n + 1)) * k / log(100))
}

