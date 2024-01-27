---
date: 2024-01-27
article_title: Design pattern typés - partie 1
article_description: Traduction en OCaml du papier "typed design pattern for functional era"
---

## Introduction

Il est, depuis un certain temps, obligatoire pour tout programmeur objet qui se respecte et qui écrit des programmes suffisamment longs de s’intéresser aux design patterns (ou motifs de conception). Il en existe une belle liste maintenant bien éprouvée et ils sont assez largement documentés sur internet, dans des livres… Mais qu’en est-il pour la programmation fonctionnelle statiquement typée ?

C’est une question que je me suis posée récemment, et aujourd’hui encore il n'existe à ma connaissance aucun équivalent du GOF, qui exposerait un ensemble de motifs de conception adressant plusieurs classes de problèmes en tirant parti à la fois des idiomes fonctionnels, mais également d’un système de types riche.

Dans ce contexte, j’ai apprécié la lecture du papier [Typed design pattern for functional era](https://arxiv.org/pdf/2307.07069.pdf) qui tente d'aborder une partie du sujet en présentant 4 problèmes plus ou moins généraux, et 4 solutions plus ou moins générales qui reposent sur l'encodage de garanties statiques via le systeme de type de Rust.

**Seul problème** : c’est écrit en **RUST**

Ne connaissant pas Rust, j'ai parfois eu beaucoup de mal à lire les implémentations. J'ai ensuite eu la forte intuition que ce serait plus lisible si c'était écrit dans un langage tout à fait sympathique que j'ai découvert récemment : **[OCaml](https://ocaml.org/)**

Je vous propose ici une série d'articles sur la traduction des exemples/problématiques du papier en OCaml. J'ai fait de mon mieux pour que lire le papier d'origine ne soit pas un prérequis pour comprendre ce que j'ai écrit. Il y a en tout 4 design patterns, et cette première salve d'articles traitera des 3 premiers. *(parce que j'ai toujours pas réussi a faire le dernier...)*

1. **Conditionner l'accès à une donnée par un témoin**.
2. **Encoder une machine à états sûre**.
3. **Un formatteur de chaîne de caractère**.


Voici comment ça va se passer : pour chaque cas, je vais d’abord expliquer le problème concret que l’on essaie de résoudre et en montrer une implémentation naïve. Puis, on va se poser et dresser la liste des manipulations de ce code qu'on veut absolument rendre illicites statiquement *(C’est tout l’intérêt du papier)*, et puis on déroulera un code satisfaisant au regard de cette liste.

Ok, **commençons !**

## Cas 1 : Witnessing

Une chose importante avant de commencer : je vais parfois parler d'un "utilisateur" dans cette partie. Étant donné qu'on va utiliser un programme web pour illustrer ce premier cas, il faut avoir en tête que je parle d'utilisateur développeur, donc d'un développeur qui va utiliser notre API, notre code, et non d'un utilisateur final qui va naviguer sur un logiciel ou utiliser l'API web hypothétique.

Vous n'avez qu'à imaginer que vous rejoignez une équipe de développeurs travaillant sur un site web avec une base de code déjà conséquente et, quand je parle de l'utilisateur, je parle de vous.

### Présentation du problème et solution naive

OK. Le premier cas est moralement quelque chose d’omniprésent dans la vie d’un développeur. On a des données, et on aimerait conditionner l’accès à un sous-ensemble de ces données. Le cas concret choisi dans l’article d'origine est l’accès à une page administrateur sur un site web.

La donnée à laquelle on aimerait accéder, c'est la page, et la condition, c’est « être un administrateur ».

Imaginons que le contexte de notre site web soit encodé de cette manière :

```ocaml=
type user = {name : string; is_admin : bool}
type context = {current_user: user}
exception Render404

(* Cette fonction créer un HTML qui composeras notre page *)
let render_admin_page () =
  let open Tyxml.Html in
  div [
    h1 [ txt ("Administration page") ] ]

```

J’imagine que tout de suite un réflexe serait d’écrire :

```ocaml=
let admin_page context =
  if context.current_user.is_admin then
    render_admin_page ()
  else
    raise Render404
```

Là, vous pourriez penser : "Yes, j'ai résolu le problème, la page admin ne sera affichée que si l'utilisateur est un admin. Que pourrait-il arriver de mal ?".

En fait, cette implémentation pose un gros problème : elle repose entièrement sur la bonne volonté de l'utilisateur à utiliser les fonctions dans le bon ordre. Effectivement, rien ne m'empêche d'écrire

```ocaml=

let main () =
 (*J'ai un contexte avec un utilisateur non administrateur*)
 let user = {name="gholad";is_admin=false}

 (*je peux m'en foutre et juste appeler la fonction*)
 render_admin_page ()

```
Oui, qu'est-ce qui m'oblige à utiliser `admin_page` ? Rien du tout. Il n'y a aucune correspondance entre l'information contenue dans notre contexte et l'utilisation de la fonction `render_admin_page`. Vous pourriez me dire : "Ok, eh bien pour faire correspondre les deux, on pourrait rajouter un if dans la fonction de rendu, et demander un contexte ou un utilisateur en paramètre !"

```ocaml=

let render_admin_page user =
  if user.is_admin then
    let open Tyxml.Html in
    div [
        h1 [ txt ("Administration page") ] ]
  else
    raise Render404

```
Oui, mais cette vérification additionnelle serait faite au.. **RUNTIME** [TINTINNNTINNNNNN](https://www.youtube.com/watch?v=9d_kO4cyHfk) (en gros, a l'éxécution du programme).

Et je pourrais donc écrire un programme valide qui viole notre objectif initial.

```ocaml=

let main () =
 (*J'ai un contexte avec un utilisateur non administrateur*)
 let user = {name="gholad";is_admin=false}

 (*je l'envoie, tout va compiler mais le programme va crash a l'execution :( *)
 render_admin_page user

```

Tout l'intérêt du papier d'origine et de cette série d'articles est de vous sensibiliser aux forces du *statique* dans "garanties *statiques*", en opposition à dynamique. On veut que les erreurs de manipulation de notre code soient détectées à la compilation, et que le programme en question soit rejeté. Et le typage est cet outil par lequel on va passer pour exprimer ces garanties statiques, et modéliser notre API de telle sorte qu'elle rende les manipulations problématiques tout simplement infaisables.

Et en cela, notre API guiderait l'utilisateur, par les types, à correctement l'utiliser.

### Construction d'une solution satisfaisante

Repartons du bon pied, et commençons par dresser la liste des garanties statiques que nous aimerions encoder :

- La fonction render_admin_page dois afficher la page que si c'est un admin qui le demande.
- Le statut d'administrateur ne peut pas etre crée a la volée, c'est une information qu'on peut récuperer sur un utilisateur.

À partir de cette liste, et en pensant "par les types", on va construire une nouvelle solution. Le premier point important : comme dit dans la liste, on veut contraindre la création et la manipulation de valeur "administrateur", donc pour commencer, on va distinguer les utilisateurs réguliers des administrateurs en rajoutant un type pour l'admin.

```ocaml
type user = (* pareil qu'en haut *)

type admin = Admin of user (* un admin est un utilisateur *)

```

Ensuite, on veut contraindre la creation d'un admin, la seule façon de faire seras de passer par une fonction `as_admin`, et notre fonction `render_admin_page` n'attendras désormais plus un utilisateur en parametre, mais directement un administrateur, voici le type de ces fonctions.

```ocaml=
(*
    Le type "t option" nous permet de représenter un calcul qui peut, ou non, renvoyer une    valeur de type t.

*)
let as_admin (u : user) : admin option =
    if u.is_admin then Some (Admin u) else None
    
let render_admin_page (Admin {name;_}) : html_document =
  let open Tyxml.Html in
  div [
    h1 [ txt ("Hello dear Administrator, " ^ name) ] ]
```

Ok, il semble qu'on ait rempli en partie le contrat : la fonction render_admin_page ne peut être appelée qu'avec une valeur de type administrateur, et on crée une valeur de type administrateur uniquement dans la fonction as_admin.

Cela dit, la bonne utilisation de notre API dépend toujours du bon vouloir de l'utilisateur, actuellement rien ne l'empêche de créer une valeur de type admin à la volée : 

```ocaml=
let main =
    (* Oui la valeur est meme incohérente, 
       is_admin étant egal a false, rien nous en empeche :(
    *)
    render_admin_page (Admin({name="leak",is_admin=false}))
```

Donc, pour rendre un admin uniquement constructible depuis la fonction as_admin, on doit également le rendre impossible à construire à la volée par l'utilisateur, et pour ça, on va introduire une fonctionnalité centrale du langage OCaml : **les modules**.

Les modules permettent d'introduire la notion d'encapsulation *(bien connue des programmeurs objet)*. On va cacher la définition du type admin et ranger notre fonction de création d'admin à l'intérieur, et via cette encapsulation, on va pouvoir rendre la création de valeurs de type admin uniquement possible à l'intérieur de ce module *(c'est pour ça qu'on met la fonction `as_admin` dedans)*, via le mot clé private *(également très connu des programmeurs objets ;) )*.

```ocaml
module Admin : sig
  type t = private Admin of user
  val from_user : user -> t option
end = struct
  type t = Admin of user
  let from_user user =
    if is_admin user then Some (Admin user)
    else None
end
```

### Implémentation complète

Bon, après tout ce travail, voici à quoi ressemble l’implémentation complete :

```ocaml=
module Admin : sig
  type t = private Admin of user
  val from_user : user -> t option
end = struct
  type t = Admin of user
  let from_user user =
    if as_admin user then Some (Admin user)
    else None
end

let render_admin_page (Admin.Admin { name ; _}) =
  let open Tyxml.Html in
  div [
    h1 [ txt ("Hello dear Administrator, " ^ name) ] ]


(*
  On peut imaginer que c'est admin_page qui seras utilisée 
  quand un certain endpoint /admin seras appelé
*)
let admin_page context =
  match Admin.from_user context.current_user with
  | Some admin_user ->
    render_admin_panel admin_user
  | None ->
    raise Render404

let main () =
 let user = {name="gholad";...}

 (* Ne compile pas : on peut pas créer d'admin a la volée !! *)
 render_admin_page (Admin user)

```

C'est gagné ! On a rempli notre contrat. L’utilisateur de notre API est guidé, par les types, à l'utilisation correcte de notre API. La valeur `Admin user`, qui nous permet de lancer la fonction `render_admin_page`, est un témoin qu'on est effectivement passé par la fonction `as_admin`, et qu'on ne fait rien d'illégal au regard de notre objectif *(contraindre la page admin aux admins)*.

Pour aller au bout des choses, on devrait également contraindre la création de valeur de type user, pour éviter qu'on puisse appeler `as_admin` en changeant la valeur is_admin à la volée de l'utilisateur qu'on manipule. Mais cette manipulation semble assez peu réaliste *(à moins que l'utilisateur veuille explicitement casser notre système)*.

## Conclusion

**BON**, J'espère que cette première partie a été relativement facile à aborder et digeste pour vous. J'espère surtout qu'elle introduit correctement la colonne vertébrale de cette série d'articles, à savoir la force de modélisation que représentent les types en programmation, et la supériorité tout à fait objective de l'encodage de garanties statiques via ces types, pour forcer l'utilisateur de notre librairie à correctement l'utiliser s'il veut voir son programme compiler.

La deuxième partie se concentrera sur l'encodage d'une machine à état sûre. Je vais introduire de nouvelles constructions d'OCaml venant témoigner petit à petit de la richesse de son système de type et de comment cela peut nous aider à atteindre des niveaux de sécurité satisfaisants sur des programmes bien plus compliqués que ce que nous avons fait là.

N'hésitez pas à me faire des retours et à me poser des questions via le canal de communication sur lequel vous pouvez me joindre.