(* Copyright (c) 2012-2014, Robbert Krebbers. *)
(* This file is distributed under the terms of the BSD license. *)
(** This file defines expressions and some associated theory. Most importantly,
to define the operational semantics in the file [smallstep], we define
corresponding evaluation contexts. Notations for expressions are declared in the
scope [expr_scope]. *)
Require Import nmap mapset natmap.
Require Export values contexts.

(** * Function names *)
(** We use the type [N] of binary natural numbers for function names, and the
implementation [Nmap] for efficient finite maps over function names. *)
Definition funname := N.
Definition funmap := Nmap.
Notation funset := (mapset funmap).

Instance funname_eq_dec: ∀ i1 i2: funname, Decision (i1 = i2) := decide_rel (=).
Instance funname_fresh `{FinCollection funname C} : Fresh funname C := _.
Instance funname_fresh_spec `{FinCollection funname C} :
  FreshSpec funname C := _.

Instance funmap_dec {A} `{∀ a1 a2 : A, Decision (a1 = a2)} :
  ∀ m1 m2 : funmap A, Decision (m1 = m2) := decide_rel (=).
Instance funmap_empty {A} : Empty (funmap A) := @empty (Nmap A) _.
Instance funmap_lookup {A} : Lookup funname A (funmap A) :=
  @lookup _ _ (Nmap A) _.
Instance funmap_partial_alter {A} : PartialAlter funname A (funmap A) :=
  @partial_alter _ _ (Nmap A) _.
Instance funmap_to_list {A} : FinMapToList funname A (funmap A) :=
  @map_to_list _ _ (funmap A) _.
Instance funmap_omap: OMap funmap := λ A B f, @omap Nmap _ _ f _.
Instance funmap_merge : Merge funmap := @merge Nmap _.
Instance funmap_fmap: FMap funmap := λ A B f, @fmap Nmap _ _ f _.
Instance: FinMap funname funmap := _.

Instance funmap_dom {A} : Dom (funmap A) funset := mapset_dom.
Instance: FinMapDom funname funmap funset := mapset_dom_spec.

Typeclasses Opaque funname funmap.

Class Funs A := funs : A → funset.
Arguments funs {_ _} !_ / : simpl nomatch.

(** * Stacks *)
(** Stacks are lists of memory indexes rather than lists of values. This allows
us to treat pointers to both automatically and dynamically allocated memory in
a uniform way. Evaluation of a variable will therefore consist of a looking up
its address in the stack and returning a pointer to that address. *)

Notation stack := (list index) (only parsing).
Class Vars A := vars: A → natset.
Arguments vars {_ _} !_ / : simpl nomatch.

(** * Syntax *)
(** The variables used in expressions are De Bruijn indexes, i.e. the variable
[var i] refers to the [i]th value on the stack. De Bruijn indexes avoid us
having to deal with shadowing due to block scope variables. Especially in
the axiomatic semantics this is useful, as we do not want to lose information
because a local variable may shadow an already existing one. *)

(** Values are annotated with a set of locked locations. Initially, all values
in a program should be annotated with the empty set. Whenever a write occurs
during the execution of the program, the written location is locked in memory,
and added to the set of locked locations in the subexpression where that write
occurred. On the execution of a connective that contains a sequence point, the
annotated locations in the subexpression where the sequence point occurred are
unlocked in memory and then discarded. Connectives without a sequence point
just take the union of the locked locations of their children. *)

(** This way of dealing with sequence points is more restrictive than the
treatment by (Norrish, PhD thesis) and (Ellison/Rosu, 2012), as whenever a
sequence point occurs, we only unlock the locations that have been locked by
evaluating the sub-expression corresponding to that particular sequence point,
instead of unlocking all locations. *)
Inductive assign :=
  | Assign (**i ordinary assignment *)
  | PreOp : binop → assign (**i assignment operators and prefix increment,
     decrement, etc. *)
  | PostOp : binop → assign (**i postfix increment, decrement, etc. *).

Inductive expr (Ti : Set) :=
  | EVar : type Ti → nat → expr Ti
  | EVal : lockset → val Ti → expr Ti
  | EAddr : lockset → addr Ti → expr Ti
  | ERtoL : expr Ti → expr Ti
  | ERofL : expr Ti → expr Ti
  | EAssign : assign → expr Ti → expr Ti → expr Ti
  | ECall : funname → list (expr Ti) → expr Ti
  | ELoad : expr Ti → expr Ti
  | EAlloc : type Ti → expr Ti
  | EFree : expr Ti → expr Ti
  | EUnOp : unop → expr Ti → expr Ti
  | EBinOp : binop → expr Ti → expr Ti → expr Ti
  | EIf : expr Ti → expr Ti → expr Ti → expr Ti
  | EComma : expr Ti → expr Ti → expr Ti
  | ECast : type Ti → expr Ti → expr Ti
  | EField : expr Ti → nat → expr Ti.

(** We use the scope [expr_scope] to declare notations for expressions. We
overload some notations already in [value_scope], and define both general and
specific notations for operations, allowing us for example to to write
[intc 10 + intc 20] instead of the much longer
[valc (intc 10) ⊙{PlusOp} valc (intc 20)]. *)
Delimit Scope expr_scope with E.
Bind Scope expr_scope with expr.

Arguments EVar {_} _ _.
Arguments EVal {_} _ _.
Arguments EAddr {_} _ _.
Arguments ERtoL {_} _%expr_scope.
Arguments ERofL {_} _%expr_scope.
Arguments EAssign {_} _ _%expr_scope _%expr_scope.
Arguments ECall {_} _%N _%expr_scope.
Arguments ELoad {_} _%expr_scope.
Arguments EAlloc {_} _.
Arguments EFree {_} _%expr_scope.
Arguments EUnOp {_} _ _%expr_scope.
Arguments EBinOp {_} _ _%expr_scope _%expr_scope.
Arguments EIf {_} _%expr_scope _%expr_scope _%expr_scope.
Arguments EComma {_} _%expr_scope _%expr_scope.
Arguments ECast {_} _ _%expr_scope.
Arguments EField {_} _%expr_scope _.

Notation "'var{' τ } x" := (EVar τ x)
  (at level 10, format "var{ τ }  x") : expr_scope.
Notation "#{ Ω } v" := (EVal Ω v)
  (at level 10, format "#{ Ω }  v") : expr_scope.
Notation "#{ Ωs }* vs" := (zip_with EVal Ωs vs)
  (at level 10, format "#{ Ωs }*  vs") : expr_scope.
Notation "# v" := (EVal ∅ v) (at level 10) : expr_scope.
Notation "%{ Ω } v" := (EAddr Ω v)
  (at level 10, format "%{ Ω }  v") : expr_scope.
Notation "% v" := (EAddr ∅ v) (at level 10) : expr_scope.
Notation ".* e" := (ERtoL e) (at level 10) : expr_scope.
Notation "& e" := (ERofL e) (at level 10) : expr_scope.
Notation "e1 ::={ ass } e2" := (EAssign ass e1 e2)
  (at level 60, format "e1  ::={ ass }  e2", right associativity) : expr_scope.
Infix "::=" := (EAssign Assign) (at level 60, right associativity) : expr_scope.
(* The infixes [++] and [::] are at level 60, [<$>] at 65. *)
Notation "'call' f @ es" := (ECall f es)
  (at level 10, es at level 66) : expr_scope.
Notation "'load' e" := (ELoad e) (at level 10) : expr_scope.
Notation "'alloc' τ" := (EAlloc τ) (at level 10) : expr_scope.
Notation "'free' e" := (EFree e) (at level 10) : expr_scope.
Notation "@{ op } e" := (EUnOp op e)
  (at level 21, format "@{ op }  e") : expr_scope.
Notation "e1 @{ op } e2" := (EBinOp op e1 e2)
  (at level 50, format "e1  @{ op }  e2") : expr_scope.
Notation "'IF' e1 'then' e2 'else' e3" := (EIf e1 e2 e3) : expr_scope.
Notation "'cast{' τ } e" := (ECast τ e)
  (at level 10, format "'cast{' τ }  e") : expr_scope.
Notation "e1 ,, e2" := (EComma e1 e2)
  (at level 55, right associativity, format "e1  ,,  e2") : expr_scope.
Notation "e .> i" := (EField e i) (at level 60) : expr_scope.

Infix "+" := (EBinOp PlusOp) : expr_scope.
Infix "-" := (EBinOp MinusOp) : expr_scope.
Infix "*" := (EBinOp MultOp) : expr_scope.
Infix "/" := (EBinOp DivOp) : expr_scope.
Infix "≤" := (EBinOp LeOp) : expr_scope.
Infix "<" := (EBinOp LtOp) : expr_scope.
Infix "=" := (EBinOp EqOp) : expr_scope.
Notation "- e" := (EUnOp NegOp e) : expr_scope.

Instance: Injective2 (=) (=) (=) (@EVar Ti).
Proof. by injection 1. Qed.
Instance: Injective2 (=) (=) (=) (@EVal Ti).
Proof. by injection 1. Qed.
Instance: Injective2 (=) (=) (=) (@EAddr Ti).
Proof. by injection 1. Qed.
Instance: Injective (=) (=) (@ELoad Ti).
Proof. by injection 1. Qed.
Instance: Injective (=) (=) (@EFree Ti).
Proof. by injection 1. Qed.

Instance assign_eq_dec: ∀ ass1 ass2 : assign, Decision (ass1 = ass2).
Proof. solve_decision. Defined.
Instance expr_eq_dec {Ti : Set} `{∀ k1 k2 : Ti, Decision (k1 = k2)} :
  ∀ e1 e2 : expr Ti, Decision (e1 = e2).
Proof.
  refine (fix go e1 e2 : Decision (e1 = e2) :=
  match e1, e2 with
  | var{τ1} i1, var{τ2} i2 =>
     cast_if_and (decide_rel (=) i1 i2) (decide_rel (=) τ1 τ2)
  | #{Ω1} v1, #{Ω2} v2 =>
     cast_if_and (decide_rel (=) Ω1 Ω2) (decide_rel (=) v1 v2)
  | %{Ω1} a1, %{Ω2} a2 =>
     cast_if_and (decide_rel (=) Ω1 Ω2) (decide_rel (=) a1 a2)
  | .* e1, .* e2 | & e1, & e2 => cast_if (decide_rel (=) e1 e2)
  | e1 ::={ass1} e3, e2 ::={ass2} e4 =>
     cast_if_and3 (decide_rel (=) ass1 ass2) (decide_rel (=) e1 e2)
       (decide_rel (=) e3 e4)
  | call f1 @ es1, call f2 @ es2 => cast_if_and (decide_rel (=) f1 f2)
     (decide_rel (=) es1 es2)
  | load e1, load e2 => cast_if (decide_rel (=) e1 e2)
  | alloc τ1, alloc τ2 => cast_if (decide_rel (=) τ1 τ2)
  | free e1, free e2 => cast_if (decide_rel (=) e1 e2)
  | @{op1} e1, @{op2} e2 => cast_if_and (decide_rel (=) op1 op2)
     (decide_rel (=) e1 e2)
  | e1 @{op1} e3, e2 @{op2} e4 => cast_if_and3 (decide_rel (=) op1 op2)
     (decide_rel (=) e1 e2) (decide_rel (=) e3 e4)
  | (IF e1 then e3 else e5), (IF e2 then e4 else e6) =>
     cast_if_and3 (decide_rel (=) e1 e2)
       (decide_rel (=) e3 e4) (decide_rel (=) e5 e6)
  | e1,, e3, e2,, e4 =>
     cast_if_and (decide_rel (=) e1 e2) (decide_rel (=) e3 e4)
  | cast{τ1} e1, cast{τ2} e2 =>
     cast_if_and (decide_rel (=) τ1 τ2) (decide_rel (=) e1 e2)
  | e1 .> i1, e2 .> i2 =>
     cast_if_and (decide_rel (=) e1 e2) (decide_rel (=) i1 i2)
  | _, _ => right _
  end%E); clear go; abstract congruence.
Defined.

(*
(** The sequenced [||] and [&&] operators are defined in terms of the
conditional. This keeps the expression language small. *)
Definition EAnd {Ti} (e1 e2 : expr Ti) := (IF e1 then e2 else intc int_false)%E.
Infix "&&" := EAnd : expr_scope.
Definition EOr (e1 e2 : expr) := (IF e1 then intc int_true else e2)%E.
Infix "||" := EOr : expr_scope.
*)

(** * Induction principles *)
(** The induction principles that Coq generates for nested inductive types are
too weak. For the case of expressions, the branch of [call f @ es] does not
contain an induction hypothesis for the function arguments [es]. We therefore
define an appropriate induction principle for expressions by hand. *)
Section expr_ind.
  Context {Ti} (P : expr Ti → Prop).
  Context (Pvar : ∀ τ x, P (var{τ} x)).
  Context (Pval : ∀ Ω v, P (#{Ω} v)).
  Context (Paddr : ∀ Ω a, P (%{Ω} a)).
  Context (Prtol : ∀ e, P e → P (.* e)).
  Context (Profl : ∀ e, P e → P (& e)).
  Context (Passign : ∀ ass e1 e2, P e1 → P e2 → P (e1 ::={ ass } e2)).
  Context (Pcall : ∀ f es, Forall P es → P (call f @ es)).
  Context (Pload : ∀ e, P e → P (load e)).
  Context (Palloc : ∀ τ, P (alloc τ)).
  Context (Pfree : ∀ e, P e → P (free e)).
  Context (Punop : ∀ op e, P e → P (@{op} e)).
  Context (Pbinop : ∀ op e1 e2, P e1 → P e2 → P (e1 @{op} e2)).
  Context (Pif : ∀ e1 e2 e3, P e1 → P e2 → P e3 → P (IF e1 then e2 else e3)).
  Context (Pcomma : ∀ e1 e2, P e1 → P e2 → P (e1 ,, e2)).
  Context (Pcast : ∀ τ e, P e → P (cast{τ} e)).
  Context (Pfield : ∀ e i, P e → P (e .> i)).
  Definition expr_ind_alt : ∀ e, P e :=
    fix go e : P e :=
    match e with
    | var{τ} x => Pvar τ x
    | #{Ω} v => Pval Ω v
    | %{Ω} a => Paddr Ω a
    | .* e => Prtol e (go e)
    | & e => Profl e (go e)
    | el ::={_} er => Passign _ _ _ (go el) (go er)
    | call f @ es => Pcall f es $ list_ind (Forall P)
       (Forall_nil_2 _) (λ e _, Forall_cons_2 _ _ _ (go e)) es
    | load e => Pload e (go e)
    | alloc _ => Palloc _
    | free e => Pfree e (go e)
    | @{op} e => Punop op _ (go e)
    | e1 @{op} e2 => Pbinop op _ _ (go e1) (go e2)
    | (IF e1 then e2 else e3) => Pif _ _ _ (go e1) (go e2) (go e3)
    | e1,, e2 => Pcomma _ _ (go e1) (go e2)
    | cast{τ} e => Pcast _ _ (go e)
    | e .> i => Pfield e i (go e)
    end%E.
End expr_ind.

(** We also define [size e] giving the number of nodes in an expression. This
measure can be used for well-founded induction on expressions. *)
Instance expr_size {Ti} : Size (expr Ti) :=
  fix go e : nat := let _ : Size _ := go in
  match e with
  | var{_} _ | #{_} _ | %{_} _ => 0
  | .* e | & e => S (size e)
  | e1 ::={_} e2 => S (size e1 + size e2)
  | call _ @ es => S (sum_list_with size es)
  | load e => S (size e)
  | alloc _ => 0
  | free e | @{_} e => S (size e)
  | e1 @{_} e2 => S (size e1 + size e2)
  | (IF e1 then e2 else e3) => S (size e1 + size e2 + size e3)
  | e1,, e2 => S (size e1 + size e2)
  | cast{_} e | e .> _ => S (go e)
  end%E.
Lemma expr_wf_ind {Ti} (P : expr Ti → Prop)
  (Pind : ∀ e, (∀ e', size e' < size e → P e') → P e) : ∀ e, P e.
Proof.
  assert (∀ n e, size e < n → P e) as help by (induction n; auto with lia).
  intros e. apply (help (S (size e))); lia.
Qed.

(** * Miscellaneous Operations and properties *)
(** An expression is [load_free] if it does not contain any occurrences of the
[load] operator. *)
Inductive load_free {Ti} : expr Ti → Prop :=
  | EVar_load_free τ x : load_free (var{τ} x)
  | EVal_load_free Ω v : load_free (#{Ω} v)
  | EAddr_load_free Ω a : load_free (%{Ω} a)
  | ERtoL_load_free e : load_free e → load_free (.* e)
  | ERofL_load_free e : load_free e → load_free (& e)
  | EAssign_load_free ass e1 e2 :
     load_free e1 → load_free e2 → load_free (e1 ::={ass} e2)
  | ECall_load_free f es : Forall load_free es → load_free (call f @ es)
  | EAlloc_load_free τ : load_free (alloc τ)
  | EFree_load_free e : load_free e → load_free (free e)
  | EUnOp_load_free op e : load_free e → load_free (@{op} e)
  | EBinOp_load_free op e1 e2 :
     load_free e1 → load_free e2 → load_free (e1 @{op} e2)
  | EIf_load_free e1 e2 e3 :
     load_free e1 → load_free e2 → load_free e3 →
     load_free (IF e1 then e2 else e3)
  | EComma_load_free e1 e2 :
     load_free e1 → load_free e2 → load_free (e1,, e2)
  | ECast_load_free τ e : load_free e → load_free (cast{τ} e)
  | EField_load_free e i : load_free e → load_free (e .> i).

Section load_free_ind.
  Context {Ti} (P : expr Ti → Prop).
  Context (Pvar : ∀ τ x, P (var{τ} x)).
  Context (Pval : ∀ Ω v, P (#{Ω} v)).
  Context (Paddr : ∀ Ω a, P (%{Ω} a)).
  Context (Prtol : ∀ e, load_free e → P e → P (.* e)).
  Context (Profl : ∀ e, load_free e → P e → P (& e)).
  Context (Passign : ∀ ass e1 e2,
    load_free e1 → P e1 → load_free e2 → P e2 → P (e1 ::={ass} e2)).
  Context (Pcall : ∀ f es, Forall load_free es → Forall P es → P (call f @ es)).
  Context (Palloc : ∀ τ, P (alloc τ)).
  Context (Pfree : ∀ e, load_free e → P e → P (free e)).
  Context (Punop : ∀ op e, load_free e → P e → P (@{op} e)).
  Context (Pbinop : ∀ op e1 e2,
    load_free e1 → P e1 → load_free e2 → P e2 → P (e1 @{op} e2)).
  Context (Pif : ∀ e1 e2 e3,
    load_free e1 → P e1 → load_free e2 → P e2 → load_free e3 → P e3 →
    P (IF e1 then e2 else e3)).
  Context (Pcomma : ∀ e1 e2,
    load_free e1 → P e1 → load_free e2 → P e2 → P (e1,, e2)).
  Context (Pcast : ∀ τ e, load_free e → P e → P (cast{τ} e)).
  Context (Pfield : ∀ e i, load_free e → P e → P (e .> i)).
  Lemma load_free_ind_alt: ∀ e, load_free e → P e.
  Proof. fix 2; destruct 1; eauto using Forall_impl. Qed.
End load_free_ind.

Instance load_free_dec {Ti} : ∀ e : expr Ti, Decision (load_free e).
Proof.
 refine (
  fix go e :=
  match e return Decision (load_free e) with
  | var{_} _ | #{_} _ | %{_} _ => left _
  | .* e | & e => cast_if (decide (load_free e))
  | e1 ::={_} e2 => cast_if_and (decide (load_free e1)) (decide (load_free e2))
  | call f @ es => cast_if (decide (Forall load_free es))
  | load e => right _
  | alloc _ => left _
  | free e => cast_if (decide (load_free e))
  | @{op} e => cast_if (decide (load_free e))
  | e1 @{op} e2 => cast_if_and (decide (load_free e1)) (decide (load_free e2))
  | (IF e1 then e2 else e3) => cast_if_and3 (decide (load_free e1))
      (decide (load_free e2)) (decide (load_free e3))
  | e1,, e2 => cast_if_and (decide (load_free e1)) (decide (load_free e2))
  | cast{_} e => cast_if (decide (load_free e))
  | e .> _ => cast_if (decide (load_free e))
  end%E); first [by constructor | by inversion 1].
Defined.

Instance expr_vars {Ti} : Vars (expr Ti) :=
  fix go e := let _ : Vars _ := @go in
  match e with
  | var{_} n => {[ n ]}
  | #{_} _ | %{_} _ => ∅
  | .* e | & e => vars e
  | e1 ::={_} e2 => vars e1 ∪ vars e2
  | call _ @ es => ⋃ (vars <$> es)
  | alloc _ => ∅
  | load e | free e | @{_} e => vars e
  | e1 @{_} e2 => vars e1 ∪ vars e2
  | (IF e1 then e2 else e3) => vars e1 ∪ vars e2 ∪ vars e3
  | e1,, e2 => vars e1 ∪ vars e2
  | cast{_} e | e .> _ => vars e
  end%E.
Instance expr_funs {Ti} : Funs (expr Ti) :=
  fix go e := let _ : Funs _ := @go in
  match e with
  | var{_} _ | #{_} _ | %{_} _ => ∅
  | .* e | & e => funs e
  | e1 ::={_} e2 => funs e1 ∪ funs e2
  | call f @ es => {[ f ]} ∪ ⋃ (funs <$> es)
  | alloc _ => ∅
  | load e | free e | @{_} e => funs e
  | e1 @{_} e2 => funs e1 ∪ funs e2
  | (IF e1 then e2 else e3) => funs e1 ∪ funs e2 ∪ funs e3
  | e1,, e2 => funs e1 ∪ funs e2
  | cast{_} e | e .> _ => funs e
  end%E.

Hint Extern 1 (load_free _) => assumption : typeclass_instances.
Hint Extern 100 (load_free ?e) =>
  apply (bool_decide_unpack _); vm_compute; exact I : typeclass_instances.
Hint Extern 1 (vars _ = ∅) => assumption : typeclass_instances.
Hint Extern 100 (vars _ = ∅) =>
  apply (bool_decide_unpack _); vm_compute; exact I : typeclass_instances.

(** In order to model sequence points, we have to keep track of sets of
locations that cannot be written to or read from. We call such locations locked,
and define a type class [Locks] to collect locks in various data structures. *)
Class Locks A := locks: A → lockset.
Arguments locks {_ _} !_ / : simpl nomatch.

Instance list_locks `{Locks A} : Locks (list A) :=
  fix go (l : list A) : lockset := let _ : Locks _ := @go in
  match l with [] => ∅ | a :: l => locks a ∪ locks l end.

Lemma locks_nil `{Locks A} : locks [] = ∅.
Proof. done. Qed.
Lemma locks_app `{Locks A} (l1 l2 : list A) :
  locks (l1 ++ l2) = locks l1 ∪ locks l2.
Proof. apply elem_of_equiv_L. induction l1; esolve_elem_of. Qed.
Lemma locks_snoc `{Locks A} (l1 : list A) a :
  locks (l1 ++ [a]) = locks l1 ∪ locks a.
Proof. rewrite locks_app. simpl. by rewrite (right_id_L ∅ (∪)). Qed.

Instance expr_locks {Ti} : Locks (expr Ti) :=
  fix go e : lockset := let _ : Locks _ := @go in
  match e with
  | var{_} _ => ∅
  | #{Ω} _ | %{Ω} _ => Ω
  | .* e | & e => locks e
  | e1 ::={_} e2 => locks e1 ∪ locks e2
  | call _ @ es => ⋃ (locks <$> es)
  | alloc _ => ∅
  | load e | free e | @{_} e => locks e
  | e1 @{_} e2 => locks e1 ∪ locks e2
  | (IF e1 then e2 else e3) => locks e1 ∪ locks e2 ∪ locks e3
  | e1,, e2 => locks e1 ∪ locks e2
  | cast{_} e | e .> _ => locks e
  end%E.

(** An expression is pure (or side-effect free) if it does not modify the
memory. Although these expressions may have sequence points (namely at the
conditional and at calls to pure functions), these sequence points are not
observable, as pure expressions do not allow any locations to get locked in
the first place. The predicate is parametrized by a set [fs] of names of pure
functions. The denotational semantics for pure expressions in the file
[expression_eval] uses a map from function names to denotations to deal with
pure function calls. *)
Inductive is_pure {Ti} (fs : funset) : (expr Ti) → Prop :=
  | EVar_pure τ x : is_pure fs (var{τ} x)
  | EVal_pure v : is_pure fs (# v)
  | EAddr_pure a : is_pure fs (% a)
  | ERtoL_pure e : is_pure fs e → is_pure fs (.* e)
  | ERofL_pure e : is_pure fs e → is_pure fs (& e)
  | ECall_pure f es : f ∈ fs → Forall (is_pure fs) es → is_pure fs (call f @ es)
  | EUnOp_pure op e : is_pure fs e → is_pure fs (@{op} e)
  | EBinOp_pure op e1 e2 :
     is_pure fs e1 → is_pure fs e2 → is_pure fs (e1 @{op} e2)
  | EIf_pure e el er :
     is_pure fs e → is_pure fs el → is_pure fs er →
     is_pure fs (IF e then el else er)
  | EComma_pure el er :
     is_pure fs el → is_pure fs er → is_pure fs (el,, er)
  | ECast_pure τ e : is_pure fs e → is_pure fs (cast{τ} e)
  | EField_pure e i : is_pure fs e → is_pure fs (e .> i).

Section is_pure_ind.
  Context {Ti} (fs : funset) (P : expr Ti → Prop).
  Context (Pvar : ∀ τ x, P (var{τ} x)).
  Context (Pval : ∀ v, P (# v)).
  Context (Paddr : ∀ a, P (% a)).
  Context (Prtol : ∀ e, is_pure fs e → P e → P (.* e)).
  Context (Profl : ∀ e, is_pure fs e → P e → P (& e)).
  Context (Pcall : ∀ f es,
    f ∈ fs → Forall (is_pure fs) es → Forall P es → P (call f @ es)).
  Context (Punop : ∀ op e, is_pure fs e → P e → P (@{op} e)).
  Context (Pbinop : ∀ op e1 e2,
    is_pure fs e1 → P e1 → is_pure fs e2 → P e2 → P (e1 @{op} e2)).
  Context (Pif : ∀ e1 e2 e3,
    is_pure fs e1 → P e1 → is_pure fs e2 → P e2 → is_pure fs e3 → P e3 →
    P (IF e1 then e2 else e3)).
  Context (Pcomma : ∀ e1 e2,
    is_pure fs e1 → P e1 → is_pure fs e2 → P e2 → P (e1,, e2)).
  Context (Pcast : ∀ τ e, is_pure fs e → P e → P (cast{τ} e)).
  Context (Pfield : ∀ e i, is_pure fs e → P e → P (e .> i)).
  Definition is_pure_ind_alt: ∀ e, is_pure fs e → P e.
  Proof. fix 2; destruct 1; eauto using Forall_impl. Qed.
End is_pure_ind.

Instance is_pure_dec {Ti} fs : ∀ e : expr Ti, Decision (is_pure fs e).
Proof.
 refine (
  fix go e :=
  match e return Decision (is_pure fs e) with
  | var{_} x => left _
  | #{Ω} _ | %{Ω} _ => cast_if (decide (Ω = ∅))
  | .* e | & e => cast_if (decide (is_pure fs e))
  | call f @ es =>
     cast_if_and (decide (f ∈ fs)) (decide (Forall (is_pure fs) es))
  | @{op} e => cast_if (decide (is_pure fs e))
  | e1 @{op} e2 => cast_if_and (decide (is_pure fs e1)) (decide (is_pure fs e2))
  | (IF e1 then e2 else e3) => cast_if_and3 (decide (is_pure fs e1))
      (decide (is_pure fs e2)) (decide (is_pure fs e3))
  | e1,, e2 => cast_if_and (decide (is_pure fs e1)) (decide (is_pure fs e2))
  | cast{_} e => cast_if (decide (is_pure fs e))
  | e .> _ => cast_if (decide (is_pure fs e))
  | _ => right _
  end%E);
  clear go; first [by subst; constructor | abstract by inversion 1; subst].
Defined.
Lemma is_pure_locks {Ti} fs (e : expr Ti) : is_pure fs e → locks e = ∅.
Proof.
  assert (∀ (es : list (expr Ti)) oi,
    Forall (λ e, oi ∉ locks e) es → oi ∉ ⋃ (locks <$> es)).
  { induction 1; esolve_elem_of. }
  intros He. apply elem_of_equiv_empty_L. intros oi.
  induction He using @is_pure_ind_alt; esolve_elem_of.
Qed.

(** The operation [e↑] increases all De Bruijn indexes of variables in [e]
by one. That means, each variable [var x] in [e] becomes [var (S x)]. *)
Reserved Notation "e ↑" (at level 20, format "e ↑").
Fixpoint expr_lift {Ti} (e : expr Ti) : expr Ti :=
  match e with
  | var{τ} x => var{τ} (S x)
  | #{Ω} v => #{Ω} v
  | %{Ω} a => %{Ω} a
  | .* e => .* (e↑)
  | & e => & (e↑)
  | e1 ::={ass} e2 => e1↑ ::={ass} e2↑
  | call f @ es => call f @ expr_lift <$> es
  | load e => load (e↑)
  | alloc τ => alloc τ
  | free e => free (e↑)
  | @{op} e => @{op} e↑
  | e1 @{op} e2 => e1↑ @{op} e2↑
  | (IF e1 then e2 else e3) => IF e1↑ then e2↑ else e3↑
  | e1,, e2 => e1↑,, e2↑
  | e .> i => e↑ .> i
  | cast{τ} e => cast{τ} (e↑)
  end%E
where "e ↑" := (expr_lift e) : expr_scope.

(** The predicate [is_nf e] states that [e] is in normal form and [is_redex e]
states that [e] is a head redex with respect to the semantics in the file
[smallstep]. *)
Inductive is_nf {Ti} : expr Ti → Prop :=
  | EVal_nf Ω v : is_nf (#{Ω} v)
  | EAddr_nf Ω a : is_nf (%{Ω} a).
Inductive is_redex {Ti} : expr Ti → Prop :=
  | EVar_redex τ x : is_redex (var{τ} x)
  | ERtoL_redex e : is_nf e → is_redex (.* e)
  | ERofL_redex e : is_nf e → is_redex (& e)
  | EAssign_redex ass e1 e2 :
     is_nf e1 → is_nf e2 → is_redex (e1 ::={ass} e2)
  | ECall_redex f es : Forall is_nf es → is_redex (call f @ es)
  | ELoad_redex e : is_nf e → is_redex (load e)
  | EAlloc_redex τ : is_redex (alloc τ)
  | EFree_redex e : is_nf e → is_redex (free e)
  | EUnOp_redex op e : is_nf e → is_redex (@{op} e)
  | EBinOp_redex op e1 e2 :
     is_nf e1 → is_nf e2 → is_redex (e1 @{op} e2)
  | EIf_redex e1 e2 e3 : is_nf e1 → is_redex (IF e1 then e2 else e3)
  | EComma_redex e1 e2 : is_nf e1 → is_redex (e1,, e2)
  | ECast_redex τ e : is_nf e → is_redex (cast{τ} e)
  | EField_redex e i : is_nf e → is_redex (e .> i).

Instance is_nf_dec {Ti} (e : expr Ti) : Decision (is_nf e).
Proof.
 refine (match e with #{_} _ | %{_} _ => left _ | _ => right _ end%E);
  try constructor; abstract (inversion 1).
Defined.
Instance is_redex_dec {Ti} (e : expr Ti) : Decision (is_redex e).
Proof.
 refine (
  match e with
  | var{_} _ => left _
  | .* e => cast_if (decide (is_nf e))
  | & e => cast_if (decide (is_nf e))
  | e1 ::={_} e2 => cast_if_and (decide (is_nf e1)) (decide (is_nf e2))
  | call _ @ es => cast_if (decide (Forall is_nf es))
  | load e => cast_if (decide (is_nf e))
  | alloc _ => left _
  | free e | @{_} e => cast_if (decide (is_nf e))
  | e1 @{_} e2 => cast_if_and (decide (is_nf e1)) (decide (is_nf e2))
  | (IF e then _ else _) => cast_if (decide (is_nf e))
  | e1 ,, e2 => cast_if (decide (is_nf e1))
  | cast{_} e => cast_if (decide (is_nf e))
  | e .> _ => cast_if (decide (is_nf e))
  | _ => right _
  end%E); first [by constructor | abstract (by inversion 1)].
Defined.

Lemma is_redex_nf {Ti} (e : expr Ti) : is_redex e → is_nf e → False.
Proof. destruct 1; inversion 1. Qed.
Lemma EVal_not_redex {Ti} Ω (v : val Ti) : ¬is_redex (#{Ω} v).
Proof. inversion 1. Qed.
Lemma EVals_nf {Ti} Ωs (vs : list (val Ti)) : Forall is_nf (#{Ωs}* vs)%E.
Proof. revert vs. induction Ωs; intros [|??]; repeat constructor; auto. Qed.
Lemma EVals_nf_alt {Ti} es Ωs (vs : list (val Ti)) :
  es = (#{Ωs}* vs)%E → Forall is_nf es.
Proof. intros ->. by apply EVals_nf. Qed.

Definition maybe_EVal {Ti} (e : expr Ti) : option (lockset * val Ti) :=
  match e with #{Ω} v => Some (Ω,v) | _ => None end%E.
Definition maybe_ECall {Ti} (e : expr Ti) : option (funname * list (expr Ti)) :=
  match e with call f @ es => Some (f,es) | _ => None end%E.
Definition maybe_CCall_redex {Ti} (e : expr Ti) :
    option (funname * list lockset * list (val Ti)) :=
  '(f,es) ← maybe_ECall e;
  vΩs ← mapM maybe_EVal es;
  Some (f, fst <$> vΩs, snd <$> vΩs).

Lemma maybe_EVal_Some {Ti} (e : expr Ti) Ω v :
  maybe_EVal e = Some (Ω, v) ↔ e = (#{Ω} v)%E.
Proof. split. by destruct e; intros; simplify_equality'. by intros ->. Qed.
Lemma maybe_ECall_Some {Ti} (e : expr Ti) f es :
  maybe_ECall e = Some (f, es) ↔ e = (call f @ es)%E.
Proof. split. by destruct e; intros; simplify_equality'. by intros ->. Qed.
Lemma maybe_CCall_redex_Some {Ti} (e : expr Ti) f Ωs vs :
  maybe_CCall_redex e = Some (f, Ωs, vs) ↔
    e = (call f @ zip_with EVal Ωs vs)%E ∧ length Ωs = length vs.
Proof.
  unfold maybe_CCall_redex. split; [intros|intros [-> ?]; simpl].
  * destruct (maybe_ECall e) as [[f' es]|] eqn:?; simplify_option_equality.
    rewrite !fmap_length; split; auto.
    apply maybe_ECall_Some. rewrite zip_with_fst_snd.
    erewrite <-(mapM_fmap_Some_inv maybe_EVal (curry EVal)); eauto.
    by intros [??] [] ?; simplify_equality'.
  * rewrite zip_with_zip, mapM_fmap_Some by (by intros []); simpl.
    by rewrite fst_zip, snd_zip by lia.
Qed.

(** * Contexts with one hole *)
(** We define singular expression contexts [ectx_item], and then full expression
(evaluation) contexts [ectx] are lists of expression contexts. These expression
contexts allow us to enforce an evaluation strategy. In particular, for the
conditional we merely allow a hole for the first branch. *)
Inductive ectx_item (Ti : Set) :=
  | CRtoL : ectx_item Ti
  | CLtoR : ectx_item Ti
  | CAssignL : assign → expr Ti → ectx_item Ti
  | CAssignR : assign → expr Ti → ectx_item Ti
  | CCall : funname → list (expr Ti) → list (expr Ti) → ectx_item Ti
  | CLoad : ectx_item Ti
  | CFree : ectx_item Ti
  | CUnOp : unop → ectx_item Ti
  | CBinOpL : binop → expr Ti → ectx_item Ti
  | CBinOpR : binop → expr Ti → ectx_item Ti
  | CIf : expr Ti → expr Ti → ectx_item Ti
  | CComma : expr Ti → ectx_item Ti
  | CCast : type Ti → ectx_item Ti
  | CField : nat → ectx_item Ti.
Notation ectx Ti := (list (ectx_item Ti)).

Bind Scope expr_scope with ectx_item.

Arguments CRtoL {_}.
Arguments CLtoR {_}.
Arguments CAssignL {_} _ _.
Arguments CAssignR {_} _ _.
Arguments CCall {_} _ _ _.
Arguments CLoad {_}.
Arguments CFree {_}.
Arguments CUnOp {_} _.
Arguments CBinOpL {_} _ _.
Arguments CBinOpR {_}_ _.
Arguments CIf {_} _ _.
Arguments CComma {_} _.
Arguments CCast {_} _.
Arguments CField {_} _.

Notation ".* □" := CRtoL (at level 10, format ".*  □") : expr_scope.
Notation "& □" := CLtoR (at level 10, format "&  □") : expr_scope.
Notation "□ ::={ ass } e2" := (CAssignL ass e2)
  (at level 60, format "□  ::={ ass }  e2") : expr_scope.
Notation "e1 ::={ ass } □" := (CAssignR ass e1)
  (at level 60, format "e1  ::={ ass }  □") : expr_scope.
Notation "'call' f @ es1 □ es2" := (CCall f es1 es2)
  (at level 10, es1 at level 66, es2 at level 66) : expr_scope.
Notation "'load' □" := CLoad (at level 10, format "load  □") : expr_scope.
Notation "'free' □" := CFree (at level 10, format "free  □") : expr_scope.
Notation "@{ op } □" := (CUnOp op)
  (at level 21, format "@{ op } □") : expr_scope.
Notation "□ @{ op } e2" := (CBinOpL op e2)
  (at level 50, format "□  @{ op }  e2") : expr_scope.
Notation "e1 @{ op } □" := (CBinOpR op e1)
  (at level 50, format "e1  @{ op }  □") : expr_scope.
Notation "'IF' □ 'then' e2 'else' e3" := (CIf e2 e3)
  (at level 200, format "'IF'  □  'then'  e2  'else'  e3") : expr_scope.
Notation "□ ,, e2" := (CComma e2) (at level 55, format "□  ,,  e2") : expr_scope.
Notation "'cast{' τ } □" := (CCast τ)
  (at level 10, format "'cast{' τ }  □") : expr_scope.
Notation "□ .> i" := (CField i)
  (at level 10, format "□ .> i") : expr_scope.

Instance ectx_item_dec {Ti : Set} `{∀ k1 k2 : Ti, Decision (k1 = k2)} :
  ∀ Ei1 Ei2 : ectx_item Ti, Decision (Ei1 = Ei2).
Proof. solve_decision. Defined.

(** Substitution is defined in a straightforward way. Using the type class
instances in the file [contexts], it is lifted to full expression contexts. *)
Instance ectx_item_subst {Ti} : Subst (ectx_item Ti) (expr Ti) (expr Ti) := λ Ei e,
  match Ei with
  | .* □ => .* e
  | & □ => & e
  | □ ::={ass} er => e ::={ass} er
  | el ::={ass} □ => el ::={ass} e
  | call f @ es1 □ es2 => call f @ (reverse es1 ++ e :: es2)
  | load □ => load e
  | free □ => free e
  | @{op} □ => @{op} e
  | □ @{op} er => e @{op} er
  | el @{op} □ => el @{op} e
  | □,, er => e ,, er
  | (IF □ then el else er) => IF e then el else er
  | cast{τ} □ => cast{τ} e
  | □ .> i => e .> i
  end%E.
Instance: DestructSubst (@ectx_item_subst Ti).

Instance: ∀ Ei : ectx_item Ti, Injective (=) (=) (subst Ei).
Proof. by destruct Ei; intros ???; simplify_list_equality. Qed.

Lemma is_nf_ectx_item {Ti} (Ei : ectx_item Ti) e : ¬is_nf (subst Ei e).
Proof. destruct Ei; inversion 1. Qed.
Lemma is_nf_ectx {Ti} (E : ectx Ti) e : is_nf (subst E e) → E = [].
Proof.
  destruct E using rev_ind; auto.
  rewrite subst_snoc. intros; edestruct @is_nf_ectx_item; eauto.
Qed.
Lemma is_nf_redex_ectx {Ti} (E : ectx Ti) e : is_redex e → ¬is_nf (subst E e).
Proof.
  intros ? HEe. rewrite (is_nf_ectx E e) in HEe by done; simpl in HEe.
  eauto using is_redex_nf.
Qed.
Lemma is_redex_ectx_item {Ti} (Ei : ectx_item Ti) e : is_redex (subst Ei e) → is_nf e.
Proof. destruct Ei; inversion 1; decompose_Forall_hyps'; auto. Qed.
Lemma is_redex_ectx {Ti} (E : ectx Ti) e :
  is_redex (subst E e) → (E = [] ∧ is_redex e) ∨ (∃ Ei, E = [Ei] ∧ is_nf e).
Proof.
  destruct E as [|Ei E _] using rev_ind; [eauto|]; rewrite subst_snoc; intros HE.
  feed pose proof (is_redex_ectx_item Ei (subst E e)); auto.
  feed pose proof (is_nf_ectx E e); subst; simpl in *; eauto.
Qed.

Instance ectx_locks {Ti} : Locks (ectx_item Ti) := λ Ei,
  match Ei with
  | .* □ | & □ => ∅
  | □ ::={_} e2 => locks e2
  | e1 ::={_} □ => locks e1
  | call f @ es1 □ es2 => ⋃ (locks <$> es1) ∪ ⋃ (locks <$> es2)
  | load □ | free □ | @{_} □ => ∅
  | □ @{op} e2 => locks e2
  | e1 @{op} □ => locks e1
  | (IF □ then e2 else e3) => locks e2 ∪ locks e3
  | □,, e2 => locks e2
  | cast{_} □ | □ .> _ => ∅
  end%E.

Lemma ectx_item_is_pure {Ti} fs (Ei : ectx_item Ti) (e : expr Ti) :
  is_pure fs (subst Ei e) → is_pure fs e.
Proof. destruct Ei; simpl; inversion_clear 1; decompose_Forall; eauto. Qed.
Lemma ectx_is_pure {Ti} fs (E : ectx Ti) (e : expr Ti) :
  is_pure fs (subst E e) → is_pure fs e.
Proof.
  induction E using rev_ind; rewrite ?subst_snoc; eauto using ectx_item_is_pure.
Qed.
Lemma ectx_item_subst_locks {Ti} (Ei : ectx_item Ti) e :
  locks (subst Ei e) = locks Ei ∪ locks e.
Proof.
  apply elem_of_equiv_L. intro. destruct Ei; simpl; try solve_elem_of.
  rewrite fmap_app, fmap_reverse; simpl.
  rewrite union_list_app_L, union_list_cons, union_list_reverse_L.
  solve_elem_of.
Qed.
Lemma ectx_subst_locks {Ti} (E : ectx Ti) e :
  locks (subst E e) = locks E ∪ locks e.
Proof.
  apply elem_of_equiv_L. intros. revert e. induction E as [|Ei E IH]; simpl.
  * solve_elem_of.
  * intros. rewrite IH, ectx_item_subst_locks. solve_elem_of.
Qed.

(** The induction principle [ectx_expr_ind] is used to perform simultaneous
induction on an expression [e] and context [E]. Although a similar result can
be obtained by generalizing over [E] before doing the induction on [e], this
induction principle is more useful together with automation. Automation now
does not have to instantiate the induction hypothesis with the appropriate
context. *)
Section ectx_expr_ind.
  Context {Ti} (P : ectx Ti → expr Ti → Prop).
  Context (Pvar : ∀ E τ x, P E (var{τ} x)).
  Context (Pval : ∀ E Ω v, P E (#{Ω} v)).
  Context (Paddr : ∀ E Ω a, P E (%{Ω} a)).
  Context (Prtol : ∀ E e, P ((.* □)%E :: E) e → P E (.* e)).
  Context (Profl : ∀ E e, P ((& □)%E :: E) e → P E (& e)).
  Context (Passign : ∀ E ass e1 e2,
    P ((□ ::={ass} e2)%E :: E) e1 → P ((e1 ::={ass} □)%E :: E) e2 →
    P E (e1 ::={ass} e2)).
  Context (Pcall : ∀ E f es,
    zipped_Forall (λ esl esr, P ((call f @ esl □ esr)%E :: E)) [] es →
    P E (call f @ es)).
  Context (Pload : ∀ E e, P ((load □)%E :: E) e → P E (load e)).
  Context (Palloc : ∀ E τ, P E (alloc τ)).
  Context (Pfree : ∀ E e, P ((free □)%E :: E) e → P E (free e)).
  Context (Punop : ∀ E op e, P ((@{op} □)%E :: E) e → P E (@{op} e)).
  Context (Pbinop : ∀ E op e1 e2,
    P ((□ @{op} e2)%E :: E) e1 → P ((e1 @{op} □)%E :: E) e2 →
    P E (e1 @{op} e2)).
  Context (Pif : ∀ E e1 e2 e3,
    P ((IF □ then e2 else e3)%E :: E) e1 → P E (IF e1 then e2 else e3)).
  Context (Pcomma : ∀ E e1 e2, P ((□,, e2)%E :: E) e1 → P E (e1,, e2)).
  Context (Pcast : ∀ E τ e, P ((cast{τ} □)%E :: E) e → P E (cast{τ} e)).
  Context (Pfield : ∀ E e i, P ((□ .> i)%E :: E) e → P E (e .> i)).

  Definition ectx_expr_ind : ∀ E e, P E e :=
    fix go E e : P E e :=
    match e with
    | var{_} x => Pvar _ _ x
    | #{_} v => Pval _ _ v
    | %{_} a => Paddr _ _ a
    | .* e => Prtol _ _ (go _ e)
    | & e => Profl _ _ (go _ e)
    | e1 ::={_} e2 => Passign _ _ _ _ (go _ e1) (go _ e2)
    | call f @ es => Pcall E f es $
       zipped_list_ind _ zipped_Forall_nil
        (λ _ _ e, @zipped_Forall_cons _ (λ _ _, P _) _ _ _ (go _ e)) [] es
    | load e => Pload _ _ (go _ e)
    | alloc _ => Palloc _ _
    | free e => Pfree _ _ (go _ e)
    | @{_} e => Punop _ _ _ (go _ e)
    | e1 @{_} e2 => Pbinop _ _ _ _ (go _ e1) (go _ e2)
    | (IF e1 then _ else _) => Pif _ _ _ _ (go _ e1)
    | e1,, _ => Pcomma _ _ _ (go _ e1)
    | cast{τ} e => Pcast _ _ _ (go _ e)
    | e .> i => Pfield _ _ _ (go _ e)
    end%E.
End ectx_expr_ind.

Ltac ectx_expr_ind E e :=
  repeat match goal with
  | H : context [ E ] |- _ => revert H | H : context [ e ] |- _ => revert H
  end; revert E e;
  match goal with |- ∀ E e, @?P E e => apply (ectx_expr_ind P) end.

(** * Contexts with multiple holes *)
(** We define singular expression contexts indexed by the number of holes. These
contexts are particularly useful to prove some of the Hoare rules in a more
generic way. *)
Inductive ectx_full (Ti : Set) : nat → Type :=
  | DCVar : type Ti → nat → ectx_full Ti 0
  | DCVal : lockset → val Ti → ectx_full Ti 0
  | DCAddr : lockset → addr Ti → ectx_full Ti 0
  | DCRtoL : ectx_full Ti 1
  | DCLtoR : ectx_full Ti 1
  | DCAssign : assign → ectx_full Ti 2
  | DCCall {n} : funname → ectx_full Ti n
  | DCLoad : ectx_full Ti 1
  | DCAlloc : type Ti → ectx_full Ti 0
  | DCFree : ectx_full Ti 1
  | DCUnOp : unop → ectx_full Ti 1
  | DCBinOp : binop → ectx_full Ti 2
  | DCIf : expr Ti → expr Ti → ectx_full Ti 1
  | DCComma : expr Ti → ectx_full Ti 1
  | DCCast : type Ti → ectx_full Ti 1
  | DCField : nat → ectx_full Ti 1.

Arguments DCVar {_} _ _.
Arguments DCVal {_} _ _.
Arguments DCAddr {_} _ _.
Arguments DCRtoL {_}.
Arguments DCLtoR {_}.
Arguments DCAssign {_} _.
Arguments DCCall {_ _} _.
Arguments DCLoad {_}.
Arguments DCAlloc {_} _.
Arguments DCFree {_}.
Arguments DCUnOp {_} _.
Arguments DCBinOp {_} _.
Arguments DCIf {_}_ _.
Arguments DCComma {_} _.
Arguments DCCast {_} _.
Arguments DCField {_} _.

Instance ectx_full_subst {Ti} :
    DepSubst (ectx_full Ti) (vec (expr Ti)) (expr Ti) := λ _ E,
  match E with
  | DCVar τ x => λ _, var{τ} x
  | DCVal Ω v => λ _, #{Ω} v
  | DCAddr Ω a => λ _, %{Ω} a
  | DCRtoL => λ es, .* (es !!! 0)
  | DCLtoR =>λ es, & (es !!! 0)
  | DCAssign ass => λ es, es !!! 0 ::={ass} es !!! 1
  | DCCall _ f => λ es, call f @ es
  | DCLoad => λ es, load (es !!! 0)
  | DCAlloc τ => λ _, alloc τ
  | DCFree => λ es, free (es !!! 0)
  | DCUnOp op => λ es, @{op} es !!! 0
  | DCBinOp op => λ es, es !!! 0 @{op} es !!! 1
  | DCIf e2 e3 => λ es, IF es !!! 0 then e2 else e3
  | DCComma e2 => λ es, es !!! 0,, e2
  | DCCast τ => λ es, cast{τ} (es !!! 0)
  | DCField i => λ es, es !!! 0 .> i
  end%E.
Instance ectx_full_locks {Ti n} : Locks (ectx_full Ti n) := λ E,
  match E with
  | DCVal Ω _ | DCAddr Ω _ => Ω
  | DCIf el er => locks el ∪ locks er
  | DCComma er => locks er
  | _ => ∅
  end%E.

Lemma ectx_full_subst_inj {Ti n} (E : ectx_full Ti n) es1 es2 :
  depsubst E es1 = depsubst E es2 → es1 = es2.
Proof.
  destruct E; inv_all_vec_fin; simpl; intros; simplify_equality;
    auto using vec_to_list_inj2.
Qed.
Lemma ectx_full_subst_locks {Ti n} (E : ectx_full Ti n) (es : vec (expr Ti) n) :
  locks (depsubst E es) = locks E ∪ ⋃ (locks <$> vec_to_list es).
Proof.
  apply elem_of_equiv_L. intro. destruct E; inv_all_vec_fin; solve_elem_of.
Qed.

(** Giving values [es] for the holes of the context [E], the function
[ectx_full_to_item E es i] yields a context with exactly one hole for the
[i]th value. The [i]th value in [es] is ignored. *)
Definition ectx_full_to_item {Ti n} (E : ectx_full Ti n)
    (es : vec (expr Ti) n) (i : fin n) : ectx_item Ti :=
  match E in ectx_full _ n return fin n → vec (expr Ti) n → ectx_item Ti with
  | DCVar _ _  | DCVal _ _ | DCAddr _ _ => fin_0_inv _
  | DCRtoL => fin_S_inv _ (λ _, .* □)%E $ fin_0_inv _
  | DCLtoR => fin_S_inv _ (λ _, & □)%E $ fin_0_inv _
  | DCAssign ass =>
     fin_S_inv _ (λ es, □ ::={ass} es !!! 1)%E $
     fin_S_inv _ (λ es, es !!! 0 ::={ass} □)%E $ fin_0_inv _
  | DCCall _ f => λ i es, (call f @ reverse (take i es) □ drop (FS i) es)%E
  | DCLoad => fin_S_inv _ (λ _, load □)%E $ fin_0_inv _
  | DCAlloc _ => fin_0_inv _
  | DCFree => fin_S_inv _ (λ _, free □)%E $ fin_0_inv _
  | DCUnOp op => fin_S_inv _ (λ _, @{op} □)%E $ fin_0_inv _
  | DCBinOp op =>
     fin_S_inv _ (λ es, □ @{op} es !!! 1)%E $
     fin_S_inv _ (λ es, es !!! 0 @{op} □)%E $ fin_0_inv _
  | DCIf e2 e3 => fin_S_inv _ (λ _, IF □ then e2 else e3)%E $ fin_0_inv _
  | DCComma e2 => fin_S_inv _ (λ _, □,, e2)%E $ fin_0_inv _
  | DCCast τ => fin_S_inv _ (λ _, cast{τ} □)%E $ fin_0_inv _
  | DCField i => fin_S_inv _ (λ _, □ .> i)%E $ fin_0_inv _
  end i es.

Lemma ectx_full_to_item_insert {Ti n} (E : ectx_full Ti n) es i e :
  ectx_full_to_item E (vinsert i e es) i = ectx_full_to_item E es i.
Proof.
  destruct E; inv_all_vec_fin; simpl; try reflexivity.
  rewrite !vec_to_list_insert, take_insert, drop_insert; auto with arith.
Qed.
Lemma ectx_full_to_item_correct {Ti n} (E : ectx_full Ti n) es i :
  depsubst E es = subst (ectx_full_to_item E es i) (es !!! i).
Proof.
  destruct E; inv_all_vec_fin; simpl; try reflexivity.
  by rewrite reverse_involutive, <-vec_to_list_take_drop_lookup.
Qed.
Lemma ectx_full_to_item_correct_alt {Ti n} (E : ectx_full Ti n) es i e :
  depsubst E (vinsert i e es) = subst (ectx_full_to_item E es i) e.
Proof.
  rewrite (ectx_full_to_item_correct _ _ i).
  by rewrite vlookup_insert, ectx_full_to_item_insert.
Qed.
Lemma ectx_full_item_subst {Ti n} (E : ectx_full Ti n) (es : vec _ n)
    (Ei : ectx_item Ti) (e : expr Ti) :
  depsubst E es = subst Ei e →
    ∃ i, e = es !!! i ∧ Ei = ectx_full_to_item E es i.
Proof.
  intros H. destruct E, Ei; simpl; simplify_equality; eauto.
  edestruct (vec_to_list_lookup_middle es) as (i&H1&?&H2); eauto.
  exists i. subst. by rewrite <-H1, reverse_involutive.
Qed.
(*
Lemma Forall_is_nf_alt_vec {Ti n} (es : vec (expr Ti) n) :
  Forall is_nf es ↔ ∃ Ωs vs, es = vzip_with EVal Ωs vs.
Proof.
  rewrite Forall_is_nf_alt. split.
  * intros (Ωs & vs & Hes & Hvs). revert n es Hes.
    rewrite <-Forall2_same_length in Hvs.
    induction Hvs as [|?????? IH]; intros ? [|???] ?; simplify_equality'; auto.
    { by eexists [#], [#]. }
    edestruct IH as (?&?&?); eauto. subst.
    eexists (_ ::: _), (_ ::: _); simpl; eauto.
  * intros (Ωs & vs & Hes). exists Ωs vs. split.
    + by rewrite Hes, vec_to_list_zip_with.
    + apply vec_to_list_same_length.
Qed.
Lemma expr_vec_values {Ti n} (es : vec (expr Ti) n) :
  (∃ Ωs vs, es = vzip_with EVal Ωs vs) ∨ (∃ i, ¬is_nf (es !!! i)).
Proof.
  destruct (Forall_Exists_dec (λ e, decide (is_nf e)) es) as [H | H].
  * left. by apply Forall_is_nf_alt_vec.
  * right. by apply Exists_vlookup in H.
Qed.
*)
Lemma is_redex_ectx_full {Ti n} (E : ectx_full Ti n) (es : vec _ n) :
  is_redex (depsubst E es) → Forall is_nf es.
Proof.
  destruct E; inversion_clear 1; inv_all_vec_fin; repeat constructor; auto.
Qed.
Lemma ectx_full_to_item_locks {Ti n} (E : ectx_full Ti n) (es : vec _ n) i :
  locks (ectx_full_to_item E es i) =
    locks E ∪ ⋃ (locks <$> delete (fin_to_nat i) (vec_to_list es)).
Proof.
  apply elem_of_equiv_L. intros b.
  destruct E; inv_all_vec_fin; simpl; try esolve_elem_of.
  rewrite fmap_reverse, union_list_reverse.
  rewrite delete_take_drop, fmap_app, union_list_app. esolve_elem_of.
Qed.

(** The function [expr_redexes e] computes the set of redexes contained in an
expression [e]. Here, redexes are pairs [(E', e')] where [E'] is an expression
evaluation context, and [e'] an expression with [is_redex e']. *)
Section expr_split.
  Context {Ti} C `{Collection (ectx Ti * expr Ti) C}.

  Definition expr_redexes_go : ectx Ti → expr Ti → C :=
    fix go E e {struct e} :=
    if decide (is_redex e) then {[ (E, e) ]} else
    match e with
    | var{_} x => ∅ (* impossible *)
    | #{_} _ | %{_} _ => ∅
    | .* e => go (.* □ :: E) e
    | & e => go (& □ :: E) e
    | e1 ::={ass} e2 => go (□ ::={ass} e2 :: E) e1 ∪ go (e1 ::={ass} □ :: E) e2
    | call f @ es =>
       ⋃ zipped_map (λ esl esr, go ((call f @ esl □ esr) :: E)) [] es
    | load e => go (load □ :: E) e
    | alloc _ => ∅ (* impossible *)
    | free e => go (free □ :: E) e
    | @{op} e => go (@{op} □ :: E) e
    | e1 @{op} e2 => go (□ @{op} e2 :: E) e1 ∪ go (e1 @{op} □ :: E) e2
    | (IF e1 then e2 else e3) => go ((IF □ then e2 else e3) :: E) e1
    | e1 ,, e2 => go ((□,, e2) :: E) e1
    | cast{τ} e => go ((cast{τ} □) :: E) e
    | e .> i => go (□ .> i :: E) e
    end%E.
  Definition expr_redexes : expr Ti → C := expr_redexes_go [].

  Lemma expr_redexes_go_is_redex E e E' e' :
    (E', e') ∈ expr_redexes_go E e → is_redex e'.
  Proof.
    assert (∀ (f : list _ → list _ → expr Ti → C) es,
      (E', e') ∈ ⋃ zipped_map f [] es →
      zipped_Forall (λ esl esr e, (E', e') ∈ f esl esr e → is_redex e') [] es →
      is_redex e').
    { intros f es Hes Hforall.
      rewrite elem_of_union_list in Hes. destruct Hes as (rs&Hes&?).
      rewrite elem_of_zipped_map in Hes. destruct Hes as (?&?&?&?&?); subst.
      apply zipped_Forall_app in Hforall. inversion Hforall; subst. auto. }
    ectx_expr_ind E e;
     simpl; intros; repeat case_decide; solve_elem_of (eauto; try constructor).
  Qed.
  Lemma expr_redexes_go_sound E e E' e' :
    (E', e') ∈ expr_redexes_go E e → subst E e = subst E' e'.
  Proof.
    assert (∀ g (f : list _ → list _ → expr Ti → C) (E : ectx Ti) es,
      (E', e') ∈ ⋃ zipped_map f [] es →
      zipped_Forall (λ esl esr e, (E', e') ∈ f esl esr e →
        subst E (g (reverse esl ++ [e] ++ esr)) = subst E' e') [] es →
      subst E (g es) = subst E' e').
    { intros ? g f es Hes Hforall.
      rewrite elem_of_union_list in Hes. destruct Hes as (rs&Hes&?).
      rewrite elem_of_zipped_map in Hes. destruct Hes as (esl&?&?&?&?); subst.
      apply zipped_Forall_app in Hforall. inversion Hforall; subst.
      rewrite <-(reverse_involutive esl), <-(right_id_L [] (++) (reverse esl)).
      auto. }
    ectx_expr_ind E e;
     simpl; intros; repeat case_decide; solve_elem_of eauto.
  Qed.
  Lemma expr_redexes_go_complete E' E e :
    is_redex e → (E ++ E', e) ∈ expr_redexes_go E' (subst E e).
  Proof.
    intros. revert E'. induction E as [|Ei E IH] using rev_ind; simpl.
    { intros. unfold expr_redexes_go. destruct e; case_decide; solve_elem_of. }
    intros E'. assert (¬is_redex (subst (E ++ [Ei]) e)) as Hredex.
    { intro. destruct (is_redex_ectx (E ++ [Ei]) e) as [[??]|(?&?&?)]; auto.
      discriminate_list_equality.
      eauto using is_redex_nf. }
    rewrite subst_snoc in Hredex |- *. rewrite <-(associative_L (++)).
    destruct Ei; simpl; case_decide; try solve_elem_of.
    rewrite elem_of_union_list. eexists (expr_redexes_go _ _).
    rewrite elem_of_zipped_map. split; eauto. eexists (reverse _), _, _.
    split. done. by rewrite reverse_involutive, (right_id_L [] (++)). 
  Qed.

  Lemma expr_redexes_is_redex e E' e' : (E', e') ∈ expr_redexes e → is_redex e'.
  Proof. apply expr_redexes_go_is_redex. Qed.
  Lemma expr_redexes_sound e E' e' :
    (E', e') ∈ expr_redexes e → e = subst E' e'.
  Proof. apply expr_redexes_go_sound. Qed.
  Lemma expr_redexes_complete E e :
    is_redex e → (E, e) ∈ expr_redexes (subst E e).
  Proof.
    generalize (expr_redexes_go_complete [] E e).
    by rewrite (right_id_L [] (++) E).
  Qed.
  Lemma expr_redexes_correct e E' e' :
    (E', e') ∈ expr_redexes e ↔ e = subst E' e' ∧ is_redex e'.
  Proof.
    split.
    * eauto using expr_redexes_sound, expr_redexes_is_redex.
    * by intros [??]; subst; apply expr_redexes_complete.
  Qed.

  Lemma expr_redexes_go_is_nf E e : expr_redexes_go E e ≡ ∅ → is_nf e.
  Proof.
    assert (∀ (f : list _ → list _ → expr Ti → C) es1 es2,
      ⋃ (zipped_map f es1 es2) ≡ ∅ →
      zipped_Forall (λ esl esr e, f esl esr e ≡ ∅ → is_nf e) es1 es2 →
      Forall is_nf es2).
    { intros ???. rewrite empty_union_list.
      induction 2; simpl in *; decompose_Forall; auto. }
    ectx_expr_ind E e;
      simpl; intros; repeat case_decide; decompose_empty;
      try match goal with
      | _ => by left; constructor
      | _ => by right; constructor
      | H : ¬is_redex _ |- _ => destruct H; constructor
      end; eauto.
  Qed.
  Lemma expr_redexes_is_nf e : expr_redexes e ≡ ∅ → is_nf e.
  Proof. apply expr_redexes_go_is_nf. Qed.
End expr_split.

Lemma is_nf_or_redex {Ti : Set} `{∀ k1 k2 : Ti, Decision (k1 = k2)} e :
  is_nf e ∨ ∃ (E' : ectx Ti) e', is_redex e' ∧ e = subst E' e'.
Proof.
  destruct (collection_choose_or_empty (expr_redexes
    (listset (ectx Ti * expr Ti)) e)) as [[[E' e'] ?]|?].
  * right. exists E' e'. split.
    + by apply (expr_redexes_is_redex (listset _)) with e E'. 
    + by apply (expr_redexes_correct (listset _)).
  * left. by apply (expr_redexes_is_nf (listset _)).
Qed.
Lemma is_nf_is_redex {Ti : Set} `{∀ k1 k2 : Ti, Decision (k1 = k2)} e :
  ¬is_nf e → ∃ (E' : ectx Ti) e', is_redex e' ∧ e = subst E' e'.
Proof. intros. by destruct (is_nf_or_redex e). Qed.