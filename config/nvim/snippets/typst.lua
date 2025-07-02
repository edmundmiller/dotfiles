-- Typst snippets for LuaSnip
local ls = require("luasnip")
local s = ls.snippet
local sn = ls.snippet_node
local t = ls.text_node
local i = ls.insert_node
local f = ls.function_node
local c = ls.choice_node
local d = ls.dynamic_node
local r = ls.restore_node
local fmt = require("luasnip.extras.fmt").fmt
local rep = require("luasnip.extras").rep

return {
  -- Document template
  s("doc", fmt([[
#set document(
  title: "{}",
  author: "{}",
  date: {}
)

#set page(
  paper: "{}",
  margin: {}
)

#set text(
  font: "{}",
  size: {}pt
)

#set heading(numbering: "{}")

#show link: underline

= {}

{}
]], {
    i(1, "Document Title"),
    i(2, "Author Name"),
    c(3, {
      t("auto"),
      fmt('datetime(year: {}, month: {}, day: {})', { i(1, "2024"), i(2, "1"), i(3, "1") }),
    }),
    c(4, {
      t("a4"),
      t("us-letter"),
      t("a3"),
    }),
    c(5, {
      t("1in"),
      t("(x: 1in, y: 1in)"),
      t("(top: 1in, bottom: 1in, left: 1.25in, right: 1.25in)"),
    }),
    c(6, {
      t("Linux Libertine"),
      t("New Computer Modern"),
      t("Times New Roman"),
    }),
    i(7, "11"),
    c(8, {
      t("1.1"),
      t("\"1.\""),
      t("\"1.1.\""),
    }),
    i(9, "Introduction"),
    i(10, "Content goes here."),
  })),

  -- Academic paper template
  s("paper", fmt([[
#set document(
  title: "{}",
  author: ({}),
  keywords: ({})
)

#set page(paper: "a4", margin: 1in)
#set text(font: "Linux Libertine", size: 11pt)
#set heading(numbering: "1.")
#set cite(style: "chicago-author-date")

#show link: underline
#show cite: it => text(blue, it)

#align(center)[
  #text(17pt, weight: "bold")[{}]
  
  #v(8pt)
  
  #text(12pt)[{}]
  
  #v(8pt)
  
  #text(10pt)[{}]
]

#v(20pt)

= Abstract

{}

#v(12pt)

= Introduction

{}

= Methods

{}

= Results

{}

= Discussion

{}

= Conclusion

{}

#bibliography("{}")
]], {
    i(1, "Paper Title"),
    i(2, '"Author One", "Author Two"'),
    i(3, '"keyword1", "keyword2", "keyword3"'),
    rep(1), -- Title again
    i(4, "Author One¹, Author Two²"),
    i(5, "¹University Name, ²Institution Name"),
    i(6, "Abstract content goes here..."),
    i(7, "Introduction content..."),
    i(8, "Methodology description..."),
    i(9, "Results and findings..."),
    i(10, "Discussion of results..."),
    i(11, "Concluding remarks..."),
    i(12, "references.bib"),
  })),

  -- Letter template
  s("letter", fmt([[
#set document(title: "Letter")
#set page(
  paper: "a4",
  margin: (x: 1.5in, y: 1in)
)
#set text(font: "Linux Libertine", size: 11pt)

#grid(
  columns: (1fr, 1fr),
  align(left)[
    {}
    
    {}
  ],
  align(right)[
    {}
  ]
)

#v(24pt)

{}

#v(12pt)

Dear {},

{}

Sincerely,

#v(36pt)

{}
]], {
    i(1, "Your Name\nYour Address\nCity, State ZIP"),
    i(2, "your.email@domain.com\n(555) 123-4567"),
    i(3, "Date: March 15, 2024"),
    i(4, "Recipient Name\nRecipient Address\nCity, State ZIP"),
    i(5, "Recipient Name"),
    i(6, "Letter content goes here..."),
    i(7, "Your Name"),
  })),

  -- Presentation template
  s("slides", fmt([[
#import "@preview/polylux:0.3.1": *

#set page(paper: "presentation-16-9")
#set text(font: "Linux Libertine", size: 20pt)

#show: polylux-theme

#title-slide[
  #align(center + horizon)[
    #text(32pt, weight: "bold")[{}]
    
    #v(12pt)
    
    #text(18pt)[{}]
    
    #v(8pt)
    
    #text(14pt)[{}]
  ]
]

#slide[
  = {}
  
  {}
]

#slide[
  = {}
  
  {}
]
]], {
    i(1, "Presentation Title"),
    i(2, "Subtitle"),
    i(3, "Author Name • Date"),
    i(4, "Introduction"),
    i(5, "Content for the first slide..."),
    i(6, "Second Slide"),
    i(7, "Content for the second slide..."),
  })),

  -- Math theorem
  s("theorem", fmt([[
#theorem[{}][
  {}
]
]], {
    i(1, "Theorem Name"),
    i(2, "Theorem statement goes here."),
  })),

  -- Math proof
  s("proof", fmt([[
#proof[
  {}
]
]], {
    i(1, "Proof content goes here..."),
  })),

  -- Code block
  s("code", fmt([[
```{}
{}
```
]], {
    i(1, "python"),
    i(2, "# Code goes here"),
  })),

  -- Figure
  s("figure", fmt([[
#figure(
  image("{}"),
  caption: [{}]
) <{}>
]], {
    i(1, "image.png"),
    i(2, "Figure caption"),
    i(3, "fig:label"),
  })),

  -- Table
  s("table", fmt([[
#figure(
  table(
    columns: {},
    stroke: none,
    table.hline(),
    [{}], [{}],
    table.hline(stroke: 0.6pt),
    [{}], [{}],
    [{}], [{}],
    table.hline(),
  ),
  caption: [{}]
) <{}>
]], {
    i(1, "2"),
    i(2, "Column 1"),
    i(3, "Column 2"),
    i(4, "Row 1 Data"),
    i(5, "Row 1 Data"),
    i(6, "Row 2 Data"),
    i(7, "Row 2 Data"),
    i(8, "Table caption"),
    i(9, "tab:label"),
  })),

  -- Bibliography
  s("bib", fmt([[
#bibliography("{}", style: "{}")
]], {
    i(1, "references.bib"),
    c(2, {
      t("ieee"),
      t("apa"),
      t("chicago-author-date"),
      t("mla"),
    }),
  })),

  -- Cite
  s("cite", fmt([[
@{}
]], {
    i(1, "reference_key"),
  })),

  -- Link
  s("link", fmt([[
#link("{}")[{}]
]], {
    i(1, "https://example.com"),
    i(2, "Link text"),
  })),

  -- Emphasis
  s("em", fmt([[
*{}*
]], {
    i(1, "emphasized text"),
  })),

  -- Strong
  s("strong", fmt([[
**{}**
]], {
    i(1, "strong text"),
  })),

  -- Math inline
  s("math", fmt([[
${}$
]], {
    i(1, "x^2 + y^2 = z^2"),
  })),

  -- Math block
  s("equation", fmt([[
$ {} $ <{}>
]], {
    i(1, "x^2 + y^2 = z^2"),
    i(2, "eq:label"),
  })),

  -- Section
  s("sec", fmt([[
= {}

{}
]], {
    i(1, "Section Title"),
    i(2, "Section content..."),
  })),

  -- Subsection
  s("subsec", fmt([[
== {}

{}
]], {
    i(1, "Subsection Title"),
    i(2, "Subsection content..."),
  })),

  -- List
  s("list", fmt([[
- {}
- {}
- {}
]], {
    i(1, "First item"),
    i(2, "Second item"),
    i(3, "Third item"),
  })),

  -- Numbered list
  s("enum", fmt([[
1. {}
2. {}
3. {}
]], {
    i(1, "First item"),
    i(2, "Second item"),
    i(3, "Third item"),
  })),

  -- Quote
  s("quote", fmt([[
#quote[
  {}
]
]], {
    i(1, "Quote content goes here..."),
  })),
}