require_relative "config/environment"

# Create plans
plans_data = [
  {
    name: "starter",
    slug: "starter",
    price_cents: 0,
    currency: "USD",
    evaluations_per_month: 2,
    max_candidates: 3,
    employer_verification: false,
    docx_export: false,
    priority_support: false,
    active: true
  },
  {
    name: "professional",
    slug: "professional",
    price_cents: 4900,
    currency: "USD",
    evaluations_per_month: 10,
    max_candidates: 10,
    employer_verification: true,
    docx_export: true,
    priority_support: false,
    active: true
  },
  {
    name: "enterprise",
    slug: "enterprise",
    price_cents: 14900,
    currency: "USD",
    evaluations_per_month: -1, # Unlimited
    max_candidates: -1, # Unlimited
    employer_verification: true,
    docx_export: true,
    priority_support: true,
    active: true
  }
]

plans_data.each do |data|
  Plan.find_or_create(slug: data[:slug]) do |plan|
    plan.name = data[:name]
    plan.price_cents = data[:price_cents]
    plan.currency = data[:currency]
    plan.evaluations_per_month = data[:evaluations_per_month]
    plan.max_candidates = data[:max_candidates]
    plan.employer_verification = data[:employer_verification]
    plan.docx_export = data[:docx_export]
    plan.priority_support = data[:priority_support]
    plan.active = data[:active]
  end
end

puts "Created #{Plan.count} plans"
