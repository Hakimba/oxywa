---
date: 2022-08-04
article_title: Un guide simple pour rajouter une page inutile dans muhokama.
article_description: Un truc que j'ai écrit pour garder une trace de mon exploration du code de muhokama, et pour en aider d'autres dans la leur.
---

Plutot qu'un guide, c'est surtout un truc que j'ai écrit pour garder une trace de mon exploration du code de muhokama, donc pas très structuré, imprécis et probablement faux sur certaines explication. ça pourrais en devenir un avec + de travail

Mais ce *"guide"* devrais permettre d'avoir une intuition très rapidement de toute les étapes a suivre pour rajouter une page dans muhokama from scratch, en tout cas c'est l'intention.

L'architecture de l'application est un MVC, mais pour notre guide nous n'allons pas regarder la partie modèle.

Et toute ses parties sont divisé en ombrelles conceptuelles, qui sont pour l'instant : 
1. admin : les fonctionnalités disponible pour le role d'administrateur
2. user : les fonctionnalités disponible pour les utilisateurs
3. topics : les fonctionnalités qui décrivent le système de conversation
4. global : les fonctionnalités les plus globales 

Dans ce guide on va créer une nouvelle page pour les utilisateurs, donc on va se concentrer sur les fichiers préfixé par `user` pour coder notre page.

Je propose un ordre des fichiers a traiter pour rajouter une page dans Muhokama, selon l'ombrelle conceptuelle* dans laquelle on veut l'ajouter. Dans notre cas ça se feras dans cet ordre :
1. `user_endpoint.ml`
2. `user_services.ml` (et son mli)
3. `user_views.ml` (et son mli)
4. `router.ml`
    
### Ajouter une route
    
On va commencer par rajouter une route dans `user_endpoint.ml`

```
open Lib_service.Endpoint

let create () = get (~/"user" / "new")
let login () = get (~/"user" / "login")
let save () = post (~/"user" / "new")
let auth () = post (~/"user" / "auth")
let leave () = get (~/"user" / "leave")
let list () = get (~/"user" / "list")

(** notre nouvelle route **)
let dummy () = get (~/"user" / "dummy")
```

C'est intuitif et limpide donc je ne sais pas quoi expliquer.

### Coder le service

Je ne suis pas a l'aise avec la notion de service (je ne saurais pas definir le scope de ce que c'est ou non qu'un service), mais partons du principe que une fonctionnalité du site est un service, ici on veut créer une nouvelle page qui feras rien du tout, et c'est un service.

Si je veux coder un nouveau service pour les utilisateurs, je vais rajouter mon code dans`app/services/user_services.ml`

Notre page étant très simple, on défini le service via `Services.straight`, qui correspond exactement a un service simple.

L'architecture d'un service straight c'est :
* Un endpoint.
* Un ou des middleware.
* Une fonction qui représente la fonctionnalité en question.

Donc dans notre cas ça donne :

```
let dummy =
  Service.straight ~:Endpoints.User.dummy [user_authenticated]
  (fun _ ->
    let view = Views.User.dummy () in
    Dream.html @@ from_tyxml view
  )
;;
```

On voit que j'ai attaché mon endpoint fraichement créé dans la section précédente, mon service necessite que l'utilisateur soit connecté donc on utilise le middleware `user_authenticated`, et enfin, la fonctionnalité... qui ne fais rien, a par appeler une vue.

### Coder la vue associée au service

Nous allons maintenant coder la vue de notre page inutile, qui afficheras simplement *"dummy page"*. Les vues sont aussi organisé en ombrelles conceptuelles, et ici ce qui nous intérésse c'est le fichier `app/view/user_views.ml`. On y trouve des fonctions, qui représentent toute une vue, écrite dans un DSL qui permet d'exprimer du HTML.

On peut directement aller a la fin du fichier, et ajouter notre vue très simple.

```
let dummy () =
  Templates.Layout.default
    ~lang:"fr"
    ~page_title:"Dummy page"
    Tyxml.Html.
      [
        div [txt "Dummy page"]
      ]
;;
```

Je ne veux pas écrire le design de la page moi meme, donc j'utilise le design commun a toute les pages du site, qui est est accesible via `Templates.Layout.default`. 

La documentation associé a ce layout est détaillée sur les arguments optionnel utilisable et leurs types, moi je me contente de renseigner la langue et le titre de la page, ensuite vous pouvez directement écrire le contenu HTML de la page, qui se résume ici a un texte dans une div. *(je ne peux pas encore expliquer Tyxml.Html)*

### Brancher le service au site

Après avoir codé tout notre service, la dernière étape reste de la rendre accessible sur le site ! Et ça se passe du coté de `app/router.ml`

Exemple

```
Lib_service.Service.choose
    method_
    uri
    [ Services.User.login
    ; Services.User.create
    ; Services.User.save
    ; Services.User.auth
    ; Services.User.leave
    ; Services.User.list_active
    ; Services.Topic.create
    ; Services.Topic.save
    ; Services.Topic.answer
    ; Services.Topic.list
    ; Services.Topic.list_by_category
    ; Services.Topic.show
    ; Services.Admin.root
    ; Services.Admin.user
    ; Services.Admin.user_state_change
    ; Services.Admin.category
    ; Services.Admin.new_category
    ; Services.Global.error
    ; Services.Global.root
    ]
```

C'est un extrait de code du fichier, ou on peut voir que chaque service codé dois etre "branché". Si on en enlève un, il ne seras plus disponible sur le site (vous aurez en réponse une erreur 404 si vous essayez d'atteindre ce service).

On voit bien que les services y sont séparé en fonction de l'ombrelle conceptuelle* auxquels ils sont rattaché, le service de login c'est un service propre aux utilisateurs du site, par exemple.

### Lancer Muhokama

Après cette dernière étape, vous pouvez build avec `make` et lancer l'application avec `./bin/muhokama.exe server.launch`.

Premier test, vous pouvez essayez d'acceder a la route que vous avez créer sans etre connecté, vous verrez que vous serez redirigé vers la page de connection grace au middleware `user_authenticated`.

Ensuite vous pouvez vous connecter et essayer `http://localhost:<votreport>/user/dummy` et vous verrez votre page inutile !

*~~(ouais c'est chelou on voit les boutons 'se connecter' etc, faut que je refasse un screen avec le fix)~~*

![](https://i.imgur.com/t8Yptba.png)


* **ombrelle conceptuelle** : je sais pas comment appeler l'ensemble {admin, topics, global, users} pour écrire des phrases dessus, donc j'ai prit la proposition de Xavier, *"ombrelle conceptuelle"*. J'ai hésité entre ça et *"Une forêt de liens ne demandant qu'à être utilisés !"*