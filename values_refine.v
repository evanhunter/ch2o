(* Copyright (c) 2012-2014, Robbert Krebbers. *)
(* This file is distributed under the terms of the BSD license. *)
Require Export values base_values_refine memory_trees_refine.
Local Open Scope ctype_scope.

Inductive val_refine' `{Env Ti} (Γ : env Ti) (α : bool) (f : meminj Ti)
     (Γm1 Γm2 : memenv Ti) : val Ti → val Ti → type Ti → Prop :=
  | VBase_refine vb1 vb2 τb :
     vb1 ⊑{Γ,α,f@Γm1↦Γm2} vb2 : τb →
     val_refine' Γ α f Γm1 Γm2 (VBase vb1) (VBase vb2) (baseT τb)
  | VArray_refine τ n vs1 vs2 :
     n = length vs1 →
     Forall2 (λ v1 v2, val_refine' Γ α f Γm1 Γm2 v1 v2 τ) vs1 vs2 →
     n ≠ 0 → val_refine' Γ α f Γm1 Γm2 (VArray τ vs1) (VArray τ vs2) (τ.[n])
  | VStruct_refine s τs vs1 vs2 :
     Γ !! s = Some τs → Forall3 (val_refine' Γ α f Γm1 Γm2) vs1 vs2 τs →
     val_refine' Γ α f Γm1 Γm2 (VStruct s vs1) (VStruct s vs2) (structT s)
  | VUnion_refine s τs i v1 v2 τ :
     Γ !! s = Some τs → τs !! i = Some τ → val_refine' Γ α f Γm1 Γm2 v1 v2 τ →
     val_refine' Γ α f Γm1 Γm2 (VUnion s i v1) (VUnion s i v2) (unionT s)
  | VUnionAll_refine s τs vs1 vs2 :
     Γ !! s = Some τs → Forall3 (val_refine' Γ α f Γm1 Γm2) vs1 vs2 τs →
     vals_representable Γ Γm1 vs1 τs → vals_representable Γ Γm2 vs2 τs →
     val_refine' Γ α f Γm1 Γm2 (VUnionAll s vs1) (VUnionAll s vs2) (unionT s)
  | VUnion_VUnionAll_refine s τs i v1 v2 τ vs2 :
     α → Γ !! s = Some τs → τs !! i = Some τ → vs2 !! i = Some v2 →
     val_refine' Γ α f Γm1 Γm2 v1 v2 τ → vals_representable Γ Γm2 vs2 τs →
     val_refine' Γ α f Γm1 Γm2 (VUnion s i v1) (VUnionAll s vs2) (unionT s).
Instance val_refine `{Env Ti} :
  RefineT Ti (env Ti) (type Ti) (val Ti) := val_refine'.

Section val_refine_ind.
  Context `{Env Ti} (Γ : env Ti) (α : bool) (f : meminj Ti).
  Context (Γm1 Γm2 : memenv Ti) (P : val Ti → val Ti → type Ti → Prop).
  Context (Pbase : ∀ vb1 vb2 τb,
    vb1 ⊑{Γ,α,f@Γm1↦Γm2} vb2 : τb → P (VBase vb1) (VBase vb2) (baseT τb)).
  Context (Parray : ∀ τ n vs1 vs2,
    length vs1 = n → vs1 ⊑{Γ,α,f@Γm1↦Γm2}* vs2 : τ →
    Forall2 (λ v1 v2, P v1 v2 τ) vs1 vs2 → n ≠ 0 →
    P (VArray τ vs1) (VArray τ vs2) (τ.[n])).
  Context (Pstruct : ∀ s τs vs1 vs2,
    Γ !! s = Some τs →
    vs1 ⊑{Γ,α,f@Γm1↦Γm2}* vs2 :* τs → Forall3 P vs1 vs2 τs →
    P (VStruct s vs1) (VStruct s vs2) (structT s)).
  Context (Punion : ∀ s τs i v1 v2 τ,
    Γ !! s = Some τs → τs !! i = Some τ →
    v1 ⊑{Γ,α,f@Γm1↦Γm2} v2 : τ → P v1 v2 τ →
    P (VUnion s i v1) (VUnion s i v2) (unionT s)).
  Context (Punion_none : ∀ s τs vs1 vs2,
    Γ !! s = Some τs →
    vs1 ⊑{Γ,α,f@Γm1↦Γm2}* vs2 :* τs → Forall3 P vs1 vs2 τs →
    vals_representable Γ Γm1 vs1 τs → vals_representable Γ Γm2 vs2 τs →
    P (VUnionAll s vs1) (VUnionAll s vs2) (unionT s)).
  Context (Punion_union_none : ∀ s τs i v1 v2 τ vs2,
    α → Γ !! s = Some τs → τs !! i = Some τ → vs2 !! i = Some v2 →
    v1 ⊑{Γ,α,f@Γm1↦Γm2} v2 : τ → P v1 v2 τ → vals_representable Γ Γm2 vs2 τs →
    P (VUnion s i v1) (VUnionAll s vs2) (unionT s)).
  Definition val_refine_ind: ∀ v1 v2 τ,
    val_refine' Γ α f Γm1 Γm2 v1 v2 τ → P v1 v2 τ.
  Proof. fix 4; destruct 1; eauto using Forall2_impl, Forall3_impl. Qed.
End val_refine_ind.

Section values.
Context `{EnvSpec Ti}.
Implicit Types Γ : env Ti.
Implicit Types α : bool.
Implicit Types Γm : memenv Ti.
Implicit Types τb : base_type Ti.
Implicit Types τ : type Ti.
Implicit Types τs : list (type Ti).
Implicit Types b : bit Ti.
Implicit Types bs : list (bit Ti).
Implicit Types x : perm.
Implicit Types xs : list perm.
Implicit Types xb : pbit Ti.
Implicit Types xbs : list (pbit Ti).
Implicit Types w : mtree Ti.
Implicit Types ws : list (mtree Ti).
Implicit Types rs : ref_seg Ti.
Implicit Types r : ref Ti.
Implicit Types vb : base_val Ti.
Implicit Types v : val Ti.
Implicit Types vs : list (val Ti).

Hint Resolve Forall_take Forall_drop Forall_app_2
  Forall_replicate Forall_resize.
Hint Resolve Forall2_take Forall2_drop Forall2_app
  Forall2_replicate Forall2_resize.
Hint Resolve BIndet_valid BIndet_weak_refine BIndet_refine BIndet_BIndet_refine.
Hint Immediate env_valid_lookup env_valid_lookup_lookup.
Ltac solve_length := repeat first
  [ rewrite take_length | rewrite drop_length | rewrite app_length
  | rewrite resize_length | rewrite fmap_length | rewrite replicate_length
  | erewrite ctree_flatten_length by eauto|erewrite val_flatten_length by eauto
  | rewrite zip_with_length | erewrite base_val_flatten_length by eauto
  | match goal with
    | |- context [ bit_size_of ?Γ ?τ ] =>
      match goal with
      | H : Γ !! ?s = Some ?τs, H2 : ?τs !! _ = Some τ |- _ =>
        unless (bit_size_of Γ τ ≤ bit_size_of Γ (unionT s)) by done;
        assert (bit_size_of Γ τ ≤ bit_size_of Γ (unionT s))
          by eauto using bit_size_of_union_lookup
      | H : Γ !! ?s = Some [?τ] |- _ =>
        unless (bit_size_of Γ τ ≤ bit_size_of Γ (unionT s)) by done;
        assert (bit_size_of Γ τ ≤ bit_size_of Γ (unionT s))
          by eauto using bit_size_of_union_singleton
      end
    end]; lia.
Hint Extern 0 (length _ = _) => solve_length.
Hint Extern 0 (_ ≤ length _) => solve_length.
Hint Extern 0 (length _ ≤ _) => solve_length.

Lemma val_refine_typed_l Γ α f Γm1 Γm2 v1 v2 τ :
  ✓ Γ → v1 ⊑{Γ,α,f@Γm1↦Γm2} v2 : τ → (Γ,Γm1) ⊢ v1 : τ.
Proof.
  intros ?. revert v1 v2 τ. refine (val_refine_ind _ _ _ _ _ _ _ _ _ _ _ _).
  * intros; typed_constructor; eauto using base_val_refine_typed_l.
  * intros τ n vs1 vs2 Hn _ IH ?; typed_constructor; auto. elim IH; eauto.
  * intros s τs vs1 vs2 Hs _ IH; typed_constructor; eauto. elim IH; eauto.
  * intros; typed_constructor; eauto.
  * intros s τs vs1 vs2 ? _ IH ? _. typed_constructor; eauto. elim IH; auto.
  * intros; typed_constructor; eauto.
Qed.
Lemma vals_refine_typed_l Γ α f Γm1 Γm2 vs1 vs2 τs :
  ✓ Γ → vs1 ⊑{Γ,α,f@Γm1↦Γm2}* vs2 :* τs → (Γ,Γm1) ⊢* vs1 :* τs.
Proof. induction 2; eauto using val_refine_typed_l. Qed.
Lemma val_refine_typed_r Γ α f Γm1 Γm2 v1 v2 τ :
  ✓ Γ → v1 ⊑{Γ,α,f@Γm1↦Γm2} v2 : τ → (Γ,Γm2) ⊢ v2 : τ.
Proof.
  intros ?. revert v1 v2 τ. refine (val_refine_ind _ _ _ _ _ _ _ _ _ _ _ _).
  * intros; typed_constructor; eauto using base_val_refine_typed_r.
  * intros τ n vs1 vs2 <- _ IH ?; typed_constructor;
      eauto using Forall2_length. elim IH; auto.
  * intros s τs vs1 vs2 Hs _ IH; typed_constructor; eauto. elim IH; eauto.
  * intros; typed_constructor; eauto.
  * intros s τs vs1 vs2 ? _ IH _ ?. typed_constructor; eauto. elim IH; auto.
  * intros; typed_constructor; eauto using vals_representable_typed.
Qed.
Lemma vals_refine_typed_r Γ α f Γm1 Γm2 vs1 vs2 τs :
  ✓ Γ → vs1 ⊑{Γ,α,f@Γm1↦Γm2}* vs2 :* τs → (Γ,Γm2) ⊢* vs2 :* τs.
Proof. induction 2; eauto using val_refine_typed_r. Qed.
Lemma val_refine_type_of_l Γ α f Γm1 Γm2 v1 v2 τ :
  v1 ⊑{Γ,α,f@Γm1↦Γm2} v2 : τ → type_of v1 = τ.
Proof. destruct 1; f_equal'; eauto using base_val_refine_type_of_l. Qed.
Lemma vals_refine_type_of_l Γ α f Γm1 Γm2 vs1 vs2 τs :
  ✓ Γ → vs1 ⊑{Γ,α,f@Γm1↦Γm2}* vs2 :* τs → type_of <$> vs1 = τs.
Proof. induction 2; f_equal'; eauto using val_refine_type_of_l. Qed.
Lemma val_refine_type_of_r Γ α f Γm1 Γm2 v1 v2 τ :
  v1 ⊑{Γ,α,f@Γm1↦Γm2} v2 : τ → type_of v2 = τ.
Proof.
  destruct 1; f_equal'; eauto using base_val_refine_type_of_r, Forall2_length_l.
Qed.
Lemma vals_refine_type_of_r Γ f α Γm1 Γm2 vs1 vs2 τs :
  ✓ Γ → vs1 ⊑{Γ,α,f@Γm1↦Γm2}* vs2 :* τs → type_of <$> vs2 = τs.
Proof. induction 2; f_equal'; eauto using val_refine_type_of_r. Qed.
Lemma val_refine_id Γ α Γm v τ : (Γ,Γm) ⊢ v : τ → v ⊑{Γ,α@Γm} v : τ.
Proof.
  revert v τ. refine (val_typed_ind _ _ _ _ _ _ _ _).
  * intros. refine_constructor; eauto using base_val_refine_id.
  * intros vs τ _ IH ?. refine_constructor; eauto. elim IH; auto.
  * intros s vs τs ? _ IH. refine_constructor; eauto.
    elim IH; constructor; auto.
  * intros. refine_constructor; eauto.
  * intros s vs τs ? _ IH ?. refine_constructor; eauto.
    elim IH; constructor; auto.
Qed.
Lemma vals_refine_id Γ α Γm vs τs :
  (Γ,Γm) ⊢* vs :* τs → vs ⊑{Γ,α@Γm}* vs :* τs.
Proof. induction 1; constructor; eauto using val_refine_id. Qed.

Lemma val_refine_compose Γ α1 α2 f1 f2 Γm1 Γm2 Γm3 v1 v2 v3 τ τ' :
  ✓ Γ → v1 ⊑{Γ,α1,f1@Γm1↦Γm2} v2 : τ → v2 ⊑{Γ,α2,f2@Γm2↦Γm3} v3 : τ' →
  v1 ⊑{Γ,α1||α2,f2 ◎ f1@Γm1↦Γm3} v3 : τ.
Proof.
  intros HΓ. assert (∀ vs1 vs2 vs3 τs τs',
    Forall3 (λ v1 v2 τ, ∀ v3 τ',
      v2 ⊑{Γ,α2,f2@Γm2↦Γm3} v3 : τ' →
      v1 ⊑{Γ,α1||α2,f2 ◎ f1@Γm1↦Γm3} v3 : τ) vs1 vs2 τs →
    vs2 ⊑{Γ,α2,f2@Γm2↦Γm3}* vs3 :* τs' →
    vs1 ⊑{Γ,α1||α2,f2 ◎ f1@Γm1↦Γm3}* vs3 :* τs).
  { intros vs1 ws2 vs3 τs τs' Hvs. revert vs3 τs'.
    induction Hvs; inversion_clear 1; constructor; eauto. }
  assert (∀ vs1 vs2 vs3 τ τ',
    Forall2 (λ v1 v2, ∀ v3 τ',
      v2 ⊑{Γ,α2,f2@Γm2↦Γm3} v3 : τ' →
      v1 ⊑{Γ,α1||α2,f2 ◎ f1@Γm1↦Γm3} v3 : τ) vs1 vs2 →
    vs2 ⊑{Γ,α2,f2@Γm2↦Γm3}* vs3 : τ' →
    vs1 ⊑{Γ,α1||α2,f2 ◎ f1@Γm1↦Γm3}* vs3 : τ).
  { intros vs1 ws2 vs3 τ'' τ''' Hvs. revert vs3.
    induction Hvs; inversion_clear 1; try constructor; eauto. }
  intros Hv; revert v3 τ'. induction Hv using @val_refine_ind;
    intros ?? Hv'; refine_inversion Hv'; decompose_Forall_hyps;
    refine_constructor; eauto using base_val_refine_compose.
Qed.
Lemma vals_refine_compose Γ α1 α2 f1 f2 Γm1 Γm2 Γm3 vs1 vs2 vs3 τs τs' :
  ✓ Γ → vs1 ⊑{Γ,α1,f1@Γm1↦Γm2}* vs2 :* τs →
  vs2 ⊑{Γ,α2,f2@Γm2↦Γm3}* vs3 :* τs' →
  vs1 ⊑{Γ,α1||α2,f2 ◎ f1@Γm1↦Γm3}* vs3 :* τs.
Proof.
  intros ? Hvs. revert vs3 τs'. induction Hvs; inversion_clear 1;
    constructor; eauto using val_refine_compose.
Qed.
Lemma val_refine_inverse Γ f Γm1 Γm2 v1 v2 τ :
  v1 ⊑{Γ,false,f@Γm1↦Γm2} v2 : τ →
  v2 ⊑{Γ,false,meminj_inverse f@Γm2↦Γm1} v1 : τ.
Proof.
  revert v1 v2 τ. refine (val_refine_ind _ _ _ _ _ _ _ _ _ _ _ _); simpl.
  * refine_constructor; eauto using base_val_refine_inverse.
  * refine_constructor; eauto using Forall2_length_l, eq_sym.
    by apply Forall2_flip.
  * intros ?????? IH; refine_constructor; eauto. elim IH; constructor; eauto.
  * refine_constructor; eauto.
  * intros ?????? IH; refine_constructor; eauto. elim IH; constructor; eauto.
  * done.
Qed.
Lemma vals_refine_inverse Γ f Γm1 Γm2 vs1 vs2 τs :
  vs1 ⊑{Γ,false,f@Γm1↦Γm2}* vs2 :* τs →
  vs2 ⊑{Γ,false,meminj_inverse f@Γm2↦Γm1}* vs1 :* τs.
Proof. induction 1; constructor; eauto using val_refine_inverse. Qed.
Lemma val_refine_weaken Γ Γ' α α' f f' Γm1 Γm2 Γm1' Γm2' v1 v2 τ :
  ✓ Γ → v1 ⊑{Γ,α,f@Γm1↦Γm2} v2 : τ → Γ ⊆ Γ' → (α → α') →
  Γm1' ⊑{Γ',α',f'} Γm2' → Γm1 ⇒ₘ Γm1' → Γm2 ⇒ₘ Γm2' →
  meminj_extend f f' Γm1 Γm2 → v1 ⊑{Γ',α',f'@Γm1'↦Γm2'} v2 : τ.
Proof.
  intros ? Hv; intros. induction Hv using @val_refine_ind; refine_constructor;
    eauto using base_val_refine_weaken,@lookup_weaken,vals_representable_weaken.
Qed.
Lemma vals_refine_weaken Γ Γ' α α' f f' Γm1 Γm2 Γm1' Γm2' vs1 vs2 τs :
  ✓ Γ → vs1 ⊑{Γ,α,f@Γm1↦Γm2}* vs2 :* τs → Γ ⊆ Γ' → (α → α') →
  Γm1' ⊑{Γ',α',f'} Γm2' → Γm1 ⇒ₘ Γm1' → Γm2 ⇒ₘ Γm2' →
  meminj_extend f f' Γm1 Γm2 → vs1 ⊑{Γ',α',f'@Γm1'↦Γm2'}* vs2 :* τs.
Proof. induction 2; constructor; eauto using val_refine_weaken. Qed.
Lemma val_flatten_refine Γ α f Γm1 Γm2 v1 v2 τ :
  ✓ Γ → v1 ⊑{Γ,α,f@Γm1↦Γm2} v2 : τ →
  val_flatten Γ v1 ⊑{Γ,α,f@Γm1↦Γm2}* val_flatten Γ v2.
Proof.
  intros ?. revert v1 v2 τ.
  refine (val_refine_ind _ _ _ _ _ _ _ _ _ _ _ _); simpl.
  * eauto using base_val_flatten_refine.
  * intros τ n vs1 vs2 <- _ ? _. by apply Forall2_bind.
  * intros s τs vs1 vs2 -> _ IH; simpl. generalize (field_bit_sizes Γ τs).
    induction IH; intros [|?]; decompose_Forall_hyps; auto.
  * eauto.
  * intros s τs vs1 vs2 ?? IH ??.
    destruct (vals_representable_as_bits Γ Γm1 (bit_size_of Γ (unionT s)) vs1
      τs) as (bs1&Hbs1&?&?&?); eauto using bit_size_of_union.
    destruct (vals_representable_as_bits Γ Γm2 (bit_size_of Γ (unionT s)) vs2
      τs) as (bs2&Hbs2&?&?&?); eauto using bit_size_of_union.
    rewrite Hbs1, Hbs2; simpl. eapply bits_list_join_refine; eauto.
    elim IH; simpl; constructor; auto.
  * intros s τs i v1 v2 τ vs2 ?? Hτ Hv2 ???. destruct α; [|done].
    destruct (vals_representable_as_bits Γ Γm2 (bit_size_of Γ (unionT s)) vs2
      τs) as (bs2&Hbs2&?&?&?); eauto using bit_size_of_union.
    rewrite Hbs2; simplify_equality'.
    rewrite <-(left_id_L meminj_id (◎) f), <-(orb_diag true).
    apply bits_refine_compose with
      Γm2 (resize (bit_size_of Γ (unionT s)) BIndet (val_flatten Γ v2)); auto.
    rewrite list_lookup_fmap, Hτ in Hv2; simplify_equality'.
    eapply bits_subseteq_refine, bits_weakly_refine_resize_l;
      eauto using val_flatten_unflatten, bit_size_of_union_lookup.
Qed.
Lemma val_unflatten_refine Γ α f Γm1 Γm2 τ bs1 bs2 :
  ✓ Γ → ✓{Γ} τ → bs1 ⊑{Γ,α,f@Γm1↦Γm2}* bs2 → length bs1 = bit_size_of Γ τ →
  val_unflatten Γ τ bs1 ⊑{Γ,α,f@Γm1↦Γm2} val_unflatten Γ τ bs2 : τ.
Proof.
  intros HΓ Hτ. revert τ Hτ bs1 bs2. refine (type_env_ind _ HΓ _ _ _ _).
  * intros ? τb bs1 bs2 ??. rewrite !val_unflatten_base.
    refine_constructor. by apply base_val_unflatten_refine.
  * intros τ n _ IH Hn bs1 bs2; rewrite !val_unflatten_array, bit_size_of_array.
    intros Hbs Hbs'. refine_constructor; auto using array_unflatten_length.
    revert bs1 bs2 Hbs Hbs'. clear Hn. induction n; simpl; auto.
  * intros [] s τs Hs _ IH _ bs1 bs2; erewrite !val_unflatten_compound,
      ?bit_size_of_struct by eauto; intros Hbs Hbs'.
    { refine_constructor; eauto.
      clear Hs. unfold struct_unflatten. revert bs1 bs2 Hbs Hbs'.
      induction (bit_size_of_fields _ τs HΓ);
        intros; decompose_Forall_hyps; constructor; auto. }
    assert (Forall (λ τ, bit_size_of Γ τ ≤ length bs1) τs).
    { rewrite Hbs'; eauto using bit_size_of_union. }
    refine_constructor; eauto.
    + clear Hbs' Hs. induction IH; decompose_Forall_hyps; constructor; eauto.
    + apply vals_unflatten_representable; eauto using bits_refine_valid_l.
    + apply vals_unflatten_representable; eauto using bits_refine_valid_r.
      by erewrite <-Forall2_length by eauto.
Qed.
Lemma val_new_refine Γ α f Γm1 Γm2 τ :
  ✓ Γ → ✓{Γ} τ → val_new Γ τ ⊑{Γ,α,f@Γm1↦Γm2} val_new Γ τ : τ.
Proof. intros. apply val_unflatten_refine; auto. Qed.
Lemma to_val_refine Γ α f Γm1 Γm2 w1 w2 τ :
  ✓ Γ → w1 ⊑{Γ,α,f@Γm1↦Γm2} w2 : τ →
  to_val Γ w1 ⊑{Γ,α,f@Γm1↦Γm2} to_val Γ w2 : τ.
Proof.
  (* Induction on the typing judgment because the IH is otherwise not
     strong enough in the [Union_UnionAll] case *)
  intros HΓ Hw. assert ((Γ,Γm1) ⊢ w1 : τ) as Hw1
    by eauto using ctree_refine_typed_l.
  revert w1 τ Hw1 f Γm2 w2 Hw. refine (ctree_typed_ind _ _ _ _ _ _ _ _).
  * intros τb xbs ??? f Γm2 w2 Hw2; pattern w2;
      apply (ctree_refine_inv_l _ _ _ _ _ _ _ _ _ Hw2); simpl; clear w2 Hw2.
    refine_constructor; eauto using base_val_unflatten_refine, pbits_tag_refine.
  * intros ws1 τ _ IH Hlen f Γm2 w2 Hw2; pattern w2;
      apply (ctree_refine_inv_l _ _ _ _ _ _ _ _ _ Hw2); simpl; clear w2 Hw2.
    intros ws2 Hws. refine_constructor; auto. clear Hlen.
    induction Hws; decompose_Forall_hyps; constructor; auto.
  * intros s wxbss1 τs Hs ? IH _ _ Hlen f Γm2 w2 Hw2; pattern w2;
      apply (ctree_refine_inv_l _ _ _ _ _ _ _ _ _ Hw2); simpl; clear w2 Hw2.
    intros ? wxbss2 ? Hws _ _; simplify_equality.
    refine_constructor; eauto. clear Hlen Hs.
    induction Hws; decompose_Forall_hyps; constructor; auto.
  * intros s i τs w xbs1 τ ? Hτ ? IH ? _ Hlen _ f Γm2 w2 Hw2; pattern w2;
      apply (ctree_refine_inv_l _ _ _ _ _ _ _ _ _ Hw2); simpl; clear w2 Hw2.
    { intros; simplify_equality; refine_constructor; eauto. }
    intros ?? xbs2_ ???; rewrite Forall2_app_inv_l;
      intros (xbs2&xbs2'&?&?&?) ?; decompose_Forall_hyps.
    erewrite val_unflatten_compound by eauto.
    refine_constructor; eauto; [by rewrite list_lookup_fmap, Hτ| |].
    { destruct α; [|done]. rewrite <-(right_id_L _ (◎) f), <-(orb_diag true).
      apply val_refine_compose with
        Γm1 (val_unflatten Γ τ (tagged_tag <$> ctree_flatten w)) τ; auto.
      { erewrite <-to_val_unflatten,
          ctree_unflatten_flatten by eauto using ctree_typed_type_valid.
        apply IH, union_reset_above;
          eauto using ctree_refine_id, pbits_refine_shared. }
      rewrite fmap_app, take_app_alt by (by erewrite <-ctree_flatten_length,
        fmap_length by eauto; eauto using Forall2_length).
      eauto using val_unflatten_refine, pbits_tag_refine. }
    eapply vals_unflatten_representable;
      eauto using pbits_tag_valid, pbits_refine_valid_r.
    erewrite fmap_length, app_length, <-Forall2_length,
      ctree_flatten_length, <-Forall2_length by eauto.
    rewrite <-Hlen; eauto using bit_size_of_union.
  * intros s τs xbs ??? f Γm2 w2 Hw2; pattern w2;
      apply (ctree_refine_inv_l _ _ _ _ _ _ _ _ _ Hw2); simpl; clear w2 Hw2.
    eauto using val_unflatten_refine, pbits_tag_refine, TCompound_valid.
Qed.
Lemma of_val_refine Γ α f Γm1 Γm2 xs v1 v2 τ :
  ✓ Γ → Forall sep_unshared xs → Forall (not ∘ sep_unmapped) xs →
  length xs = bit_size_of Γ τ → v1 ⊑{Γ,α,f@Γm1↦Γm2} v2 : τ →
  of_val Γ xs v1 ⊑{Γ,α,f@Γm1↦Γm2} of_val Γ xs v2 : τ.
Proof.
  intros HΓ Hxs Hxs' Hxs'' Hvs.
  apply ctree_leaf_refine_refine; eauto using of_val_typed,
    val_refine_typed_l, val_refine_typed_r, seps_unshared_valid.
  revert v1 v2 τ Hvs xs Hxs Hxs' Hxs''.
  refine (val_refine_ind _ _ _ _ _ _ _ _ _ _ _ _).
  * intros; simpl.
    erewrite base_val_refine_type_of_l, base_val_refine_type_of_r by eauto.
    constructor; eauto using PBits_refine,
      base_val_flatten_refine, seps_unshared_valid, base_val_typed_type_valid.
  * intros τ n vs1 vs2 <- ? IH _ xs Hxs Hxs'; simpl.
    rewrite bit_size_of_array; intros Hxs''. constructor.
    revert xs Hxs Hxs' Hxs''. induction IH; intros; decompose_Forall_hyps;
      erewrite ?val_refine_type_of_l, ?val_refine_type_of_r by eauto; auto.
  * intros s τs vs1 vs2 Hs Hvs IH xs Hxs Hxs'; simpl.
    erewrite bit_size_of_struct by eauto; intros Hxs''; clear Hs.
    erewrite vals_refine_type_of_l, vals_refine_type_of_r by eauto.
    constructor.
    + revert vs1 vs2 xs IH Hvs Hxs Hxs' Hxs''. unfold field_bit_padding.
      induction (bit_size_of_fields _ τs HΓ); do 2 inversion_clear 1;
        intros; decompose_Forall_hyps; erewrite ?val_refine_type_of_l,
        ?val_refine_type_of_r by eauto; constructor; eauto 7.
    + clear IH. revert vs1 vs2 xs Hvs Hxs Hxs' Hxs''. unfold field_bit_padding.
      induction (bit_size_of_fields _ τs HΓ); inversion_clear 1;
        intros; decompose_Forall_hyps; erewrite ?val_refine_type_of_l,
        ?val_refine_type_of_r by eauto; constructor;
        eauto 7 using PBits_BIndet_refine, seps_unshared_valid.
  * intros; simpl. erewrite val_refine_type_of_l, val_refine_type_of_r by eauto.
    constructor; eauto using PBits_BIndet_refine,
       PBits_BIndet_refine, seps_unshared_valid.
  * constructor. eapply PBits_refine, val_flatten_refine, VUnionAll_refine;
      auto using seps_unshared_valid; eauto.
  * intros s τs i v1 v2 τ vs2 ? Hs Hτ Hv2 Hv12 IH ? xs ???; simpl.
    assert ((Γ,Γm1) ⊢ v1 : τ) by eauto using val_refine_typed_l.
    assert ((Γ,Γm2) ⊢ v2 : τ) by eauto using val_refine_typed_r.
    simplify_type_equality. destruct (vals_representable_as_bits Γ Γm2
      (bit_size_of Γ (unionT s)) vs2 τs) as (bs2&->&Hlen&?&->); simpl;
      eauto using bit_size_of_union.
    rewrite list_lookup_fmap, Hτ in Hv2; simplify_equality'.
    constructor; [done| |auto using PBits_unshared].
    erewrite ctree_flatten_of_val by eauto using val_refine_typed_l.
    rewrite <-(zip_with_replicate_r _ (bit_size_of Γ (unionT s) -
      bit_size_of Γ τ)), <-zip_with_app, take_drop by auto.
    apply PBits_refine; auto using seps_unshared_valid.
    destruct α; [|done]. apply Forall2_app_l;
      [|apply Forall2_replicate_l; eauto using Forall_impl, BIndet_refine].
    rewrite <-(left_id_L _ (◎) f), <-(orb_diag true).
    eapply bits_refine_compose,
      bits_subseteq_refine; eauto using val_flatten_refine.
    erewrite val_flatten_length by eauto.
    eapply val_flatten_unflatten; eauto using val_typed_type_valid.
Qed.
Lemma of_val_to_val_refine Γ Γm x w τ :
  ✓ Γ → (Γ,Γm) ⊢ w : τ → ctree_Forall (not ∘ sep_unmapped) w →
  of_val Γ (tagged_perm <$> ctree_flatten w) (to_val Γ w) ⊑{Γ,true@Γm} w : τ.
Proof.
  intros HΓ. assert (∀ xbs, ✓{Γ,Γm}* xbs → Forall (not ∘ sep_unmapped) xbs →
    Forall (not ∘ sep_unmapped) (tagged_perm <$> xbs)).
  { eauto using pbits_perm_mapped, Forall_impl, pbit_valid_sep_valid. }
  assert (∀ xbs, ✓{Γ,Γm}* xbs → Forall sep_valid (tagged_perm <$> xbs)).
  { intros. eapply Forall_fmap, Forall_impl; eauto. by intros ? (?&?&?). }
  assert (∀ xbs, ✓{Γ,Γm}* xbs →
    Forall (not ∘ sep_unmapped) (tagged_perm <$> xbs) →
    flip PBit BIndet <$> tagged_perm <$> xbs ⊑{Γ,true@Γm}* xbs).
  { intros xbs ??. rewrite <-(zip_with_replicate_r _ (length xbs)) by auto.
    pattern xbs at 3; rewrite <-(PBits_perm_tag xbs).
    eapply PBits_refine, bits_subseteq_refine;
      eauto using pbits_tag_valid, base_val_flatten_unflatten.
    eapply Forall2_replicate_l; eauto using Forall_true. }
  intros Hw Hw'. apply ctree_leaf_refine_refine; eauto 2;
    [|eapply of_val_typed; eauto using to_val_typed, ctree_flatten_valid].
  revert w τ Hw Hw'. refine (ctree_typed_ind _ _ _ _ _ _ _ _); simpl.
  * intros τb xbs ????. rewrite base_val_unflatten_type_of by done.
    constructor. pattern xbs at 3; rewrite <-(PBits_perm_tag xbs).
    eapply PBits_refine, bits_subseteq_refine;
      eauto using pbits_tag_valid, base_val_flatten_unflatten.
  * intros ws τ Hws IH Hlen ?. constructor.
    clear Hlen. induction IH; decompose_Forall_hyps;
      erewrite ?type_of_correct, ?fmap_app, ?take_app_alt, ?drop_app_alt
      by eauto using to_val_typed; auto.
  * intros s wxbss τs Hs Hws IH Hxbss Hindet Hlen ?. rewrite list_fmap_compose.
    erewrite fmap_type_of by (eapply to_vals_typed, Forall2_fmap_l; eauto).
    constructor; clear Hs.
    + clear Hxbss Hindet. revert dependent wxbss. unfold field_bit_padding.
      induction (bit_size_of_fields _ τs HΓ); intros; decompose_Forall_hyps;
        erewrite ?type_of_correct, ?fmap_app, <-?(associative_L (++)),
          ?take_app_alt, ?drop_app_alt by eauto using to_val_typed;
        constructor; auto.
    + clear IH Hindet. revert dependent wxbss. unfold field_bit_padding.
      induction (bit_size_of_fields _ τs HΓ); intros; decompose_Forall_hyps;
        erewrite ?type_of_correct, ?fmap_app, <-?(associative_L (++)),
          ?drop_app_alt, ?take_app_alt by eauto using to_val_typed;
        constructor; simpl; auto.
  * intros s i τs w xbs τ Hs Hτs Hw IH ?? Hlen ??; decompose_Forall_hyps.
    erewrite type_of_correct by eauto using to_val_typed.
    rewrite fmap_app, take_app_alt, drop_app_alt by auto. constructor; auto.
  * intros s τs xbs Hs Hxbs Hlen ?.
    erewrite val_unflatten_compound by eauto; simpl.
    destruct (vals_representable_as_bits Γ Γm (bit_size_of Γ (unionT s))
      ((λ τ, val_unflatten Γ τ (take (bit_size_of Γ τ)
        (tagged_tag <$> xbs))) <$> τs) τs) as (bs'&Hbs'&?&?&?);
      eauto using bit_size_of_union.
    { apply vals_unflatten_representable; eauto using pbits_tag_valid.
      rewrite fmap_length, Hlen. eauto using bit_size_of_union. }
    rewrite Hbs'; simpl. constructor.
    pattern xbs at 2; rewrite <-(PBits_perm_tag xbs).
    eapply PBits_refine, bits_subseteq_refine; eauto using pbits_tag_valid.
    eapply (bits_list_join_min (bit_size_of Γ (unionT s)));
      eauto using resize_length.
    assert (✓{Γ}* τs) as Hτs_valid by eauto.
    apply bit_size_of_union in Hs; auto. clear Hbs'.
    induction Hτs_valid; decompose_Forall_hyps; constructor;
      eauto using bits_weakly_refine_resize_l,
      val_flatten_unflatten, pbits_tag_valid.
Qed.
Lemma of_val_to_val_refine_unflatten_flatten Γ Γm x w τ :
  ✓ Γ → (Γ,Γm) ⊢ w : τ →
  ctree_Forall (not ∘ sep_unmapped) w → ctree_Forall sep_unshared w →
  of_val Γ (tagged_perm <$> ctree_flatten w) (to_val Γ w)
    ⊑{Γ,true@Γm} ctree_unflatten Γ τ (ctree_flatten w) : τ.
Proof.
  intros. erewrite ctree_unflatten_flatten by eauto.
  apply (ctree_refine_compose _ true true meminj_id meminj_id Γm Γm) with w;
    eauto using of_val_to_val_refine, union_reset_above, ctree_refine_id.
Qed.
Lemma val_freeze_refine_l Γ Γm v τ :
  ✓ Γ → (Γ,Γm) ⊢ v : τ → val_map (freeze true) v ⊑{Γ,true@Γm} v : τ.
Proof.
  intros ?. revert v τ. refine (val_typed_ind _ _ _ _ _ _ _ _); simpl.
  * intros. refine_constructor; eauto using base_val_freeze_refine_l.
  * intros vs τ _ IH ?. refine_constructor; eauto. elim IH; csimpl; auto.
  * intros s vs τs ? _ IH. refine_constructor; eauto.
    elim IH; constructor; auto.
  * intros. refine_constructor; eauto.
  * intros s vs τs ? _ IH ?.
    refine_constructor; eauto using vals_representable_freeze.
    elim IH; constructor; auto.
Qed.
Lemma val_lookup_seg_refine Γ α f Γm1 Γm2 v1 v2 τ rs v3 :
  ✓ Γ → v1 ⊑{Γ,α,f@Γm1↦Γm2} v2 : τ → v1 !! rs = Some v3 →
  ∃ v4, v2 !! rs = Some v4 ∧ v3 ⊑{Γ,α,f@Γm1↦Γm2} v4 : type_of v3.
Proof.
  intros ?. revert v1 v2 τ. refine (val_refine_ind _ _ _ _ _ _ _ _ _ _ _ _).
  * by destruct rs.
  * intros τ n vs1 vs2 <- ? _ ??; destruct rs; simplify_option_equality
      by eauto using Forall2_length; decompose_Forall_hyps.
    erewrite val_refine_type_of_l by eauto; eauto.
  * intros s τs vs1 vs2 ?? _ ?; destruct rs; simplify_option_equality.
    decompose_Forall_hyps. erewrite val_refine_type_of_l by eauto; eauto.
  * intros s τs i v1 v2 τ ??? _ ?; destruct rs; simplify_option_equality.
    erewrite val_refine_type_of_l by eauto; eauto.
  * intros s τs vs1 vs2 ?? _ _ _ ?; destruct rs; simplify_option_equality.
    decompose_Forall_hyps. erewrite val_refine_type_of_l by eauto; eauto.
  * intros s τs i v1 v2 τ vs2 ????? _ _ ?; destruct rs; simplify_option_equality.
    decompose_Forall_hyps. erewrite val_refine_type_of_l by eauto; eauto.
Qed.
Lemma val_lookup_seg_refine_alt Γ α f Γm1 Γm2 v1 v2 τ rs v3 σ :
  ✓ Γ → v1 ⊑{Γ,α,f@Γm1↦Γm2} v2 : τ → v1 !! rs = Some v3 →
  Γ ⊢ rs : τ ↣ σ → ∃ v4, v2 !! rs = Some v4 ∧ v3 ⊑{Γ,α,f@Γm1↦Γm2} v4 : σ.
Proof.
  intros. assert ((Γ,Γm1) ⊢ v3 : σ)
    by eauto using val_lookup_seg_typed, val_refine_typed_l.
  destruct (val_lookup_seg_refine Γ α f Γm1 Γm2 v1 v2 τ rs v3) as (v4&?&?); auto.
  simplify_type_equality'; eauto.
Qed.
Lemma val_lookup_refine Γ α f Γm1 Γm2 v1 v2 τ r v3 :
  ✓ Γ → v1 ⊑{Γ,α,f@Γm1↦Γm2} v2 : τ → v1 !! r = Some v3 →
  ∃ v4, v2 !! r = Some v4 ∧ v3 ⊑{Γ,α,f@Γm1↦Γm2} v4 : type_of v3.
Proof.
  intros ?. revert v1 v2 τ. induction r as [|rs r IH] using rev_ind; simpl.
  { intros v1 v2 τ ??; simplify_type_equality'. exists v2.
    by erewrite val_refine_type_of_l by eauto. }
  intros v1 v2 τ. rewrite !val_lookup_snoc; intros; simplify_option_equality.
  edestruct (val_lookup_seg_refine Γ α f Γm1 Γm2 v1 v2 τ rs) as [? [??]];
    simplify_option_equality; eauto.
Qed.
Lemma val_lookup_is_Some_refine Γ α f Γm1 Γm2 v1 v2 τ r :
  ✓ Γ → v1 ⊑{Γ,α,f@Γm1↦Γm2} v2 : τ → is_Some (v1 !! r) → is_Some (v2 !! r).
Proof.
  intros ?? [v3 ?].
  destruct (val_lookup_refine Γ α f Γm1 Γm2 v1 v2 τ r v3) as (?&?&?); eauto.
Qed.
Lemma val_alter_seg_refine Γ α f Γm1 Γm2 g1 g2 v1 v2 τ rs v3 v4 :
  ✓ Γ → v1 ⊑{Γ,α,f@Γm1↦Γm2} v2 : τ → v1 !! rs = Some v3 → v2 !! rs = Some v4 →
  g1 v3 ⊑{Γ,α,f@Γm1↦Γm2} g2 v4 : type_of v3 →
  val_alter_seg g1 rs v1 ⊑{Γ,α,f@Γm1↦Γm2} val_alter_seg g2 rs v2 : τ.
Proof.
  destruct 2, rs;
    change (val_refine' Γ α f Γm1 Γm2) with (refineT Γ α f Γm1 Γm2) in *; intros;
    simplify_option_equality; decompose_Forall_hyps;
    repeat match goal with
    | H : _ ⊑{_,_,_@_↦_} _ : type_of _ |- _ =>
       erewrite val_refine_type_of_l in H by eauto
    end; refine_constructor; eauto using alter_length.
  * apply Forall2_alter; naive_solver.
  * apply Forall3_alter_lm; naive_solver.
Qed.
Lemma val_alter_refine Γ α f Γm1 Γm2 g1 g2 v1 v2 τ r v3 v4 :
  ✓ Γ → v1 ⊑{Γ,α,f@Γm1↦Γm2} v2 : τ → v1 !! r = Some v3 → v2 !! r = Some v4 →
  g1 v3 ⊑{Γ,α,f@Γm1↦Γm2} g2 v4 : type_of v3 →
  val_alter g1 r v1 ⊑{Γ,α,f@Γm1↦Γm2} val_alter g2 r v2 : τ.
Proof.
  intros ?. revert g1 g2 v1 v2 τ.
  induction r as [|rs r IH] using rev_ind; simpl; intros g1 g2 v1 v2 τ.
  { rewrite !val_lookup_nil; intros ???; simplify_equality.
    erewrite val_refine_type_of_l by eauto; eauto. }
  rewrite !val_lookup_snoc, !val_alter_snoc; intros.
  destruct (v1 !! rs) as [v1'|] eqn:?; simplify_equality'.
  destruct (v2 !! rs) as [v2'|] eqn:?; simplify_equality'.
  destruct (val_lookup_seg_refine Γ α f Γm1 Γm2 v1 v2 τ rs v1')
    as (?&?&?); auto; simplify_equality'; eauto using val_alter_seg_refine.
Qed.
Lemma ctree_alter_const_refine Γ α f Γm1 Γm2 v1 v2 τ r v3 v4 σ :
  ✓ Γ → v1 ⊑{Γ,α,f@Γm1↦Γm2} v2 : τ → Γ ⊢ r : τ ↣ σ → is_Some (v1 !! r) →
  v3 ⊑{Γ,α,f@Γm1↦Γm2} v4 : σ →
  val_alter (λ _, v3) r v1 ⊑{Γ,α,f@Γm1↦Γm2} val_alter (λ _, v4) r v2 : τ.
Proof.
  intros ??? [v3' ?] ?.
  destruct (val_lookup_refine Γ α f Γm1 Γm2 v1 v2 τ r v3') as (v4'&?&?); auto.
  eapply val_alter_refine; eauto. by erewrite (type_of_correct _ _ σ)
    by eauto using val_lookup_typed, val_refine_typed_l.
Qed.
End values.