#show: doc => article(
  $if(title)$
    title: [$title$],
  $endif$
  $if(subtitle)$
    subtitle: [$subtitle$],
  $endif$
  $if(author)$
    author: [$author$],
  $endif$
  $if(date)$
    date: [$date$],
  $endif$
  $if(institute)$
    institute: [$institute$],
  $endif$
  $if(logo)$
    logo: "$logo$",
  $endif$
    doc,
)