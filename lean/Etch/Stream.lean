import Mathlib.Algebra.Ring.Basic
import Etch.C
import Etch.Op
import Etch.Basic

--notation "𝟚"  => Bool

-- marked irreducible later
def Var (_ : Type _) := String
abbrev ArrayVar (α : Type _) := Var (ℕ → α)
def Var.mk : String → Var α := id
def Var.toString : Var α → String := id
instance : Coe String (Var α) := ⟨Var.mk⟩

inductive E : Type → Type 1
| call {α} (op : Op α) (args : (i : Fin op.arity) → E (op.argTypes i)) : E α
| var    : (v : Var α) → E α
| access : Var (ℕ → α) → E ℕ → E α
| intLit : ℕ → E ℕ
| strLit : String → E String

def E.v (α) (v : String) : E α := E.var v
abbrev Var.expr := @E.var
abbrev Var.access := @E.access

structure HeapContext where
  store : Var α → α
  heap {α : Type _} : Var (ℕ → α) → ℕ → α

def E.eval (c : HeapContext) : E α → α
| call f args => f.spec (λ i => (args i).eval c)
| var v => c.store v
| access arr arg => c.heap arr (arg.eval c)
| intLit x => x
| strLit x => x

instance : OfNat Bool (nat_lit 0) := ⟨ false ⟩
instance : OfNat Bool (nat_lit 1) := ⟨ .true ⟩
instance : Inhabited (E α) := ⟨.var "UNREACHABLE"⟩
instance [Tagged α] [Add α] : Add (E α) := ⟨ λ a b => E.call .add ![a, b] ⟩
instance [Tagged α] [Sub α] : Sub (E α) := ⟨ λ a b => E.call .sub ![a, b] ⟩
instance [Tagged α] [Mul α] : Mul (E α) := ⟨ λ a b => E.call .mul ![a, b] ⟩
instance [Tagged α] [HDiv α α β] : HDiv (E α) (E α) (E β) := ⟨ fun a b => E.call .div ![a, b] ⟩
instance [Tagged α] [Div α] : Div (E α) := ⟨ HDiv.hDiv ⟩
instance : Neg (E Bool) := ⟨ fun a => E.call .neg ![a] ⟩
instance [Tagged α] [OfNat α (nat_lit 0)] : OfNat (E α) (nat_lit 0) := ⟨ E.call .zero ![] ⟩
instance [Tagged α] [OfNat α (nat_lit 1)] : OfNat (E α) (nat_lit 1) := ⟨ E.call .one ![] ⟩
instance : OfNat (E ℕ) n := ⟨ .intLit n ⟩
instance : Coe ℕ (E ℕ) := ⟨ .intLit ⟩
instance : Coe String (E String) := ⟨ .strLit ⟩
--def E.ext (f : String) : E Unit := E.call (O.voidCall f) ![]

def E.compile : E α → Expr
| @call _ op args => Expr.call op.opName $ List.ofFn λ i => E.compile (args i)
| access base i => Expr.index (Expr.var base.toString) [i.compile]
| var v => Expr.var v.toString
| intLit x => Expr.lit x
| strLit x => Expr.lits x

infixr:40 " << " => λ a b => E.call Op.lt ![a, b]
infixr:40 " >> " => λ a b => E.call Op.lt ![b, a]
infixr:40 " <ᵣ " => λ a b => E.call Op.ofBool ![E.call Op.lt ![a, b]]
infixr:40 " >ᵣ " => λ a b => E.call Op.ofBool ![E.call Op.lt ![b, a]]
infixr:40 " == " => λ a b => E.call Op.eq ![a, b]
infixr:40 " != " => λ a b => E.call Op.neg ![(E.call Op.eq ![a, b])]
infixr:40 " <= " => λ a b => E.call Op.le ![a, b]
infixr:40 " >= " => λ a b => E.call Op.le ![b, a]

inductive P
| seq    : P → P → P
| while  : E Bool → P → P
| branch : E Bool → P → P → P
| skip   : P
| decl   [TaggedC α] : Var α → E α → P
| store_var : Var α → E α → P
| store_mem : Var (ℕ → α) → E ℕ → E α → P

-- needs to come after P to avoid injectivity_lemma issue
attribute [irreducible] Var

instance : Inhabited P := ⟨.skip⟩

abbrev Var.store_var := @P.store_var
abbrev Var.store_mem := @P.store_mem
abbrev Var.decl := @P.decl

def P.if1 := λ c t => P.branch c t P.skip
infixr:10 ";;" => P.seq

def P.compile : P → Stmt
| seq a b => Stmt.seq a.compile b.compile
| .while cond body => Stmt.while cond.compile body.compile
| branch c a b => Stmt.conde c.compile a.compile b.compile
| skip => Stmt.noop
| @decl _ taggedC var e => Stmt.decl taggedC.tag var.toString e.compile
| store_var var e => Stmt.store (Expr.var var.toString) e.compile
| store_mem v l r => Stmt.store (Expr.index (Expr.var v.toString) [l.compile]) r.compile

def Name := List ℕ
def Name.toString : Name → String := "_".intercalate ∘ List.map ToString.toString
def Name.fresh (n : Name) (new : ℕ) : Name := new :: n
def Name.freshen (n : Name) : Name := n.fresh 0
def emptyName : Name := []

def Var.fresh (v : Var α) (n : Name) : Var α := Var.mk (v.toString ++ n.toString)

structure S (ι : Type _) (α : Type _) where
  σ     : Type
  -- next_weak/next_strict?
  -- upto/past ?
  skip  : σ → E ι → P -- skip _ s i : if current index < i, must advance; may advance to first index ≥ i.
  succ  : σ → E ι → P -- succ _ s i : if current index ≤ i, must advance; may advance to first index > i.
  value : σ → α
  ready : σ → E Bool
  index : σ → E ι
  valid : σ → E Bool
  init  : Name → P × σ

infixr:25 " →ₛ " => S

instance {ι α} [Inhabited α] : Inhabited (ι →ₛ α) where
  default := {
    σ     := Unit
    skip  := fun _ _ => default
    succ  := fun _ _ => default
    value := fun _ => default
    ready := fun _ => 0
    index := fun _ => default
    valid := fun _ => 0
    init  := fun _ => ⟨default, default⟩
  }

section ι

variable {ι : Type} [Tagged ι] [DecidableEq ι]
{α : Type _}

def Var.incr [Tagged α] [Add α] [One α] (v : Var α) : P := v.store_var <| E.var v + 1
def Var.incr_array [Tagged α] [Add α] [One α] (v : Var (ℕ → α)) (ind : E ℕ) : P := v.store_mem ind <| v.access ind + 1

instance : Coe (Var α) (E α) := ⟨E.var⟩

instance : Functor (S ι) where map := λ f s => {s with value := f ∘ s.value }

structure SkipState (ι : Type) [TaggedC ι] where
  tmp : Var ι
  hi  : Var ℕ
  lo  : Var ℕ
  m   : Var ℕ
  notDone : Var Bool

variable [TaggedC ι]

def SkipState.initSimple : SkipState ι × P :=
  let ss : SkipState ι := {
    tmp := "" -- never used
    hi  := "" -- never used
    lo  := "" -- never used
    m   := "" -- never used
    notDone := "" -- never used
  }
  ⟨ss, .skip⟩

def SkipState.initLinear [Zero (E ι)] (n : Name) : SkipState ι × P :=
  let ss : SkipState ι := {
    tmp := .fresh "temp" n
    hi  := "" -- never used
    lo  := "" -- never used
    m   := "" -- never used
    notDone := "" -- never used
  }
  ⟨ss, .decl ss.tmp 0⟩

def SkipState.initBinary [Zero (E ι)] (n : Name) : SkipState ι × P :=
  let ss : SkipState ι := {
    tmp := .fresh "temp" n
    hi  := .fresh "hi" n
    lo  := .fresh "lo" n
    m   := .fresh "m" n
    notDone := .fresh "not_done" n
  }
  ⟨ss, .decl ss.tmp 0;; .decl ss.hi 0;; .decl ss.lo 0;; .decl ss.m 0;; .decl ss.notDone 0⟩

variable
[LT ι] [DecidableLT ι]
(is : ArrayVar ι)

def simpleSkip (pos : Var ℕ) (tgt : E ι) : P :=
  .if1 (is.access pos << tgt) pos.incr

def linearSearchSkip (ss : SkipState ι) (pos : Var ℕ) (max_pos : E ℕ) (tgt : E ι) :=
  ss.tmp.store_var tgt;;
  .while ((pos.expr << max_pos) * (is.access pos << ss.tmp.expr)) $
    pos.incr

def binarySearchSkip (ss : SkipState ι) (pos : Var ℕ) (max_pos : E ℕ) (i : E ι) : P :=
  ss.tmp.store_var i;;
  ss.lo.store_var pos;;
  ss.hi.store_var max_pos;;
  ss.notDone.store_var 1;;
  (.while ((ss.lo.expr <= ss.hi.expr) * ss.notDone) <|
    ss.m.store_var (.call .mid ![ss.lo.expr, ss.hi.expr]) ;;
    .branch (is.access ss.m << ss.tmp.expr)
      (ss.lo.store_var (ss.m + 1))
      (.branch (ss.tmp.expr << is.access ss.m)
        (ss.hi.store_var (ss.m - 1))
        (ss.notDone.store_var 0;; ss.lo.store_var ss.m)));;
  pos.store_var ss.lo

inductive IterMethod | step | linearSearch | binarySearch

def IterMethod.init [Zero (E ι)] : IterMethod → Name → SkipState ι × P
| .step => fun _ => SkipState.initSimple
| .linearSearch => SkipState.initLinear
| .binarySearch => SkipState.initBinary

def IterMethod.skip [TaggedC ι] : IterMethod → ArrayVar ι → SkipState ι → Var ℕ → E ℕ → E ι → P
| .step => fun is _ pos _ => simpleSkip is pos
| .linearSearch => linearSearchSkip
| .binarySearch => binarySearchSkip

-- [lower, upper)
def S.predRange [One α] (lower upper : E ι) : S ι α where
  σ := Var ι
  value   _ := 1
  succ  _ _ := .skip
  ready   _ := 1
  skip  pos := pos.store_var
  index pos := pos
  valid pos := pos.expr << upper
  init  n   := let p := .fresh "pos" n; (p.decl lower, p)

variable [LE ι] [DecidableLE ι]

-- [lower, upper]
def S.predRangeIncl [One α] (lower upper : E ι) : S ι α where
  σ := Var ι
  value   _ := 1
  succ  _ _ := .skip
  ready   _ := 1
  skip  pos := pos.store_var
  index pos := pos
  valid pos := pos.expr <= upper
  init  n   := let p := .fresh "pos" n; (p.decl lower, p)

def S.interval [Zero ι] (h : IterMethod) (pos : Var ℕ) (lower upper : E ℕ) : S ι (E ℕ) where
  σ := Var ℕ × SkipState ι
  value   := fun ⟨pos, _⟩ => pos.expr
  succ    := fun ⟨pos, _⟩ i => .if1 (is.access pos.expr <= i) pos.incr
  skip    := fun ⟨pos, ss⟩ => h.skip is ss pos upper
  ready   := Function.const _ 1
  index   := fun ⟨pos, _⟩ => is.access pos.expr
  valid   := fun ⟨pos, _⟩ => pos.expr << upper
  init  n := let p := pos.fresh n
             let ⟨ss, ssInit⟩ := h.init n
             (p.decl lower ;; ssInit, (p, ss))

-- todo: use instead of zero
--class Bot (α : Type _) := (bot : α)
--notation "⊥"  => Bot.bot
def S.univ [Add ι] [Zero ι] [One ι] [TaggedC ι] (max l : Var ι) : S ι (E ι) where
  value last := last.expr
  succ  last i := .if1 (last.expr <= i) last.incr  -- imprecise but ok
  ready _    := 1
  skip  last := last.store_var
  index last := last.expr
  valid last := last.expr << max.expr
  init  n    := let v := l.fresh n; (v.decl 0, v)

def S.valFilter (f : α → E Bool) (s : ι →ₛ α) : ι →ₛ α :=
{ s with ready := λ p => s.ready p * f (s.value p),
         skip := λ p i =>
           .branch (s.ready p * -(f (s.value p)))
             (s.succ p i;; s.skip p i)
             (s.skip p i) }

def dim : Var ι := "dim"

-- using fmap introduces a universe constraint between α and Type 1 (coming from E ι). this is probably ok anyway
--def S.repl' {α : Type 1} [Zero ι] (last : Var ι) (v : α) : S ι α := (Function.const _ v) <$> (S.univ last)
--def S.repl [Zero ι] (last : Var ι) (v : α) : S ι α := {S.univ last with value := λ _ => v}
def S.function [Zero ι] [Add ι] [One ι] (last : Var ι) (f : E ι → α) : S ι α := f <$> S.univ dim last

structure csr (ι α : Type _) := (i : Var (ℕ → ι)) (v : Var (ℕ → α)) (var : Var ℕ)

def csr.of (name : String) (n : ℕ) (ι := ℕ) : csr ι ℕ :=
  let field {ι} (x : String) : Var ι := Var.mk $ name ++ n.repr ++ x
  { i := field "_crd", v := field "_pos", var := field "_i" }

def csr.level [Zero ι] (h : IterMethod) (vars : csr ι ℕ) (loc : E ℕ) : ι →ₛ (E ℕ) :=
  S.interval vars.i h vars.var (.access vars.v loc) (vars.v.access (loc+1))
-- CSR, but assume pos[i] = i (inherit the position from the previous level)
def csr.inherit [Zero ι] (vars : csr ι ℕ) (loc : E ℕ) : ι →ₛ (E ℕ) :=
  S.interval vars.i .step vars.var loc (loc+1)
def S.level {f} [Functor f] [Zero ι] (h : IterMethod) : csr ι ℕ → f (E ℕ) → f (ι →ₛ (E ℕ)) := Functor.map ∘ csr.level h
def S.leaf  {f} [Functor f] : Var (ℕ → α) → f (E ℕ) → f (E α) := Functor.map ∘ E.access
--def S.leaf' : Var α → E ℕ → E α := E.access
def Contraction (α : Type _) := (ι : Type) × TaggedC ι × S ι α
--structure Contraction (α : Type _) where
--  f : Type _ → Type _
--  h : Functor f
--  v  : f α
--def Contraction {f : Type → Type _ → Type _} (α : Type _) := (ι : Type) × f ι α
--instance : Functor Contraction where map := λ f ⟨F, h, v⟩ => ⟨F, h, f <$> v⟩
instance : Functor Contraction where map := λ f ⟨ι, tᵢ, v⟩ => ⟨ι, tᵢ, f <$> v⟩
def S.contract [inst : TaggedC ι] (s : S ι α) : Contraction α := ⟨_, inst, s⟩

instance [Inhabited α] : Inhabited (Contraction α) := ⟨⟨ℕ, inferInstance, default⟩⟩

end ι

def Fun (ι α : Type _) := E ι → α
infixr:25 " →ₐ "  => Fun -- arbitrarily chosen for ease of typing: \ra
example : (ℕ →ₐ ℕ →ₛ ℕ) = (ℕ →ₐ (ℕ →ₛ ℕ)) := rfl
def Fun.un (h : ι →ₐ α) : E ι → α := h
def Fun.of (h : E ι → α) : ι →ₐ α := h
instance : Functor (Fun ι) where map := λ f v => f ∘ v

def range : ℕ →ₐ E ℕ := id

def seqInit (a : S ι α) (b : S ι β) (n : Name) :=
let (ai, as) := a.init (n.fresh 0);
let (bi, bs) := b.init (n.fresh 1);
(ai ;; bi, (as, bs))
