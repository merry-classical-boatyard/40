import verification.semantics.skip_stream

/-!
# Contraction of indexed streams

In this file, we define the contraction of indexed streams `Stream.contract`.
This replaces the indexing axis with `() : Unit`, implicitly summing over the
values of the stream.

## Main results
  - `contract_eval`: Correctness for `contract`; evaluating `contract s` results in
    the sum of the values of `s`
  - `is_lawful (Stream.contract s)`: `s.contract` is lawful assuming `s` is

-/

variables {ι : Type} {α : Type*}

@[simps] def Stream.contract (s : Stream ι α) : Stream unit α :=
{ σ := s.σ,
  valid := s.valid,
  ready := s.ready,
  skip := λ q hq i, s.skip q hq (s.index q hq, i.2),
  index := default,
  value := s.value }

variables [linear_order ι]

section index_lemmas

instance (s : Stream ι α) [is_bounded s] : is_bounded (Stream.contract s) :=
⟨⟨s.wf_rel, s.wf, λ q hq, begin
  rintro ⟨⟨⟩, b⟩,
  simp only [Stream.contract_skip],
  refine (s.wf_valid q hq (s.index q hq, b)).imp_right (and.imp_left _),
  simp [Stream.to_order], exact id,
end⟩⟩

@[simp] lemma contract_next (s : Stream ι α) (q : s.σ) : (Stream.contract s).next q = s.next q := rfl

lemma contract_map {β : Type*} (f : α → β) (s : Stream ι α) :
  (s.map f).contract = s.contract.map f := rfl

end index_lemmas

section value_lemmas
variables [add_comm_monoid α]

lemma contract_eval₀ (s : Stream ι α) (q : s.σ) (hq : s.valid q) :
  (Stream.contract s).eval₀ q hq () = finsupp.sum_range (s.eval₀ q hq) :=
by { simp only [Stream.eval₀], dsimp, split_ifs with hr; simp, }

lemma contract_eval (s : Stream ι α) [is_bounded s] [add_comm_monoid α] (q : s.σ) :
  (Stream.contract s).eval q () = finsupp.sum_range (s.eval q) :=
begin
  refine @well_founded.induction _ (Stream.contract s).wf_rel (Stream.contract s).wf _ q _,
  clear q, intros q ih,
  by_cases hq : s.valid q, swap, { simp [hq], },
  simp only [s.eval_valid _ hq, (Stream.contract s).eval_valid _ hq, finsupp.coe_add, pi.add_apply,
    map_add, ih _ ((Stream.contract s).next_wf q hq)], rw [contract_next, contract_eval₀],
end

lemma contract_mono (s : Stream ι α) : (Stream.contract s).is_monotonic :=
λ q hq i, by { rw [Stream.index'_val hq, punit_eq_star ((Stream.contract s).index q hq)], exact bot_le, }

instance (s : Stream ι α) [is_lawful s] : is_lawful (Stream.contract s) :=
{ mono := contract_mono s,
  skip_spec := λ q hq i j hj, begin
    cases j,
    obtain rfl : i = ((), ff) := le_bot_iff.mp hj,
    simp only [Stream.contract_skip, contract_eval, Stream.eval_skip_eq_of_ff],
  end }

end value_lemmas



