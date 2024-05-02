import verification.semantics.skip_stream
import verification.semantics.zero
import verification.semantics.add
import verification.semantics.mul
import verification.semantics.contract
import verification.semantics.replicate

/-!
# Nested stream evaluation

In this file, we define how nested streams are evaluated.
To do this, we use Lean's typeclass system to infer an evaluation
function depending on the shape of the nested stream.

## Main definitions
  - `BoundedStream`: A stream bundled with an initial state and a proof that the stream is bounded
  - `LawfulStream`: A stream bundled with a proof that the stream is strictly lawful
  - `LawfulEval`: An evaluation function that preserves addition, multiplication, and zero

## Main results 
  - `LawfulEval.ind`: Shows that if `α` lawfully evaluates to `β`,
      then (lawful) streams of type `ι ⟶ₛ α` lawfully evaluate to
      finitely supported functions `ι →₀ β`. In the base case, `α = β`,
      and in the inductive case, `α` is itself another stream type which
      lawfully evaluates to `β`. This, together with `LawfulStream.eval_contract`
      and `LawfulStream.eval_replicate`, corresponds to theorem 6.1 in the paper.

-/

noncomputable theory
open_locale classical

@[ext]
structure BoundedStream (ι : Type) [linear_order ι] (α : Type*) extends Stream ι α := 
(init : σ)
(bdd : is_bounded to_Stream)

#check BoundedStream.ext_iff

infixr ` ⟶b `:50 := BoundedStream
local notation `↟`s := s.to_Stream
attribute [instance] BoundedStream.bdd

variables {ι : Type} [linear_order ι] {α β γ : Type*}

@[simps] def BoundedStream.map (f : α → β) (s : BoundedStream ι α) : BoundedStream ι β :=
BoundedStream.mk (s.map f) s.init (by simp; apply_instance)

@[simp] lemma BoundedStream.map_id (s : BoundedStream ι α) : s.map id = s :=
by ext : 1; simp

lemma BoundedStream.map_map (g : α → β) (f : β → γ) (s : BoundedStream ι α) :
  (s.map g).map f = s.map (f ∘ g) :=
by ext : 1; simp [Stream.map_map]

class Eval (α : Type*) (β : out_param Type*)
  [add_zero_class β] :=
(eval : α → β)

open Eval

instance Eval.base {α : Type*} [add_zero_class α] : Eval α α :=
{ eval := id }

instance Eval.ind (ι : Type) [linear_order ι] (α β : Type*) [add_zero_class β]
  [Eval α β] : Eval (ι ⟶b α) (ι →₀ β) :=
{ eval := λ s, (s.map eval).eval s.init  }

structure StrictLawfulStream (ι : Type) [linear_order ι] (α : Type*) {β : Type*} [add_zero_class β]
  [Eval α β] extends (ι ⟶b α) :=
(strict_lawful : is_strict_lawful (to_Stream.map eval))

infixr ` ⟶ₛ `:50 := StrictLawfulStream

attribute [instance] StrictLawfulStream.strict_lawful

@[simp] lemma StrictLawfulStream.to_BoundedStream_to_Stream [add_zero_class β] [Eval α β] (s : ι ⟶ₛ α) :
  (↟(s.to_BoundedStream)) = ↟s := rfl

class LawfulEval (α : Type*) (β : out_param Type*) [non_unital_non_assoc_semiring β]
  extends Eval α β, has_add α, has_mul α, has_zero α :=
(eval_zero : eval 0 = 0)
(eval_add : ∀ x y, eval (x + y) = (eval x) + (eval y))
(eval_mul : ∀ x y, eval (x * y) = (eval x) * (eval y))

instance LawfulEval.base {α : Type*} [non_unital_non_assoc_semiring α] :
  LawfulEval α α :=
{ eval_zero := rfl,
  eval_add := λ x y, rfl,
  eval_mul := λ x y, rfl }

@[simps] def BoundedStream.add [has_zero α] [has_add α] (q r : ι ⟶b α) : ι ⟶b α :=
⟨q.add ↟r, (q.init, r.init), infer_instance⟩

@[simps] def BoundedStream.mul [has_mul α] (q r : ι ⟶b α) : ι ⟶b α :=
⟨q.mul ↟r, (q.init, r.init), infer_instance⟩

@[simps] def BoundedStream.zero : ι ⟶b α :=
⟨Stream.zero ι α, (), infer_instance⟩

@[simps] def BoundedStream.contract (s : ι ⟶b α) : unit ⟶b α :=
⟨(↟s).contract, s.init, infer_instance⟩

@[simps?] def BoundedStream.replicate (n : ℕ) (v : α) : (fin n) ⟶b α :=
⟨Stream.replicate n v, (0 : fin (n + 1)), infer_instance⟩

def Stream.eval' [add_zero_class α] (s : Stream ι α) (q : s.σ) : ι →₀ α :=
if h : is_bounded s then by resetI; exact s.eval q else classical.arbitrary _

lemma Stream.eval'_eq [add_zero_class α] (s : Stream ι α) [is_bounded s] (q : s.σ) :
  s.eval' q = s.eval q := dif_pos _

lemma BoundedStream.zero_eval [non_unital_non_assoc_semiring β] [LawfulEval α β] :
  eval (@BoundedStream.zero ι _ α) = (0 : ι →₀ β) :=
by { dsimp [eval], rw [← Stream.eval'_eq], convert_to (Stream.zero ι β).eval' () = 0, { congr, simp, }, simp [Stream.eval'_eq], } 

lemma Stream.add_map_eval [non_unital_non_assoc_semiring β] [LawfulEval α β] :
  ∀ (q r : Stream ι α), (q.add r).map eval = ((q.map eval).add (r.map eval)) :=
Stream.add_map eval LawfulEval.eval_add LawfulEval.eval_zero

lemma Stream.mul_map_eval [non_unital_non_assoc_semiring β] [LawfulEval α β] :
  ∀ (q r : Stream ι α), (q.mul r).map eval = ((q.map eval).mul (r.map eval)) :=
Stream.mul_map eval LawfulEval.eval_mul

lemma BoundedStream.add_map_eval [non_unital_non_assoc_semiring β] [LawfulEval α β] (q r : ι ⟶b α) :
  (q.add r).map eval = ((q.map eval).add (r.map eval)) :=
by { ext : 1, { exact Stream.add_map_eval (↟q) (↟r), }, refl, }

lemma BoundedStream.mul_map_eval [non_unital_non_assoc_semiring β] [LawfulEval α β] (q r : ι ⟶b α) :
  (q.mul r).map eval = ((q.map eval).mul (r.map eval)) :=
by { ext : 1, { exact Stream.mul_map_eval _ _, }, refl, }

lemma BoundedStream.eval_add [non_unital_non_assoc_semiring β] [LawfulEval α β]
  (q r : ι ⟶b α) [is_lawful ((↟q).map eval)] [is_lawful ((↟r).map eval)] : eval (q.add r) = (eval q) + (eval r) :=
begin
  dsimp only [eval], conv_lhs { rw ← Stream.eval'_eq, },
  convert_to ((q.map eval).add (r.map eval)).eval' (q.add r).init = _,
  { congr, exact BoundedStream.add_map_eval q r, },
  rw Stream.eval'_eq, dsimp, rw add_spec,
end

lemma BoundedStream.eval_contract [non_unital_non_assoc_semiring β] [LawfulEval α β]
  (q : ι ⟶b α) [is_lawful ((↟q).map eval)] : (eval q.contract : unit →₀ β) () = finsupp.sum_range (eval q) :=
by { dsimp [eval, ← contract_map], exact contract_eval _ _, }

lemma BoundedStream.eval_mul [non_unital_non_assoc_semiring β] [LawfulEval α β]
  (q r : ι ⟶b α) [is_strict_lawful ((↟q).map eval)] [is_strict_lawful ((↟r).map eval)] :
  eval (q.mul r) = (eval q) * (eval r) :=
begin
  dsimp only [eval], conv_lhs { rw ← Stream.eval'_eq, },
  convert_to ((q.map eval).mul (r.map eval)).eval' (q.mul r).init = _,
  { congr, exact BoundedStream.mul_map_eval q r, },
  rw Stream.eval'_eq, dsimp, rw mul_spec,
end

@[simps?] def LawfulStream.replicate [non_unital_non_assoc_semiring β] [LawfulEval α β]
  (n : ℕ) (v : α) : (fin n) ⟶ₛ α :=
⟨BoundedStream.replicate n v, (by { dsimp, apply_instance, })⟩

#check @LawfulStream.replicate_to_BoundedStream

instance LawfulEval.ind [non_unital_non_assoc_semiring β]
  [LawfulEval α β] : LawfulEval (ι ⟶ₛ α) (ι →₀ β) :=
{ eval := λ s, eval s.to_BoundedStream,
  add := λ x y, ⟨x.add y.to_BoundedStream, by { dsimp, rw Stream.add_map_eval, apply_instance, }⟩,
  mul := λ x y, ⟨x.mul y.to_BoundedStream, by { dsimp, rw Stream.mul_map_eval, apply_instance, }⟩,
  zero := ⟨BoundedStream.zero, by { simp, apply_instance, }⟩,
  eval_zero := BoundedStream.zero_eval,
  eval_add := λ x y, BoundedStream.eval_add _ _,
  eval_mul := λ x y, BoundedStream.eval_mul _ _ }

attribute [simp] LawfulEval.eval_add LawfulEval.eval_zero
  LawfulEval.eval_mul

@[simp] lemma LawfulStream.eval_contract [non_unital_non_assoc_semiring β]
  [LawfulEval α β] (q : ι ⟶ₛ α) : (eval q.contract : unit →₀ β) () = finsupp.sum_range (eval q) :=
BoundedStream.eval_contract _

@[simp] lemma LawfulStream.eval_replicate [non_unital_non_assoc_semiring β]
  [LawfulEval α β] (n : ℕ) (v : α) (j : fin n) : (eval (LawfulStream.replicate n v) : fin n →₀ β) j = eval v :=
by { dsimp [eval], simp, }
