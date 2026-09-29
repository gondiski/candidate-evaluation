require_relative "config/environment"

# Create sample user
user = User.first_or_create(email: "test@example.com") do |u|
  u.password = "password123"
end

puts "Created user: #{user.email}"

# Create sample evaluation
evaluation = Evaluation.first_or_create(user_id: user.id, title: "Sample Senior Developer Role") do |e|
  e.stage = "briefing"
end

puts "Created evaluation: #{evaluation.title}"

# Create sample drivers
drivers_data = [
  { name: "Technical skills", measures: "Depth of technical expertise", how_evidenced: "Projects, certifications, work examples", is_floor: true, position: 0 },
  { name: "Leadership", measures: "Ability to lead teams", how_evidenced: "Team size, outcomes, promotions", is_floor: false, position: 1 },
  { name: "Communication", measures: "Written and verbal skills", how_evidenced: "Publications, presentations, client work", is_floor: false, position: 2 },
  { name: "Problem solving", measures: "Analytical thinking", how_evidenced: "Complex projects, innovations", is_floor: false, position: 3 },
  { name: "Industry knowledge", measures: "Domain expertise", how_evidenced: "Years in industry, specializations", is_floor: true, position: 4 },
  { name: "Delivery track record", measures: "Consistent delivery", how_evidenced: "Project completions, timelines", is_floor: true, position: 5 },
  { name: "Stakeholder management", measures: "Managing relationships", how_evidenced: "Client work, cross-functional projects", is_floor: false, position: 6 },
  { name: "Adaptability", measures: "Handling change", how_evidenced: "Career transitions, new environments", is_floor: false, position: 7 }
]

drivers_data.each do |data|
  Driver.first_or_create(evaluation_id: evaluation.id, name: data[:name]) do |d|
    d.measures = data[:measures]
    d.how_evidenced = data[:how_evidenced]
    d.is_floor = data[:is_floor]
    d.position = data[:position]
  end
end

puts "Created #{drivers_data.length} drivers"

# Create sample kill criteria
kill_criteria_data = [
  { name: "Degree requirement", description: "Must have a relevant degree", position: 0 },
  { name: "Years experience", description: "Must have 5+ years experience", position: 1 },
  { name: "Industry background", description: "Must have relevant industry background", position: 2 }
]

kill_criteria_data.each do |data|
  KillCriterion.first_or_create(evaluation_id: evaluation.id, name: data[:name]) do |kc|
    kc.description = data[:description]
    kc.position = data[:position]
  end
end

puts "Created #{kill_criteria_data.length} kill criteria"

# Create sample human gates
human_gates_data = [
  { name: "Client-facing", question: "Can this person hold a room with clients?", position: 0 },
  { name: "Leadership presence", question: "Do they command respect and inspire confidence?", position: 1 },
  { name: "Craft depth", question: "Is their technical craft genuine or performed?", position: 2 }
]

human_gates_data.each do |data|
  HumanGate.first_or_create(evaluation_id: evaluation.id, name: data[:name]) do |hg|
    hg.question = data[:question]
    hg.position = data[:position]
  end
end

puts "Created #{human_gates_data.length} human gates"

# Create sample weight version
weight_version = WeightVersion.first_or_create(evaluation_id: evaluation.id, version_number: 1) do |wv|
  weights = {}
  evaluation.drivers.each do |d|
    case d.name
    when "Technical skills" then weights[d.id] = 20
    when "Leadership" then weights[d.id] = 15
    when "Communication" then weights[d.id] = 10
    when "Problem solving" then weights[d.id] = 15
    when "Industry knowledge" then weights[d.id] = 15
    when "Delivery track record" then weights[d.id] = 15
    when "Stakeholder management" then weights[d.id] = 5
    when "Adaptability" then weights[d.id] = 5
    end
  end
  
  floor_drivers = evaluation.drivers.select(&:floor?).map(&:id).map(&:to_s)
  
  wv.weights_json = weights.to_json
  wv.floor_driver_ids = floor_drivers.to_json
end

evaluation.update(current_weight_version: 1)
puts "Created weight version"

# Create sample candidates
candidates_data = [
  {
    name: "Alice Johnson",
    label: "CANDIDATE 1",
    cv_text: "Senior Software Engineer with 8 years of experience. BSc Computer Science. Led multiple cloud migration projects at Tech Corp. Strong technical skills in Python, Java, and AWS.",
    tenure_roles: [
      { title: "Junior Developer", company: "Startup Inc", start: "2016-01", end: "2018-06", duration: "2.5 years" },
      { title: "Developer", company: "Mid Corp", start: "2018-07", end: "2020-12", duration: "2.5 years" },
      { title: "Senior Developer", company: "Tech Corp", start: "2021-01", end: "2024-01", duration: "3 years" }
    ]
  },
  {
    name: "Bob Smith",
    label: "CANDIDATE 2",
    cv_text: "Experienced developer with 6 years in fintech. MSc in Computer Science. Built trading systems at Finance Ltd. Good communication skills, presented at 3 conferences.",
    tenure_roles: [
      { title: "Developer", company: "Finance Ltd", start: "2018-01", end: "2022-12", duration: "5 years" },
      { title: "Senior Developer", company: "Bank Corp", start: "2023-01", end: "2024-01", duration: "1 year" }
    ]
  },
  {
    name: "Carol Davis",
    label: "CANDIDATE 3",
    cv_text: "Full-stack developer with 10 years experience. Led team of 5 at Agency Co. Strong in React, Node.js. Published 2 technical articles.",
    tenure_roles: [
      { title: "Developer", company: "Small Agency", start: "2014-01", end: "2018-12", duration: "5 years" },
      { title: "Lead Developer", company: "Agency Co", start: "2019-01", end: "2024-01", duration: "5 years" }
    ]
  }
]

candidates_data.each do |data|
  candidate = Candidate.first_or_create(evaluation_id: evaluation.id, label: data[:label]) do |c|
    c.name = data[:name]
    c.cv_text = data[:cv_text]
    c.tenure_roles = data[:tenure_roles]
    c.kills_list = ["Limited enterprise experience"]
    c.strengths_list = ["Strong technical depth", "Consistent delivery"]
    c.questions = [
      { question: "Tell me about a time you had to convince a skeptical stakeholder", tests: "Stakeholder management" }
    ]
    c.recommendation = "Strong candidate for the role"
  end
  
  # Create scores
  evaluation.drivers.each do |driver|
    score = case driver.name
    when "Technical skills" then 8
    when "Leadership" then 6
    when "Communication" then 7
    when "Problem solving" then 8
    when "Industry knowledge" then 7
    when "Delivery track record" then 8
    when "Stakeholder management" then 5
    when "Adaptability" then 6
    else 5
    end
    
    CandidateScore.first_or_create(candidate_id: candidate.id, driver_id: driver.id) do |cs|
      cs.score = score
      cs.mark = "V"
      cs.evidenced = true
      cs.justification = "Evidence from CV"
    end
  end
  
  # Compute scores
  candidate.compute_scores!
end

puts "Created #{candidates_data.length} candidates"

puts "Seeds completed successfully!"
