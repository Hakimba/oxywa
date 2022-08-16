# Oxywa

My first blog, built with [YOCaml](https://github.com/xhtmlboi/yocaml)

[Oxywa](https://hakimba.github.io/oxywa/)

I shamelessly stole this whole local installation part from https://github.com/xvw/capsule, because i like this method and he taught it to me that way.

## Local installation

The most standard way to start a development environment is to build a "_local
switch_" by sequentially running these different commands (which assume that
[OPAM](https://opam.ocaml.org/) is installed on your machine).

```shellsession
opam update
opam switch create . ocaml-base-compiler.4.14.0 --deps-only -y
eval $(opam env)
```

Once the switch has been initialized, you need to install _the pinned
dependencies_ (at the time of writing this README, **YOCaml is not yet available
on OPAM**, which is very **sad**), by running these commands:

```shellsession
opam install yocaml
opam install yocaml_unix yocaml_yaml yocaml_markdown yocaml_mustache
```

And then, if everything goes well, you have to build the code with

`dune build` (at the root of the project)

And if everything goes well again, you can run it with

`dune exec bin/main.exe`