## SELinux ?

- Contrôle d'accès obligatoire\footnote{Mandatory Access Control (MAC)}, module de sécurité Linux \footnote{Linux Security Module (LSM)}
- "iptables pour des processus" (politique, restriction d'accès, etc.)
- Contextes avec des étiquettes, types, roles, niveaux, classes, contraintes, etc.

\pause

- Code:
    * noyau (Linux: security/selinux/)
    * utilisateur (libsepol, libselinux, setools, etc.)

- Compilateurs de politiques : des parseurs en C !
    * source .te/.if/.fc ou .cil
    * formats binaires .mod, .pp, policy
    * checkpolicy, checkmodule, semodule, secilc, hll/pp, secil2conf, etc.

## Vérifications ?

- Tests de non-régression\footnote{Tests} (make test)
- Drapeaux d'attention\footnote{Warning flags} (-Wall -Wextra -Werror -Wformat=2)
- Compilateur pédant\footnote{clang -Weverything}
- Analyseur statique\footnote{scan-build} (LLVM scan-build)
- Désinfectants du compilateur\footnote{Sanitizers} (ASan, UBSan, etc.)
- Frelatage\footnote{Fuzzing} (American Fuzzy Lop)

## Drapeaux d'attention

2014 :

seusers_local.c: In function 'semanage_seuser_modify_local':
seusers_local.c:122:6: error: 'rc' may be used uninitialized in this
function [-Werror=maybe-uninitialized]

\pause

```c
int semanage_seuser_modify_local(/*...*/) {
  /* ... */
  if (semanage_seuser_clone(handle, data, &new) < 0) {
    goto err;
  }
  /* ... */
err:
  return rc;
}
```

## Quelques bogues trouvés et corrigés récemment

Saurez-vous trouver les bogues\footnote{bugs} dans les extraits suivants ?

## Trouvez le bogue (1)

```c
int semanage_get_active_modules(/* ... */) {
    /* ... */
cleanup:
  semanage_list_destroy(&list);
  for (i = 0; i < all_modinfos_len; i++)
    semanage_module_info_destroy(sh, &all_modinfos[i]);

  free(all_modinfos);
  if (status != 0) {
    for (i = 0; i < j; j++) {
      semanage_module_info_destroy(sh, &(*modinfo)[i]);
    }
    free(*modinfo);
  }
  return status;
}
```

## Trouvez le bogue (1)

Janvier 2017 (merci clang)

```diff
--- a/libsemanage/src/semanage_store.c
+++ b/libsemanage/src/semanage_store.c
@@ -1158,7 +1158,7 @@ cleanup:
   free(all_modinfos);

   if (status != 0) {
-    for (i = 0; i < j; j++) {
+    for (i = 0; i < j; i++) {
       semanage_module_info_destroy(
         sh, &(*modinfo)[i]);
     }
     free(*modinfo);
```

## Trouvez le bogue (2)

```C
int role_set_expand(role_set_t * x, ebitmap_t * r,
    policydb_t * out, policydb_t * base,
    uint32_t * rolemap) {
  unsigned int i;
  policydb_t *p = out;

  ebitmap_init(r);

  if (x->flags & ROLE_STAR) {
    for (i = 0; i < p->p_roles.nprim++; i++)
      if (ebitmap_set_bit(r, i, 1))
        return -1;
    return 0;
  }
  /* ... */
```

## Trouvez le bogue (2)

Novembre 2016 (merci American Fuzzy Lop)

```diff
--- a/libsepol/src/expand.c
+++ b/libsepol/src/expand.c
@@ -2424,7 +2424,7 @@
     ebitmap_init(r);

     if (x->flags & ROLE_STAR) {
-      for (i = 0; i < p->p_roles.nprim++; i++)
+      for (i = 0; i < p->p_roles.nprim; i++)
         if (ebitmap_set_bit(r, i, 1))
           return -1;
        return 0;
```

## Trouvez le bogue (3)

```
int avrule_ioctl_ranges(
    struct av_ioctl_range_list **rangelist) {
  struct av_ioctl_range_list *rangehead;
  uint8_t omit;
  /* read in ranges to include and omit */
  if (avrule_read_ioctls(&rangehead))
    return -1;
  omit = rangehead->omit;
  if (rangehead == NULL) {
    yyerror("error processing ioctl commands");
    return -1;
  }
  /* sort and merge the input ioctls */
  if (avrule_sort_ioctls(&rangehead))
    return -1;
````

## Trouvez le bogue (3)

Mars 2017

```diff
--- a/checkpolicy/policy_define.c
+++ b/checkpolicy/policy_define.c
@@ -1924,11 +1924,11 @@
   /* read in ranges to include and omit */
   if (avrule_read_ioctls(&rangehead))
     return -1;
-  omit = rangehead->omit;
   if (rangehead == NULL) {
     yyerror("error processing ioctl commands");
     return -1;
   }
+  omit = rangehead->omit;
   /* sort and merge the input ioctls */
   if (avrule_sort_ioctls(&rangehead))
     return -1;
```

## Exécution de pointeur NULL !

Novembre 2016

```diff
--- a/libsepol/src/module_to_cil.c
+++ b/libsepol/src/module_to_cil.c
@@ -3530,6 +3530,9 @@
   struct avrule_decl *decl = stack_peek(decl_stack);

   for (args.sym_index = 0; args.sym_index < SYM_NUM;
        args.sym_index++) {
+    if (func_to_cil[args.sym_index] == NULL) {
+      continue;
+    }
     rc = hashtab_map(decl->symtab[args.sym_index].table,
             additive_scopes_to_cil_map, &args);
     if (rc != 0) {
       goto exit;
```

## LLVM scan-build (Clang Static Analyze)

https://cloud.iooss.fr/vrac/rump2017.html#EndPath

\begin{figure}
\includegraphics[width=.8\textwidth]{scan-build-cil.png}
\end{figure}

## Et aussi...

- Utilisation après libération\footnote{Use after free}, libération double\footnote{Double free}, etc.
- Fuites de mémoire allouée\footnote{Memory leaks}
- ...

## Conclusion

SELinux est génial pour tester des outils d'analyse de code !\footnote{SELinux is great!}
