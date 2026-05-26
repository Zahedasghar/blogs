// Some definitions presupposed by pandoc's typst output.
#let blockquote(body) = [
  #set text( size: 0.92em )
  #block(inset: (left: 1.5em, top: 0.2em, bottom: 0.2em))[#body]
]

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms: it => {
  it.children
    .map(child => [
      #strong[#child.term]
      #block(inset: (left: 1.5em, top: -0.4em))[#child.description]
      ])
    .join()
}

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let d = (:)
  let fields = old_block.fields()
  fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  return block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subrefnumbering: "1a",
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => numbering(subrefnumbering, n-super, quartosubfloatcounter.get().first() + 1))
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => {
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          }

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let old_title = old_title_block.body.body.children.at(2)

  // TODO use custom separator if available
  let new_title = if empty(old_title) {
    [#kind #it.counter.display()]
  } else {
    [#kind #it.counter.display(): #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block, 
    block_with_new_content(
      old_title_block.body, 
      old_title_block.body.body.children.at(0) +
      old_title_block.body.body.children.at(1) +
      new_title))

  block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color, 
        width: 100%, 
        inset: 8pt)[#text(icon_color, weight: 900)[#icon] #title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}

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
#import "@preview/fontawesome:0.5.0": *

#show: doc => article(
      title: [Adaptive Artificial Intelligence (AAI) as Your Thinking Partner],
        subtitle: [Workshop proposed under the Leadership of Planning and Development & PITB],
        author: [Prof.~Dr.~Zahid Asghar],
        date: [2025-10-01],
        institute: [Planning Monitoring Data and Analytics Section -- UNICEF],
        logo: "unicef\_logo.png",
      doc,
)

= Background
<background>
Artificial Intelligence (AI) is no longer a futuristic concept -- it is a present-day driver of transformation across governance, development planning, and public service delivery. For the Government of Punjab, AI holds particular promise in addressing complex policy challenges, streamlining workflows, and improving the quality and speed of decision-making. From analyzing lengthy policy documents to interpreting large datasets and generating actionable insights, AI can act as a strategic partner to human expertise---amplifying the province's capacity to design, implement, and monitor impactful policies.

However, effective AI integration requires more than just awareness of tools. It demands an understanding of AI's capabilities and limitations, ethical use principles, and the skills to embed AI into day-to-day operations. This workshop responds to that need by equipping Punjab's government officials with the knowledge and hands-on experience to collaborate with AI in ways that are practical, responsible, and directly relevant to their policy and planning responsibilities.

= Workshop Overview
<workshop-overview>
This two-day-long, immersive workshop will introduce participants to the concept of Adaptive AI as a thinking partner -- a collaborator that augments human intelligence rather than replaces it. Through a carefully designed blend of foundational theory, live demonstrations, and interactive exercises, participants will learn how to apply AI for:

- Reviewing and analyzing provincial policy documents with speed and precision.
- Conducting comparative policy assessments to identify best practices and gaps.
- Interpreting and communicating complex datasets in ways that inform strategic decisions.
- Integrating policy and data analysis to produce evidence-based recommendations for provincial leadership.

The training will use real Government of Punjab policy documents and official datasets to ensure that the learning is immediately transferable to participants' work. The sessions will also explore ethical considerations, data privacy safeguards, and techniques to avoid bias in AI-supported decision-making---ensuring that AI use aligns with the principles of transparency, accountability, and equity in governance.

= Objectives
<sec-objectives>
By the end of the workshop, participants will:

+ Understand AI and generative AI fundamentals, and their relevance to governance.
+ Apply AI techniques for in-depth policy document analysis and comparative studies relevant to Punjab.
+ Interpret and communicate complex datasets using AI-assisted workflows.
+ Integrate policy review with performance data for evidence-based recommendations in provincial planning.
+ Develop a personal and departmental roadmap for sustainable AI adoption within the Government of Punjab.

= Key Components
<sec-components>
== Session 1: AI & Generative AI Fundamentals
<session-1-ai-generative-ai-fundamentals>
Foundational concepts, evolution of AI, capabilities of large language models, and live demonstrations of AI in action.

== Session 2: AI for Policy Document Analysis
<session-2-ai-for-policy-document-analysis>
In-depth application of AI for summarization, gap identification, comparative policy review, and implementation readiness assessment using real government policy documents.

== Session 3: AI-Enhanced Data Analysis
<session-3-ai-enhanced-data-analysis>
Using AI to transform raw data into insights through interpretation, executive storytelling, and data visualization tailored for strategic decision-making.

== Session 4: Integrated Document & Data Analysis
<session-4-integrated-document-data-analysis>
Linking policy objectives with performance data through case studies, generating integrated insights, and developing data-backed executive briefs.

== Session 5: Practice Labs -- Build Your Own AI Workflows
<session-5-practice-labs-build-your-own-ai-workflows>
Hands-on session where participants design and test sector-specific AI prompt flows, receive facilitator feedback, and peer-review each other's outputs.

== Session 6: Simulation & Role-Based Application
<session-6-simulation-role-based-application>
Real-time roleplay exercises simulating government decision-making scenarios using AI, with teams presenting outputs and recommendations to the group.

== Session 7: Implementation Strategy & Future Planning
<session-7-implementation-strategy-future-planning>
Developing personal and departmental AI adoption roadmaps, exploring integration strategies, prompt toolkit walkthrough, open Q&A, and workshop close.

= Methodology
<sec-methodology>
The workshop will follow a highly interactive and practice-oriented approach to ensure participants not only understand AI concepts but can confidently apply them in their work. Key features include:

#strong[Foundational Briefings] -- Short, focused presentations to introduce core AI concepts, generative AI fundamentals, and governance applications.

#strong[Live Demonstrations] -- Real-time walkthroughs of AI tools analyzing Government of Punjab policy documents and datasets.

#strong[Hands-on Exercises] -- Guided, step-by-step practice sessions where participants use AI to summarize documents, identify policy gaps, compare policies, interpret datasets, and create executive briefs.

#strong[Case Studies] -- Real-world policy scenarios relevant to Punjab, integrating both document review and performance data analysis to create actionable recommendations.

#strong[Peer Collaboration] -- Small group activities and discussions to encourage cross-departmental knowledge exchange and joint problem-solving.

#strong[Prompt Development Practice] -- Training participants to craft effective AI prompts for different governance tasks (policy analysis, data storytelling, risk assessment).

#strong[Ethics & Safeguards Dialogue] -- Facilitated conversation on responsible AI use, privacy, and bias mitigation in the provincial governance context.

#strong[Action Planning] -- Individual and departmental AI adoption roadmaps to ensure post-workshop continuity and application of learning.

= Expected Outcomes
<sec-outcomes>
#block[
#callout(
body: 
[
#strong[Key Outcomes]

- Development of AI-driven policy and data analysis techniques
- Practical prompt frameworks and toolkits for daily use
- Document review processes are faster and more efficient
- Improved data storytelling and executive communication skills
- A clear strategy for embedding AI into individual and departmental workflows within the Government of Punjab

]
, 
title: 
[
Note
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
, 
body_background_color: 
white
)
]
= Workshop Details
<sec-details>
#block[
#callout(
body: 
[
#strong[Essential Information]

#strong[Duration:] Two Full Days

#strong[Target Audience:] Officials from the Planning & Development Department and other Government of Punjab departments, Academia, PITB, BOS at all experience levels

#strong[Facilitator:] Prof.~Dr.~Zahid Asghar, School of Economics, Quaid-i-Azam University, Islamabad

]
, 
title: 
[
Important
]
, 
background_color: 
rgb("#f7dddc")
, 
icon_color: 
rgb("#CC1914")
, 
icon: 
fa-exclamation()
, 
body_background_color: 
white
)
]
= Day 1 Agenda
<sec-day1>
#strong[AI as Your Thinking Partner]

#strong[Time:] 9:00 AM -- 4:00 PM

#figure([
#table(
  columns: (21.43%, 32.14%, 46.43%),
  align: (auto,auto,auto,),
  table.header([Time], [Session], [Description],),
  table.hline(),
  [9:00 AM -- 9:30 AM], [Workshop Opening & Orientation], [Welcome & Introductions; Objectives & Outcomes; Icebreaker: "What's one AI use case you're curious about?"],
  [9:30 AM -- 11:00 AM], [Session 1: Understanding AI & Generative AI Fundamentals], [What is AI? How it differs from traditional software; Evolution of Generative AI and LLMs; Overview of tools: ChatGPT-5, Claude, Gemini; Government applications; Live Demo: Policy document analysis],
  [11:00 AM -- 11:15 AM], [#strong[Tea Break];], [],
  [11:15 AM -- 1:00 PM], [Session 2: AI for Policy Document Analysis], [Document Analysis Capabilities; Exercise 1: Deep Dive into Punjab Industrial Policy 2025; Exercise 2: Compare Punjab & Sindh Industrial Policies; Exercise 3: Implementation Readiness Framework; Prompting for high-quality insights],
  [1:00 PM -- 2:00 PM], [#strong[Lunch Break];], [],
  [2:00 PM -- 3:30 PM], [Session 3: AI-Enhanced Data Analysis], [How AI transforms data workflows; Exercise 1: Punjab Development Statistics 2024; Exercise 2: Create a CM-level narrative; Visuals: AI-generated charts, narratives, dashboards],
  [3:30 PM -- 4:00 PM], [Reflection & Wrap-Up of Day 1], [Recap key takeaways; Reflection prompt: "What surprised you today?"; Preview of Day 2],
)
], caption: figure.caption(
position: top, 
[
Day 1 Schedule
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-day1>


= Day 2 Agenda
<sec-day2>
#strong[Time:] 9:00 AM -- 4:00 PM

#figure([
#table(
  columns: (21.43%, 32.14%, 46.43%),
  align: (auto,auto,auto,),
  table.header([Time], [Session], [Description],),
  table.hline(),
  [9:00 AM -- 10:30 AM], [Session 4: Integrated Document & Data Analysis], [Case Study: Punjab Education Policy + Literacy Data; Exercise 1: Is the policy working? Evidence-based review; Exercise 2: Create an executive 2-page brief; Advanced collaboration techniques with AI],
  [10:30 AM -- 10:45 AM], [#strong[Tea Break];], [],
  [10:45 AM -- 12:30 PM], [Session 5: Practice Labs -- Create Your Own AI Workflows], [Choose your theme: Health, Education, Energy, Industry, Planning; Design your own prompt flow using real policy + data; Peer-to-peer testing; Facilitator feedback],
  [12:30 PM -- 1:30 PM], [#strong[Lunch Break];], [],
  [1:30 PM -- 2:45 PM], [Session 6: Simulation & Roleplay], [Scenarios: Health emergency planning, Budget prioritization, District-level performance review; Participants act as: Secretary, Analyst, Implementer; Group presentations],
  [2:45 PM -- 3:00 PM], [#strong[Tea Break];], [],
  [3:00 PM -- 4:00 PM], [Session 7: Implementation Strategy & Future Planning], [Personal AI Adoption Plans; Department Integration Roadmap; AI Toolkit Walkthrough; Open Q&A; Evaluation + Feedback; Closing Remarks + Certificate Distribution],
)
], caption: figure.caption(
position: top, 
[
Day 2 Schedule
]), 
kind: "quarto-float-tbl", 
supplement: "Table", 
)
<tbl-day2>


= Key Workshop Deliverables
<sec-deliverables>
== Document Analysis Mastery
<document-analysis-mastery>
+ #strong[Policy Review Automation:] 80% faster document analysis
+ #strong[Comparative Policy Studies:] Cross-jurisdictional best practices
+ #strong[Implementation Readiness Assessment:] Feasibility and risk evaluation

== Data Analysis Excellence
<data-analysis-excellence>
+ #strong[AI Data Interpretation:] Transform statistics into actionable insights
+ #strong[Executive Reporting:] Create compelling data stories
+ #strong[Visualization Strategy:] Design impactful charts with AI guidance

== Integrated Analysis Capabilities
<integrated-analysis-capabilities>
+ #strong[Policy-Data Synthesis:] Combine document review with performance data
+ #strong[Evidence-Based Recommendations:] AI-enhanced policy improvement
+ #strong[Executive Communications:] Clear, actionable briefing notes

= Technical Requirements
<sec-technical>
Participants should ensure they have the following:

- Laptop with internet access
- AI tool accounts (ChatGPT, Claude, or Gemini)
- Sample policy documents (provided)
- Punjab development datasets (provided)
- PDF upload capabilities for document analysis

= Success Metrics
<sec-metrics>
#block[
#callout(
body: 
[
#strong[Expected Impact]

- #strong[70%] reduction in document review time
- #strong[50%] improvement in data analysis speed
- Enhanced policy recommendation quality
- Measurable productivity gains within 30 days

]
, 
title: 
[
Tip
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
, 
body_background_color: 
white
)
]

#horizontalrule

#emph[This workshop bridges AI technology with governance needs, empowering Punjab's officials to leverage AI as a strategic thinking partner for evidence-based policy making and effective public service delivery.]
