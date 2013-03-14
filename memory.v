(* Copyright (c) 2012-2013, Robbert Krebbers. *)
(* This file is distributed under the terms of the BSD license. *)
(** The concrete memory model is obtained by instantiating the abstract memory
model with our most expressive implementation of permissions. *)

Require Export permissions values abstract_memory.

Notation mem := (mem_ int memperm).

Hint Resolve Freeable_fragment : simpl_mem.
Hint Resolve Writable_fragment : simpl_mem.
Hint Resolve ReadOnly_fragment : simpl_mem.
