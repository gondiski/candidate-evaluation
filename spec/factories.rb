FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { "password123" }
  end

  factory :evaluation do
    association :user
    title { Faker::Job.title }
    stage { "briefing" }
  end

  factory :driver do
    association :evaluation
    name { Faker::Job.key_skill }
    measures { Faker::Lorem.sentence }
    how_evidenced { Faker::Lorem.sentence }
    is_floor { false }
    position { 0 }
  end

  factory :kill_criterion do
    association :evaluation
    name { Faker::Lorem.word }
    description { Faker::Lorem.sentence }
    position { 0 }
  end

  factory :weight_version do
    association :evaluation
    version_number { 1 }
    weights_json { { "1" => 50, "2" => 50 }.to_json }
    floor_driver_ids { ["1", "2"].to_json }
  end

  factory :human_gate do
    association :evaluation
    name { Faker::Lorem.word }
    question { Faker::Lorem.sentence }
    position { 0 }
  end

  factory :candidate do
    association :evaluation
    name { Faker::Name.name }
    label { "CANDIDATE 1" }
    cv_text { Faker::Lorem.paragraphs(number: 3).join("\n") }
  end

  factory :candidate_score do
    association :candidate
    association :driver
    score { rand(0..10) }
    mark { %w[V I].sample }
    evidenced { true }
    justification { Faker::Lorem.sentence }
  end

  factory :employer do
    association :evaluation
    name { Faker::Company.name }
    legal_name { "#{Faker::Company.name} Ltd" }
    trading_name { Faker::Company.name }
    footprint { rand(0..10) }
    status { "trading" }
  end

  factory :employer_source do
    association :employer
    url { Faker::Internet.url }
    retrieved_at { Time.now }
  end

  factory :claim do
    association :employer
    association :candidate
    cv_claim { Faker::Lorem.sentence }
    classification { "CONFIRMED" }
    search_description { Faker::Lorem.sentence }
  end

  factory :gate_mark do
    association :candidate
    association :human_gate
    mark { "YES" }
    note { nil }
  end

  factory :stage_run do
    association :evaluation
    stage_number { 1 }
    status { "completed" }
    started_at { Time.now }
    completed_at { Time.now }
  end

  factory :report do
    association :evaluation
    issue_type { "pre_interview" }
    file_path { "/tmp/test_report.pdf" }
    generated_at { Time.now }
  end
end
