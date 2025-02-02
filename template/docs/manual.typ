#import "@preview/tidy:0.3.0"

#import "template.typ": *

#import "../src/lib.typ" as template

#let package-meta = toml("../typst.toml").package
#let date = none
// #let date = datetime(year: ..., month: ..., day: ...)

#show: project.with(
  title: "Template",
  // subtitle: "...",
  authors: package-meta.authors.map(a => a.split("<").at(0).trim()),
  abstract: [
    A template for typst packages
  ],
  url: package-meta.repository,
  version: package-meta.version,
  date: date,
)

// the scope for evaluating expressions and documentation
#let scope = (template: template)

= Introduction

This is a template for typst packages. It provides, for example, the #ref-fn("template.add()") function:

#{
  let lines = read("../gallery/test.typ").trim().split("\n")
  lines = lines.slice(4)
  raw(block: true, lang: "typ", lines.join("\n"))
}

= Module reference

== `template`

#{
  let module = tidy.parse-module(
    read("../src/lib.typ"),
    label-prefix: "template.",
    scope: scope,
  )
  tidy.show-module(
    module,
    sort-functions: none,
    style: tidy.styles.minimal,
  )
}
