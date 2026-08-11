// Seed the 17 UN Sustainable Development Goals as permanent nodes
UNWIND [
  {goal: 1,  title: "No Poverty",              icon: "🏚"},
  {goal: 2,  title: "Zero Hunger",             icon: "🌾"},
  {goal: 3,  title: "Good Health & Well-being",icon: "❤"},
  {goal: 4,  title: "Quality Education",        icon: "📚"},
  {goal: 5,  title: "Gender Equality",          icon: "⚧"},
  {goal: 6,  title: "Clean Water & Sanitation", icon: "💧"},
  {goal: 7,  title: "Affordable Clean Energy",  icon: "☀"},
  {goal: 8,  title: "Decent Work & Economic Growth", icon: "📈"},
  {goal: 9,  title: "Industry, Innovation & Infrastructure", icon: "🏗"},
  {goal: 10, title: "Reduced Inequalities",     icon: "⚖"},
  {goal: 11, title: "Sustainable Cities & Communities", icon: "🏙"},
  {goal: 12, title: "Responsible Consumption & Production", icon: "♻"},
  {goal: 13, title: "Climate Action",           icon: "🌍"},
  {goal: 14, title: "Life Below Water",         icon: "🐠"},
  {goal: 15, title: "Life on Land",             icon: "🌳"},
  {goal: 16, title: "Peace, Justice & Strong Institutions", icon: "🕊"},
  {goal: 17, title: "Partnerships for the Goals", icon: "🤝"}
] AS sdg
MERGE (s:SDG {goal: sdg.goal})
SET s.title = sdg.title, s.icon = sdg.icon, s.updated_at = datetime();
