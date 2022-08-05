open Yocaml

let pages_destination = "_site/oxywa";;
let css_destination = into pages_destination "css";;
let images_destination = into pages_destination "images";;

let track_binary_update = Build.watch Sys.argv.(0);;

let css =
  process_files [ "css/" ] (with_extension "css")
  (fun file -> Build.copy_file file ~into:css_destination);;

let images =
  let open Preface.Predicate in
  process_files
    [ "images" ]
    (with_extension "png" || with_extension "jpeg")
    (fun file -> Build.copy_file file ~into:images_destination);;

let may_process_markdown file =
  let open Build in
  if with_extension "md" file then
    Yocaml_markdown.content_to_html ()
  else arrow Fun.id;;

let article_destination file =
  let fname = basename file |> into "articles" in
  replace_extension fname "html";;

let pages =
  process_files [ "pages/" ] 
  (fun f -> with_extension "html" f || with_extension "md" f) 
  (fun file ->
      let fname = basename file |> into pages_destination in
      let target = replace_extension fname "html" in
      let open Build in
      create_file
        target
        (track_binary_update
        >>> Yocaml_yaml.read_file_with_metadata (module Metadata.Page) file
        >>> may_process_markdown file
        >>> Yocaml_mustache.apply_as_template (module Metadata.Page) "templates/default.html"
        >>^ Stdlib.snd))
;;

let articles =
  process_files [ "articles/" ] (with_extension "md") (fun file ->
      let open Build in
      let target = article_destination file |> into pages_destination in
      create_file
        target
        (track_binary_update
        >>> Yocaml_yaml.read_file_with_metadata (module Metadata.Article) file
        >>> Yocaml_markdown.content_to_html ()
        >>> Yocaml_mustache.apply_as_template
              (module Metadata.Article)
              "templates/article.html"
        >>> Yocaml_mustache.apply_as_template
              (module Metadata.Article)
              "templates/default.html"
        >>^ Stdlib.snd));;

let index =
  let open Build in
  let* articles =
    collection
      (read_child_files "articles/" (with_extension "md"))
      (fun source ->
        track_binary_update
        >>> Yocaml_yaml.read_file_with_metadata (module Metadata.Article) source
        >>^ fun (x, _) -> x, article_destination source)
      (fun x (meta, content) ->
        x
        |> Metadata.Articles.make
              ?title:(Metadata.Page.title meta)
              ?description:(Metadata.Page.description meta)
        |> Metadata.Articles.sort_articles_by_date
        |> fun x -> x, content)
  in
  create_file
    (into pages_destination "index.html")
    (track_binary_update
    >>> Yocaml_yaml.read_file_with_metadata (module Metadata.Page) "index.md"
    >>> Yocaml_markdown.content_to_html ()
    >>> articles
    >>> Yocaml_mustache.apply_as_template (module Metadata.Articles) "templates/list.html"
    >>> Yocaml_mustache.apply_as_template (module Metadata.Articles) "templates/default.html"
    >>^ Stdlib.snd);;

let () =
  Logs.set_level ~all:true (Some Logs.Debug);
  Logs.set_reporter (Logs_fmt.reporter ())
;;

let () =
  Yocaml_unix.execute (pages >> css >> images >> articles >> index)