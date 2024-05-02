import Etch.Stream

variable {ι : Type} [Tagged ι] [DecidableEq ι]

def S.mul [HMul α β γ] [Max ι] (a : S ι α) (b : S ι β) : (S ι γ) where
  σ := a.σ × b.σ
  value p := a.value p.1 * b.value p.2
  skip  p i := a.skip p.1 i;; b.skip p.2 i
  succ  p i := a.succ p.1 i;; b.succ p.2 i
  ready p := a.ready p.1 * b.ready p.2 * (a.index p.1 == b.index p.2)
  index p := .call .max ![a.index p.1, b.index p.2]
  valid p := a.valid p.1 * b.valid p.2
  init    := seqInit a b

instance [Mul α] [Max ι] : Mul (S ι α) := ⟨S.mul⟩
instance [HMul α β γ] [Max ι] : HMul (S ι α) (S ι β) (S ι γ) := ⟨S.mul⟩

instance [HMul α β γ] : HMul (ι →ₛ α) (ι →ₐ β) (ι →ₛ γ) where hMul a b := {a with value := λ s => a.value s * b (a.index s)}
instance [HMul β α γ] : HMul (ι →ₐ β) (ι →ₛ α) (ι →ₛ γ) where hMul b a := {a with value := λ s => b (a.index s) * a.value s}
instance [HMul α β γ] : HMul (ι →ₐ α) (ι →ₐ β) (ι →ₐ γ) where hMul a b := λ v => a v * b v

instance : HMul (ι →ₛ α) (ι →ₐ E Bool) (ι →ₛ α) where hMul a b :=
{ a with ready := fun p => a.ready p * b (a.index p),
         skip := fun p i =>
           .if1 (a.ready p * -(b (a.index p)))
             (a.succ p i);;
           (a.skip p i) }

instance : HMul (ι →ₐ E Bool) (ι →ₛ β) (ι →ₛ β) where hMul a b :=
{ b with ready := fun p => a (b.index p) * b.ready p,
         skip := fun p i =>
           .if1 (-(a (b.index p)) * b.ready p)
             (b.succ p i);;
           (b.skip p i) }
