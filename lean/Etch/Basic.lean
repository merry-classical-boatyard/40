--set_option trace.Meta.synthInstance.instances true
--set_option pp.all true
import Mathlib.Algebra.Ring.Basic

-- not working yet
def Fin.nil {β : Fin 0 → Type _} : (i : Fin 0) → β i := (nomatch .)
syntax "!![" withoutPosition(sepBy(term, ", ")) "]" : term
open Lean in
macro_rules
  | `(!![ $elems,* ]) => (elems.getElems.foldrM (mkIdent `Fin.nil) (f := fun x xs ↦ `(Fin.cons $x $xs)) : MacroM Term)

instance : Add Bool := ⟨ or ⟩
instance : Mul Bool := ⟨ and ⟩

-- todo, generalize?
abbrev Fin.mk1 {γ : Fin 1 → Type _} (a : γ 0) : (i : Fin 1) → (γ i) | 0 => a
abbrev Fin.mk2 {γ : Fin 2 → Type _} (a : γ 0) (b : γ 1) : (i : Fin 2) → (γ i) | 0 => a | 1 => b
abbrev Fin.mk3 {γ : Fin 3 → Type _} (a : γ 0) (b : γ 1) (c : γ 2) : (i : Fin 3) → (γ i) | 0 => a | 1 => b | 2 => c

set_option quotPrecheck false
notation "![]" => (λ i => nomatch i : (_ : Fin 0) → _)
set_option quotPrecheck true
notation "![" a "]" => Fin.mk1 a
notation "![" a "," b "]" => Fin.mk2 a b
notation "![" a "," b "," c "]" => Fin.mk3 a b c

def rev_fmap_comp {f} [Functor f] (x : α → f β) (y : β → γ) := Functor.map y ∘ x
infixr:90 "⊚" => rev_fmap_comp
-- todo remove
def rev_app : α → (α → β) → β := Function.swap (. $ .)
infixr:9 "&" => rev_app

abbrev DecidableLE (α : Type u) [LE α] := @DecidableRel α LE.le
abbrev DecidableLT (α : Type u) [LT α] := @DecidableRel α LT.lt

instance : Zero (Option α) where zero := none