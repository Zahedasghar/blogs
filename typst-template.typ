#import "@preview/titleize:0.1.1": titlecase

#let blueline() = {
  line(length: 100%, stroke: 2pt + rgb("#68ACE5"))
}

#let source(color: black, body) = {
  align(right)[#text(body, style: "italic", font: ("Georgia", "Times New Roman"), size: 9pt, fill: color)]
}

#let status-boxes(top-text: "", bottom-text: "") = {
  let bluerect = box(
    width: 100%,
    height: 0.7in,
    fill: rgb("#002D72"),
    inset: 6pt,
    align(center + horizon)[
      #text(fill: white, weight: "bold", size: 9pt)[#top-text]
    ],
  )

  let redrect = box(
    width: 100%,
    height: 0.7in,
    fill: white,
    inset: 6pt,
    align(center + horizon)[
      #text(fill: black, size: 14pt)[#bottom-text]
    ],
  )

  stack(dir: ttb, bluerect, redrect, spacing: 0pt)
}

#let connected-boxes(text1: "", text2: "") = {
  let box-style = (
    width: auto,
    fill: rgb("#002D72"),
    inset: (y: 10pt, x: 20pt),
  )

  let left = box(
    ..box-style,
    align(center + horizon)[
      #text(fill: white, weight: "bold", font: ("Georgia", "Times New Roman"), text1)
    ],
  )

  let right = box(
    ..box-style,
    align(center + horizon)[
      #text(fill: white, weight: "bold", font: ("Georgia", "Times New Roman"), text2)
    ],
  )

  let connector = align(center + horizon)[
    #line(
      length: 61pt,
      stroke: (paint: rgb("#68ACE5"), thickness: 3pt),
    )
  ]

  // Now we return three elements: left box, connector, right box
  (left, connector, right)
}

#let chart-title(body) = {
  v(7pt)
  align(center)[#text(
    body,
    fill: rgb("#002D72"),
    font: ("Arial", "Liberation Sans"),
    weight: "medium",
  )]
}

#let to-string(it) = {
  if type(it) == str {
    it
  } else if type(it) != content {
    str(it)
  } else if it.has("text") {
    it.text
  } else if it.has("children") {
    it.children.map(to-string).join()
  } else if it.has("body") {
    to-string(it.body)
  } else if it == [ ] {
    " "
  }
}

#let article(
  title: none,
  subtitle: none,
  author: none,
  date: none,
  institute: none,
  logo: none,
  doc,
) = {
  
  set text(
    lang: "en", 
    region: "US", 
    font: ("Arial", "Liberation Sans", "DejaVu Sans"), 
    size: 11pt, 
    weight: "regular"
  )

  set page(
    paper: "us-letter",
    margin: (x: 0.8in, bottom: 1in, top: 0.5in),
    footer: {
      rect(
        width: 100%,
        height: 0.75in,
        outset: (x: 15%),
        fill: rgb("#68ACE5"),
        pad(top: 16pt, block(width: 100%, fill: rgb("#68ACE5"), [
          #grid(
            columns: (3fr, auto, 1fr),
            align(left)[#text(title, fill: white, weight: 600, font: ("Georgia", "Times New Roman"))],
            align(center)[],
            align(right)[#text(date, fill: white, weight: 600, font: ("Georgia", "Times New Roman"))],
          )
        ])),
      )
    },
  )

  show heading: it => {
    let sizes = (
      "1": 16pt, // Heading level 1
      "2": 14pt, // Heading level 2
      "3": 13pt, // Heading level 3
      "4": 12pt, // Heading level 4
    )
    let level = str(it.level)
    let size = if level in sizes { sizes.at(level) } else { 11pt }
    let heading_color = if level == "1" { rgb("#002D72") } else { black }

    set text(size: size, fill: heading_color, font: ("Georgia", "Times New Roman"), weight: "bold")

    v(0.5em)
    it
    v(0.3em)
  }

  // Title page header
  stack(
    // Logo (if provided)
    if logo != none {
      place(dx: 0.2in, dy: 0.25in, align(horizon, block(width: 3in, [
        #image(logo, width: 2.5in)
      ])))
    },
    
    // Blue line separator
    place(dx: 0in, dy: 1.2in, align(block([
      #blueline()
    ]))),
    
    // Title
    place(dx: 0in, dy: 1.45in, align(block(width: 100%, [
      #text(
        fill: rgb("#002D72"), 
        weight: "bold", 
        size: 20pt, 
        font: ("Georgia", "Times New Roman"),
        title
      )
    ]))),
    
    // Subtitle
    if subtitle != none {
      place(dx: 0in, dy: 2.0in, align(block(width: 100%, [
        #text(
          fill: rgb("#002D72"), 
          weight: "regular", 
          size: 16pt, 
          font: ("Georgia", "Times New Roman"),
          style: "italic",
          subtitle
        )
      ])))
    },
    
    // Author and Institute
    place(dx: 0in, dy: if subtitle != none { 2.5in } else { 2.2in }, align(block(width: 100%, [
      #if author != none {
        text(size: 12pt, weight: "medium", author)
      }
      #if institute != none {
        linebreak()
        text(size: 11pt, style: "italic", institute)
      }
    ]))),
  )

  v(if subtitle != none { 3.2in } else { 2.8in }) // margin before main content
  blueline()
  v(0.5em)

  doc
}