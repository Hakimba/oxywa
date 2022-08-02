open Yocaml

let destination = "_build"
let track_binary_update = Build.watch Sys.argv.(0)

let task =
  process_files [ "pages/" ] (with_extension "html") (fun file ->
      let target = basename file |> into destination in
      let open Build in
      create_file
        target
        (track_binary_update
        >>> Yocaml_yaml.read_file_with_metadata (module Metadata.Page) file
        >>> Yocaml_mustache.apply_as_template (module Metadata.Page) "templates/default.html"
        >>^ Stdlib.snd))
;;

let () =
  Yocaml_unix.execute task