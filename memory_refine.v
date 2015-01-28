(* Copyright (c) 2012-2014, Robbert Krebbers. *)
(* This file is distributed under the terms of the BSD license. *)
Require Export memory memory_map_refine values_refine.
Require Import natmap.
Local Open Scope ctype_scope.

Instance locks_refine `{Env Ti} :
    Refine Ti (env Ti) lockset := λ Γ α f Γm1 Γm2 Ω1 Ω2,
  (**i 1.) *) ✓{Γm1} Ω1 ∧ ✓{Γm2} Ω2 ∧
  (**i 2.) *) Γm1 ⊑{Γ,α,f} Γm2 ∧
  (**i 3.) *) (∀ o1 o2 r τ1 i,
    f !! o1 = Some (o2,r) → Γm1 ⊢ o1 : τ1 → index_alive Γm1 o1 →
    i < bit_size_of Γ τ1 →
    (o1,i) ∈ Ω1 ↔ (o2,ref_object_offset Γ r + i) ∈ Ω2).

Section memory.
Context `{EnvSpec Ti}.
Implicit Types Γ : env Ti.
Implicit Types Γm : memenv Ti.
Implicit Types τ : type Ti.
Implicit Types a : addr Ti.
Implicit Types p : ptr Ti.
Implicit Types w : mtree Ti.
Implicit Types v : val Ti.
Implicit Types m : mem Ti.
Implicit Types α β : bool.
Implicit Types βs : list bool.
Implicit Types xb : pbit Ti.
Implicit Types xbs : list (pbit Ti).
Implicit Types Ω : lockset.

Hint Immediate ctree_refine_typed_l ctree_refine_typed_r.
Hint Resolve Forall_app_2 Forall2_app.
Hint Immediate cmap_lookup_typed val_typed_type_valid.

Ltac solve_length := repeat first 
  [ rewrite take_length | rewrite drop_length | rewrite app_length
  | rewrite zip_with_length | rewrite replicate_length | rewrite resize_length
  | rewrite fmap_length | erewrite ctree_flatten_length by eauto
  | rewrite to_bools_length ]; lia.
Hint Extern 0 (length _ = _) => solve_length.
Hint Extern 0 (_ ≤ length _) => solve_length.
Hint Extern 0 (length _ ≤ _) => solve_length.

Lemma mem_lookup_refine Γ α f Γm1 Γm2 m1 m2 a1 a2 v1 τ :
  ✓ Γ → m1 ⊑{Γ,α,f@Γm1↦Γm2} m2 → a1 ⊑{Γ,α,f@Γm1↦Γm2} a2 : Some τ →
  m1 !!{Γ} a1 = Some v1 →
  ∃ v2, m2 !!{Γ} a2 = Some v2 ∧ v1 ⊑{Γ,α,f@Γm1↦Γm2} v2 : τ.
Proof.
  unfold lookupE, mem_lookup. intros.
  destruct (m1 !!{Γ} a1) as [w1|] eqn:?; simplify_option_equality.
  destruct (cmap_lookup_refine Γ α f Γm1 Γm2
    m1 m2 a1 a2 w1 τ) as (w2&->&?); auto.
  exists (to_val Γ w2); simplify_option_equality by eauto using
    pbits_refine_kind_subseteq, ctree_flatten_refine; eauto using to_val_refine.
Qed.
Lemma mem_force_refine Γ α f Γm1 Γm2 m1 m2 a1 a2 τ :
  ✓ Γ → m1 ⊑{Γ,α,f@Γm1↦Γm2} m2 → a1 ⊑{Γ,α,f@Γm1↦Γm2} a2 : Some τ →
  is_Some (m1 !!{Γ} a1) → mem_force Γ a1 m1 ⊑{Γ,α,f@Γm1↦Γm2} mem_force Γ a2 m2.
Proof.
  unfold lookupE, mem_lookup, mem_force. intros ??? [v1 ?].
  destruct (m1 !!{Γ} a1) as [w1|] eqn:?; simplify_option_equality.
  destruct (cmap_lookup_refine Γ α f Γm1 Γm2
    m1 m2 a1 a2 w1 τ) as (w2&?&?); auto.
  eapply cmap_alter_refine; eauto using ctree_Forall_not, pbits_mapped,
    pbits_refine_kind_subseteq, ctree_flatten_refine.
Qed.
Lemma mem_force_refine' Γ α f m1 m2 a1 a2 τ :
  ✓ Γ → m1 ⊑{Γ,α,f} m2 → a1 ⊑{Γ,α,f@'{m1}↦'{m2}} a2 : Some τ →
  is_Some (m1 !!{Γ} a1) → mem_force Γ a1 m1 ⊑{Γ,α,f} mem_force Γ a2 m2.
Proof.
  unfold refineM, cmap_refine'; intros ??? [v1 ?].
  destruct (mem_lookup_refine Γ α f ('{m1}) ('{m2})
    m1 m2 a1 a2 v1 τ) as (v2&?&?); eauto.
  erewrite !mem_force_memenv_of by eauto using cmap_refine_valid_l',
    cmap_refine_valid_r'; eauto using mem_force_refine.
Qed.
Lemma mem_writable_refine Γ α f Γm1 Γm2 m1 m2 a1 a2 τ :
  ✓ Γ → m1 ⊑{Γ,α,f@Γm1↦Γm2} m2 → a1 ⊑{Γ,α,f@Γm1↦Γm2} a2 : Some τ →
  mem_writable Γ a1 m1 → mem_writable Γ a2 m2.
Proof.
  intros ??? (w1&?&?). destruct (cmap_lookup_refine Γ α f Γm1 Γm2
    m1 m2 a1 a2 w1 τ) as (w2&?&?); auto.
  exists w2; eauto using pbits_refine_kind_subseteq, ctree_flatten_refine.
Qed.
Lemma mem_insert_refine Γ α f Γm1 Γm2 m1 m2 a1 a2 v1 v2 τ :
  ✓ Γ → m1 ⊑{Γ,α,f@Γm1↦Γm2} m2 → a1 ⊑{Γ,α,f@Γm1↦Γm2} a2 : Some τ →
  mem_writable Γ a1 m1 → v1 ⊑{Γ,α,f@Γm1↦Γm2} v2 : τ →
  <[a1:=v1]{Γ}>m1 ⊑{Γ,α,f@Γm1↦Γm2} <[a2:=v2]{Γ}>m2.
Proof.
  intros ??? (w1&?&?) ?. destruct (cmap_lookup_refine Γ α f Γm1 Γm2
    m1 m2 a1 a2 w1 τ) as (w2&?&?); auto.
  eapply cmap_alter_refine; eauto 1.
  * eapply ctree_Forall_not, pbits_mapped; eauto using pbits_kind_weaken.
  * erewrite <-(pbits_refine_perm _ _ _ _ _ (ctree_flatten w1)
      (ctree_flatten w2)) by eauto using ctree_flatten_refine.
    eapply of_val_refine; eauto.
    + eapply pbits_perm_unshared, pbits_unshared; eauto using
        pbits_kind_weaken, pbits_valid_sep_valid, ctree_flatten_valid.
    + eapply pbits_perm_mapped, pbits_mapped; eauto using
        pbits_kind_weaken, pbits_valid_sep_valid, ctree_flatten_valid.
  * eapply ctree_Forall_not, of_val_flatten_mapped; eauto using
      val_refine_typed_l, of_val_flatten_typed, cmap_lookup_Some.
Qed.
Lemma mem_insert_refine' Γ α f m1 m2 a1 a2 v1 v2 τ :
  ✓ Γ → m1 ⊑{Γ,α,f} m2 →
  a1 ⊑{Γ,α,f@'{m1}↦'{m2}} a2 : Some τ → mem_writable Γ a1 m1 →
  v1 ⊑{Γ,α,f@'{m1}↦'{m2}} v2 : τ → <[a1:=v1]{Γ}>m1 ⊑{Γ,α,f} <[a2:=v2]{Γ}>m2.
Proof.
  unfold refineM, cmap_refine'; intros.
  erewrite !mem_insert_memenv_of by eauto using cmap_refine_valid_l',
    cmap_refine_valid_r', addr_refine_typed_l, addr_refine_typed_r,
    val_refine_typed_l, val_refine_typed_r, mem_writable_refine.
  eauto using mem_insert_refine.
Qed.

(* todo: prove a stronger version that allows to allocate multiple objects
on the left and all map to the same object on the right. *)
Lemma mem_refine_extend Γ α f Γm1 Γm2 o1 o2 :
  ✓ Γ → Γm1 ⊑{Γ,α,f} Γm2 → Γm1 !! o1 = None → Γm2 !! o2 = None → ∃ f',
  (**i 1.) *) Γm1 ⊑{Γ,α,f'} Γm2 ∧
  (**i 2.) *) f' !! o1 = Some (o2,[]) ∧
  (**i 3.) *) meminj_extend f f' Γm1 Γm2.
Proof.
  intros ? HΓm ??. set (f' := meminj_map $
    (<[o1:=(o2,[])]> (map_of_collection (f !!) (dom indexset Γm1)))).
  assert (f' !! o1 = Some (o2,[])) as help1.
  { by unfold f', lookup; intros; simplify_map_equality'. }
  assert (∀ o' τ, Γm1 ⊢ o' : τ → f' !! o' = f !! o') as help2.
  { intros o' τ [β ?]; unfold lookup at 1, f'; simpl.
    rewrite lookup_insert_ne by naive_solver.
    apply option_eq; intros [o2' r]; simpl.
    rewrite lookup_map_of_collection, elem_of_dom; naive_solver. }
  exists f'; repeat split; auto.
  * intros o3 o3' o4 r1 r2. destruct HΓm as [? _ ?? _ _ _ _].
    unfold typed, index_typed in *; unfold lookup, f'; simpl.
    rewrite !lookup_insert_Some, !lookup_map_of_collection, !elem_of_dom.
    intros [[??]|(?&[[??]?]&?)] [[??]|(?&[[??]?]&?)]; naive_solver.
  * intros o3 o4 r. destruct HΓm as [_ ? _ _ _ _ _ _]. unfold lookup, f'; simpl.
    rewrite lookup_insert_Some, lookup_map_of_collection, elem_of_dom.
    intros [[??]|(?&[[??]?]&?)]; simplify_map_equality'; naive_solver. 
  * intros o3 o4 r τ Hf' ?; erewrite help2 in Hf' by eauto.
    eauto using memenv_refine_typed_l.
  * intros o3 o4 r τ. destruct HΓm as [_ _ _ ? _ _ _ _].
    unfold lookup, f'; simpl; unfold typed, index_typed in *.
    rewrite lookup_insert_Some, lookup_map_of_collection, elem_of_dom.
    intros [[??]|(?&[[??]?]&?)]; simplify_map_equality'; naive_solver.
  * intros o3 o4 r Hf' Ho3.
    assert (∃ τ, Γm1 ⊢ o3 : τ) as [τ ?] by (destruct Ho3; do 2 eexists; eauto).
    erewrite help2 in Hf' by eauto; eauto using memenv_refine_alive_l.
  * intros o3 o4 r ?. destruct HΓm as [_ _ _ _ _ ? _ _].
    unfold lookup, f'; simpl; unfold index_alive in *.
    rewrite lookup_insert_Some, lookup_map_of_collection, elem_of_dom.
    intros [[??]|(?&[[??]?]&?)]; simplify_map_equality'; naive_solver. 
  * intros o3 τ. destruct α; [by intros []|intros].
    destruct (memenv_refine_perm_l Γ f Γm1 Γm2 o3 τ) as (o4&?&?); auto.
    exists o4. by erewrite help2 by eauto.
  * intros o4 τ. destruct α; [by intros []|intros].
    destruct (decide (o4 = o2)) as [->|]; eauto.
    destruct (memenv_refine_perm_r Γ f Γm1 Γm2 o4 τ) as (o3&?&?); auto.
    exists o3. by erewrite help2 by eauto.
  * intros o3 o4 r τ [??].
    unfold lookup at 1, f'; simpl; unfold typed, index_typed in *.
    rewrite lookup_insert_Some, lookup_map_of_collection, elem_of_dom.
    intros [[??]|(?&[[??]?]&?)]; simplify_map_equality'; naive_solver.
Qed.
Lemma mem_alloc_refine_env Γ α f Γm1 Γm2 τ o1 o2 :
  Γm1 ⊑{Γ,α,f} Γm2 → Γm1 !! o1 = None → Γm2 !! o2 = None →
  f !! o1 = Some (o2,[]) →
  <[o1:=(τ,false)]> Γm1 ⊑{Γ,α,f} <[o2:=(τ,false)]> Γm2.
Proof.
  intros HΓm; split; eauto using memenv_refine_injective.
  * eauto using memenv_refine_frozen.
  * intros o3 o4 r τ3 ? Ho3. destruct (decide (o1 = o3)) as [->|?].
    + destruct Ho3; simplify_map_equality'.
      setoid_rewrite ref_typed_nil; eauto using mem_alloc_index_typed.
    + destruct (memenv_refine_typed_l HΓm o3 o4 r τ3)
        as (τ4&?&?); eauto using mem_alloc_forward,
        memenv_forward_typed, mem_alloc_index_typed_inv.
  * intros o3 o4 r τ4 ? Ho4. destruct (decide (o1 = o3)) as [->|?].
    { destruct Ho4; simplify_map_equality'.
      setoid_rewrite ref_typed_nil; eauto using mem_alloc_index_typed. }
    destruct (meminj_injective_ne f o1 o2 o3 o4 [] r)
      as [|[??]]; simplify_map_equality; eauto using memenv_refine_injective.
    + destruct (memenv_refine_typed_r HΓm o3 o4 r τ4)
        as (τ3&?&?); eauto using mem_alloc_forward,
        memenv_forward_typed, mem_alloc_index_typed_inv.
    + by destruct (ref_disjoint_nil_inv_l r).
  * intros o3 o4 r ??; destruct (decide (o1 = o3)) as [->|?].
    + simplify_equality; eauto using mem_alloc_index_alive.
    + eauto using mem_alloc_index_alive_neq,
        mem_alloc_index_alive_inv, memenv_refine_alive_l.
  * intros o3 o4 r ??; destruct (decide (o2 = o4)) as [->|?].
    + destruct (memenv_refine_injective Γ α f Γm1 Γm2 HΓm o1 o3 o4 [] r);
        simplify_equality; eauto using mem_alloc_index_alive.
      by destruct (ref_disjoint_nil_inv_l r).
    + eauto using mem_alloc_index_alive_neq,
        mem_alloc_index_alive_inv, memenv_refine_alive_r.
  * intros o3 ???. destruct (decide (o1 = o3)) as [->|]; eauto.
    eauto using memenv_refine_perm_l', mem_alloc_index_typed_inv.
  * intros o4 ???. destruct (decide (o2 = o4)) as [->|]; eauto.
    eauto using memenv_refine_perm_r', mem_alloc_index_typed_inv.
Qed.
Lemma mem_alloc_refine Γ α f Γm1 Γm2 m1 m2 malloc τ o1 o2 :
  let Γm1' := <[o1:=(τ,false)]>Γm1 in let Γm2' := <[o2:=(τ,false)]>Γm2 in
  ✓ Γ → m1 ⊑{Γ,α,f@Γm1↦Γm2} m2 → ✓{Γ} τ → int_typed (size_of Γ τ) sptrT →
  Γm1 !! o1 = None → Γm2 !! o2 = None → f !! o1 = Some (o2,[]) →
  mem_alloc Γ o1 malloc τ m1 ⊑{Γ,α,f@Γm1'↦Γm2'} mem_alloc Γ o2 malloc τ m2.
Proof.
  simpl; intros ? (?&?&HΓm&Hm) ?????.
  split; split_ands; auto 2 using mem_alloc_valid, mem_alloc_refine_env.
  destruct m1 as [m1], m2 as [m2]; intros o3 o4 r w3 malloc' ?; simpl in *.
  rewrite lookup_insert_Some; intros [[??]|[??]]; simplify_map_equality.
  { exists (ctree_new Γ pbit_full τ) (ctree_new Γ pbit_full τ) τ.
    split_ands; auto. apply ctree_unflatten_refine; auto.
    apply Forall2_replicate, PBit_BIndet_refine; auto using perm_full_valid. }
  destruct (meminj_injective_ne f o1 o2 o3 o4 [] r)
    as [|[??]]; simplify_map_equality; eauto using memenv_refine_injective.
  * destruct (Hm o3 o4 r w3 malloc') as (w2&w2'&τ2&?&?&?&?); auto.
    exists w2 w2' τ2; eauto 10 using ctree_refine_weaken,
      mem_alloc_forward, mem_alloc_refine_env, meminj_extend_reflexive.
  * by destruct (ref_disjoint_nil_inv_l r).
Qed.
Lemma mem_alloc_refine' Γ α f m1 m2 malloc τ o1 o2 :
  ✓ Γ → m1 ⊑{Γ,α,f} m2 → ✓{Γ} τ → int_typed (size_of Γ τ) sptrT →
  mem_allocable o1 m1 → mem_allocable o2 m2 → ∃ f',
  (**i 1.) *) f' !! o1 = Some (o2,[]) ∧
  (**i 2.) *) mem_alloc Γ o1 malloc τ m1 ⊑{Γ,α,f'} mem_alloc Γ o2 malloc τ m2 ∧
  (**i 3.) *) meminj_extend f f' ('{m1}) ('{m2}).
Proof.
  intros. destruct (mem_refine_extend Γ α f ('{m1}) ('{m2}) o1 o2) as
    (f'&?&?&?); eauto using mem_allocable_memenv_of,cmap_refine_memenv_refine.
  exists f'; split_ands; auto. unfold refineM, cmap_refine'.
  rewrite !mem_alloc_memenv_of by done.
  eauto using mem_alloc_refine, mem_allocable_memenv_of, cmap_refine_weaken.
Qed.
Lemma mem_alloc_refine'' Γ α m1 m2 malloc τ o :
  ✓ Γ → m1 ⊑{Γ,α} m2 → ✓{Γ} τ → int_typed (size_of Γ τ) sptrT →
  mem_allocable o m1 → mem_allocable o m2 →
  mem_alloc Γ o malloc τ m1 ⊑{Γ,α} mem_alloc Γ o malloc τ m2.
Proof.
  intros. unfold refineM, cmap_refine'. rewrite !mem_alloc_memenv_of by done.
  eauto using mem_alloc_refine, mem_allocable_memenv_of, cmap_refine_weaken.
Qed.
Lemma mem_alloc_val_refine' Γ α f m1 m2 malloc o1 o2 v1 v2 τ :
  ✓ Γ → m1 ⊑{Γ,α,f} m2 → v1 ⊑{Γ,α,f@'{m1}↦'{m2}} v2 : τ →
  int_typed (size_of Γ τ) sptrT →
  mem_allocable o1 m1 → mem_allocable o2 m2 → ∃ f',
  (**i 1.) *) f' !! o1 = Some (o2,[]) ∧
  (**i 2.) *) <[addr_top o1 τ:=v1]{Γ}>(mem_alloc Γ o1 malloc τ m1)
      ⊑{Γ,α,f'} <[addr_top o2 τ:=v2]{Γ}>(mem_alloc Γ o2 malloc τ m2) ∧
  (**i 3.) *) meminj_extend f f' ('{m1}) ('{m2}).
Proof.
  intros.
  assert (✓{Γ} τ) by eauto using val_refine_typed_l, val_typed_type_valid.
  destruct (mem_alloc_refine' Γ α f m1 m2 malloc τ o1 o2) as (f'&?&?&?); auto.
  exists f'; split_ands; eauto 10 using mem_insert_refine',
    mem_alloc_writable_top, addr_top_refine, mem_alloc_index_typed',
    cmap_refine_memenv_refine, val_refine_weaken, mem_alloc_forward'.
Qed.
Hint Immediate cmap_refine_valid_l' cmap_refine_valid_r'.
Hint Immediate cmap_refine_memenv_refine.
Lemma mem_alloc_val_list_refine' Γ α f m1 m2 os1 os2 vs1 vs2 τs :
  ✓ Γ → m1 ⊑{Γ,α,f} m2 → vs1 ⊑{Γ,α,f@'{m1}↦'{m2}}* vs2 :* τs →
  length os1 = length vs1 → length os2 = length vs2 →
  Forall (λ τ, int_typed (size_of Γ τ) sptrT) τs →
  mem_allocable_list m1 os1 → mem_allocable_list m2 os2 → ∃ f',
  (**i 1.) *) Forall2 (λ o1 o2, f' !! o1 = Some (o2,[])) os1 os2 ∧
  (**i 2.) *) mem_alloc_val_list Γ (zip os1 vs1) m1
      ⊑{Γ,α,f'} mem_alloc_val_list Γ (zip os2 vs2) m2 ∧
  (**i 3.) *) meminj_extend f f' ('{m1}) ('{m2}).
Proof.
  rewrite <-!Forall2_same_length. intros ? Hm Hvs Hovs1 Hovs2 Hτs Hos1 Hos2.
  revert f os1 os2 vs1 vs2 m1 m2 Hm Hos1 Hos2 Hvs Hovs1 Hovs2.
  induction Hτs as [|τ τs ?? IH];
    intros f ?? vs1' vs2' m1 m2 ? [|o1 os1 ???] [|o2 os2 ???];
    inversion_clear 1 as [|v1 v2 ? vs1 vs2 ?];
    intros; decompose_Forall_hyps; eauto using meminj_extend_reflexive.
  assert ((Γ,'{m1}) ⊢ v1 : τ) by eauto using val_refine_typed_l.
  assert ((Γ,'{m2}) ⊢ v2 : τ) by eauto using val_refine_typed_r.
  assert (✓{Γ} τ) by eauto using val_typed_type_valid.
  destruct (mem_alloc_val_refine' Γ α f m1 m2 false o1 o2 v1 v2 τ)
    as (f'&?&?&?); auto; simplify_type_equality.
  edestruct (IH f' os1 os2 vs1 vs2) as (f''&?&?&?); eauto.
  { rewrite mem_insert_allocable_list; eauto using mem_alloc_allocable_list. }
  { rewrite mem_insert_allocable_list; eauto using mem_alloc_allocable_list. }
  { eauto using vals_refine_weaken, mem_alloc_val_forward. }
  exists f''; split_ands; eauto using meminj_extend_transitive.
  * constructor; [|done]. transitivity (f' !! o1);
      eauto using eq_sym, mem_alloc_val_index_typed, meminj_extend_left.
  * eauto using meminj_extend_transitive, mem_alloc_val_forward.
Qed.
Lemma mem_freeable_refine Γ α f Γm1 Γm2 m1 m2 a1 a2 τ :
  ✓ Γ → m1 ⊑{Γ,α,f@Γm1↦Γm2} m2 →
  a1 ⊑{Γ,α,f@Γm1↦Γm2} a2 : Some τ → mem_freeable a1 m1 → mem_freeable a2 m2.
Proof.
  intros ? (_&_&_&Hm) ? (Ha&w1&?&?).
  rewrite addr_is_top_array_alt in Ha by eauto using addr_refine_typed_l.
  destruct Ha as (τ'&n&?&Ha1&?).
  destruct (addr_ref_refine Γ α f Γm1 Γm2 a1 a2 (Some τ)) as (r&?&_&Ha2); auto.
  destruct (Hm (addr_index a1) (addr_index a2) r w1 true)
    as (?&w2&τ''&?&?&?&Hr); auto; specialize (Hr I); simplify_type_equality'.
  split; [|exists w2; eauto using pbits_refine_perm_1, ctree_flatten_refine].
  rewrite addr_is_top_array_alt by eauto using addr_refine_typed_r.
  assert (addr_ref Γ a2 = [RArray 0 τ' n]) as ->.
  { by rewrite Ha1 in Ha2;
      inversion Ha2 as [|???? Harr]; inversion Harr; decompose_Forall_hyps. }
  erewrite <-addr_ref_byte_refine by eauto.
  exists τ' n; split_ands; eauto using addr_strict_refine.
Qed.
Lemma mem_freeable_index_refine Γ α f Γm1 Γm2 m1 m2 a1 a2 τ :
  ✓ Γ → m1 ⊑{Γ,α,f@Γm1↦Γm2} m2 → a1 ⊑{Γ,α,f@Γm1↦Γm2} a2 : Some τ →
  mem_freeable a1 m1 → f !! addr_index a1 = Some (addr_index a2, []).
Proof.
  intros ? (_&_&_&Hm) ? (Ha&w1&?&?).
  rewrite addr_is_top_array_alt in Ha by eauto using addr_refine_typed_l.
  destruct Ha as (τ'&n&?&Ha1&?), (addr_ref_refine Γ α f Γm1 Γm2 a1 a2 (Some τ))
    as (r&?&Ha2); naive_solver.
Qed.
Lemma mem_free_refine_env Γ α f Γm1 Γm2 o1 o2 :
  Γm1 ⊑{Γ,α,f} Γm2 → f !! o1 = Some (o2,[]) →
  alter (prod_map id (λ _, true)) o1 Γm1
    ⊑{Γ,α,f} alter (prod_map id (λ _, true)) o2 Γm2.
Proof.
  intros HΓm ?; split; eauto using memenv_refine_injective.
  * eauto using memenv_refine_frozen.
  * intros o3 o4 r τ3 ??.
    destruct (memenv_refine_typed_l HΓm o3 o4 r τ3) as (τ4&?&?); eauto
      using mem_free_index_typed_inv, mem_free_forward, memenv_forward_typed.
  * intros o3 o4 r τ4 ??.
    destruct (memenv_refine_typed_r HΓm o3 o4 r τ4) as (τ3&?&?); eauto
      using mem_free_index_typed_inv, mem_free_forward, memenv_forward_typed.
  * intros o3 o4 r ??. destruct (decide (o2 = o4)) as [->|?].
    { destruct (memenv_refine_injective Γ α f Γm1 Γm2 HΓm o1 o3 o4 [] r);
        simplify_equality; eauto.
      + by destruct (mem_free_index_alive Γm1 o3).
      + by destruct (ref_disjoint_nil_inv_l r). }
    eauto using mem_free_index_alive_neq,
      mem_free_index_alive_inv, memenv_refine_alive_l.
  * intros o3 o4 r ???. destruct (decide (o1 = o3)); simplify_equality.
    + by destruct (mem_free_index_alive Γm2 o4).
    + eauto using mem_free_index_alive_neq,
        mem_free_index_alive_inv, memenv_refine_alive_r.
  * intros o3 τ ??. destruct (decide (o1 = o3)) as [->|]; eauto.
    eauto using memenv_refine_perm_l', mem_free_index_typed_inv.
  * intros o4 τ ??. destruct (decide (o2 = o4)) as [->|]; eauto.
    eauto using memenv_refine_perm_r', mem_free_index_typed_inv.
Qed.
Lemma mem_free_refine_env_l Γ f Γm1 Γm2 o :
  Γm1 ⊑{Γ,true,f} Γm2 → alter (prod_map id (λ _, true)) o Γm1 ⊑{Γ,true,f} Γm2.
Proof.
  destruct 1; split; simpl; try by auto.
  * eauto using mem_free_index_typed_inv.
  * naive_solver eauto using mem_free_forward, memenv_forward_typed.
  * eauto using mem_free_index_alive_inv.
Qed.
Lemma mem_free_refine_env_r Γ f Γm1 Γm2 o :
  Γm1 ⊑{Γ,true,f} Γm2 → (∀ o' r, f !! o' = Some (o,r) → ¬index_alive Γm1 o') →
  Γm1 ⊑{Γ,true,f} alter (prod_map id (λ _, true)) o Γm2.
Proof.
  intros [] Hf; split; simpl; try by auto.
  * naive_solver eauto using mem_free_forward, memenv_forward_typed.
  * eauto using mem_free_index_typed_inv.
  * intros o1 o2 r ??.
    destruct (decide (o2 = o)) as [->|?]; [by destruct (Hf o1 r)|].
    eauto using mem_free_index_alive_neq.
Qed.
Lemma mem_free_refine Γ α f Γm1 Γm2 m1 m2 o1 o2 :
  let Γm1' := alter (prod_map id (λ _, true)) o1 Γm1 in
  let Γm2' := alter (prod_map id (λ _, true)) o2 Γm2 in
  ✓ Γ → m1 ⊑{Γ,α,f@Γm1↦Γm2} m2 → f !! o1 = Some (o2,[]) →
  mem_free o1 m1 ⊑{Γ,α,f@Γm1'↦Γm2'} mem_free o2 m2.
Proof.
  simpl; intros ?(?&?&?&Hm).
  split; split_ands; auto using mem_free_valid, mem_free_refine_env.
  destruct m1 as [m1], m2 as [m2]; simpl in *.
  intros o1' o2' r w1 malloc ?; rewrite lookup_alter_Some;
    intros [(?&[?|??]&?&?)|[??]]; simplify_equality'; eauto.
  destruct (Hm o1' o2' r w1 malloc) as (w2&w2'&τ2&?&?&?&?); auto.
  destruct (decide (o2 = o2')) as [->|?]; simplify_map_equality.
  * destruct (meminj_injective_alt f o1 o1' o2' [] r) as [->|[??]];
      simplify_map_equality; eauto using memenv_refine_injective.
    by destruct (ref_disjoint_nil_inv_l r).
  * exists w2 w2' τ2; split_ands; eauto using ctree_refine_weaken,
      mem_free_forward, mem_free_refine_env, meminj_extend_reflexive.
Qed.
Lemma mem_free_refine_l Γ f Γm1 Γm2 m1 m2 o :
  let Γm1' := alter (prod_map id (λ _, true)) o Γm1 in
  ✓ Γ → m1 ⊑{Γ,true,f@Γm1↦Γm2} m2 → mem_free o m1 ⊑{Γ,true,f@Γm1'↦Γm2} m2.
Proof.
  simpl; intros ?(?&?&?&Hm).
  split; split_ands; auto using mem_free_valid, mem_free_refine_env_l.
  destruct m1 as [m1], m2 as [m2]; simpl in *.
  intros o1 o2 r w1 malloc ?; rewrite lookup_alter_Some;
    intros [(?&[?|??]&?&?)|[??]]; simplify_equality'; eauto.
  destruct (Hm o1 o2 r w1 malloc) as (w2&w2'&τ2&?&?&?&?); auto.
  exists w2 w2' τ2; eauto 10 using ctree_refine_weaken,
    mem_free_forward, mem_free_refine_env_l, meminj_extend_reflexive.
Qed.
Lemma mem_free_refine_r Γ f Γm1 Γm2 m1 m2 o :
  let Γm2' := alter (prod_map id (λ _, true)) o Γm2 in ✓ Γ →
  (∀ o' r, f !! o' = Some (o,r) → ¬index_alive Γm1 o') →
  m1 ⊑{Γ,true,f@Γm1↦Γm2} m2 → m1 ⊑{Γ,true,f@Γm1↦Γm2'} mem_free o m2.
Proof.
  simpl; intros ? Hf (Hm1&?&?&Hm).
  split; split_ands; auto using mem_free_valid, mem_free_refine_env_r.
  destruct m1 as [m1], m2 as [m2]; simpl in *; intros o1 o2 r w1 malloc ??.
  destruct (cmap_valid_Obj Γ Γm1 (CMap m1) o1 w1 malloc) as (τ1&?&?&_); auto.
  destruct (decide (o2 = o)) as [->|?]; [by destruct (Hf o1 r)|].
  destruct (Hm o1 o2 r w1 malloc) as (w2&w2'&τ2&?&?&?&?); auto.
  exists w2 w2' τ2; simplify_map_equality; eauto 7 using ctree_refine_weaken,
    mem_free_forward, mem_free_refine_env_r, meminj_extend_reflexive.
Qed.
Lemma mem_free_refine' Γ α f m1 m2 o1 o2 :
  ✓ Γ → m1 ⊑{Γ,α,f} m2 → f !! o1 = Some (o2,[]) →
  mem_free o1 m1 ⊑{Γ,α,f} mem_free o2 m2.
Proof.
  unfold refineM, cmap_refine'.
  rewrite !mem_free_memenv_of; eauto using mem_free_refine.
Qed.
Lemma mem_foldr_free_refine Γ α f m1 m2 os1 os2 :
  ✓ Γ → m1 ⊑{Γ,α,f} m2 →
  Forall2 (λ o1 o2, f !! o1 = Some (o2, [])) os1 os2 →
  foldr mem_free m1 os1 ⊑{Γ,α,f} foldr mem_free m2 os2.
Proof. induction 3; simpl; auto using mem_free_refine'. Qed.

Lemma locks_refine_id Γ α Γm Ω : ✓{Γm} Ω → Ω ⊑{Γ,α@Γm} Ω.
Proof.
  split; split_ands; intros until 0; rewrite ?lookup_meminj_id; intros;
    simplify_type_equality'; eauto using memenv_refine_id.
Qed.
Lemma locks_refine_compose Γ α1 α2 f1 f2 Γm1 Γm2 Γm3 Ω1 Ω2 Ω3 :
  ✓ Γ → Ω1 ⊑{Γ,α1,f1@Γm1↦Γm2} Ω2 → Ω2 ⊑{Γ,α2,f2@Γm2↦Γm3} Ω3 →
  Ω1 ⊑{Γ,α1||α2,f2 ◎ f1@Γm1↦Γm3} Ω3.
Proof.
  intros ? (?&?&HΓm12&HΩ12) (?&?&HΓm23&HΩ23);
    split; split_ands; eauto using memenv_refine_compose.
  intros o1 o3 r τ1 i.
  rewrite lookup_meminj_compose_Some; intros (o2&r2&r3&?&?&->) ???.
  destruct (memenv_refine_typed_l HΓm12 o1 o2 r2 τ1) as (τ2&?&?); auto.
  destruct (memenv_refine_typed_l HΓm23 o2 o3 r3 τ2) as (τ3&?&?); auto.
  assert (ref_object_offset Γ r2 + i < bit_size_of Γ τ2).
  { apply Nat.lt_le_trans with
      (ref_object_offset Γ r2 + bit_size_of Γ τ1); [lia|].
    eauto using ref_object_offset_size'. }
  rewrite HΩ12, HΩ23 by eauto using memenv_refine_alive_l.
  by rewrite ref_object_offset_app, Nat.add_assoc,
    (Nat.add_comm (ref_object_offset Γ r2)).
Qed.
Lemma locks_refine_inverse Γ f Γm1 Γm2 Ω1 Ω2 :
  Ω1 ⊑{Γ,false,f@Γm1↦Γm2} Ω2 → Ω2 ⊑{Γ,false,meminj_inverse f@Γm2↦Γm1} Ω1.
Proof.
  intros (?&?&?&Hf); split; split_ands; eauto using memenv_refine_inverse.
  intros o2 o1 r τ i Ho2 ???. destruct (lookup_meminj_inverse_1 Γ f
    Γm1 Γm2 o1 o2 r τ) as (?&?&->); simpl; auto.
  symmetry; apply (Hf _ _ [] τ); eauto using memenv_refine_alive_r.
Qed.
Lemma locks_refine_valid_l Γ α f Γm1 Γm2 Ω1 Ω2 :
  Ω1 ⊑{Γ,α,f@Γm1↦Γm2} Ω2 → ✓{Γm1} Ω1.
Proof. by intros (?&?&?&?). Qed.
Lemma locks_refine_valid_r Γ α f Γm1 Γm2 Ω1 Ω2 :
  Ω1 ⊑{Γ,α,f@Γm1↦Γm2} Ω2 → ✓{Γm2} Ω2.
Proof. by intros (?&?&?&?). Qed.
Lemma locks_refine_weaken Γ α α' f f' Γm1 Γm2 Γm1' Γm2' Ω1 Ω2 :
  ✓ Γ → Ω1 ⊑{Γ,α,f@Γm1↦Γm2} Ω2 →
  Γm1' ⊑{Γ,α',f'} Γm2' → Γm1 ⇒ₘ Γm1' → Γm2 ⇒ₘ Γm2' →
  meminj_extend f f' Γm1 Γm2 → Ω1 ⊑{Γ,α',f'@Γm1'↦Γm2'} Ω2.
Proof.
  intros ? (HΩ1&HΩ2&HΓm12&HΩ) ? HΓm ? [??];
    split; split_ands; eauto 2 using lockset_valid_weaken.
  intros o1 o2 r τ1 i ????; split.
  * intros ?. destruct (HΩ1 o1 i) as [τ1' ?]; auto.
    assert (τ1 = τ1') by eauto using typed_unique, memenv_forward_typed.
    simplify_type_equality.
    by erewrite <-HΩ by eauto using memenv_forward_alive, option_eq_1.
  * intros ?. destruct (HΩ2 o2 (ref_object_offset Γ r + i)) as [τ2' ?]; auto.
    destruct (memenv_refine_typed_r HΓm12 o1 o2 r τ2') as (τ1'&?&?); eauto.
    assert (τ1 = τ1') by eauto using typed_unique, memenv_forward_typed.
    simplify_type_equality. by erewrite HΩ by eauto using memenv_forward_alive.
Qed.
Lemma locks_empty_refine Γ α f Γm1 Γm2 :
  Γm1 ⊑{Γ,α,f} Γm2 → (∅ : lockset) ⊑{Γ,α,f@Γm1↦Γm2} ∅.
Proof. split; split_ands; eauto using lockset_empty_valid; solve_elem_of. Qed.
Lemma mem_locks_refine Γ α f m1 m2 :
  ✓ Γ → m1 ⊑{Γ,α,f} m2 → mem_locks m1 ⊑{Γ,α,f@'{m1}↦'{m2}} mem_locks m2.
Proof.
  intros ? (Hm1&Hm2&?&Hm); split; split_ands; auto using mem_locks_valid.
  intros o1 o2 r σ1 i ?? [σ1' ?] ?. assert (∃ w1 malloc,
    cmap_car m1 !! o1 = Some (Obj w1 malloc)) as (w1&malloc&?).
  { destruct m1 as [m1]; simplify_map_equality'.
    destruct (m1 !! o1) as [[]|]; naive_solver. }
  destruct (Hm o1 o2 r w1 malloc) as (w2'&w2&τ2&?&?&?&?); auto; clear Hm.
  assert ((Γ,'{m1}) ⊢ w1 : τ2) by eauto.
  destruct (cmap_valid_Obj Γ ('{m1}) m1 o1 w1 malloc) as (?&?&?&?&_),
    (cmap_valid_Obj Γ ('{m2}) m2 o2 w2' malloc) as (τ'&?&?&?&_);
    simplify_type_equality'; auto.
  rewrite !elem_of_mem_locks; simplify_option_equality.
  rewrite <-!list_lookup_fmap.
  erewrite pbits_refine_locked; eauto using ctree_flatten_refine.
  rewrite <-(ctree_lookup_flatten Γ ('{m2}) w2' τ' r w2 σ1)
    by eauto using ctree_refine_typed_r, ctree_lookup_le, ref_freeze_le_l.
  by rewrite pbits_locked_mask, fmap_take, fmap_drop, lookup_take, lookup_drop.
Qed.
Lemma mem_lock_refine Γ α f Γm1 Γm2 m1 m2 a1 a2 τ : 
  ✓ Γ → m1 ⊑{Γ,α,f@Γm1↦Γm2} m2 → a1 ⊑{Γ,α,f@Γm1↦Γm2} a2 : Some τ →
  mem_writable Γ a1 m1 → mem_lock Γ a1 m1 ⊑{Γ,α,f@Γm1↦Γm2} mem_lock Γ a2 m2.
Proof.
  intros ??? (w1&?&?).
  destruct (cmap_lookup_refine Γ α f Γm1 Γm2 m1 m2 a1 a2 w1 τ) as (w2&?&?); auto.
  eapply cmap_alter_refine; eauto 1.
  * eapply ctree_Forall_not, pbits_mapped; eauto using pbits_kind_weaken.
  * apply ctree_map_refine; eauto using pbit_lock_unshared, pbit_lock_indetified,
      pbits_lock_refine, ctree_flatten_refine, pbit_lock_mapped.
  * eapply ctree_Forall_not; eauto 8 using ctree_map_typed, pbit_lock_indetified,
      pbits_lock_valid, ctree_flatten_valid, pbit_lock_mapped.
    rewrite ctree_flatten_map.
    eauto using pbits_lock_mapped, pbits_mapped, pbits_kind_weaken.
Qed.
Lemma mem_lock_refine' Γ α f m1 m2 a1 a2 τ : 
  ✓ Γ → m1 ⊑{Γ,α,f} m2 → a1 ⊑{Γ,α,f@'{m1}↦'{m2}} a2 : Some τ →
  mem_writable Γ a1 m1 → mem_lock Γ a1 m1 ⊑{Γ,α,f} mem_lock Γ a2 m2.
Proof.
  intros. unfold refineM, cmap_refine'. erewrite !mem_lock_memenv_of by eauto
    using cmap_refine_valid_l, cmap_refine_valid_r, mem_writable_refine.
  eauto using mem_lock_refine.
Qed.
Lemma ctree_unlock_refine Γ α f Γm1 Γm2 w1 w2 τ βs :
  ✓ Γ → w1 ⊑{Γ,α,f@Γm1↦Γm2} w2 : τ → length βs = bit_size_of Γ τ →
  ctree_merge true pbit_unlock_if w1 βs
    ⊑{Γ,α,f@Γm1↦Γm2} ctree_merge true pbit_unlock_if w2 βs : τ.
Proof.
  intros HΓ Hw Hlen.
  apply ctree_leaf_refine_refine; eauto using ctree_unlock_typed.
  revert w1 w2 τ Hw βs Hlen.
  refine (ctree_refine_ind _ _ _ _ _ _ _ _ _ _ _ _); simpl.
  * constructor; auto using pbits_unlock_refine.
  * intros τ n ws1 ws2 -> ? IH _ βs. rewrite bit_size_of_array. intros Hlen.
    constructor. revert βs Hlen. induction IH; intros; decompose_Forall_hyps;
      erewrite ?Forall2_length by eauto using ctree_flatten_refine; auto.
  * intros s τs wxbss1 wxbss2 Hs Hws IH Hxbss _ _ Hpad βs.
    erewrite bit_size_of_struct by eauto; clear Hs. constructor.
    + revert wxbss1 wxbss2 βs Hws IH Hxbss Hlen Hpad. unfold field_bit_padding.
      induction (bit_size_of_fields _ τs HΓ);
        intros [|[w1 xbs1] ?] [|[w2 xbs2] ?];
        do 2 inversion_clear 1; intros; decompose_Forall_hyps; [done|].
      erewrite ?ctree_flatten_length, <-(Forall2_length _ xbs1 xbs2) by eauto.
      constructor; eauto.
    + clear Hlen IH Hpad. revert βs. induction Hws as [|[w1 xbs1] [w2 xbs2]];
        intros; decompose_Forall_hyps; auto.
      erewrite ?ctree_flatten_length, <-(Forall2_length _ xbs1 xbs2) by eauto.
      constructor; eauto using pbits_unlock_refine.
  * intros. erewrite Forall2_length by eauto using ctree_flatten_refine.
    constructor; auto using pbits_unlock_refine.
  * constructor; auto using pbits_unlock_refine.
  * intros s i τs w1 xbs1 xbs2 τ ???????? βs ?.
    erewrite ctree_flatten_length by eauto.
    constructor; auto using pbits_unlock_unshared.
    rewrite ctree_flatten_merge, <-zip_with_app, take_drop by auto.
    auto using pbits_unlock_refine.
Qed.
Lemma mem_unlock_refine Γ α f Γm1 Γm2 m1 m2 Ω1 Ω2 :
  ✓ Γ → m1 ⊑{Γ,α,f@Γm1↦Γm2} m2 → Ω1 ⊑{Γ,α,f@Γm1↦Γm2} Ω2 →
  mem_unlock Ω1 m1 ⊑{Γ,α,f@Γm1↦Γm2} mem_unlock Ω2 m2.
Proof.
  assert (∀ xb β,
    pbit_unlock_if (pbit_indetify xb) β = pbit_indetify (pbit_unlock_if xb β)).
  { by intros ? []. }
  assert (∀ xb β, sep_unshared xb → sep_unshared (pbit_unlock_if xb β)).
  { intros ? []; eauto using pbit_unlock_unshared. }
  assert (∀ n xbs,
    length xbs = n → zip_with pbit_unlock_if xbs (replicate n false) = xbs).
  { intros n xbs <-. rewrite zip_with_replicate_r by auto.
    by elim xbs; intros; f_equal'. }
  intros ? (Hm1&Hm2&?&Hm) (_&_&_&HΩ);
    split; split_ands; auto using mem_unlock_valid; intros o1 o2 r w1 β ? Hw1.
  destruct m1 as [m1], m2 as [m2], Ω1 as [Ω1 HΩ1], Ω2 as [Ω2 HΩ2]; simpl in *.
  unfold elem_of, lockset_elem_of in HΩ; simpl in HΩ; clear HΩ1 HΩ2.
  rewrite lookup_merge in Hw1 |- * by done.
  destruct (m1 !! o1) as [[|w1' β']|] eqn:?; try by destruct (Ω1 !! o1).
  destruct (Hm o1 o2 r w1' β') as (w2&w2'&τ1&Ho2&?&?&?); auto; clear Hm.
  assert ((Γ,Γm1) ⊢ w1' : τ1) by eauto using ctree_refine_typed_l.
  assert ((Γ,Γm2) ⊢ w2' : τ1) by eauto using ctree_refine_typed_r.
  destruct (cmap_valid_Obj Γ Γm1 (CMap m1) o1 w1' β')as (?&?&?&?&_),
    (cmap_valid_Obj Γ Γm2 (CMap m2) o2 w2 β') as (τ2&?&?&?&_);
    simplify_type_equality; auto.
  destruct (ctree_lookup_Some Γ Γm2 w2 τ2 r w2')
    as (τ1'&?&?); auto; simplify_type_equality.
  assert (ref_object_offset Γ r + bit_size_of Γ τ1
    ≤ bit_size_of Γ τ2) by eauto using ref_object_offset_size'.
  erewrite Ho2, ctree_flatten_length by eauto.
  destruct (Ω1 !! o1) as [ω1|] eqn:?; simplify_equality'.
  { erewrite ctree_flatten_length by eauto. destruct (Ω2 !! o2) as [ω2|] eqn:?.
    * assert (take (bit_size_of Γ τ1) (drop (ref_object_offset Γ r) (to_bools
        (bit_size_of Γ τ2) ω2)) = to_bools (bit_size_of Γ τ1) ω1) as Hω2.
      { apply list_eq_same_length with (bit_size_of Γ τ1); try done.
        intros i β1 β2 ?.
        specialize (HΩ o1 o2 r τ1 i); feed specialize HΩ; auto.
        assert (i ∈ ω1 ↔ ref_object_offset Γ r + i ∈ ω2) as Hi by naive_solver.
        rewrite lookup_take, lookup_drop, !lookup_to_bools, Hi by omega.
        destruct β1, β2; intuition.   }
      do 3 eexists; split_ands; eauto using ctree_lookup_merge.
      rewrite Hω2; eauto using ctree_unlock_refine.
    * assert (to_bools (bit_size_of Γ τ1) ω1
        = replicate (bit_size_of Γ τ1) false) as Hω.
      { apply list_eq_same_length with (bit_size_of Γ τ1); try done.
        intros i β1 β2 ?. rewrite lookup_replicate_2 by done.
        intros Hβ1 ?; destruct β1; simplify_equality'; try done.
        rewrite lookup_to_bools_true in Hβ1 by omega.
        specialize (HΩ o1 o2 r τ1 i); feed specialize HΩ; auto.
        destruct (proj1 HΩ) as (?&?&?); simplify_equality; eauto. }
      do 3 eexists; split_ands; eauto.
      rewrite Hω, ctree_merge_id by auto; eauto. }
  destruct (Ω2 !! o2) as [ω2|] eqn:?; [|by eauto 7].
  assert (take (bit_size_of Γ τ1) (drop (ref_object_offset Γ r) (to_bools
    (bit_size_of Γ τ2) ω2)) = replicate (bit_size_of Γ τ1) false) as Hω2.
  { apply list_eq_same_length with (bit_size_of Γ τ1); try done.
    intros i β1 β2 ?.
    rewrite lookup_take, lookup_drop, lookup_replicate_2 by done.
    intros Hβ1 ?; destruct β1; simplify_equality'; try done.
    rewrite lookup_to_bools_true in Hβ1 by omega.
    specialize (HΩ o1 o2 r τ1 i); feed specialize HΩ; auto.
    destruct (proj2 HΩ) as (?&?&?); simplify_equality; eauto. }
  do 3 eexists; split_ands; eauto using ctree_lookup_merge.
  rewrite Hω2, ctree_merge_id by auto; eauto.
Qed.
Lemma mem_unlock_refine' Γ α f m1 m2 Ω1 Ω2 :
  ✓ Γ → m1 ⊑{Γ,α,f} m2 → Ω1 ⊑{Γ,α,f@'{m1}↦'{m2}} Ω2 →
  mem_unlock Ω1 m1 ⊑{Γ,α,f} mem_unlock Ω2 m2.
Proof.
  unfold refineM, cmap_refine'. rewrite !mem_unlock_memenv_of.
  eauto using mem_unlock_refine.
Qed.
Lemma lock_singleton_refine Γ α f Γm1 Γm2 a1 a2 σ :
  ✓ Γ → a1 ⊑{Γ,α,f@Γm1↦Γm2} a2 : Some σ → addr_strict Γ a1 →
  lock_singleton Γ a1 ⊑{Γ,α,f@Γm1↦Γm2} lock_singleton Γ a2.
Proof.
  intros ? Ha ?.
  assert (Γm1 ⊑{Γ,α,f} Γm2) as HΓm by eauto using addr_refine_memenv_refine.
  assert ((Γ,Γm1) ⊢ a1 : Some σ) by eauto using addr_refine_typed_l.
  assert ((Γ,Γm2) ⊢ a2 : Some σ) by eauto using addr_refine_typed_r.
  split; split_ands; eauto using lock_singleton_valid.
  intros o1 o2 r τ i ????. rewrite !elem_of_lock_singleton_typed by eauto.
  destruct (addr_object_offset_refine Γ α f
    Γm1 Γm2 a1 a2 (Some σ)) as (r'&?&?&->); auto.
  split; [intros (->&?&?); simplify_equality'; intuition lia|intros (->&?&?)].
  destruct (meminj_injective_alt f o1 (addr_index a1) (addr_index a2) r r')
    as [|[??]]; simplify_equality'; eauto using memenv_refine_injective.
  { intuition lia. }
  destruct (memenv_refine_typed_r HΓm o1 (addr_index a2) r
    (addr_type_object a2)) as (?&?&?); eauto using addr_typed_index;
    simplify_type_equality'.
  assert (addr_object_offset Γ a1 + bit_size_of Γ σ
    ≤ bit_size_of Γ (addr_type_object a1)).
  { erewrite addr_object_offset_alt by eauto. transitivity
      (ref_object_offset Γ (addr_ref Γ a1) + bit_size_of Γ (addr_type_base a1));
    eauto using ref_object_offset_size', addr_typed_ref_typed.
    rewrite <-Nat.add_assoc, <-Nat.add_le_mono_l; eauto using addr_bit_range. }
  destruct (ref_disjoint_object_offset Γ (addr_type_object a2) r r'
    τ (addr_type_object a1)); auto; lia.
Qed.
Lemma locks_union_refine Γ α f Γm1 Γm2 Ω1 Ω2 Ω1' Ω2' :
  Ω1 ⊑{Γ,α,f@Γm1↦Γm2} Ω2 → Ω1' ⊑{Γ,α,f@Γm1↦Γm2} Ω2' →
  Ω1 ∪ Ω1' ⊑{Γ,α,f@Γm1↦Γm2} Ω2 ∪ Ω2'.
Proof.
  intros (?&?&?&HΩ) (?&?&_&HΩ');
    split; split_ands; auto using lockset_union_valid.
  intros o1 o2 r τ1 i ????. by rewrite !elem_of_union, HΩ, HΩ' by eauto.
Qed.
Lemma locks_union_list_refine Γ α f Γm1 Γm2 Ωs1 Ωs2 :
  Γm1 ⊑{Γ,α,f} Γm2 → Ωs1 ⊑{Γ,α,f@Γm1↦Γm2}* Ωs2 → ⋃ Ωs1 ⊑{Γ,α,f@Γm1↦Γm2} ⋃ Ωs2.
Proof.
  induction 2; simpl; eauto using locks_union_refine, locks_empty_refine.
Qed.
End memory.